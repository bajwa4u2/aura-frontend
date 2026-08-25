import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aura/core/auth/session_bootstrap.dart';
import 'package:aura/core/auth/session_providers.dart';
import 'package:aura/core/navigation/return_path_authority.dart';
import 'package:aura/core/navigation/route_registry.dart';
import 'package:aura/router.dart';

/// INSTITUTION CONTEXT MUST SURVIVE — founder ruling §11.
///
/// 22 of the 83 audited defects were institution-context findings, and the
/// failure mode was always the same: returning from an institution destination
/// dropped the person into a generic root, losing the institution entirely.
///
/// So this exercises the chains the census supports — institution → member
/// surface → Space → Conversation → detail — and asserts the institution is
/// still in the answer at every step.
void main() {
  late RouteRegistry registry;
  const inst = 'aura-platform-llc';

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final c = ProviderContainer(overrides: [
      sessionBootstrapProvider.overrideWith((ref) async {}),
      isAuthedProvider.overrideWithValue(true),
      emailVerifiedProvider.overrideWith((ref) async => true),
      identityBaselineCompleteProvider.overrideWith((ref) async => true),
    ]);
    registry =
        RouteRegistry.fromRoutes(c.read(routerProvider).configuration.routes);
  });

  ReturnAction out(String path, {bool canPop = false}) =>
      ReturnPathAuthority.resolve(
        path: path,
        canPop: canPop,
        isAuthed: true,
        exists: registry.exists,
      );

  group('a direct entry never loses the institution', () {
    const chain = [
      '/institution/$inst/spaces',
      '/institution/$inst/spaces/general',
      '/institution/$inst/members',
      '/institution/$inst/units',
      '/institution/$inst/units/u1',
      '/institution/$inst/announcements',
      '/institution/$inst/announcements/a1',
      '/institution/$inst/posts/p1',
      '/institution/$inst/join-requests',
      '/institution/$inst/invites',
      '/institution/$inst/domains',
      '/institution/$inst/public-engagement',
      '/institution/$inst/availability',
    ];

    for (final path in chain) {
      test('$path returns inside its institution', () {
        final a = out(path);
        expect(a.hasAffordance, isTrue, reason: '$path has no way out at all');
        expect(a.destination, isNotNull);
        expect(a.destination, contains('/institution/$inst'),
            reason: '$path drops the person out of the institution — this is '
                'the context loss §11 exists to remove');
      });
    }
  });

  test('the way out is always a destination the app renders', () {
    for (final p in [
      '/institution/$inst/spaces/general',
      '/institution/$inst/units/u1',
      '/institution/$inst/members',
    ]) {
      final d = out(p).destination!;
      expect(registry.exists(d), isTrue,
          reason: '$p returns to $d, which nothing renders');
    }
  });

  test('an in-app journey unwinds itself rather than jumping to a section', () {
    // Founder ruling §8 mode A: Directory → Institution → Space →
    // Conversation must return through what the person actually did.
    for (final p in [
      '/institution/$inst/spaces/general',
      '/institution/$inst/units/u1',
    ]) {
      final a = out(p, canPop: true);
      expect(a.semantic, ReturnSemantic.stackReturn, reason: p);
      expect(a.destination, isNull,
          reason: '$p invented a destination while real history existed');
    }
  });

  test('a Space returns to Spaces, not to the workspace root', () {
    // Specificity matters: the nearest true parent, not the nearest
    // convenient one.
    expect(out('/institution/$inst/spaces/general').destination,
        '/institution/$inst/spaces');
  });

  test('an institution SECTION root returns to the institution itself', () {
    // A section root has no structural parent. Before, that meant /home.
    final a = out('/institution/$inst/members');
    expect(a.semantic, ReturnSemantic.contextReturn);
    expect(a.destination, startsWith('/institution/$inst/'));
  });

  test('a conversation reached in institution context still returns to '
      'Messages', () {
    // The canonical Conversation surface is member-space by design (the
    // DirectThread cutover resolves there for an institution actor too), so
    // its parent is Messages. Asserted so a future change to that has to be
    // deliberate.
    expect(out('/messages/c/c1').destination, '/messages');
  });
}
