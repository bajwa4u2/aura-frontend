import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aura/core/auth/session_bootstrap.dart';
import 'package:aura/core/auth/session_providers.dart';
import 'package:aura/core/navigation/return_path_authority.dart';
import 'package:aura/core/navigation/route_registry.dart';
import 'package:aura/router.dart';

/// THE RECENSUS — founder ruling §16.
///
/// The audit's instrument measured what each SCREEN did about returning,
/// because in August 2026 that was the only place an answer existed. It is the
/// wrong instrument now: the answer is governed and presented once, so counting
/// bespoke back icons would report a product that got worse.
///
/// This asks the question that is now true: for every registered route, what
/// does the authority resolve, and is an affordance presented?
///
/// The target is ZERO KNOWN EXECUTABLE RETURN-PATH DEFECTS across the
/// authorized, non-protected population — and anything remaining named.
void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('recensus the whole registered population', () {
    final container = ProviderContainer(overrides: [
      sessionBootstrapProvider.overrideWith((ref) async {}),
      isAuthedProvider.overrideWithValue(true),
      emailVerifiedProvider.overrideWith((ref) async => true),
      identityBaselineCompleteProvider.overrideWith((ref) async => true),
    ]);
    // Deliberately not disposed — the TokenStore's load is still in flight.

    final router = container.read(routerProvider);
    final registry = RouteRegistry.fromRoutes(router.configuration.routes);

    final routes = <Map<String, Object?>>[];
    void walk(List<RouteBase> rs, String prefix) {
      for (final r in rs) {
        var here = prefix;
        if (r is GoRoute) {
          here = r.path.startsWith('/')
              ? r.path
              : '${prefix.endsWith('/') ? prefix : '$prefix/'}${r.path}';
          routes.add({
            'path': here,
            'renders': r.builder != null || r.pageBuilder != null,
          });
        }
        if (r.routes.isNotEmpty) walk(r.routes, here);
      }
    }

    walk(router.configuration.routes, '');

    /// Parameterised routes are resolved as a person actually meets them.
    String concrete(String template) => template
        .split('/')
        .map((s) => s.startsWith(':') ? 'x-${s.substring(1).toLowerCase()}' : s)
        .join('/');

    final rows = <Map<String, Object?>>[];
    for (final r in routes) {
      final template = r['path']! as String;
      final path = concrete(template);
      final renders = r['renders'] == true;
      final protected = ReturnPathAuthority.isProtectedDomain(path);

      // Both entry modes, for every route. The deep-link mode is the one the
      // audit found had no answer anywhere.
      final direct = ReturnPathAuthority.resolve(
        path: path,
        canPop: false,
        isAuthed: true,
        exists: registry.exists,
      );
      final inApp = ReturnPathAuthority.resolve(
        path: path,
        canPop: true,
        isAuthed: true,
        exists: registry.exists,
      );

      String verdict;
      if (!renders) {
        verdict = 'NOT_A_SURFACE';
      } else if (protected) {
        verdict = 'PROTECTED_BOUNDARY';
      } else if (!direct.hasAffordance) {
        verdict = 'ROOT_NO_RETURN_REQUIRED';
      } else if (direct.destination == null &&
          direct.semantic != ReturnSemantic.stackReturn) {
        verdict = 'MISSING_RETURN_PATH';
      } else if (inApp.semantic != ReturnSemantic.stackReturn &&
          inApp.semantic != ReturnSemantic.flowCancel &&
          inApp.semantic != ReturnSemantic.rootNoReturn) {
        // In-app entry must unwind the real journey, not jump to a parent.
        verdict = 'WRONG_RETURN_SEMANTICS';
      } else {
        verdict = 'COMPLIANT';
      }

      rows.add({
        'route': template,
        'sample': path,
        'renders': renders,
        'protected': protected,
        'deepLinkSemantic': direct.semantic.name,
        'deepLinkDestination': direct.destination,
        'inAppSemantic': inApp.semantic.name,
        'affordance': direct.hasAffordance,
        'verdict': verdict,
      });
    }

    final counts = <String, int>{};
    for (final r in rows) {
      final v = r['verdict']! as String;
      counts[v] = (counts[v] ?? 0) + 1;
    }

    final csv = StringBuffer(
        'route,sample,renders,protected,deeplink_semantic,'
        'deeplink_destination,in_app_semantic,affordance,verdict\n');
    for (final r in rows) {
      csv.writeln([
        r['route'], r['sample'], r['renders'], r['protected'],
        r['deepLinkSemantic'], r['deepLinkDestination'] ?? '',
        r['inAppSemantic'], r['affordance'], r['verdict'],
      ].join(','));
    }
    Directory('docs/navigation').createSync(recursive: true);
    File('docs/navigation/return_path_recensus.csv')
        .writeAsStringSync(csv.toString());
    File('docs/navigation/return_path_recensus.json').writeAsStringSync(
        const JsonEncoder.withIndent(' ').convert(rows));

    // ignore: avoid_print
    print('RECENSUS :: ${rows.length} registered routes');
    for (final e in (counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value)))) {
      // ignore: avoid_print
      print('RECENSUS :: ${e.key.padRight(26)} ${e.value}');
    }

    // THE TARGET. Anything defective must be named, not counted down.
    final defective = rows
        .where((r) => const {
              'MISSING_RETURN_PATH',
              'WRONG_RETURN_SEMANTICS',
              'DEEPLINK_ESCAPE_MISSING',
              'HARDCODED_PARENT_RETURN',
            }.contains(r['verdict']))
        .map((r) => '${r['route']} (${r['verdict']})')
        .toList();
    expect(defective, isEmpty,
        reason: 'authorized non-protected return-path defects remain');
  });
}
