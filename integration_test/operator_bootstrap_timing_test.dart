// COLD BOOTSTRAP, MEASURED IN A FOREGROUND ENGINE.
//
// The question this exists to answer came from a browser trace: `/v1/admin/me`
// — the call that establishes what an operator may do — did not fire until
// 16.2 SECONDS after navigation, while everything it could possibly depend on
// had finished at 1.2 seconds. Fifteen seconds of nothing, and it fired in the
// same millisecond as a presence heartbeat, which is what a request gated
// behind a periodic timer looks like.
//
// That measurement could not be trusted. Chrome reported `visibilityState:
// "hidden"` for every tab in that window, and a backgrounded tab has its
// timers throttled to roughly one tick a minute — which produces exactly this
// shape for reasons that have nothing to do with the product. Certifying a
// performance number from it would have been certifying an artefact.
//
// So the measurement moves somewhere an engine is guaranteed to be drawing and
// timers are guaranteed to run: the real Windows client, the real `AuraApp`,
// the real `routerProvider` with its redirect and its admin-probe latch. The
// only thing replaced is the network, and it is replaced with a transport that
// answers INSTANTLY — which is the point. With every response free, any
// remaining gap is the client's own sequencing, and that is the thing worth
// knowing.
//
// This asserts a generous ceiling rather than a target. It exists to catch a
// return of dead time, not to police milliseconds on whatever machine runs it.

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aura/app/aura_app.dart';
import 'package:aura/core/net/dio_provider.dart';
import 'package:aura/router.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('COLD BOOTSTRAP to a usable operator console', (tester) async {
    final requests = <String, int>{};
    final clock = Stopwatch()..start();

    // A signed-in desktop client. On anything but web the token store restores
    // from storage, so this is the ordinary returning-operator path rather
    // than a fresh sign-in.
    SharedPreferences.setMockInitialValues({
      'flutter.aura_access_token': _unexpiredJwt(),
    });

    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.putIfAbsent(options.path, () => clock.elapsedMilliseconds);
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: _answer(options.path),
            ),
          );
        },
      ),
    );

    final container = ProviderContainer(
      overrides: [dioProvider.overrideWithValue(dio)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AuraApp(),
      ),
    );
    final firstFrame = clock.elapsedMilliseconds;

    // Frame-only pumps. Advancing the clock would drive the shell's periodic
    // work and measure the timer rather than the bootstrap.
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    // ENTERING /admin IS THE EVENT. The probe latch is deliberately not set by
    // signing in — an operator who never opens the console should not have
    // their authority probed, and that gating is exactly what is being timed.
    final navigatedAt = clock.elapsedMilliseconds;
    container.read(routerProvider).go('/admin');
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (requests.containsKey('/v1/admin/me')) break;
    }
    final adminMe = requests['/v1/admin/me'];

    // Settle to whatever the console renders.
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final settled = clock.elapsedMilliseconds;

    debugPrint('── COLD BOOTSTRAP (foreground, instant transport) ──');
    debugPrint('first frame            : ${firstFrame}ms');
    for (final entry in (requests.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value)))) {
      debugPrint('${entry.key.padRight(38)}: ${entry.value}ms');
    }
    debugPrint('settled                : ${settled}ms');
    debugPrint('');
    // THE NUMBER THAT MEANS ANYTHING. The absolutes above include this
    // harness pumping frames synchronously, which is not the app's cost. The
    // interval from asking for the console to the console asking who you are
    // is the app's own, and it is the interval the browser trace put at
    // fifteen seconds of nothing.
    debugPrint(
      'ENTER /admin -> authority requested: '
      '${adminMe == null ? "never" : adminMe - navigatedAt}ms',
    );

    // THE ASSERTION THAT MATTERS. Authority must be asked for because the
    // operator asked for the console, not because a heartbeat came round.
    expect(
      adminMe,
      isNotNull,
      reason: 'entering /admin never triggered the authority probe at all',
    );
    final afterNavigation = adminMe! - navigatedAt;
    expect(
      afterNavigation,
      lessThan(3000),
      reason:
          'authority took ${afterNavigation}ms after entering /admin with a '
          'transport that answers instantly — that is client-side dead time, '
          'not the network',
    );

    // And it must not be waiting on the presence heartbeat, which is what the
    // browser trace appeared to show.
    final ping = requests['/v1/presence/ping'];
    if (ping != null) {
      expect(
        adminMe,
        lessThan(ping),
        reason: 'authority arrived no earlier than the presence heartbeat, '
            'which is the gating this test exists to rule out',
      );
    }
  });
}

/// A JWT the token store will accept: unexpired, and shaped like one.
String _unexpiredJwt() {
  String seg(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final exp = DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch;
  return '${seg({'alg': 'HS256', 'typ': 'JWT'})}'
      '.${seg({'sub': 'op-1', 'exp': exp ~/ 1000})}'
      '.signature-not-verified-client-side';
}

/// Answers every bootstrap call instantly.
///
/// Deliberately minimal. This measures WHEN the console asks for things and
/// how long it takes to become usable, not what it renders — an empty section
/// costs nothing here, and a fixture that had to be kept in step with the
/// server would rot.
dynamic _answer(String path) {
  if (path.endsWith('/auth/refresh')) {
    return {'accessToken': _unexpiredJwt(), 'refreshToken': 'r'};
  }
  if (path.endsWith('/auth/me')) {
    return {
      'id': 'op-1',
      'handle': 'operator',
      'displayName': 'Operator',
      'emailVerifiedAt': DateTime.now().toIso8601String(),
    };
  }
  if (path.endsWith('/admin/me')) {
    return {
      'userId': 'op-1',
      'roles': ['OWNER'],
      'effectivePermissions': ['USERS_READ', 'AUDIT_READ', 'DISCOVERY_READ'],
    };
  }
  if (path.endsWith('/client/compatibility')) {
    return {'supported': true, 'minimumVersion': '0.0.1'};
  }
  if (path.contains('unread-count')) return {'count': 0};
  return {'items': const <dynamic>[]};
}
