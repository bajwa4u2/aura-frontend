import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/meetings/domain/meeting_institution_routing.dart';

// Realtime Architecture Correction — Phase 6, Meeting Attendee-Context
// Restoration. Pure-function coverage for the shared routing authority now
// used by booking_confirm_screen.dart, keep_meeting_screen.dart, and
// meeting_detail_screen.dart.

void main() {
  group('belongsToOwningInstitution', () {
    test('unowned meeting (no institution) never belongs', () {
      expect(
        belongsToOwningInstitution(
          owningInstitutionId: null,
          viewerActiveInstitutionId: 'inst-1',
          viewerAffiliationInstitutionIds: const ['inst-1'],
        ),
        isFalse,
      );
    });

    test('viewer whose active institution identity matches the owner belongs', () {
      expect(
        belongsToOwningInstitution(
          owningInstitutionId: 'inst-1',
          viewerActiveInstitutionId: 'inst-1',
          viewerAffiliationInstitutionIds: const [],
        ),
        isTrue,
      );
    });

    test('viewer affiliated with the owning institution (but not active) belongs', () {
      expect(
        belongsToOwningInstitution(
          owningInstitutionId: 'inst-1',
          viewerActiveInstitutionId: 'inst-2',
          viewerAffiliationInstitutionIds: const ['inst-9', 'inst-1'],
        ),
        isTrue,
      );
    });

    test('an external attendee — booked/invited but no institution affiliation — does not belong', () {
      expect(
        belongsToOwningInstitution(
          owningInstitutionId: 'inst-1',
          viewerActiveInstitutionId: null,
          viewerAffiliationInstitutionIds: const [],
        ),
        isFalse,
      );
    });

    test('affiliation with a DIFFERENT institution does not grant access to this one', () {
      expect(
        belongsToOwningInstitution(
          owningInstitutionId: 'inst-1',
          viewerActiveInstitutionId: 'inst-2',
          viewerAffiliationInstitutionIds: const ['inst-2', 'inst-3'],
        ),
        isFalse,
      );
    });
  });

  group('resolveMeetingRecordRoute — the actual regression this chapter fixes', () {
    test('institutional actor routes into the Institution Workspace shell', () {
      expect(
        resolveMeetingRecordRoute(
          meetingId: 'm1',
          owningInstitutionId: 'inst-1',
          viewerBelongsToOwningInstitution: true,
        ),
        '/institution/inst-1/meetings/m1',
      );
    });

    test('external attendee of an institution-owned meeting routes to the member-path record, NOT the Institution Workspace shell', () {
      expect(
        resolveMeetingRecordRoute(
          meetingId: 'm1',
          owningInstitutionId: 'inst-1',
          viewerBelongsToOwningInstitution: false,
        ),
        '/meetings/m1',
      );
    });

    test('a personal (unowned) meeting always routes to the member-path record', () {
      expect(
        resolveMeetingRecordRoute(
          meetingId: 'm1',
          owningInstitutionId: null,
          viewerBelongsToOwningInstitution: false,
        ),
        '/meetings/m1',
      );
    });

    test('an empty meeting id falls back to /home rather than constructing a broken route', () {
      expect(
        resolveMeetingRecordRoute(
          meetingId: '   ',
          owningInstitutionId: 'inst-1',
          viewerBelongsToOwningInstitution: true,
        ),
        '/home',
      );
    });
  });


  group('the live room address', () {
    // FOUNDER-OBSERVED 2026-09-07. Pressing Enter room on a meeting with no
    // owning institution navigated to `/home?sessionId=...&isHost=true`. The
    // person landed on their feed, pressed the card again, and landed there
    // again — from the home card and the profile participation card alike. It
    // read as the record throwing when it was routing, to a page that is not a
    // room.
    //
    // The member route existed the whole time with nothing pointing at it,
    // because every institutional viewer takes the other branch and so the
    // broken one was only ever reached by people whose meeting had no owner.
    test('sends a member to the member room, never to the feed', () {
      final route = resolveMeetingLiveRoute(
        meetingId: 'm-1',
        viewerInstitutionId: null,
      );
      expect(route, '/meetings/m-1/live');
      expect(route, isNot(contains('/home')));
    });

    test('sends a canonicalised institutional viewer to the workspace room', () {
      expect(
        resolveMeetingLiveRoute(meetingId: 'm-1', viewerInstitutionId: 'inst-1'),
        '/institution/inst-1/meetings/m-1/live',
      );
    });

    test('treats a blank institution as no institution', () {
      expect(
        resolveMeetingLiveRoute(meetingId: 'm-1', viewerInstitutionId: '   '),
        '/meetings/m-1/live',
      );
    });

    test('agrees with the record route about which surface the viewer is on', () {
      // The two must not disagree: a viewer sent to the member record and then
      // into an institution room would cross a boundary mid-meeting.
      const viewer = null;
      expect(
        resolveMeetingRecordRoute(
          meetingId: 'm-1',
          owningInstitutionId: 'inst-1',
          viewerBelongsToOwningInstitution: false,
        ),
        '/meetings/m-1',
      );
      expect(
        resolveMeetingLiveRoute(meetingId: 'm-1', viewerInstitutionId: viewer),
        '/meetings/m-1/live',
      );
    });
  });
}