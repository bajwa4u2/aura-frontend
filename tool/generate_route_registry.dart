// ROUTE REGISTRY — GENERATED FROM THE ROUTER, NEVER HAND-MAINTAINED.
//
// `routes.json` was a hand-made snapshot dated 2026-08-24. By 2026-09-10 it
// advertised sixteen `/admin/*` routes that do not exist — `/admin/users`,
// `/admin/grants`, `/admin/communications` and more — because the admin console
// was reconstructed after the snapshot was taken and nothing regenerated it.
//
// That is not a stale file, it is a false one. The founder went looking for
// Announcements at `/admin/communications` because the registry said it was
// there, found nothing, and could not pin the release announcement. An
// inventory that lies is worse than no inventory: it sends people to places
// that were never built and it makes every audit that consults it wrong.
//
// So the registry is now DERIVED. Run:
//
//     dart tool/generate_route_registry.dart
//
// and `test/doctrine/route_registry_truth_test.dart` fails the build if the
// committed file and the router ever disagree again.

import 'dart:convert';
import 'dart:io';

/// Every `path: '...'` the router declares, in source order.
List<String> extractRoutePaths(String routerSource) {
  final paths = <String>[];
  final re = RegExp(r"""path:\s*(?:'([^']+)'|"([^"]+)")""");
  for (final m in re.allMatches(routerSource)) {
    final value = m.group(1) ?? m.group(2);
    if (value == null || value.isEmpty) continue;
    paths.add(value);
  }
  return paths;
}

/// Route constants referenced as `path: kSomethingRoute` or
/// `path: NavigationAuthority.personalDetailsRoute`.
List<String> extractConstantRoutes(String routerSource) {
  final re = RegExp(r'path:\s*([A-Za-z_][A-Za-z0-9_.]*)\s*,');
  return re.allMatches(routerSource).map((m) => m.group(1)!).toSet().toList()
    ..sort();
}

/// Every `const String NAME = '/path';` declared anywhere under `lib/`.
///
/// WITHOUT THIS THE PARSER IS BLIND to a whole class of route. `/personal-details`
/// and `/verify-identity` are declared as `NavigationAuthority` constants, so a
/// literal-only scan reports them as undeclared — and a certification test built
/// on that would fail correct code while passing phantom routes, which is the
/// worst of both.
Map<String, String> routeConstants(Directory libDir) {
  final out = <String, String>{};
  final decl = RegExp(
    r"""static\s+const\s+String\s+([A-Za-z_][A-Za-z0-9_]*)\s*=\s*'([^']+)'|"""
    r"""^const\s+String\s+([A-Za-z_][A-Za-z0-9_]*)\s*=\s*'([^']+)'""",
    multiLine: true,
  );
  for (final entity in libDir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    for (final m in decl.allMatches(entity.readAsStringSync())) {
      final name = m.group(1) ?? m.group(3);
      final value = m.group(2) ?? m.group(4);
      if (name == null || value == null) continue;
      if (!value.startsWith('/')) continue;
      // Last segment only: `NavigationAuthority.personalDetailsRoute` is
      // referenced by its member name, and a bare `kMeCommunicationsRoute` by
      // its own. Both resolve on the final identifier.
      out[name] = value;
    }
  }
  return out;
}

/// Literal paths PLUS constant-declared paths the router references.
Set<String> allDeclaredRoutes(String routerSource, Directory libDir) {
  final constants = routeConstants(libDir);
  final resolved = <String>{...extractRoutePaths(routerSource)};
  for (final ref in extractConstantRoutes(routerSource)) {
    final key = ref.contains('.') ? ref.split('.').last : ref;
    final value = constants[key];
    if (value != null) resolved.add(value);
  }
  return resolved;
}

void main(List<String> args) {
  final router = File('lib/router.dart');
  if (!router.existsSync()) {
    stderr.writeln('lib/router.dart not found — run from the client root');
    exit(1);
  }
  final source = router.readAsStringSync();

  final literal = extractRoutePaths(source);
  final constants = extractConstantRoutes(source);

  if (literal.length < 50) {
    // A generator that quietly produced an almost-empty registry would replace
    // a false inventory with an emptier one. Refuse instead.
    stderr.writeln('only ${literal.length} routes extracted — the parser is wrong, refusing to write');
    exit(1);
  }

  final unique = <String>{...literal}.toList()..sort();
  final registry = {
    'generatedFrom': 'lib/router.dart',
    'generator': 'tool/generate_route_registry.dart',
    'note':
        'DERIVED. Do not hand-edit. Regenerate after changing the router; '
        'test/doctrine/route_registry_truth_test.dart enforces agreement.',
    'literalPathCount': unique.length,
    'paths': unique,
    'pathsDeclaredViaConstant': constants,
  };

  File('routes.json').writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(registry)}\n');
  stdout.writeln('routes.json regenerated: ${unique.length} literal paths, '
      '${constants.length} declared via a constant');
}
