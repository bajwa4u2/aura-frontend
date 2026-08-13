import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/meetings/application/meeting_realtime_semantics.dart';
import 'package:aura/features/realtime/domain/realtime_enums.dart';

// Realtime Architecture Correction — Phase 7, Meetings realtime
// orchestration (frontend piece). Pure-function coverage for the adapter
// contract now consumed by realtime_controller.dart instead of inlined
// `if (isMeeting)` checks. Proves each Meeting-specific decision fires only
// for RealtimeSurfaceType.meeting and never for any other surface.

void main() {
  const nonMeetingSurfaces = <RealtimeSurfaceType>[
    RealtimeSurfaceType.dm,
    RealtimeSurfaceType.thread,
    RealtimeSurfaceType.space,
    RealtimeSurfaceType.room,
    RealtimeSurfaceType.institution,
    RealtimeSurfaceType.unknown,
  ];

  group('tolerateRestJoinFailure', () {
    test('true for meeting', () {
      expect(
        MeetingRealtimeSemantics.tolerateRestJoinFailure(
          RealtimeSurfaceType.meeting,
        ),
        isTrue,
      );
    });

    test('false for null and every non-meeting surface', () {
      expect(MeetingRealtimeSemantics.tolerateRestJoinFailure(null), isFalse);
      for (final surface in nonMeetingSurfaces) {
        expect(
          MeetingRealtimeSemantics.tolerateRestJoinFailure(surface),
          isFalse,
          reason: 'surface=$surface',
        );
      }
    });
  });

  group('appliesReconnectGraceOnParticipantLeft', () {
    test('true only for a meeting AND a transient drop reason', () {
      expect(
        MeetingRealtimeSemantics.appliesReconnectGraceOnParticipantLeft(
          surfaceType: RealtimeSurfaceType.meeting,
          leftReason: 'disconnect',
        ),
        isTrue,
      );
      expect(
        MeetingRealtimeSemantics.appliesReconnectGraceOnParticipantLeft(
          surfaceType: RealtimeSurfaceType.meeting,
          leftReason: 'heartbeat_timeout',
        ),
        isTrue,
      );
    });

    test('false for a meeting with a non-transient reason (voluntary leave)', () {
      expect(
        MeetingRealtimeSemantics.appliesReconnectGraceOnParticipantLeft(
          surfaceType: RealtimeSurfaceType.meeting,
          leftReason: 'left',
        ),
        isFalse,
      );
    });

    test('false for a non-meeting surface even with a transient reason', () {
      expect(
        MeetingRealtimeSemantics.appliesReconnectGraceOnParticipantLeft(
          surfaceType: RealtimeSurfaceType.thread,
          leftReason: 'disconnect',
        ),
        isFalse,
      );
    });
  });

  group('waitsForParticipantReturnWhenAlone', () {
    test('true for meeting, false otherwise', () {
      expect(
        MeetingRealtimeSemantics.waitsForParticipantReturnWhenAlone(
          RealtimeSurfaceType.meeting,
        ),
        isTrue,
      );
      for (final surface in nonMeetingSurfaces) {
        expect(
          MeetingRealtimeSemantics.waitsForParticipantReturnWhenAlone(surface),
          isFalse,
          reason: 'surface=$surface',
        );
      }
      expect(
        MeetingRealtimeSemantics.waitsForParticipantReturnWhenAlone(null),
        isFalse,
      );
    });
  });

  group('suppressesStaleDisconnectSignal', () {
    test('true for meeting, false otherwise', () {
      expect(
        MeetingRealtimeSemantics.suppressesStaleDisconnectSignal(
          RealtimeSurfaceType.meeting,
        ),
        isTrue,
      );
      for (final surface in nonMeetingSurfaces) {
        expect(
          MeetingRealtimeSemantics.suppressesStaleDisconnectSignal(surface),
          isFalse,
          reason: 'surface=$surface',
        );
      }
    });
  });

  group('discardsOutOfOrderEndedEvent', () {
    test('true for a meeting whose payload says it is still ACCEPTED', () {
      expect(
        MeetingRealtimeSemantics.discardsOutOfOrderEndedEvent(
          surfaceType: RealtimeSurfaceType.meeting,
          terminalReason: 'ACCEPTED',
          terminalCallState: '',
        ),
        isTrue,
      );
    });

    test('true for a meeting whose payload says it is still ACTIVE', () {
      expect(
        MeetingRealtimeSemantics.discardsOutOfOrderEndedEvent(
          surfaceType: RealtimeSurfaceType.meeting,
          terminalReason: '',
          terminalCallState: 'ACTIVE',
        ),
        isTrue,
      );
    });

    test('false for a meeting with a genuine terminal reason', () {
      expect(
        MeetingRealtimeSemantics.discardsOutOfOrderEndedEvent(
          surfaceType: RealtimeSurfaceType.meeting,
          terminalReason: 'HOST_ENDED',
          terminalCallState: 'ENDED',
        ),
        isFalse,
      );
    });

    test('false for a non-meeting surface even with ACCEPTED/ACTIVE', () {
      expect(
        MeetingRealtimeSemantics.discardsOutOfOrderEndedEvent(
          surfaceType: RealtimeSurfaceType.dm,
          terminalReason: 'ACCEPTED',
          terminalCallState: 'ACTIVE',
        ),
        isFalse,
      );
    });
  });
}
