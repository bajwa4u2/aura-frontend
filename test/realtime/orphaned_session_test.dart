import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/realtime/domain/orphaned_session.dart';
import 'package:aura/features/realtime/domain/realtime_enums.dart';
import 'package:aura/features/realtime/domain/realtime_models.dart';
import 'package:aura/features/realtime/domain/realtime_state.dart';

// Realtime Architecture Correction — Runtime Lifecycle Phase 2, corrected
// 2026-08-17 after live founder evidence during three-party certification:
//
// * a session the client is engaged with at ANY stage (connecting / ready /
//   joined) is never orphaned — the old rule only excluded fully-joined,
//   which painted "You have an active call / Rejoin" over the user's own
//   in-progress call screen;
// * a session this user never joined (invited only, joinedAt == null) is
//   never orphaned — ringing belongs to the incoming-call pipeline;
// * a session this user LEFT is never orphaned — leaving answered it.

const _me = 'me-1';

RealtimeSessionParticipantSummary _p(
  String userId, {
  String joinState = 'ACTIVE',
  DateTime? joinedAt,
}) {
  return RealtimeSessionParticipantSummary(
    userId: userId,
    joinState: joinState,
    joinedAt: joinedAt,
  );
}

RealtimeSession _session({
  required String id,
  bool isActive = true,
  RealtimeSurfaceType surfaceType = RealtimeSurfaceType.meeting,
  List<RealtimeSessionParticipantSummary>? participants,
}) {
  return RealtimeSession(
    id: id,
    surfaceType: surfaceType,
    surfaceId: 'surface-1',
    startedByUserId: 'host-1',
    status: isActive ? 'ACTIVE' : 'ENDED',
    kind: 'VIDEO',
    isActive: isActive,
    isLocked: false,
    waitingRoomEnabled: false,
    startedAt: null,
    answeredAt: null,
    firstJoinedAt: null,
    endedAt: null,
    durationSeconds: null,
    createdAt: null,
    updatedAt: null,
    activeParticipantCount: 1,
    participantSummaries:
        participants ?? [_p(_me, joinedAt: DateTime(2026, 8, 17))],
  );
}

void main() {
  group('findOrphanedActiveSession', () {
    test('no sessions from the backend — nothing orphaned', () {
      expect(
        findOrphanedActiveSession(
          mySessions: const [],
          clientState: RealtimeState.initial(),
          currentUserId: _me,
        ),
        isNull,
      );
    });

    test(
      'active session I joined, fresh process with no in-memory awareness — orphaned',
      () {
        final session = _session(id: 's1');
        final result = findOrphanedActiveSession(
          mySessions: [session],
          clientState: RealtimeState.initial(),
          currentUserId: _me,
        );
        expect(result?.id, 's1');
      },
    );

    test('session already joined by the client — not orphaned', () {
      final session = _session(id: 's1');
      final clientState = RealtimeState.initial().copyWith(
        joinState: RealtimeJoinState.joined,
        session: session,
      );
      expect(
        findOrphanedActiveSession(
          mySessions: [session],
          clientState: clientState,
          currentUserId: _me,
        ),
        isNull,
      );
    });

    test(
      'client mid-join (connecting / ready-to-join) on the SAME session — '
      'not orphaned: the call surface owns presentation at every stage',
      () {
        final session = _session(id: 's1');
        final clientState = RealtimeState.initial().copyWith(
          joinState: RealtimeJoinState.joining,
          sessionId: 's1',
        );
        expect(
          findOrphanedActiveSession(
            mySessions: [session],
            clientState: clientState,
            currentUserId: _me,
          ),
          isNull,
        );
      },
    );

    test(
      'client engaged with a DIFFERENT session — the other joined session '
      'still surfaces',
      () {
        final other = _session(id: 'other');
        final clientState = RealtimeState.initial().copyWith(
          joinState: RealtimeJoinState.joined,
          session: _session(id: 'tracked'),
        );
        final result = findOrphanedActiveSession(
          mySessions: [other],
          clientState: clientState,
          currentUserId: _me,
        );
        expect(result?.id, 'other');
      },
    );

    test('inactive (ended) sessions are never orphaned', () {
      final ended = _session(id: 's1', isActive: false);
      expect(
        findOrphanedActiveSession(
          mySessions: [ended],
          clientState: RealtimeState.initial(),
          currentUserId: _me,
        ),
        isNull,
      );
    });

    test(
      'invited but never joined (joinedAt null) — never orphaned; ringing '
      'is the incoming-call pipeline, not "your active call"',
      () {
        final invitedOnly = _session(
          id: 's1',
          participants: [_p(_me, joinState: 'ACTIVE', joinedAt: null)],
        );
        expect(
          findOrphanedActiveSession(
            mySessions: [invitedOnly],
            clientState: RealtimeState.initial(),
            currentUserId: _me,
          ),
          isNull,
        );
      },
    );

    test('session I LEFT — never orphaned even while active for others', () {
      final leftSession = _session(
        id: 's1',
        participants: [
          _p(_me, joinState: 'LEFT', joinedAt: DateTime(2026, 8, 17)),
        ],
      );
      expect(
        findOrphanedActiveSession(
          mySessions: [leftSession],
          clientState: RealtimeState.initial(),
          currentUserId: _me,
        ),
        isNull,
      );
    });

    test('no roster row for me — never claim "you have an active call"', () {
      final notMine = _session(
        id: 's1',
        participants: [_p('someone-else', joinedAt: DateTime(2026, 8, 17))],
      );
      expect(
        findOrphanedActiveSession(
          mySessions: [notMine],
          clientState: RealtimeState.initial(),
          currentUserId: _me,
        ),
        isNull,
      );
    });

    test(
      'DISCONNECTED after a real join (device died, not yet reaped) — '
      'orphaned: this is the rejoin window the banner exists for',
      () {
        final dropped = _session(
          id: 's1',
          participants: [
            _p(_me, joinState: 'DISCONNECTED', joinedAt: DateTime(2026, 8, 17)),
          ],
        );
        final result = findOrphanedActiveSession(
          mySessions: [dropped],
          clientState: RealtimeState.initial(),
          currentUserId: _me,
        );
        expect(result?.id, 's1');
      },
    );
  });
}
