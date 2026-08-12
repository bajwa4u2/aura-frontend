import 'package:flutter_test/flutter_test.dart';

import 'package:aura/router.dart';

void main() {
  group('requiresInstitutionAccessForPath — Meetings regression restoration', () {
    // 2026-08-14 — a booked/invited Meeting attendee with no institution
    // access was redirected to Institution Sign In merely because the
    // meeting's URL carried an institutionId segment. This locks in the
    // fix: meeting attendee sub-paths must never require institution
    // access, regardless of who owns the meeting.
    test('meeting attendee sub-paths do NOT require institution access', () {
      expect(
        requiresInstitutionAccessForPath('/institution/inst-1/meetings/mtg-1'),
        isFalse,
      );
      expect(
        requiresInstitutionAccessForPath(
          '/institution/inst-1/meetings/mtg-1/prep',
        ),
        isFalse,
      );
      expect(
        requiresInstitutionAccessForPath(
          '/institution/inst-1/meetings/mtg-1/room',
        ),
        isFalse,
      );
      expect(
        requiresInstitutionAccessForPath(
          '/institution/inst-1/meetings/mtg-1/waiting',
        ),
        isFalse,
      );
      expect(
        requiresInstitutionAccessForPath(
          '/institution/inst-1/meetings/mtg-1/live',
        ),
        isFalse,
      );
      expect(
        requiresInstitutionAccessForPath(
          '/institution/inst-1/meetings/mtg-1/summary',
        ),
        isFalse,
      );
      expect(
        requiresInstitutionAccessForPath(
          '/institution/inst-1/meetings/mtg-1/post-meeting',
        ),
        isFalse,
      );
    });

    test('institution-staff meeting management routes remain gated', () {
      // The meeting LIST (no meetingId segment) and CREATION route are
      // genuinely institution-staff-only and must stay behind the gate.
      expect(
        requiresInstitutionAccessForPath('/institution/inst-1/meetings'),
        isTrue,
      );
      expect(
        requiresInstitutionAccessForPath('/institution/inst-1/meetings/new'),
        isTrue,
      );
      expect(
        requiresInstitutionAccessForPath(
          '/institution/inst-1/availability',
        ),
        isTrue,
      );
    });

    test('other institution-scoped resources remain gated (no blanket weakening)', () {
      expect(
        requiresInstitutionAccessForPath('/institution/inst-1/profile'),
        isTrue,
      );
      expect(
        requiresInstitutionAccessForPath(
          '/institution/inst-1/announcements',
        ),
        isTrue,
      );
      expect(
        requiresInstitutionAccessForPath(
          '/institution/inst-1/correspondence',
        ),
        isTrue,
      );
      expect(requiresInstitutionAccessForPath(kInstitutionDashboardRoute), isTrue);
      expect(requiresInstitutionAccessForPath(kInstitutionVerificationRoute), isTrue);
    });

    test('non-institution paths are unaffected', () {
      expect(requiresInstitutionAccessForPath('/meetings/mtg-1'), isFalse);
      expect(requiresInstitutionAccessForPath('/meetings/mtg-1/live'), isFalse);
      expect(requiresInstitutionAccessForPath('/home'), isFalse);
      expect(requiresInstitutionAccessForPath('/realtime/session-1'), isFalse);
    });
  });
}
