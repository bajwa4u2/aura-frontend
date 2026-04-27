import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'device_repository.dart';

class DeviceService {
  DeviceService(this._repository);

  final DeviceRepository _repository;

  static const _deviceIdKey = 'aura_device_id';
  static const _presenceDebounce = Duration(minutes: 30);

  String? _cachedDeviceId;
  DateTime? _lastPresenceRefresh;

  Future<void> registerCurrentDevice() async {
    try {
      final payload = _buildPayload();
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

  /// Re-registers the device on app resume, throttled to once per 30 minutes.
  Future<void> refreshPresence() async {
    final now = DateTime.now();
    if (_lastPresenceRefresh != null &&
        now.difference(_lastPresenceRefresh!) < _presenceDebounce) {
      return;
    }
    _lastPresenceRefresh = now;
    await registerCurrentDevice();
  }

  Map<String, dynamic> _buildPayload() {
    String platform;
    String provider;

    if (kIsWeb) {
      platform = 'WEB';
      provider = 'WEB_PUSH';
    } else {
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          platform = 'ANDROID';
          provider = 'FCM';
        case TargetPlatform.iOS:
          platform = 'IOS';
          provider = 'APNS';
        default:
          platform = 'DESKTOP';
          provider = 'FCM';
      }
    }

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
