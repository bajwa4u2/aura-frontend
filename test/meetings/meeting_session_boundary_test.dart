import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/meetings/application/meeting_session_adapter.dart';
import 'package:aura/features/meetings/domain/meeting_av_contract.dart';
import 'package:aura/features/realtime/domain/realtime_enums.dart';
import 'package:aura/features/realtime/domain/realtime_models.dart';
import 'package:aura/features/realtime/domain/realtime_state.dart';

/// THE A/V BOUNDARY — founder ruling 2026-08-25 §VIII and §XXVII.
///
/// The whole point of the adapter is that the meeting workspace can be
/// reasoned about — and tested — without a socket. If these tests need one,
/// the boundary has not been drawn.
void main() {
  // Built from the real initial state, which is the point: the adapter is
  // exercised against the A/V system's own value type, not a stand-in.
  RealtimeState state({
    RealtimeConnectionStatus connection = RealtimeConnectionStatus.connected,
    RealtimeJoinState join = RealtimeJoinState.idle,
    String? sessionId,
    bool mediaReady = false,
    bool mic = false,
    bool camera = false,
    bool screen = false,
    String? mediaError,
    List<RealtimeParticipant> participants = const [],
  }) =>
      RealtimeState.initial().copyWith(
        connectionStatus: connection,
        joinState: join,
        sessionId: sessionId,
        participants: participants,
        isMediaReady: mediaReady,
        microphoneEnabled: mic,
        cameraEnabled: camera,
        isScreenSharing: screen,
        mediaError: mediaError,
      );

  RealtimeParticipant peer({
    required String userId,
    bool audioOn = false,
    bool videoOn = false,
    bool screenOn = false,
  }) =>
      RealtimeParticipant(
        id: userId,
        userId: userId,
        runtimeDeviceId: null,
        role: RealtimeParticipantRole.participant,
        joinState: 'JOINED',
        isPresent: true,
        audioOn: audioOn,
        videoOn: videoOn,
        screenOn: screenOn,
        displayName: userId,
        handle: null,
        avatarUrl: null,
        displayRole: null,
        institutionName: null,
        institutionHandle: null,
        institutionRole: null,
        institutionTitle: null,
        joinedAt: null,
        leftAt: null,
      );

  group('the workspace sees product states, not transport states', () {
    test('nothing started', () {
      expect(MeetingSessionAdapter.from(state()).state,
          MeetingSessionState.none);
    });

    test('a session exists and could be entered', () {
      expect(MeetingSessionAdapter.from(state(sessionId: 's1')).state,
          MeetingSessionState.available);
    });

    test('on the way in', () {
      expect(
        MeetingSessionAdapter.from(state(join: RealtimeJoinState.joining)).state,
        MeetingSessionState.joining,
      );
      expect(
        MeetingSessionAdapter.from(state(join: RealtimeJoinState.requested))
            .state,
        MeetingSessionState.joining,
      );
    });

    test('in', () {
      expect(
        MeetingSessionAdapter.from(state(join: RealtimeJoinState.joined)).state,
        MeetingSessionState.joined,
      );
    });
  });

  group('a dropped connection holds their place', () {
    test('reconnecting is not leaving', () {
      // THE PRODUCT DECISION this boundary exists to make: transport says the
      // pipe is being rebuilt; the product says the person is still in the
      // meeting and their place is held.
      final s = MeetingSessionAdapter.from(state(
        join: RealtimeJoinState.joined,
        connection: RealtimeConnectionStatus.reconnecting,
      ));
      expect(s.state, MeetingSessionState.reconnecting);
      expect(s.isConnecting, isTrue);
      expect(MeetingSessionAdapter.explain(s),
          contains('place is being held'));
    });

    test('a joined participant whose socket is re-dialling is reconnecting',
        () {
      expect(
        MeetingSessionAdapter.from(state(
          join: RealtimeJoinState.joined,
          connection: RealtimeConnectionStatus.connecting,
        )).state,
        MeetingSessionState.reconnecting,
      );
    });
  });

  group('failures are told apart, because their recoveries differ', () {
    test('being refused is terminal — retrying would be refused again', () {
      for (final refusal in [
        RealtimeJoinState.rejected,
        RealtimeJoinState.removed,
        RealtimeJoinState.banned,
        RealtimeJoinState.locked,
      ]) {
        final s = MeetingSessionAdapter.from(state(join: refusal));
        expect(s.state, MeetingSessionState.terminalFailure, reason: '$refusal');
        expect(s.canRetry, isFalse,
            reason: '$refusal offered a retry that cannot succeed');
        expect(s.fault, MeetingSessionFault.notAdmitted);
      }
    });

    test('a service failure IS worth retrying', () {
      final s = MeetingSessionAdapter.from(state(
        join: RealtimeJoinState.failed,
        connection: RealtimeConnectionStatus.error,
      ));
      expect(s.state, MeetingSessionState.recoverableFailure);
      expect(s.canRetry, isTrue);
    });

    test('a denied permission is named as such, not as a network problem', () {
      final s = MeetingSessionAdapter.from(
        state(mediaError: 'NotAllowedError: Permission denied'),
      );
      expect(s.fault, MeetingSessionFault.mediaPermissionDenied);
      expect(s.fault.needsPersonAction, isTrue);
      expect(s.fault.isRetryable, isFalse,
          reason: 'a permission a person must grant elsewhere is not fixed by '
              'pressing Try again');
      expect(MeetingSessionAdapter.explain(s), contains('permission'));
    });

    test('a missing device is distinguished from a refused one', () {
      final s = MeetingSessionAdapter.from(
        state(mediaError: 'NotFoundError: Requested device not found'),
      );
      expect(s.fault, MeetingSessionFault.mediaDeviceUnavailable);
    });

    test('a handover to another device is leaving, not failing', () {
      // The person did not fail to join. They moved.
      final s =
          MeetingSessionAdapter.from(state(join: RealtimeJoinState.replaced));
      expect(s.state, MeetingSessionState.left);
      expect(s.hasFailed, isFalse);
    });
  });

  group('intent is not reality', () {
    test('asking for a microphone does not make one live', () {
      // §IX — do not fake permission success in UI. The engine has not
      // reported readiness, so the contract must not claim the microphone is
      // carrying anything.
      final s = MeetingSessionAdapter.from(state(mic: true, mediaReady: false));
      expect(s.intent.microphoneEnabled, isTrue);
      expect(s.media.microphoneLive, isFalse);
      expect(s.media.microphoneDisagrees(s.intent), isTrue,
          reason: 'the disagreement worth surfacing was not detectable');
    });

    test('when the engine is ready, intent and reality agree', () {
      final s = MeetingSessionAdapter.from(state(mic: true, mediaReady: true));
      expect(s.media.microphoneLive, isTrue);
      expect(s.media.microphoneDisagrees(s.intent), isFalse);
    });

    test('a camera nobody asked for is not live either', () {
      final s = MeetingSessionAdapter.from(state(mediaReady: true));
      expect(s.media.cameraLive, isFalse);
      expect(s.media.cameraDisagrees(s.intent), isFalse);
    });
  });

  group('the workspace never sees a track, a socket or a renderer', () {
    test('peers arrive as product facts', () {
      final s = MeetingSessionAdapter.from(state(
        join: RealtimeJoinState.joined,
        participants: [peer(userId: 'u1', audioOn: true)],
      ));
      expect(s.peers, hasLength(1));
      expect(s.peers.single.participantId, 'u1');
      expect(s.peers.single.audioArriving, isTrue);
      expect(s.peers.single.videoArriving, isFalse);
    });
  });

  group('what a person is told', () {
    test('silence is the common case, and must stay silent', () {
      final joined =
          MeetingSessionAdapter.from(state(join: RealtimeJoinState.joined));
      expect(MeetingSessionAdapter.explain(joined), isNull,
          reason: 'a working meeting narrated itself at somebody');
    });

    test('every fault says something specific', () {
      for (final fault in MeetingSessionFault.values) {
        if (fault == MeetingSessionFault.none) continue;
        final message = MeetingSessionAdapter.explain(
          MeetingSession(state: MeetingSessionState.terminalFailure, fault: fault),
        );
        expect(message, isNotNull, reason: '$fault had nothing to say');
        expect(message!.toLowerCase(), isNot(contains('try again')),
            reason: '$fault fell back to the generic retry §XXXI forbids');
      }
    });
  });
}
