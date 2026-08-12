import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/realtime/domain/realtime_enums.dart';
import 'package:aura/features/realtime/domain/realtime_models.dart';
import 'package:aura/features/realtime/domain/realtime_state.dart';

// 2026-08-14 repair — Native Background/Terminated Notification
// Certification, Phase C: authoritative ACCEPT truth must propagate to the
// caller independent of whether realtime/media join has completed, and must
// never be collapsed with CONNECTED. These tests cover the pure state model
// backing that doctrine (`RealtimeState.acceptedByPeer` /
// `isPeerAcceptedNotYetPresent`) — the WS wiring that sets `acceptedByPeer`
// lives in `RealtimeController`'s socket-event switch.

RealtimeParticipant _presentParticipant(String userId) {
  return RealtimeParticipant(
    id: 'participant-$userId',
    userId: userId,
    runtimeDeviceId: 'device-$userId',
    role: RealtimeParticipantRole.guest,
    joinState: 'joined',
    isPresent: true,
    audioOn: true,
    videoOn: false,
    screenOn: false,
    displayName: 'User $userId',
    handle: userId,
    avatarUrl: null,
    displayRole: null,
    institutionName: null,
    institutionHandle: null,
    institutionRole: null,
    institutionTitle: null,
    joinedAt: DateTime.utc(2026, 8, 14),
    leftAt: null,
  );
}

void main() {
  group('RealtimeState.acceptedByPeer / isPeerAcceptedNotYetPresent', () {
    test('starts false on a fresh state', () {
      final state = RealtimeState.initial();
      expect(state.acceptedByPeer, isFalse);
      expect(state.isPeerAcceptedNotYetPresent, isFalse);
    });

    test('copyWith sets acceptedByPeer without requiring participants to change', () {
      final state = RealtimeState.initial().copyWith(acceptedByPeer: true);
      expect(state.acceptedByPeer, isTrue);
    });

    test(
      'isPeerAcceptedNotYetPresent is true once accepted but before the peer is actually present — the ACCEPTED/JOINING step',
      () {
        final state = RealtimeState.initial().copyWith(acceptedByPeer: true);
        expect(state.participants.where((p) => p.isPresent).length, lessThanOrEqualTo(1));
        expect(state.isPeerAcceptedNotYetPresent, isTrue);
      },
    );

    test(
      'isPeerAcceptedNotYetPresent becomes false once the peer is actually present — CONNECTED must not stay collapsed with ACCEPTED',
      () {
        // `participants` includes the local caller's own entry (matching the
        // existing `<= 1` "not yet connected" convention already used by
        // `_CallTopBar`'s `isRinging`/`phaseForRealtime` elsewhere in this
        // codebase) — two present entries means self + the actually-joined peer.
        final state = RealtimeState.initial().copyWith(
          acceptedByPeer: true,
          participants: [_presentParticipant('self'), _presentParticipant('peer-1')],
        );
        expect(state.isPeerAcceptedNotYetPresent, isFalse);
      },
    );

    test('isPeerAcceptedNotYetPresent is false when acceptedByPeer is still false, regardless of participants', () {
      final state = RealtimeState.initial();
      expect(state.isPeerAcceptedNotYetPresent, isFalse);
    });
  });
}
