// F053 / F116 — THE PERSON / MEETING-ROLE BOUNDARY IN THE MEETINGS DOMAIN.
//
// Founder ruling 2026-08-19: an Aura user is not a guest merely because their
// display identity is incomplete. "Guest" is an EXTERNAL PARTICIPANT TYPE, and
// a meeting model may not answer PERSON identity with it.
//
//     PERSON IDENTITY  ≠  MEETING ROLE / EXTERNAL PARTICIPANT TYPE
//
// The ruling cuts both ways, and both directions are tested here: the AURA_USER
// branch must stop inventing "Guest", and the genuine external-participant
// branch must KEEP it, because for an external attendee it is an accurate
// statement of what they are rather than a fabricated name.
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/meetings/domain/availability_profile.dart';
import 'package:aura/features/meetings/domain/meeting.dart';
import 'package:aura/features/meetings/domain/meeting_entry_resolution.dart';
import 'package:aura/features/meetings/domain/meeting_identity.dart';

void main() {
  group('MeetingIdentityRef — the AURA_USER branch', () {
    test('an Aura user with no display name is NOT named Guest', () {
      final ref = MeetingIdentityRef.fromUserJson(const {
        'id': 'u-1',
        'handle': 'amjad',
        'email': 'a@example.com',
      });

      expect(ref.identityType, 'AURA_USER');
      expect(ref.isAuraUser, isTrue);
      expect(ref.displayName, isNot('Guest'));
      // The canonical order reaches their handle long before any neutral word.
      expect(ref.displayName, '@amjad');
      expect(ref.auraUserId, 'u-1');
      expect(ref.handle, 'amjad');
    });

    test('an Aura user with neither name nor handle gets the SHARED neutral '
        'word, not a meetings-specific one', () {
      final ref = MeetingIdentityRef.fromUserJson(const {
        'id': 'u-2',
        'email': 'b@example.com',
      });

      expect(ref.isAuraUser, isTrue);
      expect(ref.displayName, 'Someone');
      expect(ref.displayName, isNot('Guest'));
    });

    test('a named Aura user is named by their own name', () {
      final ref = MeetingIdentityRef.fromUserJson(const {
        'id': 'u-3',
        'displayName': 'Amjad Bajwa',
        'handle': 'amjad',
        'email': 'c@example.com',
        'emailVerifiedAt': '2026-01-01T00:00:00.000Z',
      });

      expect(ref.displayName, 'Amjad Bajwa');
      expect(ref.verifiedEmail, isTrue);
    });

    test('an embedded AURA_USER booker identity resolves as a person', () {
      final ref = MeetingIdentityRef.fromJson(const {
        'identityType': 'AURA_USER',
        'auraUserId': 'u-4',
        'displayName': '',
        'handle': 'nadia',
        'email': 'd@example.com',
        'avatarUrl': 'https://cdn.example/a.png',
      });

      expect(ref.isAuraUser, isTrue);
      expect(ref.auraUserId, 'u-4');
      expect(ref.displayName, '@nadia');
      expect(ref.avatarUrl, 'https://cdn.example/a.png');
    });
  });

  group('MeetingIdentityRef — external participants keep their own semantics', () {
    test('an unnamed GUEST is still called Guest', () {
      final ref = MeetingIdentityRef.fromJson(const {
        'identityType': 'GUEST',
        'email': 'guest@example.com',
      });

      expect(ref.isAuraUser, isFalse);
      expect(ref.identityType, 'GUEST');
      expect(ref.displayName, 'Guest');
      expect(ref.auraUserId, isNull);
      expect(ref.handle, isNull);
    });

    test('a named external CONTACT keeps the name they gave', () {
      final ref = MeetingIdentityRef.fromJson(const {
        'identityType': 'CONTACT',
        'contactId': 'c-1',
        'displayName': 'Dr. Rivera',
        'email': 'rivera@example.com',
      });

      expect(ref.isAuraUser, isFalse);
      expect(ref.displayName, 'Dr. Rivera');
      expect(ref.contactId, 'c-1');
      // An external contact is NOT forced into an Aura person.
      expect(ref.person, isNull);
    });

    test('a saved CONTACT that is LINKED to an Aura user is the Aura person, '
        'and still remembers it is a contact', () {
      // buildContactBookerIdentity spreads the AURA_USER identity and keeps
      // contactId — an Aura person the institution also has on file.
      final ref = MeetingIdentityRef.fromJson(const {
        'identityType': 'AURA_USER',
        'auraUserId': 'u-8',
        'contactId': 'c-2',
        'displayName': 'Imran Qadir',
        'handle': 'imran',
        'email': 'imran@example.com',
      });

      expect(ref.isAuraUser, isTrue);
      expect(ref.displayName, 'Imran Qadir');
      expect(ref.contactId, 'c-2');
    });

    test('meeting-domain state stays on the ref, never inside the person', () {
      final ref = MeetingIdentityRef.fromJson(const {
        'identityType': 'AURA_USER',
        'auraUserId': 'u-5',
        'displayName': 'Sara',
        'memberId': 'm-1',
        'title': 'Head of Clinic',
        'email': 'sara@example.com',
        'verifiedEmail': true,
      });

      expect(ref.memberId, 'm-1');
      expect(ref.title, 'Head of Clinic');
      expect(ref.verifiedEmail, isTrue);
      expect(ref.email, 'sara@example.com');
    });
  });

  group('MeetingEntryResolution — the entrant is two kinds of thing', () {
    Map<String, dynamic> payload(Map<String, dynamic> identity) => {
          'outcome': 'GUEST_DIRECT',
          'action': 'JOIN',
          'reasonCode': 'OK',
          'identity': identity,
        };

    test('a MEMBER entrant is read as a person', () {
      final r = MeetingEntryResolution.fromJson(payload(const {
        'kind': 'MEMBER',
        'displayName': 'Hana Yusuf',
        'email': 'hana@example.com',
      }));

      expect(r.identityKind, 'MEMBER');
      expect(r.identityIsAuraPerson, isTrue);
      expect(r.identityName, 'Hana Yusuf');
      expect(r.identityEmail, 'hana@example.com');
    });

    test('a GUEST_SESSION entrant keeps the name the EVIDENCE supplied and is '
        'not turned into an Aura person', () {
      final r = MeetingEntryResolution.fromJson(payload(const {
        'kind': 'GUEST_SESSION',
        'displayName': 'Walk-in Attendee',
      }));

      expect(r.identityIsAuraPerson, isFalse);
      expect(r.identityPerson, isNull);
      expect(r.identityName, 'Walk-in Attendee');
    });

    test('an unresolved entrant is still UNRESOLVED — the pre-join name box '
        'must not be pre-filled with a neutral word', () {
      final anonymous =
          MeetingEntryResolution.fromJson(payload(const {'kind': 'ANONYMOUS'}));
      expect(anonymous.identityName, isNull);

      // The same must hold for a MEMBER the resolver could not name: the
      // canonical LABEL is for rendering, and this field is not rendered.
      final unnamedMember =
          MeetingEntryResolution.fromJson(payload(const {'kind': 'MEMBER'}));
      expect(unnamedMember.identityName, isNull);
      expect(unnamedMember.identityName, isNot('Someone'));
    });

    test('a missing identity block still fails closed the way it always did',
        () {
      final r = MeetingEntryResolution.fromJson(const {
        'outcome': 'MEETING_UNAVAILABLE',
        'action': 'BLOCK',
      });

      expect(r.identityKind, 'ANONYMOUS');
      expect(r.identityName, isNull);
      expect(r.identityIsAuraPerson, isFalse);
    });
  });

  group('Meeting host and profile owner — canonical naming', () {
    test('MeetingHost no longer answers Unknown for a person with a handle', () {
      final host = MeetingHost.fromJson(const {
        'id': 'u-6',
        'handle': 'kareem',
        'title': 'Director',
      });

      expect(host.name, '@kareem');
      expect(host.name, isNot('Unknown'));
      expect(host.id, 'u-6');
      // The institutional role line is meeting-domain state, not identity.
      expect(host.title, 'Director');
    });

    test('ProfileOwner names its person canonically', () {
      final owner = ProfileOwner.fromJson(const {
        'id': 'u-7',
        'displayName': 'Layla Haddad',
        'handle': 'layla',
      });

      expect(owner.name, 'Layla Haddad');
      expect(owner.handle, 'layla');
    });

    test('MeetingEntryHost reads a reduced person projection without '
        'reinterpreting it', () {
      final host = MeetingEntryHost.fromJson(const {
        'displayName': 'Dr. Osman',
        'avatarUrl': 'https://cdn.example/o.png',
        'title': 'Consultant',
      });

      expect(host.displayName, 'Dr. Osman');
      expect(host.avatarUrl, 'https://cdn.example/o.png');
      expect(host.title, 'Consultant');
    });
  });
}
