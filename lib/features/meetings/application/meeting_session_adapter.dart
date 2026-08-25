import '../domain/meeting_av_contract.dart';
import '../../realtime/domain/realtime_enums.dart';
import '../../realtime/domain/realtime_state.dart';

/// THE ONE PLACE THE MEETINGS WORKSPACE READS THE A/V SYSTEM.
///
/// Founder ruling 2026-08-25 §VIII and §XXVII. The audit measured
/// `MeetingLiveRoomScreen` at 3,934 lines holding 12 providers, 44 `setState`
/// calls and **113 direct socket/realtime references**, importing
/// `realtime/data/` — the media service and the raw event parser — into a
/// presentation file. No test instantiated it, and that was not an oversight:
/// a screen that talks to a socket cannot be instantiated without one.
///
/// This is the seam that fixes the cause rather than the symptom. It maps the
/// A/V system's transport vocabulary onto the product vocabulary in
/// `meeting_av_contract.dart`, in one pure function, so that:
///
///   * the workspace can be rendered and tested from a plain value;
///   * the A/V chapter can change `RealtimeState` freely, and only this file
///     has to follow;
///   * nobody has to decide, at each of 113 call sites, what a particular
///     transport condition means to a person.
///
/// ─────────────────────────────────────────────────────────────────────────
/// THE TRANSLATION IS A PRODUCT DECISION, WHICH IS WHY IT LIVES HERE
/// ─────────────────────────────────────────────────────────────────────────
///
/// `reconnecting` is a transport fact; "hold their place, do not say they
/// left" is a product decision. `RealtimeJoinState.replaced` is a device
/// handover; what a person should be told about it is not the socket's
/// business. Those decisions belong to Meetings, so they are made here — on
/// the Meetings side of the line, reading the A/V side.
///
/// This file is deliberately pure: no providers, no widgets, no I/O. That is
/// what makes the whole mapping testable without a network.
class MeetingSessionAdapter {
  const MeetingSessionAdapter._();

  /// Read the A/V system's state as the meeting workspace's contract.
  static MeetingSession from(RealtimeState state) {
    final fault = _fault(state);
    return MeetingSession(
      state: _sessionState(state, fault),
      fault: fault,
      intent: MeetingMediaIntent(
        microphoneEnabled: state.microphoneEnabled,
        cameraEnabled: state.cameraEnabled,
        screenShareEnabled: state.isScreenSharing,
      ),
      media: MeetingMediaState(
        // INTENT IS NOT REALITY (§IX). The engine reports readiness
        // separately from what was asked for, and a control that showed the
        // request rather than the result would tell somebody their microphone
        // was on while the room heard nothing.
        microphoneLive: state.isMediaReady && state.microphoneEnabled,
        cameraLive: state.isMediaReady && state.cameraEnabled,
        screenShareLive: state.isScreenSharing,
        fault: fault,
      ),
      peers: state.participants
          .map(
            (p) => MeetingPeerMedia(
              participantId: p.userId,
              audioArriving: p.audioOn,
              videoArriving: p.videoOn,
              screenShareArriving: p.screenOn,
            ),
          )
          .toList(growable: false),
    );
  }

  static MeetingSessionState _sessionState(
    RealtimeState state,
    MeetingSessionFault fault,
  ) {
    // A reconnect in progress outranks the join state: the person IS in the
    // meeting, the pipe is being rebuilt, and the product must not describe
    // that as having left.
    if (state.connectionStatus == RealtimeConnectionStatus.reconnecting ||
        (state.joinState == RealtimeJoinState.joined &&
            state.connectionStatus == RealtimeConnectionStatus.connecting)) {
      return MeetingSessionState.reconnecting;
    }

    switch (state.joinState) {
      case RealtimeJoinState.joined:
        return MeetingSessionState.joined;
      case RealtimeJoinState.joining:
      case RealtimeJoinState.requested:
        return MeetingSessionState.joining;
      case RealtimeJoinState.rejected:
      case RealtimeJoinState.removed:
      case RealtimeJoinState.banned:
      case RealtimeJoinState.locked:
        // Being refused is terminal for THIS attempt in a way a network blip
        // is not: retrying will be refused again, so the product must not
        // offer it. §XXXI.
        return MeetingSessionState.terminalFailure;
      case RealtimeJoinState.replaced:
        // A deliberate handover to another of this person's devices. They did
        // not fail to join and they are not in the room — they left this one.
        return MeetingSessionState.left;
      case RealtimeJoinState.failed:
        return fault.isRetryable
            ? MeetingSessionState.recoverableFailure
            : MeetingSessionState.terminalFailure;
      case RealtimeJoinState.idle:
        if (state.connectionStatus == RealtimeConnectionStatus.error) {
          return MeetingSessionState.recoverableFailure;
        }
        return (state.sessionId ?? '').trim().isEmpty
            ? MeetingSessionState.none
            : MeetingSessionState.available;
    }
  }

  static MeetingSessionFault _fault(RealtimeState state) {
    switch (state.joinState) {
      case RealtimeJoinState.rejected:
      case RealtimeJoinState.removed:
      case RealtimeJoinState.banned:
      case RealtimeJoinState.locked:
        return MeetingSessionFault.notAdmitted;
      default:
        break;
    }

    // A media error is about this device, and is the one failure a person can
    // usually fix themselves — so it is distinguished from the network.
    final media = (state.mediaError ?? '').trim();
    if (media.isNotEmpty) {
      final lower = media.toLowerCase();
      if (lower.contains('notallowed') ||
          lower.contains('permission') ||
          lower.contains('denied')) {
        return MeetingSessionFault.mediaPermissionDenied;
      }
      if (lower.contains('notfound') ||
          lower.contains('notreadable') ||
          lower.contains('device')) {
        return MeetingSessionFault.mediaDeviceUnavailable;
      }
    }

    if (state.connectionStatus == RealtimeConnectionStatus.error) {
      return MeetingSessionFault.serviceUnavailable;
    }
    if (state.joinState == RealtimeJoinState.failed) {
      return MeetingSessionFault.serviceUnavailable;
    }
    return MeetingSessionFault.none;
  }

  /// What to TELL somebody, given the session they are in.
  ///
  /// §XXXI: distinguish the states, and avoid a generic "Try again" where a
  /// specific recovery exists. Returning null means there is nothing worth
  /// saying, which is the common case and must stay silent.
  static String? explain(MeetingSession session) => switch (session.fault) {
        MeetingSessionFault.none => switch (session.state) {
            MeetingSessionState.reconnecting =>
              'Reconnecting — your place is being held.',
            MeetingSessionState.joining => 'Joining the meeting…',
            _ => null,
          },
        MeetingSessionFault.networkUnavailable =>
          'You appear to be offline. The meeting will reconnect on its own '
              'when your connection comes back.',
        MeetingSessionFault.serviceUnavailable =>
          'Aura could not reach the meeting service. This is usually brief.',
        MeetingSessionFault.mediaPermissionDenied =>
          'Aura does not have permission to use your microphone or camera. '
              'You can still join and listen.',
        MeetingSessionFault.mediaDeviceUnavailable =>
          'No working microphone or camera was found. You can still join and '
              'listen.',
        MeetingSessionFault.notAdmitted =>
          'You have not been admitted to this meeting.',
        MeetingSessionFault.meetingConcluded => 'This meeting has ended.',
        MeetingSessionFault.unknown =>
          'Something went wrong joining this meeting.',
      };
}
