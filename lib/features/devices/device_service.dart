import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'device_repository.dart';
import 'web_push_service.dart';

class DeviceService {
  DeviceService(this._repository);

  final DeviceRepository _repository;

  static const _deviceIdKey = 'aura_device_id';
  static const _presenceDebounce = Duration(minutes: 30);

  String? _cachedDeviceId;
  DateTime? _lastPresenceRefresh;
  StreamSubscription<String>? _tokenRefreshSub;
  bool _tokenRefreshBound = false;

  /// Registers the current device only when a valid payload can be built.
  ///
  /// On web, this is a no-op when no active push subscription exists.
  /// On Android, this uses FCM and requires a non-empty FCM token.
  /// On iOS, APNS/FCM wiring will be finalized separately.
  Future<void> registerCurrentDevice() async {
    try {
      // On Android 13+ POST_NOTIFICATIONS is a runtime permission. Request it
      // here so the OS surface a prompt the first time we have an authed user
      // even if the explicit security-screen flow was never opened. Without
      // this, a token can register but the system suppresses delivery.
      await _ensureNativePushPermission();

      final payload = await _buildPayload();
      if (payload == null) return;

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
    try {
      final id = _cachedDeviceId ?? await _loadPersistedDeviceId();
      if (id == null || id.isEmpty) return;
      await _repository.revokeDevice(id);
      _cachedDeviceId = null;
      await _clearPersistedDeviceId();
    } catch (e) {
      debugPrint('DeviceService.revokeCurrentDevice failed: $e');
    } finally {
      await _tokenRefreshSub?.cancel();
      _tokenRefreshSub = null;
      _tokenRefreshBound = false;
    }
  }

  /// Re-registers on app resume, throttled to once per 30 minutes.
  Future<void> refreshPresence() async {
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
      default:
        return null;
    }
  }

  Future<Map<String, dynamic>?> _fcmPayload({
    required String platform,
  }) async {
    try {
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