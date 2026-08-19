// RC6 — ROUTE POLICY IS DECLARED, NOT GUESSED FROM THE URL.
//
// Two defects, one shape: policy was written by hand against URL strings, so
// it drifted from the routes that actually exist.
//
//   1. AN ADMIN GATE THAT COULD NO LONGER MATCH ANYTHING.
//      `requiresInstitutionAdmin` matched exactly two SHORTHAND constants —
//      `/institution/edit-profile` and `/institution/domains`. The canonical
//      forms of the same destinations matched nothing and carried no admin
//      gate. RC2/RC3 then turned those shorthands into pure redirects, so the
//      only paths the gate could match stopped rendering: an institution
//      member without admin standing could reach the profile editor.
//
//   2. A PREFIX THAT SWALLOWED AN EDITOR. `/posts/` was public, and the
//      public check runs before the member matcher, so `/posts/:id/edit`
//      classified PUBLIC. A read-only sibling being public never implies its
//      editor is.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:aura/app/route_classification.dart';

void main() {
  group('RC6 — the same destination, the same policy, either way in', () {
    test('editing an institution profile requires ADMIN in BOTH URL forms', () {
      // The security defect this gate exists for.
      expect(institutionRoutePolicyFor('/institution/edit-profile'),
          InstitutionRoutePolicy.admin);
      expect(institutionRoutePolicyFor('/institution/inst-1/edit-profile'),
          InstitutionRoutePolicy.admin);
    });

    test('domains likewise', () {
      expect(institutionRoutePolicyFor('/institution/domains'),
          InstitutionRoutePolicy.admin);
      expect(institutionRoutePolicyFor('/institution/inst-1/domains'),
          InstitutionRoutePolicy.admin);
    });

    test('shorthand and canonical resolve to the SAME SECTION, structurally',
        () {
      for (final section in const [
        'edit-profile',
        'domains',
        'announcements',
        'live-rooms',
        'profile',
        'messages',
      ]) {
        expect(institutionSectionOf('/institution/$section'), section);
        expect(institutionSectionOf('/institution/inst-1/$section'), section);
        expect(
          institutionRoutePolicyFor('/institution/$section'),
          institutionRoutePolicyFor('/institution/inst-1/$section'),
          reason: '$section disagrees between its two URL forms',
        );
      }
    });

    test('a deeper canonical path keeps its section policy', () {
      expect(institutionRoutePolicyFor('/institution/inst-1/announcements/a1'),
          InstitutionRoutePolicy.adminOrSpeaker);
      expect(
          institutionRoutePolicyFor('/institution/inst-1/public-engagement/r1'),
          InstitutionRoutePolicy.member);
    });

    test('speaking for the institution needs speaker or admin standing', () {
      for (final path in const [
        '/institution/announcements',
        '/institution/inst-1/announcements',
        '/institution/inst-1/live-rooms',
        '/institution/inst-1/request-verification',
      ]) {
        expect(institutionRoutePolicyFor(path),
            InstitutionRoutePolicy.adminOrSpeaker,
            reason: path);
      }
    });

    test('ordinary workspace surfaces require membership, not leadership', () {
      for (final path in const [
        '/institution/inst-1',
        '/institution/inst-1/profile',
        '/institution/inst-1/members',
        '/institution/inst-1/units',
        '/institution/inst-1/meetings',
      ]) {
        expect(institutionRoutePolicyFor(path), InstitutionRoutePolicy.member,
            reason: path);
      }
    });

    test('a section nobody declared FAILS CLOSED to the strictest policy', () {
      // A new workspace surface cannot ship ungated because someone forgot to
      // declare it. The route gate below makes that failure loud too.
      expect(institutionRoutePolicyFor('/institution/inst-1/unbuilt-surface'),
          InstitutionRoutePolicy.admin);
    });

    test('non-institution paths are not institutional', () {
      for (final path in const ['/home', '/messages', '/institutions', '/me']) {
        expect(institutionRoutePolicyFor(path),
            InstitutionRoutePolicy.notInstitutional,
            reason: path);
      }
    });
  });

  group('RC6 — reading is public, authoring is not', () {
    test('/posts/:id is public but /posts/:id/edit is NOT', () {
      expect(classifyRoute('/posts/abc'), RouteClass.public);
      expect(classifyRoute('/posts/abc/edit'), RouteClass.member);
      expect(routeAllowsUnauthenticatedEntry('/posts/abc/edit'), isFalse);
    });

    test('the same holds for articles, which already had this fix', () {
      expect(classifyRoute('/articles/some-slug'), RouteClass.public);
      expect(classifyRoute('/articles/write'), RouteClass.member);
      expect(classifyRoute('/articles/write/draft-1'), RouteClass.member);
    });

    test('institution post editing is member-classed too', () {
      expect(routeAllowsUnauthenticatedEntry('/institution/i1/posts/p1/edit'),
          isFalse);
    });
  });

  group('RC6 — the ratchet', () {
    final routerSrc = File('lib/router.dart').readAsStringSync();

    final constants = <String, String>{
      for (final m in RegExp(r"const String (k\w+) =[\s\r\n]*'([^']+)'")
          .allMatches(routerSrc))
        m.group(1)!: m.group(2)!,
    };

    final declared = <String>{
      ...RegExp(r"path:\s*'([^']+)'").allMatches(routerSrc).map((m) {
        var out = m.group(1)!;
        constants.forEach((n, v) => out = out.replaceAll('\$$n', v));
        return out;
      }),
      ...RegExp(r"path:\s*(k\w+)")
          .allMatches(routerSrc)
          .map((m) => constants[m.group(1)!])
          .whereType<String>(),
    }..removeWhere((p) => !p.startsWith('/'));

    String concretize(String pattern) => pattern
        .split('/')
        .map((s) => s.startsWith(':') ? 'sample' : s)
        .join('/');

    test('the gate is reading a real route population', () {
      expect(declared.length, greaterThan(80),
          reason: 'The extractor matched suspiciously few routes.');
    });

    test('EVERY registered institution route has a declared policy', () {
      final undeclared = <String>[];
      for (final pattern in declared) {
        final path = concretize(pattern);
        final section = institutionSectionOf(path);
        if (section == null) continue;
        if (!kInstitutionSectionPolicy.containsKey(section)) {
          undeclared.add('$pattern  →  section "$section"');
        }
      }
      expect(undeclared, isEmpty,
          reason: 'Declare these sections in kInstitutionSectionPolicy. They '
              'currently fail closed to ADMIN, which is safe but silent:\n  '
              '${undeclared.join('\n  ')}');
    });

    test('NO registered edit/write route is publicly reachable', () {
      final leaks = <String>[];
      for (final pattern in declared) {
        final path = concretize(pattern);
        final last = path.split('/').where((s) => s.isNotEmpty).lastOrNull;
        if (last != 'edit' && last != 'write') continue;
        if (routeAllowsUnauthenticatedEntry(path)) leaks.add(pattern);
      }
      expect(leaks, isEmpty,
          reason: 'Authoring surfaces must not be reachable without a '
              'session:\n  ${leaks.join('\n  ')}');
    });

    test('FAILS on a seeded violation — proof the ratchet enforces (FD-13)', () {
      // A ratchet never shown to fail is decoration. The seed is the exact
      // shape of defect 2: a public prefix swallowing an editor.
      //
      // `/spaces/:slug/edit` is NOT a registered route today, so this is a
      // hypothetical — but it is publicly classified by the `/spaces/`
      // prefix, so if someone registered it tomorrow the scanner below would
      // catch it before it shipped.
      bool wouldLeak(String path) =>
          routeAllowsUnauthenticatedEntry(path) &&
          (path.endsWith('/edit') || path.endsWith('/write'));

      expect(wouldLeak('/spaces/civic/edit'), isTrue,
          reason: 'The scanner must flag a public-prefixed editor.');
      expect(declared.map(concretize), isNot(contains('/spaces/civic/edit')),
          reason: 'The seed must stay hypothetical — if this route is ever '
              'registered, the gate above fails until it is classified.');

      // ...and the real one it was built for no longer leaks.
      expect(wouldLeak('/posts/abc/edit'), isFalse);
    });

    test('the router no longer hand-writes institution admin policy', () {
      // The deprecated form must not come back: two string equality checks
      // against shorthand constants, which is how the hole was opened.
      expect(
        routerSrc.contains("path == kInstitutionDomainsRoute ||"),
        isFalse,
        reason: 'requiresInstitutionAdmin must delegate to the declared '
            'section policy, not re-list shorthand constants.',
      );
      expect(routerSrc.contains('institutionRoutePolicyFor('), isTrue);
    });
  });
}
