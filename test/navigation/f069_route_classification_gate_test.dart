import 'dart:io';

import 'package:aura/app/route_classification.dart';
import 'package:flutter_test/flutter_test.dart';

/// F069 ROUTE-CLASSIFICATION GATE — founder ruling 2026-08-17.
///
/// Frozen invariants proven here:
///   1. UNKNOWN IS NOT PUBLIC.
///   2. Every route declared by the router is explicitly classified.
///   3. Classes are PUBLIC · MEMBER · AUTH_ACTION · GUEST_REACHABLE.
///   4. GUEST_REACHABLE is an entry model, not an authorization.
///   5. Unclassified paths fail CLOSED (member), never open.
///
/// The gate reads `lib/router.dart` as the single source of truth, so a
/// future route cannot silently bypass the continuity contract the way
/// `/articles/write` did — excluded from the public list, never added to
/// the member list, therefore unclassified and failing open.
void main() {
  final routerSrc = File('lib/router.dart').readAsStringSync();

  final constants = <String, String>{
    for (final m in RegExp(r"const String (k\w+) =[\s\r\n]*'([^']+)'")
        .allMatches(routerSrc))
      m.group(1)!: m.group(2)!,
  };

  final declared = <String>{
    ...RegExp(r"path:\s*'([^']+)'").allMatches(routerSrc).map((m) {
      var out = m.group(1)!;
      constants.forEach((name, value) => out = out.replaceAll('\$$name', value));
      return out;
    }),
    ...RegExp(r"path:\s*(k\w+)")
        .allMatches(routerSrc)
        .map((m) => constants[m.group(1)!])
        .whereType<String>(),
  }..removeWhere((p) => !p.startsWith('/'));

  /// Route patterns carry `:params`; classification operates on real paths,
  /// so substitute a concrete sample segment for each parameter.
  String concretize(String pattern) => pattern
      .split('/')
      .map((s) => s.startsWith(':') ? 'sample' : s)
      .join('/');

  group('F069 — every declared route is explicitly classified', () {
    test('no declared route falls through to the fail-closed default '
        'without being genuinely member-owned', () {
      final unexplained = <String>[];

      for (final pattern in declared) {
        final path = concretize(pattern);
        final cls = classifyRoute(path);

        // A route may legitimately BE member-class. What must never happen
        // is reaching member-class only by fall-through: i.e. matching no
        // explicit predicate at all.
        final explicit =
            isMemberShellPath(path) ||
            isAuthActionPath(path) ||
            isPublicPath(path) ||
            isGuestReachablePath(path);

        if (!explicit) unexplained.add('$pattern  →  $path  ($cls)');
      }

      expect(
        unexplained,
        isEmpty,
        reason:
            'These router-declared routes match NO explicit classification '
            'predicate. Unknown is not public: classify each one in '
            'lib/app/route_classification.dart as PUBLIC, MEMBER, '
            'AUTH_ACTION or GUEST_REACHABLE.\n  ${unexplained.join('\n  ')}',
      );
    });
  });

  group('F069 — frozen invariants', () {
    test('unknown paths fail CLOSED, never public', () {
      for (final path in const [
        '/some-route-that-does-not-exist',
        '/messages/secret/new-surface',
        '/institution/x/unbuilt-feature',
      ]) {
        expect(classifyRoute(path), RouteClass.member, reason: path);
        expect(routeAllowsUnauthenticatedEntry(path), isFalse, reason: path);
      }
    });

    test('article READING is public but AUTHORING is member '
        '(the F069 evidence case)', () {
      expect(classifyRoute('/articles/some-published-slug'), RouteClass.public);
      expect(classifyRoute('/articles/write'), RouteClass.member);
      expect(classifyRoute('/articles/write/draft-id'), RouteClass.member);
      expect(routeAllowsUnauthenticatedEntry('/articles/write'), isFalse);
    });

    test('guest-reachable meeting entry is its OWN class, not PUBLIC', () {
      for (final path in const [
        '/meetings/join',
        '/meetings/abc123/room',
        '/meetings/abc123/live',
        '/meet/some-booking',
      ]) {
        expect(classifyRoute(path), RouteClass.guestReachable, reason: path);
        // Entry model only — a guest may REACH these without a member
        // session; the destination's own authority still adjudicates.
        expect(routeAllowsUnauthenticatedEntry(path), isTrue, reason: path);
        expect(isPublicPath(path), isFalse, reason: path);
      }
    });

    test('Meetings guest behavior is preserved: no guest-reachable meeting '
        'path is member-gated', () {
      for (final path in const [
        '/meetings/join',
        '/meetings/join-error',
        '/meetings/abc123/waiting',
        '/meetings/abc123/summary',
      ]) {
        expect(isMemberShellPath(path), isFalse, reason: path);
      }
    });

    test('member surfaces still require authentication', () {
      for (final path in const [
        '/home',
        '/messages',
        '/messages/c/abc',
        '/me/edit',
        '/create',
      ]) {
        expect(classifyRoute(path), RouteClass.member, reason: path);
        expect(routeAllowsUnauthenticatedEntry(path), isFalse, reason: path);
      }
    });
  });
}
