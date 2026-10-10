import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/institutions/institution_route_authority.dart';

/// 10 Oct 2026: `/institution/aura-platform-llc` rendered "Route not found"
/// and `/i/aura-platform-llc` opened the invitation claim screen.
void main() {
  const held = InstitutionAuthoritySnapshot(
    resolved: true,
    activeId: 'inst-1',
    authorizedIds: ['inst-1'],
    slugToId: {'aura-platform-llc': 'inst-1'},
    idToSlug: {'inst-1': 'aura-platform-llc'},
  );

  group('/institution/:address', () {
    test('a person who holds it arrives at its Desk', () {
      expect(
        institutionRootDestination(held, 'aura-platform-llc'),
        '/institution/aura-platform-llc/desk',
      );
    });

    test('an id or a differently-cased address arrives at the canonical Desk', () {
      expect(
        institutionRootDestination(held, 'inst-1'),
        '/institution/aura-platform-llc/desk',
      );
      expect(
        institutionRootDestination(held, 'Aura-Platform-LLC'),
        '/institution/aura-platform-llc/desk',
      );
    });

    test('anyone else is shown the public page', () {
      expect(
        institutionRootDestination(held, 'city-of-detroit'),
        '/institutions/city-of-detroit',
      );
      expect(
        institutionRootDestination(
          const InstitutionAuthoritySnapshot(resolved: true),
          'aura-platform-llc',
        ),
        '/institutions/aura-platform-llc',
      );
    });

    test('while authority is resolving, the Desk gate decides', () {
      expect(
        institutionRootDestination(
          const InstitutionAuthoritySnapshot(resolved: false),
          'aura-platform-llc',
        ),
        '/institution/aura-platform-llc/desk',
      );
    });
  });

  group('/i/:segment', () {
    test('an institution address is not an invitation', () {
      expect(isInstitutionAddressSegment('aura-platform-llc'), isTrue);
      expect(isInstitutionAddressSegment('detroit'), isTrue);
    });

    test('a claim token stays an invitation', () {
      // randomBytes(32).toString('base64url'), as invitations.service mints.
      expect(
        isInstitutionAddressSegment('q3Vx_9kLmN2pQrStUvWxYz0aBcDeFgHiJkLmNoPqRsT'),
        isFalse,
      );
      // Even an all-lower-case one: 43 characters is a token's length.
      expect(isInstitutionAddressSegment('a' * 43), isFalse);
      expect(isInstitutionAddressSegment('Has-Capitals'), isFalse);
      expect(isInstitutionAddressSegment('-edge'), isFalse);
    });
  });
}
