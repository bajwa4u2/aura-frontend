import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TrustedDeviceStore {
  static const _key = 'aura_trusted_device_token';

  static Future<String?> load() async {
    if (kIsWeb) return null;
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_key);
    return (v != null && v.trim().isNotEmpty) ? v.trim() : null;
  }

  static Future<void> save(String token) async {
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, token.trim());
  }

  static Future<void> remove() async {
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
