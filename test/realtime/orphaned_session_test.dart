import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/realtime/domain/orphaned_session.dart';
import 'package:aura/features/realtime/domain/realtime_enums.dart';
import 'package:aura/features/realtime/domain/realtime_models.dart';
import 'package:aura/features/realtime/domain/realtime_state.dart';

// Realtime Architecture Correction — Runtime Lifecycle Phase 2. Pure-function
// coverage for the process-recreation gap: the backend still holds an
// ACTIVE/JOINING participant row for this user (surfaced via
// liveSessionsProvider), but a fresh process's RealtimeState has no
// in-memory awareness of it.

RealtimeSession _session({
  required String id,
  bool isActive = true,
  RealtimeSurfaceType surfaceType = RealtimeSurfaceType.meeting,
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
  );
}

void main() {
  group('findOrphanedActiveSession', () {
    test('no sessions from the backend — nothing orphaned', () {
      expect(
        findOrphanedActiveSession(
          mySessions: const [],
          clientState: RealtimeState.initial(),
        ),
        isNull,
      );
    });

    test('one active backend session, client has no in-memory awareness — orphaned', () {
      final session = _session(id: 's1');
      final result = findOrphanedActiveSession(
        mySessions: [session],
        clientState: RealtimeState.initial(),
      );
      expect(result?.id, 's1');
    });

    test('backend session already matches the client-tracked joined session — not orphaned', () {
      final session = _session(id: 's1');
      final clientState = RealtimeState.initial().copyWith(
        joinState: RealtimeJoinState.joined,
        session: session,
      );
      expect(
        findOrphanedActiveSession(mySessions: [session], clientState: clientState),
        isNull,
      );
    });

    test('client is joined to a DIFFERENT session than the backend-listed one — the backend one is still orphaned', () {
      final trackedSession = _session(id: 'tracked');
      final otherSession = _session(id: 'other');
      final clientState = RealtimeState.initial().copyWith(
        joinState: RealtimeJoinState.joined,
        session: trackedSession,
      );
      final result = findOrphanedActiveSession(
        mySessions: [otherSession],
        clientState: clientState,
      );
      expect(result?.id, 'other');
    });

    test('inactive (ended) backend sessions are never treated as orphaned', () {
      final endedSession = _session(id: 's1', isActive: false);
      expect(
        findOrphanedActiveSession(
          mySessions: [endedSession],
          clientState: RealtimeState.initial(),
        ),
        isNull,
      );
    });

    test('client mid-join (joinState.joining, not yet joined) still surfaces the backend session as orphaned', () {
      final session = _session(id: 's1');
      // joinState.joining means isJoined is false — the client does not yet
      // consider itself connected, so the backend-known session must still
      // be surfaced rather than assumed already handled.
      final clientState = RealtimeState.initial().copyWith(
        joinState: RealtimeJoinState.joining,
        sessionId: 's1',
      );
      final result = findOrphanedActiveSession(
        mySessions: [session],
        clientState: clientState,
      );
      expect(result?.id, 's1');
    });
  });
}
