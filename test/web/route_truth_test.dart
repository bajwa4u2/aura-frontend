/// A 200 must mean the address exists (2026-10-26).
///
/// The web front door used to answer every path with the app shell at 200, so
/// `/zzz` and `/privacy` were indistinguishable to a search engine. It now
/// keeps a coarse list of known first path segments in the Dockerfile's nginx
/// template (`map $uri $aura_route_known`) and answers anything else 404, still
/// with the app as the body.
///
/// `lib/router.dart` stays the authority on routes. This file is why the
/// duplication is safe: a route added to the app and not to the map would 404
/// in production while every other test stayed green. That drift fails here.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Segments the front door admits that the router does not declare, on
/// purpose: `/p/` is the share gateway, and `/deck` and `/demo` are static
/// representation pages served from files, not app routes.
const _frontDoorOnly = {'p', 'deck', 'demo'};

/// Every `const String kName = '/path'` (or `static const`) in lib/, so a
/// route declared through a named constant is resolved like a literal one.
Map<String, String> _routeConstants() {
  final out = <String, String>{};
  final decl = RegExp(
    r"(?:static\s+)?const\s+String\s+(\w+)\s*=\s*'(/[^']*)'",
  );
  for (final f in Directory('lib').listSync(recursive: true)) {
    if (f is! File || !f.path.endsWith('.dart')) continue;
    for (final m in decl.allMatches(f.readAsStringSync())) {
      out[m.group(1)!] = m.group(2)!;
    }
  }
  return out;
}

/// Top-level segments the router declares, e.g. `/posts/:id` -> `posts`.
Set<String> _routerSegments(String source, Map<String, String> constants) {
  final paths = <String>[
    for (final m in RegExp(r"path:\s*'(/[^']*)'").allMatches(source))
      m.group(1)!,
  ];
  for (final m in RegExp(r'path:\s*([A-Za-z_][\w.]*)\s*[,)]').allMatches(source)) {
    final name = m.group(1)!.split('.').last;
    final value = constants[name];
    expect(value, isNotNull,
        reason: 'route constant $name could not be resolved to a path; the '
            'extractor has to see every top-level route');
    paths.add(value!);
  }
  final out = <String>{};
  for (final path in paths) {
    final seg = path.split('/')[1];
    if (seg.isEmpty || seg.startsWith(':')) continue;
    out.add(seg);
  }
  return out;
}

Set<String> _nginxSegments(String dockerfile) {
  final block = RegExp(r"map \$uri \$aura_route_known \{' \\([\s\S]*?)'\}' \\")
      .firstMatch(dockerfile)
      ?.group(1);
  expect(block, isNotNull,
      reason: 'the known-route map is gone from the Dockerfile; the front door '
          'can no longer tell a real address from a wrong one');
  return {
    for (final m in RegExp(r'"~\^/\(([^)]*)\)').allMatches(block!))
      ...m.group(1)!.split('|'),
  };
}

void main() {
  final router = File('lib/router.dart').readAsStringSync();
  final dockerfile = File('Dockerfile').readAsStringSync();
  // Extracted inside the tests: their own expectations must run in a test.
  late Set<String> fromRouter;
  late Set<String> fromNginx;
  setUpAll(() {
    fromRouter = _routerSegments(router, _routeConstants());
    fromNginx = _nginxSegments(dockerfile);
  });

  test('both extractors found the tables', () {
    expect(fromRouter.length, greaterThan(40),
        reason: 'router extraction found ${fromRouter.length} segments; the '
            'regex stopped matching the router');
    expect(fromNginx.length, greaterThan(40));
  });

  test('every router segment is admitted by the front door', () {
    final missing = fromRouter.difference(fromNginx);
    expect(missing, isEmpty,
        reason: 'these routes exist in the app but would answer 404 at the '
            'front door: ${missing.toList()..sort()}. Add them to the '
            r'`map $uri $aura_route_known` block in the Dockerfile.');
  });

  test('the front door admits nothing the app cannot render', () {
    final stale = fromNginx.difference(fromRouter).difference(_frontDoorOnly);
    expect(stale, isEmpty,
        reason: 'the front door admits addresses the app no longer has, so '
            'they would answer 200 with a not-found page: '
            '${stale.toList()..sort()}');
  });

  test('the fallback keeps the 404 while serving the app', () {
    expect(dockerfile, contains(r"'    try_files $uri $uri/index.html $uri/ @spa;' \"));
    expect(dockerfile, contains(r"'    if ($aura_route_known = 0) {' \"));
    // Without "=": the status stays 404 while the body is the shell.
    expect(dockerfile, contains(r"'    error_page 404 /index.html;' \"));
  });
}
