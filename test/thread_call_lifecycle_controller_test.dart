import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/realtime/application/thread_call_lifecycle_controller.dart';
import 'package:aura/features/realtime/domain/realtime_enums.dart';
import 'package:aura/features/realtime/domain/realtime_models.dart';
import 'package:aura/features/realtime/domain/realtime_state.dart';
import 'package:aura/features/updates/incoming_call_bridge.dart';

void main() {
  group('IncomingCallBridgeNotifier', () {
    test('normalizes foreground push payloads and dedupes by session id', () {
      final bridge = IncomingCallBridgeNotifier();

      bridge.addIncoming({
        'type': 'CALL_RINGING',
        'notificationKind': 'LIVE',
        'sessionId': 'session-1',
        'attention': 'INTERRUPT',
      });
      bridge.addIncoming({
        'id': 'canonical-communication-1',
        'notificationKind': 'LIVE',
        'data': {
          'sessionId': 'session-1',
          'attention': 'INTERRUPT',
          'notificationKind': 'LIVE',
        },
      });

      expect(bridge.state, hasLength(1));
      expect(bridge.state.single['id'], 'canonical-communication-1');
      expect(bridge.currentSessionIds(), {'session-1'});
    });

    test('terminal removal is idempotent by session id', () {
      final bridge = IncomingCallBridgeNotifier();

      bridge.addIncoming({
        'id': 'call:session-2',
        'data': {
          'sessionId': 'session-2',
          'attention': 'INTERRUPT',
          'notificationKind': 'LIVE',
        },
      });

      bridge.removeBySession('session-2');
      bridge.removeBySession('session-2');

      expect(bridge.state, isEmpty);
    });

    test('preserves released call metadata in normalized data payload', () {
      final bridge = IncomingCallBridgeNotifier();

      bridge.addIncoming({
        'type': 'CALL_RINGING',
        'notificationKind': 'LIVE',
        'realtimeSessionId': 'session-3',
        'threadId': 'thread-1',
        'spaceId': 'space-1',
        'callKind': 'VIDEO',
        'mediaMode': 'VIDEO',
        'attention': 'INTERRUPT',
        'deeplink': '/realtime/session-3?action=join',
        'expiresAt': '2999-08-08T20:00:00.000Z',
      });

      expect(bridge.state, hasLength(1));
      final item = bridge.state.single;
      final data = item['data'] as Map;

      expect(item['id'], 'call:session-3');
      expect(data['sessionId'], 'session-3');
      expect(data['realtimeSessionId'], 'session-3');
      expect(data['threadId'], 'thread-1');
      expect(data['spaceId'], 'space-1');
      expect(data['callKind'], 'VIDEO');
      expect(data['mediaMode'], 'VIDEO');
      expect(data['notificationKind'], 'LIVE');
      expect(data['attention'], 'INTERRUPT');
      expect(data['deeplink'], '/realtime/session-3?action=join');
    });
  });

  group('ThreadCallLifecycleController.phaseForRealtime', () {
    test('keeps invited phase while realtime has no session yet', () {
      final phase = ThreadCallLifecycleController.phaseForRealtime(
        RealtimeState.initial(),
        currentPhase: ThreadCallLifecyclePhase.invited,
      );

      expect(phase, ThreadCallLifecyclePhase.invited);
    });

    test('maps join and media progression deterministically', () {
      expect(
        ThreadCallLifecycleController.phaseForRealtime(
          RealtimeState.initial().copyWith(
            sessionId: 'session-1',
            joinState: RealtimeJoinState.joining,
          ),
        ),
        ThreadCallLifecyclePhase.joining,
      );

      expect(
        ThreadCallLifecycleController.phaseForRealtime(
          RealtimeState.initial().copyWith(
            sessionId: 'session-1',
            joinState: RealtimeJoinState.joined,
            connectionStatus: RealtimeConnectionStatus.connected,
            participants: [_participant('a')],
          ),
        ),
        ThreadCallLifecyclePhase.joined,
      );

      expect(
        ThreadCallLifecycleController.phaseForRealtime(
          RealtimeState.initial().copyWith(
            sessionId: 'session-1',
            joinState: RealtimeJoinState.joined,
            connectionStatus: RealtimeConnectionStatus.connected,
            isMediaBusy: true,
            participants: [_participant('a'), _participant('b')],
          ),
        ),
        ThreadCallLifecyclePhase.mediaNegotiating,
      );

      expect(
        ThreadCallLifecycleController.phaseForRealtime(
          RealtimeState.initial().copyWith(
            sessionId: 'session-1',
            joinState: RealtimeJoinState.joined,
            connectionStatus: RealtimeConnectionStatus.connected,
            isMediaReady: true,
            participants: [_participant('a'), _participant('b')],
          ),
        ),
        ThreadCallLifecyclePhase.connected,
      );
    });

    test('maps transport loss and terminal join states', () {
      expect(
        ThreadCallLifecycleController.phaseForRealtime(
          RealtimeState.initial().copyWith(
            sessionId: 'session-1',
            joinState: RealtimeJoinState.joined,
            connectionStatus: RealtimeConnectionStatus.reconnecting,
          ),
        ),
        ThreadCallLifecyclePhase.transportDegraded,
      );

      expect(
        ThreadCallLifecycleController.phaseForRealtime(
          RealtimeState.initial().copyWith(
            sessionId: 'session-1',
            joinState: RealtimeJoinState.replaced,
          ),
        ),
        ThreadCallLifecyclePhase.ended,
      );
    });
  });
}

RealtimeParticipant _participant(String id) {
  return RealtimeParticipant(
    id: 'participant-$id',
    userId: 'user-$id',
    runtimeDeviceId: 'socket-$id',
    role: RealtimeParticipantRole.participant,
    joinState: 'ACTIVE',
    isPresent: true,
    audioOn: true,
    videoOn: false,
    screenOn: false,
    displayName: 'User $id',
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
}
