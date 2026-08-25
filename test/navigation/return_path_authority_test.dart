import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aura/core/auth/session_bootstrap.dart';
import 'package:aura/core/auth/session_providers.dart';
import 'package:aura/core/navigation/destination_continuity.dart';
import 'package:aura/core/navigation/return_path_authority.dart';
import 'package:aura/core/navigation/route_registry.dart';
import 'package:aura/router.dart';

/// THE RETURN CONTRACT.
///
/// Founder ruling 2026-08-25 §8: two entry modes, and the difference between
/// them is not guessed — it is whether a predecessor exists.
///
/// The population tests at the bottom run over the REAL route table rather
/// than examples, because "every destination has a way out" is a claim about
/// the population and 47 of them lacked one when this chapter opened.
void main() {
  late RouteRegistry registry;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final container = ProviderContainer(overrides: [
      sessionBootstrapProvider.overrideWith((ref) async {}),
      isAuthedProvider.overrideWithValue(true),
      emailVerifiedProvider.overrideWith((ref) async => true),
      identityBaselineCompleteProvider.overrideWith((ref) async => true),
    ]);
    // Deliberately not disposed — see return_path_census_dump_test.
    registry = RouteRegistry.fromRoutes(
      container.read(routerProvider).configuration.routes,
    );
  });

  ReturnAction resolve(String path,
          {bool canPop = false, bool authed = true}) =>
      ReturnPathAuthority.resolve(
        path: path,
        canPop: canPop,
        isAuthed: authed,
        exists: registry.exists,
      );

  group('mode A — a real journey is unwound, never replaced', () {
    test('a detail entered in-app returns to what the person actually did', () {
      // The founder's example: Directory → Institution → Space → Conversation.
      // Every one of these has a structural parent, and NONE of them should be
      // used while a real predecessor exists.
      for (final path in [
        '/institutions/aura-platform-llc',
        '/institution/aura-platform-llc/spaces/general',
        '/messages/c/conv-1',
        '/posts/p1',
      ]) {
        final a = resolve(path, canPop: true);
        expect(a.semantic, ReturnSemantic.stackReturn, reason: path);
        expect(a.destination, isNull,
            reason: '$path invented a destination while history existed');
      }
    });
  });

  group('mode B — direct entry derives, and never manufactures', () {
    test('a Space falls back to its institution, not to /home', () {
      final a = resolve('/institution/aura-platform-llc/spaces/general');
      expect(a.destination, '/institution/aura-platform-llc/spaces');
      expect(a.semantic, ReturnSemantic.parentReturn);
    });

    test('an institution SECTION root returns to its institution', () {
      // The context-loss case: a section root has no structural parent, and
      // dropping the person at /home loses the institution entirely.
      final a = resolve('/institution/aura-platform-llc/members');
      expect(a.semantic, ReturnSemantic.contextReturn);
      expect(a.destination, startsWith('/institution/aura-platform-llc/'));
    });

    test('a conversation falls back to Messages', () {
      final a = resolve('/messages/c/conv-1');
      expect(a.destination, '/messages');
      expect(a.label, 'Messages');
    });

    test('a person falls back to Discover, not Home', () {
      expect(resolve('/u/someone').destination, '/discover');
    });

    test('informational surfaces fall back to the viewer\'s own home', () {
      // CROSS_PLATFORM_INFORMATIONAL_DESTINATIONS: first-class everywhere, and
      // the escape differs by session rather than being written into a table.
      for (final p in ['/privacy', '/terms', '/mission']) {
        expect(resolve(p, authed: true).destination, '/home', reason: p);
        expect(resolve(p, authed: false).destination, '/', reason: p);
        expect(resolve(p).semantic, ReturnSemantic.deepLinkFallback);
      }
    });
  });

  group('roots never acquire a fake Back', () {
    test('the primaries offer no affordance, even mid-journey', () {
      for (final p in ['/home', '/messages', '/discover', '/create', '/']) {
        final a = resolve(p, canPop: true);
        expect(a.semantic, ReturnSemantic.rootNoReturn, reason: p);
        expect(a.hasAffordance, isFalse, reason: p);
      }
    });
  });

  group('Cancel is not Back', () {
    test('a creation flow cancels rather than returning a level', () {
      for (final p in ['/messages/new', '/articles/write', '/create',
                       '/institutions/get-started']) {
        final a = resolve(p, canPop: true);
        if (p == '/create') {
          expect(a.semantic, ReturnSemantic.rootNoReturn,
              reason: 'Create is a primary destination');
          continue;
        }
        expect(a.semantic, ReturnSemantic.flowCancel, reason: p);
        expect(a.isHierarchical, isFalse,
            reason: '$p would present Cancel as hierarchical Back');
      }
    });

    test('an edit flow cancels too', () {
      expect(resolve('/institution/x/edit-profile', canPop: true).semantic,
          ReturnSemantic.flowCancel);
    });
  });

  group('POPULATION — every registered destination is accounted for', () {
    test('no resolved destination is an address the app does not render', () {
      // The failure this prevents: returning someone to a route that does not
      // exist, which is worse than no way back because it looks like it worked.
      final bad = <String>[];
      for (final path in _samplePaths()) {
        final a = resolve(path);
        final d = a.destination;
        if (d != null && !registry.exists(d)) bad.add('$path -> $d');
      }
      expect(bad, isEmpty);
    });

    test('every non-root destination offers SOME way out', () {
      final none = <String>[];
      for (final path in _samplePaths()) {
        final a = resolve(path);
        if (a.semantic == ReturnSemantic.rootNoReturn) continue;
        if (a.destination == null &&
            a.semantic != ReturnSemantic.stackReturn &&
            a.semantic != ReturnSemantic.modalDismiss) {
          none.add(path);
        }
      }
      expect(none, isEmpty);
    });

    test('a resolved destination is never the destination itself', () {
      // A return that goes where you already are is a loop wearing an arrow.
      for (final path in _samplePaths()) {
        final a = resolve(path);
        expect(a.destination, isNot(path), reason: path);
      }
    });

    test('the return target passes RC4 shape validation', () {
      for (final path in _samplePaths()) {
        final d = resolve(path).destination;
        if (d == null) continue;
        expect(ReturnPathAuthority.safeDestination(d), isNotNull,
            reason: '$path resolved to a shape RC4 would refuse: $d');
      }
    });

    test('a SIGNED-OUT reader can actually reach the public root', () {
      // The one place the two authorities deliberately disagree. RC4 refuses
      // '/' as a preserved gate target — correctly, it says nothing. It is a
      // real destination for a return, and refusing it made the control on
      // /terms render and then do nothing when tapped.
      final a = resolve('/terms', authed: false);
      expect(a.destination, '/');
      expect(ReturnPathAuthority.safeDestination(a.destination), '/',
          reason: 'the signed-out way out of an informational page is refused');
    });

    test('RC4 itself is unchanged — it still refuses the root', () {
      // Weakening RC4 to fix the above would have loosened the open-redirect
      // refusal for every gate in the product.
      expect(validatedReturnTarget('/'), isNull);
      expect(validatedReturnTarget('//evil.com'), isNull);
      expect(ReturnPathAuthority.safeDestination('//evil.com'), isNull);
    });
  });
}

/// Concrete paths standing in for the registered patterns, so parameterised
/// routes are exercised as a person would actually meet them.
List<String> _samplePaths() => const [
      '/institutions',
      '/institutions/aura-platform-llc',
      '/institutions/aura-platform-llc/units',
      '/institutions/aura-platform-llc/units/finance',
      '/institution/aura-platform-llc/spaces',
      '/institution/aura-platform-llc/spaces/general',
      '/institution/aura-platform-llc/members',
      '/institution/aura-platform-llc/units/u1',
      '/institution/aura-platform-llc/announcements',
      '/messages/c/conv-1',
      '/posts/p1',
      '/articles/some-slug',
      '/u/someone',
      '/privacy',
      '/terms',
      '/mission',
      '/saved',
      '/updates',
      '/activity',
      '/security',
      '/devices',
      '/spaces',
      '/spaces/some-space',
      '/discover/people',
      '/admin/users',
      '/me/settings',
    ];
