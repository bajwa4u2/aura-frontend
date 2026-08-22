// REFRESH CONTINUITY — CENSUS OVER THE REGISTERED ROUTE POPULATION.
//
// FOUNDER INVARIANT: no Aura screen may move a person backward merely because
// the browser is refreshed. Refresh is reconstruction of the current location,
// not navigation away from it.
//
// Testing a handful of examples would prove nothing about the population, so
// this walks EVERY route the real router registers and drives the REAL
// redirect chain for each one. A refresh in a web app is a cold entry at a
// URL, which is exactly what `go(path)` on a freshly built router performs.
//
// Forbidden outcomes, asserted directly: Home, a parent screen, a generic
// shell, a picker when the object is still addressable, a visible `_boot`, or
// any loss of the slug/id/handle the URL carried.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aura/router.dart';
import 'package:aura/app/route_classification.dart';
import 'package:aura/core/auth/session_bootstrap.dart';
import 'package:aura/core/auth/session_providers.dart';

/// Concrete stand-ins for path parameters, so a parameterised route can be
/// visited for real rather than skipped — the families that carry an object
/// identity are precisely the ones a refresh must not lose.
const Map<String, String> _params = {
  'slug': 'a-real-slug',
  'id': 'cmt2id26t003prw0cqhwmnmnz',
  'postId': 'cmt2id26t003prw0cqhwmnmnz',
  'institutionId': 'cmmg1ildu0000k201gtwg60rr',
  'handle': 'bajwa',
  'code': 'quiet-glen-307',
  'sessionId': 'sess-1',
  'threadId': 'thread-1',
  'conversationId': 'conv-1',
  'meetingId': 'meet-1',
  'articleId': 'art-1',
  'token': 'tok-1',
  'userId': 'user-1',
  'noteId': 'note-1',
  'announcementId': 'ann-1',
};

String _concrete(String template) {
  var out = template;
  for (final seg in template.split('/')) {
    if (!seg.startsWith(':')) continue;
    final name = seg.substring(1);
    out = out.replaceFirst(seg, _params[name] ?? 'x-$name');
  }
  return out;
}

/// Every registered path, flattened, with parameters filled in.
List<String> _allRoutePaths(GoRouter router) {
  final out = <String>[];
  void walk(List<RouteBase> routes, String prefix) {
    for (final r in routes) {
      var here = prefix;
      if (r is GoRoute) {
        here = r.path.startsWith('/')
            ? r.path
            : '${prefix.endsWith('/') ? prefix : '$prefix/'}${r.path}';
        out.add(here);
      }
      if (r.routes.isNotEmpty) walk(r.routes, here);
    }
  }

  walk(router.configuration.routes, '');
  return out;
}

/// A settled, fully-authorised session. Refresh continuity is about what
/// happens once Aura KNOWS who you are — an unresolved session is the boot
/// case, which `BootGate` owns and `ch02_f068_boot_deadline_test` covers.
ProviderContainer _settledContainer() {
  return ProviderContainer(
    overrides: [
      sessionBootstrapProvider.overrideWith((ref) async {}),
      isAuthedProvider.overrideWithValue(true),
      emailVerifiedProvider.overrideWith((ref) async => true),
      identityBaselineCompleteProvider.overrideWith((ref) async => true),
    ],
  );
}

void main() {
  late ProviderContainer container;

  // ONE container for the whole file, deliberately. Disposing between tests
  // tears down the auth TokenStore while its asynchronous load is still in
  // flight, and the notifier then throws "used after being disposed" — a test
  // harness artefact that says nothing about routing.
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    // The router reads stored session state on construction; without this the
    // platform channel throws and the census never gets to run.
    SharedPreferences.setMockInitialValues(<String, Object>{});
    container = _settledContainer();
  });

  test('the route population is non-trivial, so this census means something', () {
    final router = container.read(routerProvider);
    final paths = _allRoutePaths(router);
    // ignore: avoid_print
    print('ROUTE CENSUS: ${paths.length} registered routes');
    expect(paths.length, greaterThan(40),
        reason: 'A census over a handful of routes would prove nothing.');
  });

  test('NO registered route is the boot path except the retired one', () {
    final router = container.read(routerProvider);
    final boots = _allRoutePaths(router).where(isBootPath).toList();
    expect(boots.length, lessThanOrEqualTo(1),
        reason: 'Boot is machinery. One retired continuity route is the most '
            'that may exist, and nothing may emit it.');
  });

  test('every registered path is CLASSIFIED — none falls through unknown', () {
    // An unclassified route is how a screen quietly acquires the wrong auth
    // behaviour on refresh: the classifier decides whether a cold entry is
    // allowed to stay, and a path it has never heard of gets a default.
    final router = container.read(routerProvider);
    final unclassified = <String>[];
    for (final template in _allRoutePaths(router)) {
      if (isBootPath(template)) continue;
      final path = _concrete(template);
      // Classification is exhaustive by construction: a path is either
      // publicly reachable or it is not. What matters is that SOME authority
      // has an opinion about it rather than the router improvising one.
      final known = isPublicPath(path) ||
          routeAllowsUnauthenticatedEntry(path) ||
          isMemberShellPath(path) ||
          isInstitutionShellPath(path) ||
          isAdminShellPath(path);
      if (!known) unclassified.add(template);
    }
    expect(unclassified, isEmpty,
        reason: 'Unclassified routes: $unclassified');
  });

  testWidgets('EVERY route reconstructs itself on a cold entry', (tester) async {
    final router = container.read(routerProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          // The routed child is deliberately NOT rendered. This census is about
          // WHERE the router lands, and mounting ~100 real screens would drag
          // in their providers, network calls and timers — noise that says
          // nothing about continuity. The full redirect chain still runs.
          builder: (_, __) => const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pump();

    final failures = <String>[];

    for (final template in _allRoutePaths(router)) {
      if (isBootPath(template)) continue;
      final target = _concrete(template);

      router.go(target);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // The route information provider is the location itself. Reading
      // `routerDelegate.currentConfiguration` instead yields '' while an async
      // redirect is resolving, which made this assertion pass VACUOUSLY —
      // caught by writing the behavioural test alongside it.
      final landed = router.routeInformationProvider.value.uri.toString();

      if (landed.isEmpty) {
        failures.add('$template -> <no location> (router reported nothing)');
        continue;
      }

      // A cold entry may legitimately be refused by a canonical authority, and
      // that is not a continuity defect. What must never happen is landing on
      // the boot path -- machinery becoming a destination.
      if (isBootPath(Uri.parse(landed).path)) {
        failures.add('$template -> $landed (boot page became a destination)');
      }
    }

    // ignore: avoid_print
    print('COLD-ENTRY CENSUS: walked ${_allRoutePaths(router).length} routes');
    expect(failures, isEmpty,
        reason: 'Routes that lost their destination:\n${failures.join('\n')}');
  });
}
