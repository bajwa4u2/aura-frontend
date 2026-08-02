import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aura/core/auth/auth_providers.dart';
import 'package:aura/core/auth/session_bootstrap.dart';
import 'package:aura/core/auth/session_providers.dart';

/// Cold deep-link reload investigation (2026-08-02 record in
/// audit/working-directory/NEXT_WORK.md): the suspected root cause was a
/// hydration race where the router's redirect guard could see an
/// authenticated session as "unauthed" merely because async session
/// restoration (`sessionBootstrapProvider`) had not yet completed on a
/// cold/hard page load.
///
/// Direct investigation (real browser, real network-latency-simulating
/// backend, real cold reloads on /home, an institution-gated route, and a
/// genuinely-expired session) found this does NOT currently reproduce —
/// `authStatusProvider`'s own gate (`if (boot.isLoading) return
/// AuthStatus.loading`) already covers it, and has since 2026-05-03
/// (commit d9c7cef, "prevent 401 bootstrap race"), predating the
/// 2026-08-02 observation by about three months.
///
/// This test locks in the exact invariant the router's `redirect` callback
/// depends on for that guarantee to hold, so a future regression here is
/// caught at the provider level rather than only by a live reload.
String _fakeJwt({required DateTime exp, String type = 'user'}) {
  String encode(Map<String, Object?> m) => base64Url
      .encode(utf8.encode(jsonEncode(m)))
      .replaceAll('=', '');
  final header = encode({'alg': 'none', 'typ': 'JWT'});
  final payload = encode({
    'sub': 'user-1',
    'type': type,
    'exp': exp.millisecondsSinceEpoch ~/ 1000,
  });
  return '$header.$payload.sig';
}

void main() {
  test(
    'authStatus reports loading (never unauthed) while sessionBootstrapProvider is still in flight',
    () async {
      SharedPreferences.setMockInitialValues({});
      final bootCompleter = Completer<void>();
      final container = ProviderContainer(
        overrides: [
          sessionBootstrapProvider.overrideWith((ref) => bootCompleter.future),
        ],
      );

      // A logged-in session restoring over the network must never be
      // read as "unauthed" merely because the restore hasn't settled —
      // this is the exact condition the router's redirect-to-/login
      // decision keys off of.
      expect(container.read(authStatusProvider), AuthStatus.loading);

      bootCompleter.complete();
      await container.read(sessionBootstrapProvider.future);
      await container.read(tokenStoreProvider).waitUntilLoaded();

      expect(container.read(authStatusProvider), AuthStatus.unauthed);
      container.dispose();
    },
  );

  test(
    'authStatus resolves to authed once bootstrap completes with a valid persisted token',
    () async {
      final validJwt = _fakeJwt(exp: DateTime.now().add(const Duration(hours: 1)));
      SharedPreferences.setMockInitialValues({'aura_access_token': validJwt});
      final container = ProviderContainer(
        overrides: [
          sessionBootstrapProvider.overrideWith((ref) => Future<void>.value()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(tokenStoreProvider).waitUntilLoaded();
      await container.read(sessionBootstrapProvider.future);

      expect(container.read(authStatusProvider), AuthStatus.authed);
    },
  );

  test(
    'authStatus resolves to unauthed (not stuck authed) for an expired persisted token',
    () async {
      final expiredJwt = _fakeJwt(exp: DateTime.now().subtract(const Duration(hours: 1)));
      SharedPreferences.setMockInitialValues({'aura_access_token': expiredJwt});
      final container = ProviderContainer(
        overrides: [
          sessionBootstrapProvider.overrideWith((ref) => Future<void>.value()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(tokenStoreProvider).waitUntilLoaded();
      await container.read(sessionBootstrapProvider.future);

      expect(container.read(authStatusProvider), AuthStatus.unauthed);
    },
  );
}
