import 'dart:io';

import 'package:aura/core/auth/secure_token_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// THE CREDENTIAL STORE, EXERCISED ON THE REAL PLATFORM.
///
/// The unit gate in `test/security/` pins the wiring. This runs the real thing:
/// on Windows it writes to and reads from the actual Credential Manager
/// through FFI, with DPAPI doing the encryption, and proves the migration off
/// SharedPreferences moves a session without losing it.
///
///     flutter test integration_test/secure_token_storage_certification_test.dart -d windows
///
/// It is written to run unchanged on iOS and Android, where the same calls go
/// through Aura's own native channel instead. Nothing here is Windows-specific
/// except the comment.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const accessKey = SecureTokenStorage.legacyAccessKey;
  const refreshKey = SecureTokenStorage.legacyRefreshKey;

  // Long enough to be a plausible JWT, and distinct per run so a stale entry
  // from an earlier run cannot make a failure look like a pass.
  final marker = 'aura-cert-${DateTime.now().microsecondsSinceEpoch}';

  tearDown(() async {
    await SecureTokenStorage.delete(accessKey);
    await SecureTokenStorage.delete(refreshKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(accessKey);
    await prefs.remove(refreshKey);
  });

  group('Secure token storage on ${Platform.operatingSystem}', () {
    testWidgets('a written secret reads back exactly', (_) async {
      await SecureTokenStorage.write(accessKey, marker);
      expect(await SecureTokenStorage.read(accessKey), marker);
    });

    testWidgets('a long value survives the round trip', (_) async {
      // Real access tokens are hundreds of characters. A Windows credential
      // blob is measured in BYTES while a Dart string is measured in UTF-16
      // code units, and getting that conversion wrong truncates at exactly
      // half — which a short value would not reveal.
      final long = 'x' * 900;
      await SecureTokenStorage.write(accessKey, long);
      final read = await SecureTokenStorage.read(accessKey);
      expect(read, long);
      expect(read!.length, 900);
    });

    testWidgets('non-ASCII survives, so a token is never corrupted', (_) async {
      const value = 'aura-Ω-é-字-🔐';
      await SecureTokenStorage.write(accessKey, value);
      expect(await SecureTokenStorage.read(accessKey), value);
    });

    testWidgets('deleting removes it, and deleting again is harmless', (_) async {
      await SecureTokenStorage.write(accessKey, marker);
      await SecureTokenStorage.delete(accessKey);
      expect(await SecureTokenStorage.read(accessKey), isNull);
      // Signing out twice must not fail because there was nothing to sign out
      // of.
      await SecureTokenStorage.delete(accessKey);
      expect(await SecureTokenStorage.read(accessKey), isNull);
    });

    testWidgets('writing null clears rather than storing an empty session',
        (_) async {
      await SecureTokenStorage.write(accessKey, marker);
      await SecureTokenStorage.write(accessKey, null);
      expect(await SecureTokenStorage.read(accessKey), isNull);
    });

    testWidgets('access and refresh do not collide', (_) async {
      await SecureTokenStorage.write(accessKey, 'access-$marker');
      await SecureTokenStorage.write(refreshKey, 'refresh-$marker');
      expect(await SecureTokenStorage.read(accessKey), 'access-$marker');
      expect(await SecureTokenStorage.read(refreshKey), 'refresh-$marker');
    });

    testWidgets('migration moves a legacy session and then clears it',
        (_) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(accessKey, 'legacy-access-$marker');
      await prefs.setString(refreshKey, 'legacy-refresh-$marker');
      await SecureTokenStorage.delete(accessKey);
      await SecureTokenStorage.delete(refreshKey);

      await SecureTokenStorage.migrateFromPreferences();

      // Moved.
      expect(await SecureTokenStorage.read(accessKey), 'legacy-access-$marker');
      expect(await SecureTokenStorage.read(refreshKey), 'legacy-refresh-$marker');
      // And no longer readable in the old place.
      final after = await SharedPreferences.getInstance();
      await after.reload();
      expect(after.getString(accessKey), isNull);
      expect(after.getString(refreshKey), isNull);
    });

    testWidgets('migration never overwrites a live session with a stale one',
        (_) async {
      await SecureTokenStorage.write(accessKey, 'live-$marker');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(accessKey, 'stale-$marker');

      await SecureTokenStorage.migrateFromPreferences();

      expect(await SecureTokenStorage.read(accessKey), 'live-$marker',
          reason: 'A leftover in the old location must never clobber the '
              'session actually in use.');
    });

    testWidgets('migration is idempotent and safe to run every launch',
        (_) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(accessKey, 'once-$marker');
      await SecureTokenStorage.delete(accessKey);

      await SecureTokenStorage.migrateFromPreferences();
      await SecureTokenStorage.migrateFromPreferences();
      await SecureTokenStorage.migrateFromPreferences();

      expect(await SecureTokenStorage.read(accessKey), 'once-$marker');
    });
  });
}
