/// NAVIGATION MUST POINT AT ROUTES THAT EXIST.
///
/// 2026-09-10: the founder could not pin the 1.4.3 release announcement. They
/// looked in the admin console for Announcements, found nothing, and the route
/// inventory told them it lived at `/admin/communications` — a path the router
/// has never declared and a screen that was never built.
///
/// TWO SEPARATE FINDINGS, and the second is the one worth keeping:
///
///   1. `routes.json` was stale, dated 2026-08-24, advertising sixteen
///      `/admin/*` routes that do not exist. It is also GITIGNORED — one of a
///      family of `nav_*.json` scratch outputs from an old audit. So it was
///      never a governed registry at all; it was a local file with an
///      authoritative-sounding name, which is worse than no file.
///   2. Nothing anywhere asserted that a navigation DESTINATION resolves to a
///      declared route. That is the real gap, and it is what this file closes.
///
/// A test that regenerated the registry and then compared it to the router
/// would be vacuous — both sides derived from the same source. So this asserts
/// what actually matters: every destination the product navigates to is a route
/// the router declares.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/admin/domain/operator_area.dart';

import '../../tool/generate_route_registry.dart' as generator;

void main() {
  late Set<String> declared;

  setUpAll(() {
    final router = File('lib/router.dart');
    expect(router.existsSync(), isTrue, reason: 'lib/router.dart must exist');
    // Literal paths AND constant-declared ones. `/personal-details` and
    // `/verify-identity` are `NavigationAuthority` constants, so a literal-only
    // scan would report real routes as phantom — failing correct code while
    // letting an actual phantom through.
    declared = generator.allDeclaredRoutes(
      router.readAsStringSync(),
      Directory('lib'),
    );
  });

  test('the parser reads the router — positive control', () {
    // Without this, every assertion below could pass by comparing against an
    // empty set. A route parser that matches nothing certifies nothing, and
    // this estate has already shipped one measuring device that was blind.
    expect(
      declared.length,
      greaterThan(100),
      reason: 'only ${declared.length} routes parsed; the parser is broken',
    );
    for (final known in const ['/home', '/announcements', '/personal-details', '/verify-identity']) {
      expect(declared, contains(known), reason: '$known must be declared');
    }
  });

  test('every operator area points at a route the router declares', () {
    // THE ACTUAL DEFECT CLASS. An area whose `path` is not a real route is a
    // rail item that navigates nowhere — indistinguishable, to the person
    // clicking it, from the product being broken.
    final missing = <String>[];
    for (final area in OperatorArea.values) {
      final path = area.path;
      final ok = declared.contains(path) ||
          // A parent area may own a route declared only by its children.
          declared.any((d) => d.startsWith('$path/'));
      if (!ok) missing.add('${area.id} -> $path');
    }
    expect(
      missing,
      isEmpty,
      reason: 'operator areas navigating to undeclared routes:\n  ${missing.join('\n  ')}',
    );
  });

  test('the phantom admin routes are not declared, and never were', () {
    // Named explicitly. These are the exact claims the stale inventory made,
    // and asserting their ABSENCE is what stops somebody re-adding an alias to
    // "fix" a broken link by inventing the route it pointed at.
    for (final phantom in const [
      '/admin/communications',
      '/admin/users',
      '/admin/grants',
      '/admin/audit-logs',
      '/admin/settings',
      '/admin/institutions',
      '/admin/review-queue',
      '/admin/moderation',
      '/admin/feature-flags',
      '/admin/policies',
      '/admin/migrations',
      '/admin/support',
      '/admin/media-appeals',
      '/admin/institution-domains',
    ]) {
      expect(
        declared,
        isNot(contains(phantom)),
        reason: '$phantom is a phantom route from the 2026-08-24 inventory',
      );
    }
  });

  test('announcements are reachable, and every leg of that journey exists', () {
    // The counterpart. Deleting a phantom route helps nobody find the real one.
    for (final real in const [
      '/announcements',
      '/announcements/create',
      '/announcements/:slug',
      '/announcements/:slug/edit',
    ]) {
      expect(declared, contains(real), reason: '$real must exist');
    }
  });

  test('the stale scratch inventory is not resurrected as governance', () {
    // `routes.json` is gitignored and always was. If it ever becomes tracked,
    // it becomes a second source of truth about navigation that nothing
    // regenerates — which is precisely how it went wrong the first time.
    final tracked = Process.runSync('git', ['ls-files', 'routes.json']);
    expect(
      (tracked.stdout as String).trim(),
      isEmpty,
      reason: 'routes.json must stay a derived scratch artifact, never a '
          'committed registry. Regenerate it with '
          'tool/generate_route_registry.dart when an audit needs it.',
    );
  });

  test('if the scratch inventory exists locally, it agrees with the router', () {
    // Not required to exist. But a stale copy sitting in a working tree is what
    // sent the founder to a screen that was never built, so when it IS there it
    // must be true.
    final file = File('routes.json');
    if (!file.existsSync()) return;

    final content = file.readAsStringSync();
    if (!content.contains('"paths"')) {
      fail(
        'routes.json is in the pre-2026-09-10 hand-made format. Regenerate it: '
        'dart tool/generate_route_registry.dart',
      );
    }
    final listed = RegExp(r'"(/[^"]*)"').allMatches(content).map((m) => m.group(1)!).toSet();
    final phantom = listed.difference(declared).toList()..sort();
    expect(
      phantom,
      isEmpty,
      reason: 'routes.json advertises routes the router does not declare:\n  '
          '${phantom.join('\n  ')}',
    );
  });
}
