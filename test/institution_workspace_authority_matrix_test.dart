// INSTITUTION WORKSPACE — AUTHORITY PROJECTION CERTIFICATION.
//
// Founder principle (2026-08-23): the workspace is a PROJECTION of the
// person's legitimate institutional authority, not a universal console with
// permissions layered over it. And: VISIBILITY FOLLOWS AUTHORITY FIRST,
// DENIAL PROTECTS THE BOUNDARY SECOND.
//
// So these certify the projection itself. Every case checks BOTH directions —
// overexposure (sees something authority does not grant) and underexposure
// (a granted capability fails to surface its destination). Both fail.
//
// The combinations are the ones the canonical model can actually produce:
// three roles crossed with delegated capabilities. Representative and Host are
// capabilities, never roles, so they appear here as Member + grant.
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/app/shell/member_shell.dart';
import 'package:aura/core/institutions/institution_access_provider.dart';

const _adminCapabilities = <String>{
  InstitutionCapabilities.manageMembers,
  InstitutionCapabilities.manageInvitations,
  InstitutionCapabilities.manageJoinRequests,
  InstitutionCapabilities.manageMeetings,
  InstitutionCapabilities.manageAvailability,
  InstitutionCapabilities.manageBookings,
  InstitutionCapabilities.managePublicBooking,
  InstitutionCapabilities.manageSpaces,
  InstitutionCapabilities.manageAnnouncements,
  InstitutionCapabilities.manageAnalytics,
  InstitutionCapabilities.manageMaterials,
  InstitutionCapabilities.manageSummaries,
  InstitutionCapabilities.manageRecordings,
  InstitutionCapabilities.hostMeetings,
  InstitutionCapabilities.officialRepresentation,
  InstitutionCapabilities.publishOfficial,
  InstitutionCapabilities.startLive,
  InstitutionCapabilities.endLive,
};

const _ownerHeld = <String>{
  InstitutionCapabilities.manageBranding,
  InstitutionCapabilities.manageDomains,
  InstitutionCapabilities.manageBilling,
  InstitutionCapabilities.manageVerification,
};

InstitutionIdentity identity({
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

Set<String> labelsFor(InstitutionIdentity? id) =>
    buildInstitutionWorkspaceEntries(id).map((e) => e.label).toSet();

void main() {
  // ROLE_CAPABILITIES[MEMBER] is the empty list. Every capability a member
  // holds is an explicit delegation.
  final member = identity(role: 'MEMBER');
  final memberHost = identity(
    role: 'MEMBER',
    capabilities: {InstitutionCapabilities.hostMeetings},
  );
  final memberRep = identity(
    role: 'MEMBER',
    capabilities: {
      InstitutionCapabilities.officialRepresentation,
      InstitutionCapabilities.publishOfficial,
    },
  );
  final memberRepHost = identity(
    role: 'MEMBER',
    capabilities: {
      InstitutionCapabilities.officialRepresentation,
      InstitutionCapabilities.publishOfficial,
      InstitutionCapabilities.hostMeetings,
    },
  );
  final admin = identity(role: 'ADMIN', capabilities: _adminCapabilities);
  final owner = identity(
    role: 'OWNER',
    capabilities: {..._adminCapabilities, ..._ownerHeld},
  );

  group('participation baseline (D1)', () {
    test('a member with no delegation keeps their participation surfaces', () {
      final labels = labelsFor(member);

      // UNDEREXPOSURE: a member must not lose the institution they belong to.
      for (final expected in [
        'Explore',
        'Activity',
        'Announcements',
        'Live',
        'Spaces',
        'Messages',
        'Meetings',
        'Members',
        'Profile',
      ]) {
        expect(labels, contains(expected),
            reason: '$expected is participation baseline');
      }
    });

    test('membership alone grants no administration or governance', () {
      final labels = labelsFor(member);

      // OVEREXPOSURE: none of these may follow from standing alone.
      for (final forbidden in [
        'Overview',
        'Join Requests',
        'Invites',
        'Booking pages',
        'Domains',
        'Billing',
        'Edit Profile',
      ]) {
        expect(labels, isNot(contains(forbidden)),
            reason: '$forbidden requires a delegated capability');
      }
    });
  });

  group('capabilities compose, roles do not gate', () {
    test('Host widens no destination beyond Meetings and Live controls', () {
      expect(labelsFor(memberHost), labelsFor(member),
          reason: 'HOST_MEETINGS governs controls inside Meetings and Live, '
              'not access to further destinations');
    });

    test('Representative gains no administration', () {
      final labels = labelsFor(memberRep);

      for (final forbidden in [
        'Join Requests',
        'Invites',
        'Billing',
        'Domains',
        'Overview',
      ]) {
        expect(labels, isNot(contains(forbidden)));
      }
    });

    test('Representative + Host is the union, never an escalation', () {
      final union = {...labelsFor(memberRep), ...labelsFor(memberHost)};
      expect(labelsFor(memberRepHost), union);
    });
  });

  group('administrative and governance authority', () {
    test('admin holds the operational workspace', () {
      final labels = labelsFor(admin);
      for (final expected in [
        'Overview',
        'Members',
        'Join Requests',
        'Invites',
        'Booking pages',
      ]) {
        expect(labels, contains(expected));
      }
    });

    test('admin does NOT hold owner-tier governance', () {
      // Owner-held capabilities are delegable, but only BY the owner — an
      // ADMIN does not receive them by role.
      final labels = labelsFor(admin);
      expect(labels, isNot(contains('Domains')));
      expect(labels, isNot(contains('Billing')));
      expect(labels, isNot(contains('Edit Profile')));
    });

    test('an owner-delegated capability reaches an ADMIN without a role change', () {
      final delegated = identity(
        role: 'ADMIN',
        capabilities: {
          ..._adminCapabilities,
          InstitutionCapabilities.manageBilling,
        },
      );
      expect(labelsFor(delegated), contains('Billing'));
      // ...and grants nothing it did not name.
      expect(labelsFor(delegated), isNot(contains('Domains')));
    });

    test('owner holds governance', () {
      final labels = labelsFor(owner);
      for (final expected in [
        'Domains',
        'Billing',
        'Edit Profile',
        'Overview',
      ]) {
        expect(labels, contains(expected));
      }
    });
  });

  group('standing is the floor', () {
    test('no standing projects no workspace at all', () {
      expect(labelsFor(null), isEmpty);
    });
  });

  group('the projection is authority-shaped, not role-shaped', () {
    test('a capability set alone determines the projection', () {
      // Same capabilities, different role label -> identical projection.
      final asAdmin = identity(role: 'ADMIN', capabilities: _adminCapabilities);
      final asMember = identity(
        role: 'MEMBER',
        capabilities: _adminCapabilities,
      );
      expect(labelsFor(asMember), labelsFor(asAdmin),
          reason: 'the role label explains standing; '
              'capabilities govern authority');
    });
  });
}
