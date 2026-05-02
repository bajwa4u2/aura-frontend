import 'package:shared_preferences/shared_preferences.dart';

/// Persists only the user's email/username across sessions.
/// Password is NEVER stored here.
class RememberedIdentifier {
  static const _key = 'aura_remembered_identifier';

  static Future<String?> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  static Future<void> save(String identifier) async {
    final trimmed = identifier.trim();
    if (trimmed.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, trimmed);
  }

  static Future<void> remove() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
