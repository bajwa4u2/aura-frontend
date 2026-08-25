/// THE MEETINGS-FACING AUDIO/VIDEO CONTRACT.
///
/// Founder ruling 2026-08-25 §XXVII. This chapter reconstructs the Meetings
/// Workspace; the **A/V Call System is the next chapter** and is deliberately
/// not rebuilt here. What this file does is draw the line between them, so
/// that the next chapter has something clean to build against and this one
/// stops reaching through it.
///
/// The audit measured the problem precisely: `MeetingLiveRoomScreen` held 113
/// direct socket/realtime references and imported `realtime/data/` — the media
/// service and the raw event parser — straight into a presentation file. The
/// meeting workspace knew about transport. That is why it could not be tested,
/// and why an A/V change could break a product surface.
///
/// ## What the workspace is allowed to know
///
/// Everything in this file is stated in terms a person would recognise: am I
/// connected, is my camera on, did it fail, can I try again. Nothing here
/// mentions a socket, an ICE candidate, an SFU, a track, or a peer connection.
/// If a future capability cannot be described without those words, it belongs
/// on the far side of this line.
///
/// ## What is deliberately NOT here
///
/// Codecs, transport, mesh/SFU topology, media recovery algorithms and quality
/// adaptation are the A/V chapter's business. This contract does not model
/// them, does not leak them, and does not pretend to own them.
library;

/// Where this person stands with respect to the meeting's live session.
///
/// This is the product's vocabulary, not the transport's. A person does not
/// care whether the signalling channel is open; they care whether they are in
/// the meeting.
enum MeetingSessionState {
  /// No live session exists yet. Nobody has started anything.
  none,

  /// A session exists and this person could enter it.
  available,

  /// On the way in.
  joining,

  /// In.
  joined,

  /// Was in, and the connection dropped. The product holds their place and
  /// says so, rather than treating this as having left.
  reconnecting,

  /// Was in, and left deliberately.
  left,

  /// Could not get in, and trying again is worth offering.
  recoverableFailure,

  /// Could not get in, and trying again will not help. The reason belongs in
  /// [MeetingSessionFault].
  terminalFailure,
}

/// Why a session could not be joined or could not continue.
///
/// Named in product terms because these drive what a person is told and what
/// they are offered — §XXXI forbids a generic "Try again" where a specific
/// recovery exists.
enum MeetingSessionFault {
  none,

  /// The network is not there.
  networkUnavailable,

  /// The network is there; Aura's realtime service is not answering.
  serviceUnavailable,

  /// The person declined, or the platform refuses, camera/microphone access.
  mediaPermissionDenied,

  /// There is no usable microphone or camera.
  mediaDeviceUnavailable,

  /// The meeting will not admit this person.
  notAdmitted,

  /// The meeting is over.
  meetingConcluded,

  /// Something failed that the product cannot name usefully.
  unknown,
}

/// Whether recovery is worth offering, and how.
extension MeetingSessionFaultRecovery on MeetingSessionFault {
  /// True when retrying the same action could plausibly succeed.
  bool get isRetryable => switch (this) {
        MeetingSessionFault.networkUnavailable ||
        MeetingSessionFault.serviceUnavailable ||
        MeetingSessionFault.unknown =>
          true,
        _ => false,
      };

  /// True when the person must do something outside Aura first — the recovery
  /// is theirs to perform, so "Try again" would be a lie.
  bool get needsPersonAction => switch (this) {
        MeetingSessionFault.mediaPermissionDenied ||
        MeetingSessionFault.mediaDeviceUnavailable =>
          true,
        _ => false,
      };
}

/// INTENT VERSUS REALITY, kept apart on purpose.
///
/// A person turning their camera on is an intention. Whether the camera is
/// actually producing anything is a fact about hardware and permission, and it
/// can disagree — the request can be denied, the device can be in use, the
/// track can fail after starting. Collapsing the two is how a product ends up
/// showing "camera on" to somebody whose camera is off, which §IX forbids in
/// as many words: *do not fake permission success in UI*.
class MeetingMediaIntent {
  const MeetingMediaIntent({
    this.microphoneEnabled = true,
    this.cameraEnabled = false,
    this.screenShareEnabled = false,
  });

  final bool microphoneEnabled;
  final bool cameraEnabled;
  final bool screenShareEnabled;

  MeetingMediaIntent copyWith({
    bool? microphoneEnabled,
    bool? cameraEnabled,
    bool? screenShareEnabled,
  }) =>
      MeetingMediaIntent(
        microphoneEnabled: microphoneEnabled ?? this.microphoneEnabled,
        cameraEnabled: cameraEnabled ?? this.cameraEnabled,
        screenShareEnabled: screenShareEnabled ?? this.screenShareEnabled,
      );
}

/// What is actually happening with this person's devices.
class MeetingMediaState {
  const MeetingMediaState({
    this.microphoneLive = false,
    this.cameraLive = false,
    this.screenShareLive = false,
    this.fault = MeetingSessionFault.none,
  });

  final bool microphoneLive;
  final bool cameraLive;
  final bool screenShareLive;
  final MeetingSessionFault fault;

  static const MeetingMediaState idle = MeetingMediaState();

  /// The disagreement worth surfacing: they asked for it and it is not
  /// happening. This is what drives an honest indicator instead of a hopeful
  /// one.
  bool microphoneDisagrees(MeetingMediaIntent intent) =>
      intent.microphoneEnabled && !microphoneLive;

  bool cameraDisagrees(MeetingMediaIntent intent) =>
      intent.cameraEnabled && !cameraLive;
}

/// One other person, as the meeting workspace understands them.
///
/// Deliberately thin. The workspace needs to know who is here and whether
/// their media is arriving; it does not need, and must not hold, the objects
/// that carry the media.
class MeetingPeerMedia {
  const MeetingPeerMedia({
    required this.participantId,
    this.audioArriving = false,
    this.videoArriving = false,
    this.screenShareArriving = false,
    this.speaking = false,
  });

  final String participantId;
  final bool audioArriving;
  final bool videoArriving;
  final bool screenShareArriving;
  final bool speaking;
}

/// The whole A/V picture the workspace is entitled to, in one value.
///
/// A surface that renders from this and nothing else is testable without a
/// socket, which is the entire point of drawing the line here.
class MeetingSession {
  const MeetingSession({
    this.state = MeetingSessionState.none,
    this.fault = MeetingSessionFault.none,
    this.intent = const MeetingMediaIntent(),
    this.media = MeetingMediaState.idle,
    this.peers = const <MeetingPeerMedia>[],
  });

  final MeetingSessionState state;
  final MeetingSessionFault fault;
  final MeetingMediaIntent intent;
  final MeetingMediaState media;
  final List<MeetingPeerMedia> peers;

  static const MeetingSession none = MeetingSession();

  bool get isConnected => state == MeetingSessionState.joined;
  bool get isConnecting =>
      state == MeetingSessionState.joining ||
      state == MeetingSessionState.reconnecting;
  bool get hasFailed =>
      state == MeetingSessionState.recoverableFailure ||
      state == MeetingSessionState.terminalFailure;

  /// Whether the product should offer to try again.
  bool get canRetry =>
      state == MeetingSessionState.recoverableFailure && fault.isRetryable;

  MeetingSession copyWith({
    MeetingSessionState? state,
    MeetingSessionFault? fault,
    MeetingMediaIntent? intent,
    MeetingMediaState? media,
    List<MeetingPeerMedia>? peers,
  }) =>
      MeetingSession(
        state: state ?? this.state,
        fault: fault ?? this.fault,
        intent: intent ?? this.intent,
        media: media ?? this.media,
        peers: peers ?? this.peers,
      );
}
