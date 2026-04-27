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

  Future<void> registerCurrentDevice() async {
    try {
      final payload = await _buildPayload();
      final device = await _repository.register(payload);
      if (device.id.isNotEmpty) {
        _cachedDeviceId = device.id;
        await _persistDeviceId(device.id);
      }
    } catch (_) {}
  }

  Future<void> revokeCurrentDevice() async {
    try {
      final id = _cachedDeviceId ?? await _loadPersistedDeviceId();
      if (id == null || id.isEmpty) return;
      await _repository.revokeDevice(id);
      _cachedDeviceId = null;
      await _clearPersistedDeviceId();
    } catch (_) {}
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

  /// Called from user-initiated permission UX.
  /// Requests browser notification permission, subscribes, then updates
  /// the backend device record (PATCH if device ID known, else register).
  Future<bool> requestAndRegisterWebPush(String vapidKey) async {
    if (!kIsWeb) return false;
    try {
      final perm = await WebPushService.requestPermission();
      if (perm != 'granted') return false;

      final sub = await WebPushService.subscribe(vapidKey);
      if (sub == null || sub.endpoint.isEmpty) return false;

      final payload = _webPushPayload(sub);

      final id = _cachedDeviceId ?? await _loadPersistedDeviceId();
      if (id != null && id.isNotEmpty) {
        await _repository.updateDevice(id, payload);
      } else {
        final device = await _repository.register(payload);
        if (device.id.isNotEmpty) {
          _cachedDeviceId = device.id;
          await _persistDeviceId(device.id);
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Payload builders ──────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _buildPayload() async {
    if (kIsWeb) {
      final sub = await WebPushService.getExistingSubscription();
      if (sub != null && sub.endpoint.isNotEmpty) {
        return _webPushPayload(sub);
      }
      return _metadataPayload(platform: 'WEB', provider: 'WEB_PUSH');
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _metadataPayload(platform: 'ANDROID', provider: 'FCM');
      case TargetPlatform.iOS:
        return _metadataPayload(platform: 'IOS', provider: 'APNS');
      default:
        return _metadataPayload(platform: 'DESKTOP', provider: 'FCM');
    }
  }

  Map<String, dynamic> _webPushPayload(WebPushResult sub) {
    return {
      'platform': 'WEB',
      'provider': 'WEB_PUSH',
      // endpoint doubles as the stable token for upsert keying
      'token': sub.endpoint,
      'endpoint': sub.endpoint,
      'webPushP256dh': sub.p256dh ?? '',
      'webPushAuth': sub.auth ?? '',
      'deviceName': _resolveDeviceName(),
      'appVersion': const String.fromEnvironment(
        'APP_VERSION',
        defaultValue: '1.0.0',
      ),
      'locale': _resolveLocale(),
      'timezone': _resolveTimezone(),
    };
  }

  Map<String, dynamic> _metadataPayload({
    required String platform,
    required String provider,
  }) {
    return {
      'platform': platform,
      'provider': provider,
      'token': '',
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
