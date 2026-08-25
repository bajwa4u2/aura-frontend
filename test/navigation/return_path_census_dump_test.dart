import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aura/core/auth/session_bootstrap.dart';
import 'package:aura/core/auth/session_providers.dart';
import 'package:aura/router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// AUDIT TOOLING — the registered route population, from the ROUTER ITSELF.
///
/// Founder ruling 2026-08-25 (Global Navigation / Return-Path Authority) asks
/// for the current exact population and does not let the previously recorded
/// RC6 figures be assumed still true.
///
/// A text scan of `router.dart` is not good enough to answer that: routes
/// nest, a `GoRoute(` can sit inside a comment, and a parser that silently
/// drifts from the real configuration is exactly the failure RC6 was written
/// about. So the census walks `router.configuration.routes` — the object the
/// app actually navigates with — and writes it to disk for the audit to join
/// against.
///
/// This test asserts almost nothing on purpose. It is an instrument.
void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('dump the registered route population', () {
    final container = ProviderContainer(
      overrides: [
        sessionBootstrapProvider.overrideWith((ref) async {}),
        isAuthedProvider.overrideWithValue(true),
        emailVerifiedProvider.overrideWith((ref) async => true),
        identityBaselineCompleteProvider.overrideWith((ref) async => true),
      ],
    );
    // Deliberately NOT disposed: tearing the container down cancels the
    // TokenStore's in-flight load, which then throws "used after being
    // disposed". That is a harness artefact and says nothing about routing —
    // the same reason `refresh_continuity_census_test` keeps one container.

    final router = container.read(routerProvider);
    final rows = <Map<String, Object?>>[];

    void walk(List<RouteBase> routes, String prefix, List<String> shellChain) {
      for (final r in routes) {
        var here = prefix;
        var chain = shellChain;
        if (r is GoRoute) {
          here = r.path.startsWith('/')
              ? r.path
              : '${prefix.endsWith('/') ? prefix : '$prefix/'}${r.path}';
          rows.add({
            'path': here,
            'segments': here.split('/').where((s) => s.isNotEmpty).length,
            'params': RegExp(r':(\w+)')
                .allMatches(here)
                .map((m) => m.group(1))
                .toList(),
            'renders': r.builder != null || r.pageBuilder != null,
            'hasRedirect': r.redirect != null,
            'childCount': r.routes.length,
            'shellChain': List<String>.from(shellChain),
            'parent': prefix,
          });
        } else if (r is ShellRoute) {
          chain = [...shellChain, 'ShellRoute#${shellChain.length}'];
        } else if (r is StatefulShellRoute) {
          chain = [...shellChain, 'StatefulShellRoute#${shellChain.length}'];
        }
        if (r.routes.isNotEmpty) walk(r.routes, here, chain);
      }
    }

    walk(router.configuration.routes, '', const []);

    final out = File('test/navigation/_route_census.json');
    out.writeAsStringSync(const JsonEncoder.withIndent(' ').convert(rows));

    // ignore: avoid_print
    print('RETURN-PATH CENSUS :: registered routes = ${rows.length}');
    // ignore: avoid_print
    print('RETURN-PATH CENSUS :: renders a screen  = '
        '${rows.where((r) => r['renders'] == true).length}');
    // ignore: avoid_print
    print('RETURN-PATH CENSUS :: redirect-only     = '
        '${rows.where((r) => r['renders'] != true && r['hasRedirect'] == true).length}');
    // ignore: avoid_print
    print('RETURN-PATH CENSUS :: institution       = '
        '${rows.where((r) => (r['path'] as String).startsWith('/institution')).length}');

    expect(rows.length, greaterThan(40),
        reason: 'a census over a handful of routes would prove nothing');
  });
}
