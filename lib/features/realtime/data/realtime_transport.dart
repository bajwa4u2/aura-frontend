import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../domain/remote_media_presentation.dart';

/// HOW MEDIA MOVES — the one thing that differs between mesh and SFU.
///
/// Founder ruling, media-service transport seam §1 and §3. The released client
/// currently owns mesh topology as an implicit permanent assumption: one
/// remote device becomes one `RTCPeerConnection`, and remote media is
/// discovered through `onTrack` and keyed by device. That is not a fact about
/// realtime media; it is a fact about mesh.
///
/// This interface is the smallest seam that makes the assumption explicit.
/// Everything above it — call initiation, ringing, Meeting lifecycle,
/// participant identity, control meaning, return behaviour, preflight, cleanup
/// semantics — is deliberately unchanged. This is a transport migration.
///
/// Both implementations answer the same question, *whose media is arriving*,
/// in the same shape: [RemoteParticipantMedia] keyed by canonical participant
/// id. No product surface needs to know which one answered.
abstract class RealtimeTransport {
  /// Stable identifier for logs and topology reporting.
  String get id;

  /// Open the transport for a session, offering whatever local media exists.
  ///
  /// [local] may be null. Mesh deliberately continues when capture fails —
  /// a participant whose camera and microphone were denied or are busy can
  /// still SEE and HEAR the room — and the stage path must not be stricter,
  /// or a permission denial would turn a degraded call into no call at all.
  Future<void> open({
    required String sessionId,
    MediaStream? local,
    String trigger,
  });

  /// Publish the local tracks attached at [open].
  Future<void> publishLocal({String trigger});

  /// Resolve everyone else's media in this session.
  ///
  /// Returns the canonical presentation model. Implementations must never
  /// report a participant's own outbound media as remote.
  Future<Map<String, RemoteParticipantMedia>> refreshRemoteMedia({
    String trigger,
  });

  /// Replace the published video source in place.
  ///
  /// This is camera switching, screen share, and device selection, and it is a
  /// TRACK replacement: no new session, no new participant, no re-admission,
  /// and never one replacement path per subscriber.
  ///
  /// A null track CLEARS the sender. Stopping a screen share in an audio-only
  /// call has no camera to restore, and leaving the retired screen track on
  /// the wire would keep publishing a frozen frame of someone's desktop.
  Future<void> replaceVideoSource(MediaStreamTrack? track);

  /// Replace the published audio source in place. Same contract as
  /// [replaceVideoSource]; this is microphone selection.
  Future<void> replaceAudioSource(MediaStreamTrack? track);

  Future<void> setMicrophoneEnabled(bool enabled);

  Future<void> setCameraEnabled(bool enabled);

  /// Tear down transport state. Must be idempotent and must not throw on a
  /// leave — a failed cleanup must never strand the person in the call.
  Future<void> close();

  /// Report one client-side fact about this transport, for the operator.
  ///
  /// The stage path already reports its subscribe and bind outcomes this way,
  /// and those reports are what identified two consecutive defects that no
  /// server record could see. Rendering is the next unlit stretch: a bound
  /// track that never reaches a renderer looks, from the server, exactly like
  /// one that did.
  ///
  /// Default is a no-op so mesh is unchanged and so a transport can never be
  /// obliged to have an opinion about diagnostics.
  Future<void> report({
    required String phase,
    required String code,
    required String message,
  }) async {}

  /// What is actually moving.
  ///
  /// The selector has to be observable (§6), and certification has to assert
  /// DELIVERY rather than negotiation (§10) — a connected transport that
  /// carries no media is a failure, and the suite that once passed while
  /// delivering nothing is the reason this is on the interface rather than
  /// reached for inside a test.
  Future<RealtimeTransportStats> stats();
}

/// Delivery facts, transport-independent.
class RealtimeTransportStats {
  const RealtimeTransportStats({
    required this.inboundBytes,
    required this.outboundBytes,
    required this.uploadPathCount,
  });

  final int inboundBytes;
  final int outboundBytes;

  /// Number of outbound RTP streams the local publisher is sending.
  ///
  /// The architectural invariant in one number: under SFU this is one per
  /// TRACK and does not move as the audience grows; under mesh it is one per
  /// track per remote peer.
  final int uploadPathCount;
}
