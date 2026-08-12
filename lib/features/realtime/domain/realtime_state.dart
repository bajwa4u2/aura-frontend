import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'realtime_enums.dart';
import 'realtime_models.dart';

class RealtimeState {
  const RealtimeState({
    required this.connectionStatus,
    required this.joinState,
    required this.sessionId,
    required this.session,
    required this.participants,
    required this.policy,
    required this.consents,
    required this.recordings,
    required this.transcripts,
    required this.artifacts,
    required this.errorMessage,
    required this.infoMessage,
    required this.lastSocketEvent,
    required this.isBusy,
    required this.isMediaReady,
    required this.isMediaBusy,
    required this.localRenderer,
    required this.remoteRenderers,
    required this.microphoneEnabled,
    required this.cameraEnabled,
    required this.mediaError,
    required this.callMode,
    required this.incomingCall,
    this.isScreenSharing = false,
    this.isCallRoomVisible = false,
    this.isEndingCall = false,
    this.reconnectingUserIds = const <String>{},
    this.acceptedByPeer = false,
    this.speakerphoneEnabled = false,
  });

  final RealtimeConnectionStatus connectionStatus;
  final RealtimeJoinState joinState;
  final String? sessionId;
  final RealtimeSession? session;
  final List<RealtimeParticipant> participants;
  final RealtimePolicy? policy;
  final List<RealtimeConsent> consents;
  final List<RealtimeRecording> recordings;
  final List<RealtimeTranscriptJob> transcripts;
  final List<RealtimeArtifact> artifacts;
  final String? errorMessage;
  final String? infoMessage;
  final String? lastSocketEvent;
  final bool isBusy;
  final bool isMediaReady;
  final bool isMediaBusy;
  final RTCVideoRenderer? localRenderer;
  final Map<String, RTCVideoRenderer> remoteRenderers;
  final bool microphoneEnabled;
  final bool cameraEnabled;
  final String? mediaError;
  final String? callMode;
  final Map<String, dynamic>? incomingCall;

  /// I1: True while the local user is broadcasting their screen.
  final bool isScreenSharing;

  /// A4: True while the dedicated /realtime/:id room screen is mounted and
  /// covering the rest of the UI. Drives PiP visibility from state instead
  /// of from the route path, so there's never a frame where neither the
  /// full call nor the PiP is rendered during minimize/restore.
  final bool isCallRoomVisible;

  /// A5: True between the start and finish of the controller's `endCall()`.
  /// UI surfaces (room screen, PiP) read this flag instead of carrying their
  /// own end-tap guard. Single source of truth — one tap, one end.
  final bool isEndingCall;

  /// Participants whose connection dropped involuntarily and are inside the
  /// reconnect grace window. They stay on the roster (tile shows
  /// "Reconnecting…") instead of vanishing; if the grace expires they leave
  /// for real.
  final Set<String> reconnectingUserIds;

  /// Authoritative ACCEPT truth for the CALLER: true once the backend has
  /// confirmed the invited party's first-action-wins ACCEPT transaction
  /// committed (`call:accepted`), independent of whether that party's
  /// realtime/media join has actually completed. This must never be treated
  /// as proof of connection — `participants` reflecting a present peer
  /// remains the sole evidence of that. Represents the ACCEPTED/JOINING
  /// step between RINGING/CONNECTING and CONNECTED.
  final bool acceptedByPeer;

  /// Thread/DM speaker toggle (2026-08-14 repair) — mirrors
  /// `RealtimeMediaService.speakerphoneEnabled`. Mobile-native only; resolved
  /// fresh per call, never a persisted/global preference.
  final bool speakerphoneEnabled;

  factory RealtimeState.initial() {
    return const RealtimeState(
      connectionStatus: RealtimeConnectionStatus.disconnected,
      joinState: RealtimeJoinState.idle,
      sessionId: null,
      session: null,
      participants: <RealtimeParticipant>[],
      policy: null,
      consents: <RealtimeConsent>[],
      recordings: <RealtimeRecording>[],
      transcripts: <RealtimeTranscriptJob>[],
      artifacts: <RealtimeArtifact>[],
      errorMessage: null,
      infoMessage: null,
      lastSocketEvent: null,
      isBusy: false,
      isMediaReady: false,
      isMediaBusy: false,
      localRenderer: null,
      remoteRenderers: <String, RTCVideoRenderer>{},
      microphoneEnabled: true,
      cameraEnabled: true,
      mediaError: null,
      callMode: null,
      incomingCall: null,
      isScreenSharing: false,
      isCallRoomVisible: false,
      isEndingCall: false,
      reconnectingUserIds: <String>{},
      acceptedByPeer: false,
      speakerphoneEnabled: false,
    );
  }

  RealtimeState copyWith({
    RealtimeConnectionStatus? connectionStatus,
    RealtimeJoinState? joinState,
    String? sessionId,
    bool clearSessionId = false,
    RealtimeSession? session,
    bool clearSession = false,
    List<RealtimeParticipant>? participants,
    RealtimePolicy? policy,
    bool clearPolicy = false,
    List<RealtimeConsent>? consents,
    List<RealtimeRecording>? recordings,
    List<RealtimeTranscriptJob>? transcripts,
    List<RealtimeArtifact>? artifacts,
    String? errorMessage,
    bool clearErrorMessage = false,
    String? infoMessage,
    bool clearInfoMessage = false,
    String? lastSocketEvent,
    bool clearLastSocketEvent = false,
    bool? isBusy,
    bool? isMediaReady,
    bool? isMediaBusy,
    RTCVideoRenderer? localRenderer,
    bool clearLocalRenderer = false,
    Map<String, RTCVideoRenderer>? remoteRenderers,
    bool clearRemoteRenderers = false,
    bool? microphoneEnabled,
    bool? cameraEnabled,
    String? mediaError,
    bool clearMediaError = false,
    String? callMode,
    bool clearCallMode = false,
    Map<String, dynamic>? incomingCall,
    bool clearIncomingCall = false,
    bool? isScreenSharing,
    bool? isCallRoomVisible,
    bool? isEndingCall,
    Set<String>? reconnectingUserIds,
    bool? acceptedByPeer,
    bool? speakerphoneEnabled,
  }) {
    return RealtimeState(
      connectionStatus: connectionStatus ?? this.connectionStatus,
      joinState: joinState ?? this.joinState,
      sessionId: clearSessionId ? null : (sessionId ?? this.sessionId),
      session: clearSession ? null : (session ?? this.session),
      participants: participants ?? this.participants,
      policy: clearPolicy ? null : (policy ?? this.policy),
      consents: consents ?? this.consents,
      recordings: recordings ?? this.recordings,
      transcripts: transcripts ?? this.transcripts,
      artifacts: artifacts ?? this.artifacts,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      infoMessage: clearInfoMessage ? null : (infoMessage ?? this.infoMessage),
      lastSocketEvent: clearLastSocketEvent ? null : (lastSocketEvent ?? this.lastSocketEvent),
      isBusy: isBusy ?? this.isBusy,
      isMediaReady: isMediaReady ?? this.isMediaReady,
      isMediaBusy: isMediaBusy ?? this.isMediaBusy,
      localRenderer: clearLocalRenderer ? null : (localRenderer ?? this.localRenderer),
      remoteRenderers: clearRemoteRenderers
          ? <String, RTCVideoRenderer>{}
          : (remoteRenderers ?? this.remoteRenderers),
      microphoneEnabled: microphoneEnabled ?? this.microphoneEnabled,
      cameraEnabled: cameraEnabled ?? this.cameraEnabled,
      mediaError: clearMediaError ? null : (mediaError ?? this.mediaError),
      callMode: clearCallMode ? null : (callMode ?? this.callMode),
      incomingCall: clearIncomingCall ? null : (incomingCall ?? this.incomingCall),
      isScreenSharing: isScreenSharing ?? this.isScreenSharing,
      isCallRoomVisible: isCallRoomVisible ?? this.isCallRoomVisible,
      isEndingCall: isEndingCall ?? this.isEndingCall,
      reconnectingUserIds: reconnectingUserIds ?? this.reconnectingUserIds,
      acceptedByPeer: acceptedByPeer ?? this.acceptedByPeer,
      speakerphoneEnabled: speakerphoneEnabled ?? this.speakerphoneEnabled,
    );
  }

  bool get isConnected => connectionStatus == RealtimeConnectionStatus.connected;
  bool get isJoined => joinState == RealtimeJoinState.joined;
  bool get hasIncomingCall => incomingCall != null && incomingCall!.isNotEmpty;
  /// Peer accepted but has not yet actually joined media — the ACCEPTED/
  /// JOINING step. Must not be conflated with connected/present.
  bool get isPeerAcceptedNotYetPresent =>
      acceptedByPeer && participants.where((p) => p.isPresent).length <= 1;
  bool get isVideoMode => (callMode ?? '').trim().toLowerCase() == 'video';
  bool get isAudioMode => (callMode ?? '').trim().toLowerCase() == 'audio';
}
