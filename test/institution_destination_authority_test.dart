// SAME ANSWER THROUGH EVERY ENTRY PATH.
//
// Founder ruling (2026-08-23): an unauthorized destination should normally
// never have been projected; if an exceptional, stale or direct path reaches
// it, fail-safe denial protects the boundary. Denial is not ordinary UX.
//
// The defect this prevents is drift between the rail and the address bar: a
// destination vanishing from navigation while its URL stays open. Both read
// ONE table, and these certify that they agree.
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/app/shell/member_shell.dart';
import 'package:aura/core/authority/capability_projection.dart';
import 'package:aura/core/institutions/institution_access_provider.dart';
import 'package:aura/core/institutions/institution_destination_authority.dart';

const _adminCapabilities = <String>{
  InstitutionCapabilities.manageMembers,
  InstitutionCapabilities.manageInvitations,
  InstitutionCapabilities.manageJoinRequests,
  InstitutionCapabilities.manageMeetings,
  InstitutionCapabilities.manageAvailability,
  InstitutionCapabilities.manageSpaces,
  InstitutionCapabilities.manageAnnouncements,
  InstitutionCapabilities.manageAnalytics,
  InstitutionCapabilities.hostMeetings,
  InstitutionCapabilities.officialRepresentation,
  InstitutionCapabilities.publishOfficial,
  InstitutionCapabilities.startLive,
  InstitutionCapabilities.endLive,
};

CapabilityProjection projectionFor({
  required String role,
  Set<String> capabilities = const {},
}) {
  return CapabilityProjection(
    InstitutionStanding.fromBackend(
      institutionId: 'inst-1',
      institutionName: 'Test Institution',
      institutionLogoUrl: null,
      capabilities: capabilities,
      roleWire: role,
      isInstitutionAccount: false,
    ),
  );
}

InstitutionIdentity identityFor({
  required String role,
  Set<String> capabilities = const {},
}) {
  return InstitutionIdentity(
    id: 'inst-1',
    name: 'Test Institution',
    slug: 'test',
    isAuthorizedSpeaker:
        capabilities.contains(InstitutionCapabilities.officialRepresentation),
    capabilities: capabilities,
    role: role,
  );
}

void main() {
  group('section parsing', () {
    test('reads the section from a canonical institution address', () {
      expect(institutionSectionOf('/institution/inst-1/invites'), 'invites');
      expect(
        institutionSectionOf('/institution/inst-1/meetings/m-1/room'),
        'meetings',
      );
      expect(institutionSectionOf('/institution/inst-1/dashboard?x=1'),
          'dashboard');
    });

    test('is not fooled by other addresses', () {
      expect(institutionSectionOf('/institutions/aura-platform'), isNull);
      expect(institutionSectionOf('/home'), isNull);
      expect(institutionSectionOf('/institution/dashboard'), isNull);
    });
  });

  group('a member reaching an administrative address directly', () {
    final member = projectionFor(role: 'MEMBER');

    test('is refused every capability-gated destination', () {
      for (final section in [
        'dashboard',
        'join-requests',
        'invites',
        'availability',
        'domains',
        'billing',
        'edit-profile',
      ]) {
        expect(institutionDestinationPermits(member, section), isFalse,
            reason: '$section requires a delegated capability');
      }
    });

    test('keeps every participation destination', () {
      for (final section in [
        'explore',
        'activity',
        'announcements',
        'live-rooms',
        'spaces',
        'messages',
        'meetings',
        'members',
        'profile',
      ]) {
        expect(institutionDestinationPermits(member, section), isTrue,
            reason: '$section is participation baseline');
      }
    });
  });

  group('capabilities compose at the address, exactly as in the rail', () {
    test('a delegated capability opens exactly its own destination', () {
      final billingOnly = projectionFor(
        role: 'MEMBER',
        capabilities: {InstitutionCapabilities.manageBilling},
      );

      expect(institutionDestinationPermits(billingOnly, 'billing'), isTrue);
      // ...and nothing else it did not name.
      expect(institutionDestinationPermits(billingOnly, 'domains'), isFalse);
      expect(institutionDestinationPermits(billingOnly, 'invites'), isFalse);
    });

    test('a Host reaches no administrative address', () {
      final host = projectionFor(
        role: 'MEMBER',
        capabilities: {InstitutionCapabilities.hostMeetings},
      );
      for (final section in ['dashboard', 'invites', 'join-requests']) {
        expect(institutionDestinationPermits(host, section), isFalse);
      }
    });

    test('a Representative reaches no administrative address', () {
      final rep = projectionFor(
        role: 'MEMBER',
        capabilities: {
          InstitutionCapabilities.officialRepresentation,
          InstitutionCapabilities.publishOfficial,
        },
      );
      for (final section in ['dashboard', 'invites', 'billing']) {
        expect(institutionDestinationPermits(rep, section), isFalse);
      }
    });

    test('one administrative capability opens the operational surface', () {
      // Operational authority is a SET of acts, not a role: holding any one
      // administrative capability is enough, which is how a delegated manager
      // who is not an admin still gets an operational surface.
      final oneCapability = projectionFor(
        role: 'MEMBER',
        capabilities: {InstitutionCapabilities.manageSpaces},
      );
      expect(institutionDestinationPermits(oneCapability, 'dashboard'), isTrue);
    });
  });

  group('authoring is Representative authority, not administration', () {
    final representative = projectionFor(
      role: 'MEMBER',
      capabilities: {InstitutionCapabilities.officialRepresentation},
    );
    final member = projectionFor(role: 'MEMBER');

    test('a Representative may reach the authoring destinations', () {
      // The backend draws this line: authoring requires
      // OFFICIAL_REPRESENTATION, publishing requires PUBLISH_OFFICIAL /
      // MANAGE_ANNOUNCEMENTS. A Representative drafts; releasing is separate.
      for (final section in ['posts/new', 'posts/edit', 'announcements/new']) {
        expect(institutionDestinationPermits(representative, section), isTrue,
            reason: '$section is authoring in the institution voice');
      }
    });

    test('and still reaches nothing administrative', () {
      for (final section in ['dashboard', 'invites', 'billing', 'domains']) {
        expect(institutionDestinationPermits(representative, section), isFalse);
      }
    });

    test('a plain member may read but not author', () {
      expect(institutionDestinationPermits(member, 'announcements'), isTrue);
      expect(institutionDestinationPermits(member, 'announcements/new'), isFalse);
      expect(institutionDestinationPermits(member, 'posts/new'), isFalse);
    });

    test('an authoring verb is part of the destination identity', () {
      // Reading a post and composing one are different acts, so the address
      // must not collapse them into one section.
      expect(institutionSectionOf('/institution/i1/posts/new'), 'posts/new');
      expect(
        institutionSectionOf('/institution/i1/posts/p1/edit'),
        'posts/edit',
      );
      expect(institutionSectionOf('/institution/i1/posts/p1'), 'posts');
    });
  });

  group('unresolved standing decides nothing (RC2)', () {
    test('a null projection refuses rather than admits', () {
      // The ROUTER checks `resolved` before consulting this, so a person mid
      // load is never refused; this is the fail-closed default for everything
      // else that asks.
      expect(institutionDestinationPermits(null, 'billing'), isFalse);
      // Baseline destinations need no authority at all.
      expect(institutionDestinationPermits(null, 'explore'), isTrue);
    });
  });

  group('the rail and the address cannot disagree', () {
    test('every gated nav entry has the same authority as its address', () {
      // The regression this catches: a destination hidden from the rail while
      // its URL stayed open, or gated differently in the two places.
      final admin = identityFor(role: 'ADMIN', capabilities: _adminCapabilities);

      for (final entry in buildInstitutionWorkspaceEntries(admin)) {
        final path = entry.resolvedPath(admin);
        if (path == null) continue;
        final section = institutionSectionOf(path);
        if (section == null) continue;

        expect(
          entry.requiresAny,
          institutionDestinationAuthority(section),
          reason:
              '"${entry.label}" ($section) is gated differently in navigation '
              'than at its address',
        );
      }
    });
  });
}
