import 'package:aura/app/route_targets.dart';
import 'package:flutter_test/flutter_test.dart';

/// A PUBLIC SPACE ADDRESS SURVIVES NORMALISATION.
///
/// `/spaces/...` used to be rewritten to `/messages` on the reasoning that a
/// bare `/spaces/:id` named a retired personal correspondence space. But that
/// prefix is also the LIVE PublicSpace address — the destination Discover →
/// Spaces links to — and the rule could not tell the two apart.
///
/// Measured 2026-08-23: production holds ZERO persisted deeplinks naming
/// `/spaces/`, so the rule protected nothing real — while the product offers
/// TEN live Space addresses through the public registry, six backed by a
/// PublicSpace row and four resolving through the registry fallback (both
/// kinds verified rendering in production).
///
/// SCOPE, stated precisely — this normaliser governs the post-sign-in
/// `?redirect=` destination, Activity attention deeplinks and notification
/// deeplinks. Direct navigation and in-app Discover taps never reach it, and
/// /spaces/civic was verified rendering correctly in production while the rule
/// was still live. The reachable loss was the sign-in redirect: arriving
/// signed-out at a Space and then authenticating dropped the destination and
/// landed on Messages instead.
void main() {
  group('public space addresses reach their own surface', () {
    test('a PublicSpace slug is left alone', () {
      // All TEN registry addresses, not just the six with a PublicSpace row —
      // a registry-only Space is just as reachable and was just as rewritten.
      for (final slug in [
        'civic',
        'climate',
        'culture',
        'economy',
        'education',
        'health',
        'justice',
        'local',
        'science',
        'technology',
      ]) {
        expect(
          normalizeMemberFacingRoute('/spaces/$slug'),
          '/spaces/$slug',
          reason: 'the live Discover → Spaces destination must survive',
        );
      }
    });

    test('the spaces directory itself is untouched', () {
      expect(normalizeMemberFacingRoute('/spaces'), '/spaces');
    });

    test('a query string does not reopen the rewrite', () {
      expect(
        normalizeMemberFacingRoute('/spaces/civic?from=share'),
        '/spaces/civic?from=share',
      );
    });
  });

  group('the sign-in redirect keeps its destination', () {
    test('a Space survives the redirect normaliser', () {
      // This is the reachable path the old rule actually broke: the router
      // sends `?redirect=` through this same primitive before honouring it.
      expect(normalizeMemberFacingRoute('/spaces/civic', fallback: '/home'),
          '/spaces/civic');
    });
  });

  group('genuinely retired families still normalise', () {
    test('the retired correspondence family still goes to Messages', () {
      // This is the address the removed rule was actually aimed at. It keeps
      // its treatment; only the collision with PublicSpace was removed.
      expect(
        normalizeMemberFacingRoute('/correspondence/abc'),
        startsWith('/me/correspondence'),
      );
      expect(normalizeMemberFacingRoute('/conversations'), '/messages');
    });

    test('a retired /spaces/<legacy-id> now answers honestly instead', () {
      // It resolves to the PublicSpace surface and finds nothing, which is the
      // truthful answer for a retired address — better than silently landing
      // somewhere unrelated and looking like it worked.
      const legacy = '/spaces/cmsmely4s002ltw0c1a7kx8so';
      expect(normalizeMemberFacingRoute(legacy), legacy);
    });
  });
}
