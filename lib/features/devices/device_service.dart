import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'device_repository.dart';
import 'web_push_service.dart';
import 'windows_push_service.dart';

class DeviceService {
  DeviceService(this._repository, {bool Function()? isAuthed})
      : _isAuthed = isAuthed ?? (() => true);

  final DeviceRepository _repository;

  /// Auth gate. Read every time we are about to hit a `/devices/*` endpoint
  /// so a signed-out app — including a public-route navigation after a token
  /// expiry — never produces 401 spam from `PATCH /v1/devices/<cached-id>`.
  /// Defaults to `true` for tests / direct construction without a ref so the
  /// previous behaviour is preserved when no callback is supplied.
  final bool Function() _isAuthed;

  static const _deviceIdKey = 'aura_device_id';
  static const _presenceDebounce = Duration(minutes: 30);

  String? _cachedDeviceId;
  DateTime? _lastPresenceRefresh;
  StreamSubscription<String>? _tokenRefreshSub;
  bool _tokenRefreshBound = false;

  /// In-flight coalescing handle. App boot, auth-transition listener, and
  /// lifecycle resume can all schedule a registerCurrentDevice within the
  /// same frame; without coalescing each fires its own POST/PATCH and the
  /// backend ends up creating duplicate device rows or racing on update.
  /// Concurrent callers await the same Future and resolve together.
  Future<void>? _registerInFlight;

  /// Registers the current device only when a valid payload can be built.
  ///
  /// On web, this is a no-op when no active push subscription exists.
  /// On Android, this uses FCM and requires a non-empty FCM token.
  /// On iOS, APNS/FCM wiring will be finalized separately.
  Future<void> registerCurrentDevice() async {
    // Hard gate: every callsite (app boot, auth transition, lifecycle resume,
    // FCM token refresh) is supposed to check auth before dispatching, but a
    // single missed gate produces console-visible 401 spam on public routes.
    // Failing closed here makes the contract impossible to violate.
    if (!_isAuthed()) return;

    // Coalesce concurrent calls. If a registration is already running, just
    // return its Future — duplicates would race the deviceId upsert and
    // produce duplicate device records on the backend.
    final inFlight = _registerInFlight;
    if (inFlight != null) {
      return inFlight;
    }

    final task = _doRegisterCurrentDevice();
    _registerInFlight = task;
    try {
      await task;
    } finally {
      // Clear only if this is still the current handle — a later call may
      // have replaced it.
      if (identical(_registerInFlight, task)) {
        _registerInFlight = null;
      }
    }
  }

  Future<void> _doRegisterCurrentDevice() async {
    try {
      // On Android 13+ POST_NOTIFICATIONS is a runtime permission. Request it
      // here so the OS surface a prompt the first time we have an authed user
      // even if the explicit security-screen flow was never opened. Without
      // this, a token can register but the system suppresses delivery.
      await _ensureNativePushPermission();

      final payload = await _buildPayload();
      if (payload == null) {
        // BIND FIRST, GIVE UP SECOND.
        //
        // This used to return here, before `_bindTokenRefresh()` at the bottom
        // of the method. On iOS that made the whole thing single-shot: the
        // first `getToken()` came back null because APNs had not finished
        // registering, we returned, and the listener that would have caught
        // the token arriving a second later was never attached. The device
        // never registered, and the only trace was a debugPrint.
        //
        // Binding before the early return costs nothing when a token is
        // already in hand and is the difference between a deferred
        // registration and none at all.
        _bindTokenRefresh();
        return;
      }

      final id = _cachedDeviceId ?? await _loadPersistedDeviceId();
      if (id != null && id.isNotEmpty) {
        await _repository.updateDevice(id, payload);
        _cachedDeviceId = id;
      } else {
        final device = await _repository.register(payload);
        if (device.id.isNotEmpty) {
          _cachedDeviceId = device.id;
          await _persistDeviceId(device.id);
        }
      }

      _bindTokenRefresh();
    } catch (e) {
      debugPrint('DeviceService.registerCurrentDevice failed: $e');
    }
  }

  Future<void> _ensureNativePushPermission() async {
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
    } catch (e) {
      debugPrint('DeviceService._ensureNativePushPermission failed: $e');
    }
  }

  /// Register the PushKit VoIP token as its OWN device row.
  ///
  /// A VoIP token is not an FCM token wearing a different hat. It comes from a
  /// different registry, rotates on its own schedule, and APNs delivers to it
  /// on a different topic (`<bundle>.voip`) with a different push type. Writing
  /// it into the FCM row would produce a registration that looks healthy and
  /// receives nothing — the same class of silent failure that kept the iPhone
  /// quiet in the first place.
  ///
  /// So it is registered as `provider: APNS`, which no client has ever used and
  /// which the backend's direct APNs adapter already serves. That makes the
  /// provider itself the discriminator: on iOS, an APNS row means PushKit, and
  /// an FCM row means the ordinary alert path. One person on one iPhone
  /// legitimately has both.
  Future<void> registerVoipToken(String token) async {
    if (kIsWeb || token.trim().isEmpty) return;
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    if (!_isAuthed()) return;
    try {
      final payload = <String, dynamic>{
        'platform': 'IOS',
        'provider': 'APNS',
        'token': token.trim(),
        'deviceName': '${_resolveDeviceName()} (calls)',
        'appVersion': const String.fromEnvironment(
          'APP_VERSION',
          defaultValue: '1.0.0',
        ),
        'locale': _resolveLocale(),
        'timezone': _resolveTimezone(),
        'isActive': true,
      };
      final id = await _loadPersistedVoipDeviceId();
      if (id != null && id.isNotEmpty) {
        await _repository.updateDevice(id, payload);
      } else {
        final device = await _repository.register(payload);
        if (device.id.isNotEmpty) await _persistVoipDeviceId(device.id);
      }
      debugPrint('[callkit] voip device registered');
    } catch (e) {
      debugPrint('DeviceService.registerVoipToken failed: $e');
    }
  }

  /// iOS invalidated the VoIP token. Deactivate rather than delete, so the
  /// backend stops attempting delivery to a credential Apple has retired
  /// without losing the row's history.
  Future<void> deactivateVoipDevice() async {
    final id = await _loadPersistedVoipDeviceId();
    if (id == null || id.isEmpty || !_isAuthed()) return;
    try {
      await _repository.updateDevice(id, {'isActive': false});
    } catch (e) {
      debugPrint('DeviceService.deactivateVoipDevice failed: $e');
    }
  }

  static const _kVoipDeviceId = 'aura_voip_device_id';

  Future<String?> _loadPersistedVoipDeviceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_kVoipDeviceId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _persistVoipDeviceId(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kVoipDeviceId, id);
    } catch (_) {
      // Non-fatal: a lost id means the next registration creates a new row
      // rather than updating this one, which the backend tolerates.
    }
  }

  /// Persist any FCM token rotation pushed by Firebase. Without this the
  /// backend keeps a stale token after the OS rotates it, and offline rings
  /// stop arriving silently.
  void _bindTokenRefresh() {
    if (_tokenRefreshBound || kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    try {
      _tokenRefreshSub =
          FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        if (newToken.isEmpty) return;
        // Same gate as registerCurrentDevice — a token rotation that
        // arrives while signed out must not hit /v1/devices/*.
        if (!_isAuthed()) return;
        try {
          final id = _cachedDeviceId ?? await _loadPersistedDeviceId();
          final platform =
              defaultTargetPlatform == TargetPlatform.iOS ? 'IOS' : 'ANDROID';
          final payload = <String, dynamic>{
            'platform': platform,
            'provider': 'FCM',
            'token': newToken,
            'isActive': true,
          };
          if (id != null && id.isNotEmpty) {
            await _repository.updateDevice(id, payload);
          } else {
            final device = await _repository.register(payload);
            if (device.id.isNotEmpty) {
              _cachedDeviceId = device.id;
              await _persistDeviceId(device.id);
            }
          }
        } catch (e) {
          debugPrint('DeviceService.onTokenRefresh sync failed: $e');
        }
      });
      _tokenRefreshBound = true;
    } catch (e) {
      debugPrint('DeviceService._bindTokenRefresh failed: $e');
    }
  }

  Future<void> revokeCurrentDevice() async {
    final id = _cachedDeviceId ?? await _loadPersistedDeviceId();
    try {
      // Best-effort backend revoke. A failure must not leave the cached id
      // dangling — that's exactly what produced the post-logout 401 spam
      // when the next visit re-attempted PATCH /v1/devices/<old-id>.
      if (id != null && id.isNotEmpty && _isAuthed()) {
        await _repository.revokeDevice(id);
      }
    } catch (e) {
      debugPrint('DeviceService.revokeCurrentDevice failed: $e');
    } finally {
      // Always clear local handle regardless of backend result.
      _cachedDeviceId = null;
      await _clearPersistedDeviceId();
      await _tokenRefreshSub?.cancel();
      _tokenRefreshSub = null;
      _tokenRefreshBound = false;
    }
  }

  /// Re-registers on app resume, throttled to once per 30 minutes.
  Future<void> refreshPresence() async {
    if (!_isAuthed()) return;
    final now = DateTime.now();
    if (_lastPresenceRefresh != null &&
        now.difference(_lastPresenceRefresh!) < _presenceDebounce) {
      return;
    }
    _lastPresenceRefresh = now;
    await registerCurrentDevice();
  }

  /// Called from user-initiated browser permission UX.
  Future<bool> requestAndRegisterWebPush(String vapidKey) async {
    if (!kIsWeb) return false;
    if (vapidKey.isEmpty) return false;
    if (!_isAuthed()) return false;

    try {
      final perm = await WebPushService.requestPermission();
      if (perm != 'granted') return false;

      final sub = await WebPushService.subscribe(vapidKey);
      if (sub == null || sub.endpoint.isEmpty) return false;

      final payload = _webPushPayload(sub);
      await _upsertCurrentDevice(payload);
      return true;
    } catch (e) {
      debugPrint('DeviceService.requestAndRegisterWebPush failed: $e');
      return false;
    }
  }

  /// Called from user-initiated native notification permission UX.
  ///
  /// Android:
  /// - Android 13+ may show a runtime notification permission prompt.
  /// - FCM token registration can succeed only when Firebase is configured.
  ///
  /// iOS:
  /// - Kept safe for later APNS work, but the final iOS/APNS pass should
  ///   validate capabilities, APNS key/cert, entitlements, and foreground
  ///   presentation behavior.
  Future<bool> requestAndRegisterNativePush() async {
    if (kIsWeb) return false;
    if (!_isAuthed()) return false;

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        break;
      default:
        return false;
    }

    try {
      final messaging = FirebaseMessaging.instance;

      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      final payload = await _nativePushPayload();
      if (payload == null) return false;

      await _upsertCurrentDevice(payload);
      return true;
    } catch (e) {
      debugPrint('DeviceService.requestAndRegisterNativePush failed: $e');
      return false;
    }
  }

  /// Returns true if the backend has at least one active WEB_PUSH device record
  /// for the current user. Used by the security screen to confirm the backend
  /// saved the subscription before showing the Active state.
  Future<bool> checkBackendWebPushActive() async {
    if (!kIsWeb) return false;
    if (!_isAuthed()) return false;
    try {
      final devices = await _repository.getMyDevices();
      return devices.any((d) =>
        d.provider.toUpperCase() == 'WEB_PUSH' &&
        d.isActive &&
        d.revokedAt == null &&
        (d.endpoint?.isNotEmpty ?? false),
      );
    } catch (e) {
      debugPrint('DeviceService.checkBackendWebPushActive failed: $e');
      return false;
    }
  }

  Future<void> _upsertCurrentDevice(Map<String, dynamic> payload) async {
    final id = _cachedDeviceId ?? await _loadPersistedDeviceId();
    if (id != null && id.isNotEmpty) {
      await _repository.updateDevice(id, payload);
      _cachedDeviceId = id;
      return;
    }

    final device = await _repository.register(payload);
    if (device.id.isNotEmpty) {
      _cachedDeviceId = device.id;
      await _persistDeviceId(device.id);
    }
  }

  // ── Payload builders ──────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> _buildPayload() async {
    if (kIsWeb) {
      if (!WebPushService.isSupported) return null;
      if (WebPushService.permission != 'granted') return null;

      final sub = await WebPushService.getExistingSubscription();
      if (sub != null && sub.endpoint.isNotEmpty) {
        return _webPushPayload(sub);
      }
      return null;
    }

    return _nativePushPayload();
  }

  Future<Map<String, dynamic>?> _nativePushPayload() async {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _fcmPayload(platform: 'ANDROID');
      case TargetPlatform.iOS:
        return _fcmPayload(platform: 'IOS');
      case TargetPlatform.windows:
        // THE LEG THAT DID NOT EXIST.
        //
        // This switch returned null for Windows, so no Windows device was ever
        // registered, so `listActiveForUser` could never return one, so the
        // backend's complete WNS adapter — raw call notifications, channel
        // expiry handling and all — has never had a device to deliver to.
        // Windows call arrival worked only while the app was open on the
        // realtime socket.
        return _wnsPayload();
      default:
        return null;
    }
  }

  Future<Map<String, dynamic>?> _wnsPayload() async {
    final channel = await WindowsPushService.createChannel();
    if (channel == null) return null;
    return {
      'platform': 'WINDOWS',
      'provider': 'WNS',
      // The adapter reads `endpoint ?? token`; both are set so neither a
      // registry lookup nor a send has to know which one this transport uses.
      'token': channel.uri,
      'endpoint': channel.uri,
      'isActive': true,
      'deviceName': _resolveDeviceName(),
      'appVersion': const String.fromEnvironment(
        'APP_VERSION',
        defaultValue: '1.0.0',
      ),
      'locale': _resolveLocale(),
      'timezone': _resolveTimezone(),
    };
  }

  /// Poll for the APNs device token, bounded. Apple gives no future to await,
  /// so the only honest shape is a short retry that gives up rather than one
  /// that hangs a sign-in. ~5s total is far longer than a normal grant takes
  /// and short enough that a device with notifications denied is not stalled.
  static const Duration _apnsPollInterval = Duration(milliseconds: 500);
  static const int _apnsPollAttempts = 10;

  Future<void> _awaitApnsToken() async {
    for (var attempt = 0; attempt < _apnsPollAttempts; attempt++) {
      try {
        final apns = await FirebaseMessaging.instance.getAPNSToken();
        if (apns != null && apns.isNotEmpty) return;
      } catch (e) {
        debugPrint('DeviceService._awaitApnsToken failed: $e');
        return;
      }
      await Future<void>.delayed(_apnsPollInterval);
    }
    debugPrint(
      'DeviceService: no APNs token after '
      '${_apnsPollAttempts * _apnsPollInterval.inMilliseconds}ms — '
      'push registration deferred to onTokenRefresh',
    );
  }

  Future<Map<String, dynamic>?> _fcmPayload({
    required String platform,
  }) async {
    try {
      // ON APPLE PLATFORMS THE FCM TOKEN DOES NOT EXIST YET.
      //
      // `getToken()` on iOS returns null until APNs has handed the app its
      // device token, and that registration is asynchronous — it is routinely
      // not finished in the moments after `requestPermission()` returns. On
      // Android the token is there immediately, which is exactly why Android
      // rang and the iPhone did not: the first and only attempt came back
      // null, `_buildPayload` returned null, and the device was never
      // registered at all. Nothing downstream is wrong — the Firebase project
      // carries both APNs auth keys for `org.auraplatform.app` and the backend
      // sends iOS a real alert payload. There was simply no token to send to.
      //
      // So wait for the APNs token first, briefly and boundedly. If it never
      // arrives we still return null — but `_doRegisterCurrentDevice` now
      // binds the refresh listener before giving up, so the token that lands a
      // moment later registers itself.
      if (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        await _awaitApnsToken();
      }

      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return null;

      return {
        'platform': platform,
        'provider': 'FCM',
        'token': token,
        'deviceName': _resolveDeviceName(),
        'appVersion': const String.fromEnvironment(
          'APP_VERSION',
          defaultValue: '1.0.0',
        ),
        'locale': _resolveLocale(),
        'timezone': _resolveTimezone(),
      };
    } catch (e) {
      debugPrint('DeviceService._fcmPayload failed: $e');
      return null;
    }
  }

  Map<String, dynamic> _webPushPayload(WebPushResult sub) {
    return {
      'platform': 'WEB',
      'provider': 'WEB_PUSH',
      'token': sub.endpoint,
      'endpoint': sub.endpoint,
      'webPushP256dh': sub.p256dh ?? '',
      'webPushAuth': sub.auth ?? '',
      'isActive': true,
      'deviceName': _resolveDeviceName(),
      'appVersion': const String.fromEnvironment(
        'APP_VERSION',
        defaultValue: '1.0.0',
      ),
      'locale': _resolveLocale(),
      'timezone': _resolveTimezone(),
    };
  }

  // ── Metadata helpers ──────────────────────────────────────────────────────

  String _resolveDeviceName() {
    if (kIsWeb) return 'Web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'Android';
      case TargetPlatform.iOS:
        return 'iOS';
      case TargetPlatform.macOS:
        return 'macOS';
      case TargetPlatform.windows:
        return 'Windows';
      case TargetPlatform.linux:
        return 'Linux';
      default:
        return 'Desktop';
    }
  }

  String _resolveLocale() {
    try {
      return PlatformDispatcher.instance.locale.toString();
    } catch (_) {
      return '';
    }
  }

  String _resolveTimezone() {
    try {
      return DateTime.now().timeZoneName;
    } catch (_) {
      return '';
    }
  }

  // ── Local persistence ─────────────────────────────────────────────────────

  Future<void> _persistDeviceId(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_deviceIdKey, id);
    } catch (_) {}
  }

  Future<String?> _loadPersistedDeviceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_deviceIdKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> _clearPersistedDeviceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_deviceIdKey);
    } catch (_) {}
  }
}