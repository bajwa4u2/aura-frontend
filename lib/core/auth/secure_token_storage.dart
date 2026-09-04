import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'secure_token_storage_stub.dart'
    if (dart.library.io) 'secure_token_storage_io.dart'
    if (dart.library.html) 'secure_token_storage_web.dart' as platform;

/// WHERE AURA'S SESSION ACTUALLY LIVES ON A DEVICE.
///
/// The access and refresh tokens were persisted in `SharedPreferences` — on
/// iOS the app's own `NSUserDefaults` plist, on Android an XML file in the app
/// data directory, on Windows a file under the roaming profile. Every one of
/// those is readable by anything that can read the app container: a device
/// backup, a rooted or jailbroken phone, another process running as the same
/// user on desktop. A bearer token in a plist is a session anyone holding the
/// file can resume.
///
/// This moves them to each platform's own credential store and migrates
/// whatever was already written to the old place.
///
/// WHY THIS IS FIRST-PARTY RATHER THAN A PLUGIN. `flutter_secure_storage` was
/// tried first and rejected on evidence: its Windows implementation compiles
/// `flutter_secure_storage_windows_plugin.cpp`, which includes `<atlstr.h>`,
/// and this machine's Visual Studio 2022 Build Tools has no ATL component —
/// `error C1083: Cannot open include file: 'atlstr.h'`. Adopting it would have
/// added a Visual Studio component to the Windows release prerequisites in
/// order to compile a file the package no longer uses at runtime, since its
/// Dart side already routes through FFI. The same Credential Manager is
/// reachable from Dart directly.
///
/// WHAT THIS DELIBERATELY IS NOT. Storage hardening and nothing else.
/// `TokenStore` keeps its shape, its `ChangeNotifier` behaviour, its
/// `isAuthed` / `isMemberSession` derivation and its session-hint writes. There
/// is no second authentication authority here and no change to how a session is
/// restored — only to where the bytes rest between runs.
///
/// WEB IS NOT INVOLVED AND MUST NOT BE. The web build persists no token at all:
/// the refresh token is an HttpOnly cookie Dart cannot read, and the access
/// token is deliberately memory-only to avoid stale-token flicker. A browser
/// has no equivalent of a Keychain, so "secure storage on web" would be
/// `localStorage` wearing a better name.
class SecureTokenStorage {
  const SecureTokenStorage._();

  /// The keys the tokens used to live under, kept so migration can find them.
  static const legacyAccessKey = 'aura_access_token';
  static const legacyRefreshKey = 'aura_refresh_token';

  static bool get isApplicable => !kIsWeb;

  static Future<String?> read(String key) async {
    if (!isApplicable) return null;
    try {
      return await platform.readSecret(key);
    } catch (e) {
      // A credential store can be unavailable — a Keychain locked by policy, a
      // Windows profile without one. Losing a session is recoverable; failing
      // the boot path is not.
      debugPrint('[secure-store] read failed for $key: $e');
      return null;
    }
  }

  static Future<void> write(String key, String? value) async {
    if (!isApplicable) return;
    try {
      if (value == null || value.trim().isEmpty) {
        await platform.deleteSecret(key);
      } else {
        await platform.writeSecret(key, value);
      }
    } catch (e) {
      debugPrint('[secure-store] write failed for $key: $e');
    }
  }

  static Future<void> delete(String key) => write(key, null);

  /// ONE-TIME MOVE, AND IT MUST NOT LOSE A SESSION.
  ///
  /// Order matters: read the old location, write the new one, and only then
  /// remove the old. A crash between any two steps leaves the token readable
  /// in at least one place, so the worst case is that migration runs again —
  /// never that someone is silently signed out by an upgrade.
  ///
  /// Idempotent: once the legacy keys are gone this does nothing, and a token
  /// already in the credential store is never overwritten by a stale leftover.
  static Future<void> migrateFromPreferences() async {
    if (!isApplicable) return;
    // Under `flutter test` the credential store IS SharedPreferences, so
    // migrating would read a seeded session, write it back to the same place,
    // and then delete it.
    if (platform.isUnitTest) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final legacyAccess = prefs.getString(legacyAccessKey);
      final legacyRefresh = prefs.getString(legacyRefreshKey);
      if (legacyAccess == null && legacyRefresh == null) return;

      if (legacyAccess != null && (await read(legacyAccessKey)) == null) {
        await write(legacyAccessKey, legacyAccess);
      }
      if (legacyRefresh != null && (await read(legacyRefreshKey)) == null) {
        await write(legacyRefreshKey, legacyRefresh);
      }

      await prefs.remove(legacyAccessKey);
      await prefs.remove(legacyRefreshKey);
      debugPrint('[secure-store] migrated session out of SharedPreferences');
    } catch (e) {
      // The tokens stay where they were and migration retries next launch.
      debugPrint('[secure-store] migration deferred: $e');
    }
  }
}
