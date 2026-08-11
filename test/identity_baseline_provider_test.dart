import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aura/core/auth/auth_providers.dart';
import 'package:aura/core/auth/session_bootstrap.dart';
import 'package:aura/core/auth/session_providers.dart';

/// Identity Foundation Phase 1 -- identityBaselineCompleteProvider mirrors
/// emailVerifiedProvider's contract exactly (true/false/null=wait), since
/// the router's redirect callback depends on that null-means-wait
/// discipline to avoid flashing /complete-identity prematurely. See
/// router.dart's boot-path and main gate blocks.

String _fakeJwt({required DateTime exp, String type = 'user'}) {
  String encode(Map<String, Object?> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final header = encode({'alg': 'none', 'typ': 'JWT'});
  final payload = encode({
    'sub': 'user-1',
    'type': type,
    'exp': exp.millisecondsSinceEpoch ~/ 1000,
  });
  return '$header.$payload.sig';
}

Future<ProviderContainer> _authedContainer({
  required Future<Map<String, dynamic>> Function(Ref ref) authMe,
}) async {
  final validJwt = _fakeJwt(exp: DateTime.now().add(const Duration(hours: 1)));
  SharedPreferences.setMockInitialValues({'aura_access_token': validJwt});
  final container = ProviderContainer(
    overrides: [
      sessionBootstrapProvider.overrideWith((ref) => Future<void>.value()),
      authMeDataProvider.overrideWith(authMe),
    ],
  );
  await container.read(tokenStoreProvider).waitUntilLoaded();
  await container.read(sessionBootstrapProvider.future);
  return container;
}

void main() {
  test('reports false for an unauthenticated session (no /auth/me call needed)', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(
      overrides: [
        sessionBootstrapProvider.overrideWith((ref) => Future<void>.value()),
      ],
    );
    addTearDown(container.dispose);
    await container.read(tokenStoreProvider).waitUntilLoaded();
    await container.read(sessionBootstrapProvider.future);

    final result = await container.read(identityBaselineCompleteProvider.future);

    expect(result, false);
  });

  test('reports true when /auth/me returns identityBaselineComplete: true', () async {
    final container = await _authedContainer(
      authMe: (ref) async => {'identityBaselineComplete': true, 'accountType': 'PUBLIC'},
    );
    addTearDown(container.dispose);

    final result = await container.read(identityBaselineCompleteProvider.future);

    expect(result, true);
  });

  test('reports false when /auth/me returns identityBaselineComplete: false', () async {
    final container = await _authedContainer(
      authMe: (ref) async => {'identityBaselineComplete': false, 'accountType': 'PUBLIC'},
    );
    addTearDown(container.dispose);

    final result = await container.read(identityBaselineCompleteProvider.future);

    expect(result, false);
  });

  test('reports null (wait, do not redirect) when /auth/me returns an empty payload', () async {
    final container = await _authedContainer(authMe: (ref) async => {});
    addTearDown(container.dispose);

    final result = await container.read(identityBaselineCompleteProvider.future);

    expect(result, null);
  });

  test('institution accounts bypass the requirement, same as email verification', () async {
    final container = await _authedContainer(
      authMe: (ref) async => {'identityBaselineComplete': false, 'accountType': 'INSTITUTION'},
    );
    addTearDown(container.dispose);

    final result = await container.read(identityBaselineCompleteProvider.future);

    expect(result, true);
  });

  test('a missing identityBaselineComplete key (older cached response) is treated as incomplete, not true', () async {
    final container = await _authedContainer(
      authMe: (ref) async => {'accountType': 'PUBLIC'},
    );
    addTearDown(container.dispose);

    final result = await container.read(identityBaselineCompleteProvider.future);

    expect(result, false);
  });
}
