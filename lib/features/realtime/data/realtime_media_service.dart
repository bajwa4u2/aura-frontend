import 'dart:async';



import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../core/media/device_permission.dart';
import '../domain/remote_media_presentation.dart';
import 'realtime_transport.dart';

/// What a camera request ACTUALLY achieved.
///
/// [enabled] is the state now in effect, which is not necessarily the state
/// that was asked for: a camera that cannot be acquired reports false. The
/// caller publishes THIS, never its own intent.
class _SelectedPath {
  const _SelectedPath({
    required this.candidateType,
    required this.protocol,
    required this.networkType,
  });
  final String? candidateType;
  final String? protocol;
  final String? networkType;
}

class CameraSetResult {
  const CameraSetResult({
    required this.enabled,
    required this.needsRenegotiation,
  });

  final bool enabled;
  final bool needsRenegotiation;
}

class RealtimeMediaSnapshot {
  const RealtimeMediaSnapshot({
    required this.ready,
    required this.micEnabled,
    required this.cameraEnabled,
    required this.localRenderer,
    required this.remoteRenderers,
    required this.error,
    required this.isScreenSharing,
    this.sentTrackKinds = const <String>[],
    this.onTrackAudioSeen = false,
    this.onTrackVideoSeen = false,
    this.localVideoTrackPresent = false,
    this.remoteVideoRendererAttached = false,
    this.cameraUnavailable = false,
    this.speakerphoneEnabled = false,
    this.readiness = MediaReadiness.unchecked,
    this.remoteByParticipant = const <String, RemoteParticipantMedia>{},
    this.remoteRenderersByParticipant = const <String, RTCVideoRenderer>{},
  });

  final bool ready;
  final bool micEnabled;
  final bool cameraEnabled;
  /// Thread/DM speaker toggle (2026-08-14 repair) — mobile-native
  /// speakerphone routing state, resolved fresh per call.
  final bool speakerphoneEnabled;
  final RTCVideoRenderer? localRenderer;
  final Map<String, RTCVideoRenderer> remoteRenderers;

  /// CANONICAL remote media, keyed by Aura participant id.
  ///
  /// The transport-independent answer to "whose media is arriving". Mesh keys
  /// its renderers by device because it builds one peer connection per remote
  /// device; the stage transport has one peer connection in total and nothing
  /// device-shaped to key on. Surfaces should read this and stop treating
  /// `remoteRenderers[deviceId]` as identity authority.
  final Map<String, RemoteParticipantMedia> remoteByParticipant;

  /// Renderers keyed by PARTICIPANT — what surfaces should display.
  ///
  /// `remoteRenderers` above is device-keyed and belongs to mesh. Surfaces
  /// must not rebuild participant identity from a device key: somebody who
  /// reconnects is the same person, and that is exactly what produced a
  /// duplicate anonymous tile after every refresh.
  final Map<String, RTCVideoRenderer> remoteRenderersByParticipant;
  /// A sentence, for surfaces that only need to say something went wrong.
  ///
  /// Derived from [readiness] rather than hand-written at the failure site —
  /// the engine used to compose its own copy here and told Windows, Android
  /// and iOS people to check "this browser".
  final String? error;

  /// WHAT ACTUALLY HAPPENED, classified.
  ///
  /// The canonical authority (`core/media/device_permission.dart`) existed
  /// before this chapter but was consumed by exactly one Meetings widget; the
  /// engine itself collapsed permission denial, a busy camera, a missing
  /// camera and an insecure origin into a single string. Surfaces can now ask
  /// what the actual state is and offer the recovery that matches it.
  final MediaReadiness readiness;

  final bool isScreenSharing;
  // Video capture failed but audio succeeded — camera busy in another
  // app/browser. Audio still publishes; UI shows an explicit message.
  final bool cameraUnavailable;
  // ── Temporary RTC debug (on-screen badge) ────────────────────────────
  final List<String> sentTrackKinds; // kinds addTrack'd to the peer
  final bool onTrackAudioSeen;
  final bool onTrackVideoSeen;
  final bool localVideoTrackPresent; // local stream has a video track
  final bool remoteVideoRendererAttached; // a remote stream has a video track
}

/// Peer transport health, surfaced to the controller so recovery decisions
/// (ICE restart, re-offer, removal) live in ONE place instead of inside the
/// media layer's callbacks.
enum RealtimePeerHealth { recovered, needsRestart, dead }

class RealtimePeerHealthEvent {
  const RealtimePeerHealthEvent({required this.peerKey, required this.health});
  final String peerKey;
  final RealtimePeerHealth health;
}

/// One aggregated quality sample across all peers — attached to the session
/// heartbeat so the backend's quality record holds evidence, not nulls.
class RealtimeQualitySample {
  const RealtimeQualitySample({
    this.rttMs,
    this.jitterMs,
    this.packetLossPct,
    this.bitrateKbps,
    this.selectedCandidateType,
    this.transportProtocol,
    this.networkType,
  });
  final int? rttMs;
  final int? jitterMs;
  final double? packetLossPct;
  final int? bitrateKbps;

  /// WHICH TRANSPORT ACTUALLY CARRIED THE CALL.
  ///
  /// HOST / SRFLX / PRFLX / RELAY, read from the SELECTED candidate pair —
  /// not from the ICE servers that were issued. Every sample written before
  /// this stored the column default UNKNOWN, so production could not answer,
  /// from its own records, whether any call had ever used TURN. Issuance and
  /// provider health are capability, never carriage.
  ///
  /// Null when the platform does not expose it. Never guessed.
  final String? selectedCandidateType;

  /// UDP / TCP / TLS for the selected pair. For a relayed candidate this is
  /// the protocol to the TURN server (`relayProtocol`), which is the leg that
  /// answers "did this traverse 443?" — the question coturn could not.
  final String? transportProtocol;

  /// WIFI / ETHERNET / CELLULAR / VPN. Some browsers withhold this for
  /// fingerprinting reasons; absent means absent.
  final String? networkType;

  bool get hasAny =>
      rttMs != null ||
      jitterMs != null ||
      packetLossPct != null ||
      bitrateKbps != null ||
      selectedCandidateType != null ||
      transportProtocol != null ||
      networkType != null;
}

class RealtimeMediaService {
  RealtimeMediaService();

  /// The only label `createLocalMediaStream` may be given.
  ///
  /// On native the label IS the stream's `ownerTag`, and Android resolves a
  /// renderer's source from `localStreams` only when that tag reads exactly
  /// `local`. Any other value sends the lookup to `getStreamForId`, which
  /// searches peer connections by id, finds nothing, and hands the renderer a
  /// null stream — silently. Named here so the constraint is stated once
  /// rather than rediscovered from a black tile.
  static const String _localOwnerTag = 'local';

  final StreamController<RealtimeMediaSnapshot> _snapshots =
      StreamController<RealtimeMediaSnapshot>.broadcast();
  final StreamController<RealtimePeerHealthEvent> _peerHealth =
      StreamController<RealtimePeerHealthEvent>.broadcast();

  final Map<String, RTCPeerConnection> _peers = <String, RTCPeerConnection>{};
  final Map<String, RTCVideoRenderer> _remoteRenderers =
      <String, RTCVideoRenderer>{};
  final Map<String, MediaStream> _remoteStreams = <String, MediaStream>{};
  // Perfect-negotiation: peers for which we currently have an offer in flight.
  final Map<String, bool> _makingOffer = <String, bool>{};

  // ── Transport resilience state ────────────────────────────────────────
  // Trickle-ICE correctness: candidates that arrive before the peer exists
  // or before its remote description is applied are BUFFERED, not dropped.
  // The answerer spends seconds in getUserMedia while the offerer trickles
  // immediately — without this buffer the earliest (usually best) candidates
  // of every single connect were silently lost.
  final Map<String, List<Map<String, dynamic>>> _pendingRemoteCandidates =
      <String, List<Map<String, dynamic>>>{};
  final Set<String> _remoteDescriptionSet = <String>{};
  static const int _maxBufferedCandidatesPerPeer = 64;

  // ICE recovery: per-peer disconnect grace timers and restart budgets. A
  // network path change surfaces as disconnected→failed; instead of killing
  // the peer we escalate to the controller, which performs an ICE restart
  // through the normal perfect-negotiation path.
  final Map<String, Timer> _iceGraceTimers = <String, Timer>{};
  final Map<String, int> _iceRestartAttempts = <String, int>{};
  static const int _maxIceRestartAttempts = 2;
  static const Duration _iceDisconnectGrace = Duration(seconds: 5);

  Stream<RealtimePeerHealthEvent> get peerHealthEvents => _peerHealth.stream;

  MediaStream? _localStream;

  /// The stage transport, when the SERVER has selected it. Null means mesh.
  ///
  /// Founder ruling §2: no screen, caller or local flag chooses this — it is
  /// attached only in response to the session's server-authoritative
  /// routingMode, and while it is null every mesh path below behaves exactly
  /// as it did before this migration.
  RealtimeTransport? _stage;
  Map<String, RemoteParticipantMedia> _remoteByParticipant =
      const <String, RemoteParticipantMedia>{};

  /// Renderers keyed by PARTICIPANT, for surfaces to display.
  ///
  /// The stage delivers tracks, not streams, and a renderer needs a stream —
  /// so one is built per participant. Keyed by participant id because that is
  /// presentation identity: somebody who reconnects is the same person, and a
  /// device-keyed renderer map cannot express that.
  final Map<String, RTCVideoRenderer> _remoteRenderersByParticipant =
      <String, RTCVideoRenderer>{};
  final Map<String, MediaStream> _remoteStreamsByParticipant =
      <String, MediaStream>{};
  RTCVideoRenderer? _localRenderer;
  MediaStream? _screenStream;
  bool _ready = false;
  bool _micEnabled = true;
  bool _cameraEnabled = true;
  // Resolved fresh per call (never persisted globally/across sessions) — the
  // 2026-08-14 Thread/DM speaker-route repair. Mobile-native only (iOS/
  // Android); web routes output via `setAudioOutput`/device selection.
  bool _speakerphoneEnabled = false;
  bool _isScreenSharing = false;
  String? _error;

  /// Classified device readiness — the engine's answer to "why not", kept
  /// beside the sentence rather than baked into it.
  MediaReadiness _readiness = MediaReadiness.unchecked;
  bool _disposed = false;
  // Preferred input/output devices (chosen in pre-join or the in-meeting device
  // menu). Honoured by acquisition constraints and by the live-switch methods.
  String? _preferredVideoDeviceId;
  String? _preferredAudioDeviceId;
  String? _preferredAudioOutputDeviceId;
  // Coalesces concurrent ensureLocalMedia() calls (join + offer + reconcile can
  // all fire near-simultaneously); the winner's future is shared so a later
  // call never resets the freshly-acquired stream mid-flight.
  Future<void>? _mediaAcquisition;
  // True when video acquisition failed but audio succeeded — the camera is held
  // by another app/browser (host + guest sharing one physical camera on the
  // same laptop). The UI shows an explicit "camera busy" message; audio still
  // publishes so the peer connection is not empty.
  bool _cameraUnavailable = false;
  // ── Temporary RTC debug ──────────────────────────────────────────────
  List<String> _lastSentTrackKinds = const <String>[];
  bool _onTrackAudioSeen = false;
  bool _onTrackVideoSeen = false;

  Stream<RealtimeMediaSnapshot> get snapshots => _snapshots.stream;

  /// True when a peer connection already exists for [peerKey]. Used so
  /// renegotiation only re-offers to already-connected peers; NEW connections
  /// are initiated exclusively from the participant.joined path.
  bool hasPeer(String peerKey) => _peers.containsKey(peerKey);

  /// True while our offer to [peerKey] is outstanding (no answer applied).
  /// Drives the negotiation watchdog: a lost answer is re-offered instead of
  /// waiting forever.
  bool isAwaitingAnswer(String peerKey) {
    final connection = _peers[peerKey];
    if (connection == null) return false;
    return connection.signalingState ==
        RTCSignalingState.RTCSignalingStateHaveLocalOffer;
  }

  RealtimeMediaSnapshot get currentSnapshot => RealtimeMediaSnapshot(
        ready: _ready,
        micEnabled: _micEnabled,
        cameraEnabled: _cameraEnabled,
        localRenderer: _localRenderer,
        remoteRenderers: Map<String, RTCVideoRenderer>.from(_remoteRenderers),
        remoteByParticipant:
            Map<String, RemoteParticipantMedia>.from(_remoteByParticipant),
        remoteRenderersByParticipant:
            Map<String, RTCVideoRenderer>.from(_remoteRenderersByParticipant),
        error: _error,
        readiness: _readiness,
        isScreenSharing: _isScreenSharing,
        sentTrackKinds: List<String>.from(_lastSentTrackKinds),
        onTrackAudioSeen: _onTrackAudioSeen,
        onTrackVideoSeen: _onTrackVideoSeen,
        localVideoTrackPresent:
            _localStream?.getVideoTracks().isNotEmpty ?? false,
        remoteVideoRendererAttached:
            _remoteStreams.values.any((s) => s.getVideoTracks().isNotEmpty),
        cameraUnavailable: _cameraUnavailable,
        speakerphoneEnabled: _speakerphoneEnabled,
      );

  Future<void> ensureLocalMedia({
    required bool audio,
    required bool video,
  }) async {
    if (_disposed) return;

    if (_ready && _localStream != null && _localRenderer != null) {
      if (_micEnabled != audio) {
        await setMicrophoneEnabled(audio);
      }
      if (_cameraEnabled != video) {
        await setCameraEnabled(video);
      }
      return;
    }

    // Coalesce concurrent acquisitions. join, session:offer and reconcile can
    // all call this near-simultaneously; without a guard the second call's
    // _resetLocalMediaOnly() nulls the first call's freshly-acquired stream
    // mid-flight — so the answerer attaches NO local stream and never publishes
    // to the peer (guest badge localVid=false / "attach: NO local stream").
    final inflight = _mediaAcquisition;
    if (inflight != null) return inflight;
    final future = _acquireLocalMedia(audio: audio, video: video);
    _mediaAcquisition = future;
    try {
      await future;
    } finally {
      _mediaAcquisition = null;
    }
  }

  Future<void> _acquireLocalMedia({
    required bool audio,
    required bool video,
  }) async {
    await _resetLocalMediaOnly();
    _cameraUnavailable = false;

    final renderer = RTCVideoRenderer();
    await renderer.initialize();

    // Honour the user's preferred devices when set (chosen in pre-join or the
    // in-meeting device menu). `ideal` — not `exact` — so a removed/unplugged
    // device falls back to the system default instead of failing acquisition.
    Map<String, dynamic> constraints(bool wantVideo) {
      final audioConstraint = audio
          ? ((_preferredAudioDeviceId?.isNotEmpty ?? false)
              ? <String, dynamic>{
                  'deviceId': <String, dynamic>{'ideal': _preferredAudioDeviceId},
                }
              : true)
          : false;
      final videoConstraint = wantVideo
          ? <String, dynamic>{
              'facingMode': 'user',
              'width': <String, dynamic>{'ideal': 1280},
              'height': <String, dynamic>{'ideal': 720},
              'frameRate': <String, dynamic>{'ideal': 24},
              if (_preferredVideoDeviceId?.isNotEmpty ?? false)
                'deviceId': <String, dynamic>{'ideal': _preferredVideoDeviceId},
            }
          : false;
      return <String, dynamic>{'audio': audioConstraint, 'video': videoConstraint};
    }

    MediaStream? stream;
    var gotVideo = video;
    // What the platform actually said, per device. Starts as "not asked" so a
    // device we never requested is never reported as refused.
    var micState = audio
        ? DevicePermissionState.granted
        : DevicePermissionState.notRequested;
    var cameraState = video
        ? DevicePermissionState.granted
        : DevicePermissionState.notRequested;
    try {
      stream = await navigator.mediaDevices.getUserMedia(constraints(video));
    } catch (error) {
      // NotReadableError / TrackStartError ⇒ the camera is held by ANOTHER
      // app/browser (host + guest on ONE laptop share a single physical camera;
      // the second browser can't open it). NotAllowedError ⇒ permission denied.
      // Rather than fail the whole acquisition (publishing NOTHING — the old
      // "attach: NO local stream" bug), DEGRADE to audio-only so this side
      // still publishes audio and the peer connection has a live sender.
      debugPrint(
        '[rtc-media] getUserMedia FAILED audio=$audio video=$video err=$error',
      );
      // CLASSIFY, do not narrate. `NotAllowedError` is a refusal;
      // `NotReadableError` is a device someone else already has;
      // `NotFoundError` is no device at all; `SecurityError` is policy. They
      // need three different things from the person and one of them needs
      // nothing at all.
      final combined = classifyMediaError(error, kind: MediaDeviceKind.camera);
      if (video) cameraState = combined;
      if (audio) micState = combined;
      if (video && audio) {
        try {
          stream = await navigator.mediaDevices.getUserMedia(constraints(false));
          gotVideo = false;
          _cameraUnavailable = true;
          // Audio came back, so whatever went wrong was the camera's alone.
          micState = DevicePermissionState.granted;
          cameraState = classifyMediaError(error, kind: MediaDeviceKind.camera);
          debugPrint(
            '[rtc-media] degraded to AUDIO-ONLY camera=$cameraState'
            ' aTracks=${stream.getAudioTracks().length}',
          );
        } catch (audioError) {
          micState =
              classifyMediaError(audioError, kind: MediaDeviceKind.microphone);
          debugPrint('[rtc-media] audio-only ALSO failed mic=$micState');
        }
      }
    }

    _readiness = MediaReadiness(
      microphone: DeviceReadiness(
        kind: MediaDeviceKind.microphone,
        state: micState,
      ),
      camera: DeviceReadiness(kind: MediaDeviceKind.camera, state: cameraState),
    );

    if (stream == null) {
      // Nothing acquired at all — surface the error but do NOT rethrow, so the
      // caller stays joined (they can retry via the camera/mic toggle).
      await renderer.dispose();
      // The sentence now comes from the classification, so it is
      // platform-correct by construction rather than by remembering to write
      // it correctly at each failure site.
      final concern = _readiness.primaryConcern;
      _error = concern == null
          ? 'Your camera and microphone could not be started.'
          : concern.summary;
      _ready = false;
      _publish();
      return;
    }

    renderer.srcObject = stream;
    _localRenderer = renderer;
    _localStream = stream;
    _ready = true;
    _micEnabled = audio && stream.getAudioTracks().isNotEmpty;
    _cameraEnabled = gotVideo && stream.getVideoTracks().isNotEmpty;
    // Joined, but possibly without the camera. Say which, in the words that
    // match what actually happened on THIS platform.
    _error = _cameraUnavailable ? _readiness.camera.summary : null;
    _publish();
  }

  Future<void> _attachLocalTracks(
    RTCPeerConnection connection,
    String peerKey,
  ) async {
    // WAIT FOR MEDIA IN FLIGHT BEFORE CONCLUDING THERE IS NONE.
    //
    // THE DEFECT THIS FIXES — founder-observed live on 2026-08-25, Pixel ↔
    // browser: the callee saw nothing while the caller saw them perfectly.
    //
    // This is the answerer path. `handleRemoteOffer` attaches local tracks
    // after `setRemoteDescription`, exactly once, guarded by `isNewPeer`. If
    // the offer lands while `getUserMedia` is STILL RESOLVING, `_localStream`
    // is null, this method used to log "NO local stream" and return, and
    // `createAnswer` then produced **recvonly** m-lines. The peer reaches
    // Connected and is permanently dark and silent to the far side.
    //
    // It is unrecoverable afterwards: `setCameraEnabled` only flips
    // `track.enabled` on tracks that already exist, and `replaceTrack` needs a
    // sender to replace — which is why toggling the camera did nothing and
    // only leaving and rejoining helped.
    //
    // Answering the offer is not urgent enough to justify answering it wrong.
    // Acquisition is already coalesced into a single future, so waiting here
    // costs one in-flight getUserMedia and removes the whole race.
    final inflight = _mediaAcquisition;
    if (_localStream == null && inflight != null) {
      debugPrint('[rtc] attach: media in flight, waiting peerKey=$peerKey');
      try {
        await inflight;
      } catch (_) {/* acquisition reports its own failure via _readiness */}
    }

    final local = _localStream;
    if (local == null) {
      // Genuinely nothing to send — a refused or absent device. The peer is
      // receive-only by circumstance, not by accident, and the readiness model
      // has already said why.
      debugPrint('[rtc] attach: NO local stream peerKey=$peerKey');
      return;
    }
    final kinds = <String>[];
    for (final track in local.getTracks()) {
      try {
        await connection.addTrack(track, local);
        kinds.add(track.kind ?? '?');
      } catch (e) {
        debugPrint(
          '[rtc] addTrack FAILED kind=${track.kind} peerKey=$peerKey err=$e',
        );
      }
    }
    _lastSentTrackKinds = kinds;
    _publish();
  }

  Future<RTCPeerConnection> _ensurePeer({
    required String peerKey,
    required Map<String, dynamic> configuration,
    required void Function(RTCIceCandidate candidate) onIceCandidate,
    bool addLocalTracks = true,
  }) async {
    final existing = _peers[peerKey];
    if (existing != null) return existing;

    final connection = await createPeerConnection(configuration);
    final iceServerCount = (configuration['iceServers'] is List)
        ? (configuration['iceServers'] as List).length
        : 0;
    // OFFERER attaches local tracks up front (it creates the transceivers).
    // The ANSWERER must NOT — it attaches AFTER setRemoteDescription so the
    // tracks bind to the offered transceivers (recvonly → sendrecv). Adding
    // them before setRemoteDescription misaligned the m-lines, so the
    // answerer's media never reached the offerer → one-way video (host stuck
    // "waiting for guest" while the guest saw the host).
    if (addLocalTracks) {
      await _attachLocalTracks(connection, peerKey);
    }
    debugPrint(
      '[rtc] peer created peerKey=$peerKey iceServers=$iceServerCount'
      ' addLocalTracks=$addLocalTracks',
    );

    connection.onIceCandidate = (RTCIceCandidate candidate) {
      debugPrint('[rtc] ice-candidate LOCAL peerKey=$peerKey');
      onIceCandidate(candidate);
    };

    connection.onIceConnectionState = (RTCIceConnectionState state) {
      debugPrint('[rtc] iceConnectionState peerKey=$peerKey state=$state');
      switch (state) {
        case RTCIceConnectionState.RTCIceConnectionStateConnected:
        case RTCIceConnectionState.RTCIceConnectionStateCompleted:
          _iceGraceTimers.remove(peerKey)?.cancel();
          _iceRestartAttempts.remove(peerKey);
          _emitPeerHealth(peerKey, RealtimePeerHealth.recovered);
          break;
        case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
          // Transient by definition — WebRTC often self-heals within
          // seconds. Only escalate if it persists past the grace window.
          _iceGraceTimers.remove(peerKey)?.cancel();
          _iceGraceTimers[peerKey] = Timer(_iceDisconnectGrace, () {
            _iceGraceTimers.remove(peerKey);
            if (_peers.containsKey(peerKey)) {
              _escalateIceFailure(peerKey);
            }
          });
          break;
        case RTCIceConnectionState.RTCIceConnectionStateFailed:
          _iceGraceTimers.remove(peerKey)?.cancel();
          _escalateIceFailure(peerKey);
          break;
        default:
          break;
      }
    };

    connection.onTrack = (RTCTrackEvent event) async {
      final kind = event.track.kind ?? '';
      if (kind == 'audio') _onTrackAudioSeen = true;
      if (kind == 'video') _onTrackVideoSeen = true;
      try {
        final stream = await _resolveRemoteStream(peerKey, event);
        if (stream == null) return;

        _remoteStreams[peerKey] = stream;
        final renderer = _remoteRenderers[peerKey] ?? await _createRemoteRenderer();
        renderer.srcObject = stream;
        _remoteRenderers[peerKey] = renderer;
        _error = null;
        // Remote attach is logged on the SUCCESS path, not only on failure.
        // During two-party certification a device log could show ICE connected
        // and `setVideoTrack` with the local track id, but could not answer
        // "did onTrack fire with a remote video track" — which is the first
        // question anyone asks about one-way media. It can now.
        debugPrint(
          '[rtc] onTrack ATTACHED peerKey=$peerKey kind=$kind '
          'streams=${event.streams.length} '
          'v=${stream.getVideoTracks().length} a=${stream.getAudioTracks().length} '
          'renderers=${_remoteRenderers.length}',
        );
        _publish();
      } catch (error) {
        debugPrint('[rtc] onTrack ERROR peerKey=$peerKey err=$error');
        _error = error.toString();
        _publish();
      }
    };

    // FALLBACK: on some flutter_webrtc web builds the remote media arrives via
    // onAddStream (plan-b style) and onTrack never fires — audio auto-plays
    // natively so it "works", but no remote RENDERER is created and video never
    // shows (remoteRenderers=0, onTrackVideoSeen=false). Attach the remote
    // stream here too so video renders regardless of which callback fires.
    connection.onAddStream = (MediaStream stream) {
      _onTrackAudioSeen = _onTrackAudioSeen || stream.getAudioTracks().isNotEmpty;
      _onTrackVideoSeen = _onTrackVideoSeen || stream.getVideoTracks().isNotEmpty;
      unawaited(() async {
        try {
          _remoteStreams[peerKey] = stream;
          final renderer =
              _remoteRenderers[peerKey] ?? await _createRemoteRenderer();
          renderer.srcObject = stream;
          _remoteRenderers[peerKey] = renderer;
          _error = null;
          _publish();
        } catch (error) {
          debugPrint('[rtc] onAddStream ERROR peerKey=$peerKey err=$error');
        }
      }());
    };

    connection.onConnectionState = (RTCPeerConnectionState state) async {
      debugPrint('[rtc] connectionState peerKey=$peerKey state=$state');
      // Recovery doctrine: `failed` is no longer a death sentence — the ICE
      // handler above escalates it through the restart budget first. Only a
      // CLOSED connection (disposed underneath us) is removed here.
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        debugPrint('[rtc] peer REMOVED (closed) peerKey=$peerKey');
        await removePeer(peerKey);
      }
    };

    _peers[peerKey] = connection;
    return connection;
  }

  Future<MediaStream?> _resolveRemoteStream(
    String peerKey,
    RTCTrackEvent event,
  ) async {
    if (event.streams.isNotEmpty) {
      return event.streams.first;
    }

    final existing = _remoteStreams[peerKey];
    // Same trap as the stage path: the label becomes the ownerTag on native,
    // and only 'local' resolves against `localStreams`. This branch is the
    // rare one — a track event normally arrives with its own stream — which
    // is exactly why it could stay wrong without anyone noticing.
    final stream = existing ?? await createLocalMediaStream(_localOwnerTag);
    if (existing == null) {
      _remoteStreams[peerKey] = stream;
    }

    await stream.addTrack(event.track);
    return stream;
  }

  Future<RTCVideoRenderer> _createRemoteRenderer() async {
    final renderer = RTCVideoRenderer();
    await renderer.initialize();
    return renderer;
  }

  Future<RTCSessionDescription> createOffer({
    required String peerKey,
    required String? targetSocketId,
    required Map<String, dynamic> configuration,
    required void Function(RTCIceCandidate candidate) onIceCandidate,
  }) async {
    final connection = await _ensurePeer(
      configuration: configuration,
      onIceCandidate: onIceCandidate,
      peerKey: peerKey,
    );

    // Perfect-negotiation: mark that we have an offer in flight so a colliding
    // inbound offer is detected in handleRemoteOffer. Cleared once our local
    // description is set (after which signalingState alone flags the collision).
    _makingOffer[peerKey] = true;
    try {
      final offer = await connection.createOffer(<String, dynamic>{
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': true,
      });
      await connection.setLocalDescription(offer);
      return offer;
    } finally {
      _makingOffer[peerKey] = false;
    }
  }

  /// Returns the answer to send, or `null` when this offer must be IGNORED
  /// (perfect-negotiation glare: we are the impolite peer and a collision
  /// occurred — we keep our own offer and send no answer).
  Future<RTCSessionDescription?> handleRemoteOffer({
    required String peerKey,
    required String? targetSocketId,
    required bool polite,
    required Map<String, dynamic> configuration,
    required Map<String, dynamic> sdp,
    required void Function(RTCIceCandidate candidate) onIceCandidate,
  }) async {
    // A stage session has no peers to negotiate with. A late socket event
    // must not build a mesh peer alongside the stage transport, which would
    // duplicate this participant's media and their tile.
    if (_stage != null) return null;

    final existing = _peers[peerKey];

    // Perfect-negotiation collision handling. A collision = an inbound offer
    // arrives while we have our own offer outstanding (making it, or signaling
    // state is not stable). The IMPOLITE peer ignores the inbound offer (keeps
    // its own); the POLITE peer rolls back its offer and accepts the inbound.
    if (existing != null) {
      final st = existing.signalingState;
      final collision = (_makingOffer[peerKey] == true) ||
          (st != null && st != RTCSignalingState.RTCSignalingStateStable);
      if (collision) {
        if (!polite) {
          debugPrint('[rtc] glare: impolite IGNORES offer peer=$peerKey');
          return null;
        }
        debugPrint('[rtc] glare: polite ROLLS BACK then accepts peer=$peerKey');
        try {
          await existing.setLocalDescription(
            RTCSessionDescription(null, 'rollback'),
          );
        } catch (error) {
          debugPrint('[rtc] rollback failed peer=$peerKey err=$error');
        }
      }
    }

    final isNewPeer = !_peers.containsKey(peerKey);
    final connection = await _ensurePeer(
      configuration: configuration,
      onIceCandidate: onIceCandidate,
      peerKey: peerKey,
      addLocalTracks: false,
    );

    await connection.setRemoteDescription(
      RTCSessionDescription(
        (sdp['sdp'] ?? '').toString(),
        (sdp['type'] ?? 'offer').toString(),
      ),
    );
    _remoteDescriptionSet.add(peerKey);
    await _flushPendingCandidates(peerKey);

    // Attach local tracks AFTER setRemoteDescription (answerer path) so they
    // bind to the offered transceivers and actually reach the offerer. Only for
    // a freshly-created peer — a renegotiation offer arrives on a peer that
    // already has its tracks.
    if (isNewPeer) {
      await _attachLocalTracks(connection, peerKey);
    }

    final answer = await connection.createAnswer(<String, dynamic>{
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': true,
    });
    await connection.setLocalDescription(answer);
    return answer;
  }

  Future<void> handleRemoteAnswer({
    required String peerKey,
    required Map<String, dynamic> sdp,
  }) async {
    // A stage session has no peers to negotiate with. A late socket event
    // must not build a mesh peer alongside the stage transport, which would
    // duplicate this participant's media and their tile.
    if (_stage != null) return;

    final connection = _peers[peerKey];
    if (connection == null) return;

    // A stale answer (e.g. from a negotiation the other side abandoned)
    // arriving while we are already stable would throw InvalidStateError and
    // desync nothing — drop it deliberately instead of via a swallowed throw.
    final st = connection.signalingState;
    if (st == RTCSignalingState.RTCSignalingStateStable) {
      debugPrint('[rtc] stale answer IGNORED (stable) peerKey=$peerKey');
      return;
    }

    await connection.setRemoteDescription(
      RTCSessionDescription(
        (sdp['sdp'] ?? '').toString(),
        (sdp['type'] ?? 'answer').toString(),
      ),
    );
    _remoteDescriptionSet.add(peerKey);
    await _flushPendingCandidates(peerKey);
  }

  Future<void> addRemoteCandidate({
    required String peerKey,
    required Map<String, dynamic> candidate,
  }) async {
    // A stage session has no peers to negotiate with. A late socket event
    // must not build a mesh peer alongside the stage transport, which would
    // duplicate this participant's media and their tile.
    if (_stage != null) return;

    final value = candidate['candidate'];
    if (value == null) return;

    final connection = _peers[peerKey];
    // Buffer until the peer exists AND its remote description is applied —
    // candidates added before either are rejected or lost by the engine.
    if (connection == null || !_remoteDescriptionSet.contains(peerKey)) {
      final buffer = _pendingRemoteCandidates.putIfAbsent(
        peerKey,
        () => <Map<String, dynamic>>[],
      );
      if (buffer.length < _maxBufferedCandidatesPerPeer) {
        buffer.add(Map<String, dynamic>.from(candidate));
      }
      return;
    }

    await _applyRemoteCandidate(connection, peerKey, candidate);
  }

  Future<void> _applyRemoteCandidate(
    RTCPeerConnection connection,
    String peerKey,
    Map<String, dynamic> candidate,
  ) async {
    final value = candidate['candidate'];
    if (value == null) return;
    try {
      await connection.addCandidate(
        RTCIceCandidate(
          value.toString(),
          candidate['sdpMid']?.toString(),
          candidate['sdpMLineIndex'] is int
              ? candidate['sdpMLineIndex'] as int
              : int.tryParse(candidate['sdpMLineIndex']?.toString() ?? ''),
        ),
      );
    } catch (error) {
      debugPrint('[rtc] addCandidate failed peerKey=$peerKey err=$error');
    }
  }

  Future<void> _flushPendingCandidates(String peerKey) async {
    final connection = _peers[peerKey];
    final buffered = _pendingRemoteCandidates.remove(peerKey);
    if (connection == null || buffered == null || buffered.isEmpty) return;
    for (final candidate in buffered) {
      await _applyRemoteCandidate(connection, peerKey, candidate);
    }
  }

  // ── ICE recovery ──────────────────────────────────────────────────────

  void _emitPeerHealth(String peerKey, RealtimePeerHealth health) {
    if (_peerHealth.isClosed) return;
    _peerHealth.add(RealtimePeerHealthEvent(peerKey: peerKey, health: health));
  }

  void _escalateIceFailure(String peerKey) {
    final attempts = _iceRestartAttempts[peerKey] ?? 0;
    if (attempts >= _maxIceRestartAttempts) {
      _emitPeerHealth(peerKey, RealtimePeerHealth.dead);
      return;
    }
    _iceRestartAttempts[peerKey] = attempts + 1;
    _emitPeerHealth(peerKey, RealtimePeerHealth.needsRestart);
  }

  /// ICE restart on an EXISTING peer: fresh credentials (via
  /// [configuration], when provided), a restart offer, and the normal
  /// perfect-negotiation path from there. The transport recovers in place —
  /// tracks, renderers, and the visible tile all survive.
  Future<RTCSessionDescription?> restartIce({
    required String peerKey,
    Map<String, dynamic>? configuration,
  }) async {
    final connection = _peers[peerKey];
    if (connection == null) return null;

    if (configuration != null) {
      try {
        await connection.setConfiguration(configuration);
      } catch (error) {
        debugPrint('[rtc] setConfiguration failed peerKey=$peerKey err=$error');
      }
    }

    _makingOffer[peerKey] = true;
    try {
      final offer = await connection.createOffer(<String, dynamic>{
        'iceRestart': true,
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': true,
      });
      await connection.setLocalDescription(offer);
      return offer;
    } catch (error) {
      debugPrint('[rtc] restartIce failed peerKey=$peerKey err=$error');
      return null;
    } finally {
      _makingOffer[peerKey] = false;
    }
  }

  /// Refresh ICE servers on every live peer (TURN credential rotation). New
  /// credentials take effect on the next ICE restart or negotiation.
  Future<void> updateIceConfiguration(Map<String, dynamic> configuration) async {
    for (final entry in _peers.entries) {
      try {
        await entry.value.setConfiguration(configuration);
      } catch (error) {
        debugPrint(
          '[rtc] updateIceConfiguration failed peerKey=${entry.key} err=$error',
        );
      }
    }
  }

  /// App-resume health check: peers whose transport died while the device
  /// slept are escalated through the same restart path as a live failure.
  Future<void> checkPeersHealth() async {
    for (final entry in Map<String, RTCPeerConnection>.from(_peers).entries) {
      final ice = entry.value.iceConnectionState;
      if (ice == RTCIceConnectionState.RTCIceConnectionStateFailed ||
          ice == RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
        _escalateIceFailure(entry.key);
      }
    }
  }

  Future<void> setMicrophoneEnabled(bool enabled) async {
    _micEnabled = enabled;
    await _setTrackEnabled(
      tracks: _localStream?.getAudioTracks() ?? const <MediaStreamTrack>[],
      enabled: enabled,
    );
    _publish();
  }

  /// Set the camera and report WHAT IS ACTUALLY IN EFFECT.
  ///
  /// This used to return void, and the caller published its own INTENT to
  /// the session. When acquisition had failed there was no video track to
  /// flip, this method quietly stayed off, and the controller still told the
  /// server `enabled: true`. Founder-observed 2026-08-28: five
  /// `VIDEO_STATE_CHANGED publishState=ON` events for a participant with
  /// zero outbound video RTP and a black self-view. A boolean saying
  /// camera=true is not evidence that a camera is capturing.
  ///
  /// It also now RE-ACQUIRES. Turning the camera off and on again could not
  /// recover a stream that was never captured — `setCameraEnabled` only ever
  /// flipped `track.enabled` on tracks that already existed (the same
  /// property `_attachLocalTracks` documents as unrecoverable). That is why
  /// the camera "could not be turned on again" and only rejoining helped.
  ///
  /// [CameraSetResult.needsRenegotiation] mirrors [startScreenShare]: a peer
  /// that never had a video sender needs the track ADDED, which the caller
  /// must follow with a re-offer.
  Future<CameraSetResult> setCameraEnabled(bool enabled) async {
    var videoTracks =
        _localStream?.getVideoTracks() ?? const <MediaStreamTrack>[];
    var needsRenegotiation = false;

    if (enabled && videoTracks.isEmpty) {
      needsRenegotiation = await _reacquireCamera();
      videoTracks =
          _localStream?.getVideoTracks() ?? const <MediaStreamTrack>[];
      if (videoTracks.isEmpty) {
        // The device is genuinely unavailable — busy in another app or
        // browser, refused, or absent. Stay off and SAY so, rather than
        // reporting a publish that cannot exist.
        _cameraEnabled = false;
        _publish();
        return const CameraSetResult(enabled: false, needsRenegotiation: false);
      }
    }

    _cameraEnabled = enabled;
    await _setTrackEnabled(tracks: videoTracks, enabled: enabled);
    _publish();
    return CameraSetResult(
      enabled: enabled,
      needsRenegotiation: needsRenegotiation,
    );
  }

  /// Try to obtain a real camera track and put it on every peer.
  ///
  /// Returns whether any peer needed the track ADDED rather than replaced,
  /// which requires the caller to re-offer. Defensive throughout: a failure
  /// leaves the call exactly as it was and is reported as "still off".
  Future<bool> _reacquireCamera() async {
    if (_disposed) return false;

    MediaStream? fresh;
    try {
      fresh = await navigator.mediaDevices.getUserMedia(<String, dynamic>{
        'audio': false,
        'video': _preferredVideoDeviceId == null
            ? <String, dynamic>{
                'width': <String, dynamic>{'ideal': 1280},
                'height': <String, dynamic>{'ideal': 720},
              }
            : <String, dynamic>{
                'deviceId': <String, dynamic>{
                  'exact': _preferredVideoDeviceId,
                },
                'width': <String, dynamic>{'ideal': 1280},
                'height': <String, dynamic>{'ideal': 720},
              },
      });
    } catch (error) {
      debugPrint('[rtc-media] camera re-acquire FAILED err=$error');
      return false;
    }

    final track =
        fresh.getVideoTracks().isNotEmpty ? fresh.getVideoTracks().first : null;
    if (track == null) {
      try {
        await fresh.dispose();
      } catch (_) {}
      return false;
    }

    final local = _localStream ?? await createLocalMediaStream(_localOwnerTag);
    _localStream = local;
    try {
      await local.addTrack(track);
    } catch (error) {
      debugPrint('[rtc-media] camera re-acquire addTrack err=$error');
    }

    // Routed rather than looped over `_peers`: on the stage that map is empty,
    // and a camera recovered after a denied or busy device would have been
    // published to nobody.
    //
    // The stage case that replacement CANNOT serve is the one this method
    // exists for: a call that published no video at all has no sender to
    // replace, and needs a publish. The transport reports that as
    // `REPLACE_NO_SENDER` rather than returning silently — see
    // `SfuRealtimeTransport._replaceSource`. Closing it properly means
    // republishing on the stage, which is [STAGE_REPUBLISH_AFTER_NO_CAPTURE]
    // in the debt ledger and is NOT closed here.
    final needsRenegotiation =
        await _replaceOutboundVideo(track, reason: 'camera-reacquire');

    debugPrint(
      '[rtc-media] camera re-acquired renegotiate=$needsRenegotiation',
    );
    return needsRenegotiation;
  }

  Future<void> _setTrackEnabled({
    required List<MediaStreamTrack> tracks,
    required bool enabled,
  }) async {
    for (final track in tracks) {
      track.enabled = enabled;
    }
  }

  /// Start broadcasting the local screen. On peers that already carry a
  /// video sender the screen track replaces it (no renegotiation). On peers
  /// WITHOUT one — every audio-only meeting — the track is ADDED, which
  /// requires renegotiation; returns true so the controller re-offers.
  /// Before this, sharing a screen in an audio meeting silently reached
  /// no one: replaceTrack found no video sender to replace.
  /// Carry an outbound media change to WHICHEVER transport is live.
  ///
  /// THE DEFECT THIS CLOSES (2026-08-28). Every outbound change below —
  /// screen share, camera flip, device selection, camera re-acquisition —
  /// was written in the mesh era and iterated `_peers` directly. Under the
  /// stage that map is EMPTY, so each of them updated the local preview,
  /// returned success, and reached nobody. Nothing threw and nothing logged,
  /// because an empty loop is a successful loop.
  ///
  /// `RealtimeTransport.replaceVideoSource` had existed and been implemented
  /// correctly the whole time. It had no callers. Routing every outbound
  /// change through one method is what stops the next capability from
  /// rediscovering this the same way.
  ///
  /// Returns whether a mesh peer needed the track ADDED rather than replaced,
  /// which is the caller's signal to re-offer. The stage never needs that:
  /// replacement is in place and subscribers keep receiving.
  Future<bool> _replaceOutboundVideo(
    MediaStreamTrack? track, {
    required String reason,
  }) async {
    final stage = _stage;
    if (stage != null) {
      await stage.replaceVideoSource(track);
      return false;
    }

    var needsRenegotiation = false;
    for (final entry in _peers.entries) {
      try {
        final senders = await entry.value.getSenders();
        var replaced = false;
        for (final sender in senders) {
          if (sender.track?.kind != 'video') continue;
          await sender.replaceTrack(track);
          replaced = true;
        }
        if (!replaced && track != null) {
          // SAME TRAP AS THE REMOTE PATH: the label becomes the native
          // `ownerTag`, and only `local` resolves against the platform's
          // `localStreams` registry. A stream tagged with a descriptive name
          // is a stream the native side cannot find — the exact defect that
          // made Android draw nothing for remote video (2026-08-28).
          final sendStream =
              _localStream ?? await createLocalMediaStream(_localOwnerTag);
          await entry.value.addTrack(track, sendStream);
          needsRenegotiation = true;
        }
      } catch (error) {
        debugPrint(
          '[rtc] outbound video replace failed reason=$reason '
          'peerKey=${entry.key} err=$error',
        );
      }
    }
    return needsRenegotiation;
  }

  /// Microphone selection. Same contract as [_replaceOutboundVideo].
  Future<void> _replaceOutboundAudio(
    MediaStreamTrack? track, {
    required String reason,
  }) async {
    final stage = _stage;
    if (stage != null) {
      await stage.replaceAudioSource(track);
      return;
    }
    for (final peer in _peers.values) {
      try {
        final senders = await peer.getSenders();
        for (final sender in senders) {
          if (sender.track?.kind != 'audio') continue;
          await sender.replaceTrack(track);
        }
      } catch (error) {
        debugPrint('[rtc] outbound audio replace failed reason=$reason '
            'err=$error');
      }
    }
  }

  Future<bool> startScreenShare() async {
    if (_disposed || _isScreenSharing) return false;

    final stream = await navigator.mediaDevices.getDisplayMedia(<String, dynamic>{
      'video': <String, dynamic>{'cursor': 'always'},
      'audio': false,
    });

    _screenStream = stream;
    var needsRenegotiation = false;

    final screenTracks = stream.getVideoTracks();
    if (screenTracks.isNotEmpty) {
      final screenTrack = screenTracks.first;
      needsRenegotiation =
          await _replaceOutboundVideo(screenTrack, reason: 'screen-share');
      try {
        await _applyDegradationPreference(screenTrack, 'maintain-resolution');
      } catch (_) {}
    }

    _isScreenSharing = true;
    _publish();
    return needsRenegotiation;
  }

  Future<void> stopScreenShare() async {
    if (_disposed || !_isScreenSharing) return;

    _isScreenSharing = false;

    final cameraTracks = _localStream?.getVideoTracks();
    final cameraTrack = (cameraTracks != null && cameraTracks.isNotEmpty)
        ? cameraTracks.first
        : null;
    // Audio-only meetings have no camera track to restore — a null clears the
    // sender rather than leaving a frozen frame of someone's desktop on the
    // wire.
    await _replaceOutboundVideo(cameraTrack, reason: 'screen-share-stop');

    await _disposeStream(_screenStream);
    _screenStream = null;
    _publish();
  }

  // ── STAGE (SFU) TRANSPORT ────────────────────────────────────────────
  //
  // Attached only when the SERVER selected it. While no stage is attached the
  // mesh paths below are untouched, which is why this migration cannot change
  // the behaviour of a released call until the topology owner says so.

  /// Whether this session's media moves through the stage transport.
  bool get usesStageTransport => _stage != null;

  /// Bytes of media this device has actually RECEIVED and decoded, or null
  /// when there is no transport to ask.
  ///
  /// Local truth, available without the server's opinion. It exists so a client
  /// can tell "the call has not connected" apart from "the call connected and
  /// the report went missing" — which look identical from the phase alone, and
  /// which need opposite answers.
  Future<int?> inboundMediaBytes() async {
    final stage = _stage;
    if (stage == null) return null;
    try {
      final stats = await stage.stats();
      return stats.inboundBytes;
    } catch (_) {
      // Unknown is not zero. A stats read that failed must not be reported as
      // "nothing is arriving".
      return null;
    }
  }

  /// Is THIS transport still the live one?
  ///
  /// `usesStageTransport` answers presence, not health, and a DEAD transport
  /// is still non-null. Recovery used that to decide whether its work had
  /// already been done by someone else, so it declared itself moot every time
  /// -- including when the transport it was called about was the dead one
  /// still sitting in this field. Detection worked and recovery never ran.
  /// Measured 2026-08-28: `media_stalled_18s` followed three seconds later by
  /// `stage_recovery_moot`, and the call died.
  ///
  /// Identity is the question actually being asked.
  bool ownsStage(Object transport) => identical(_stage, transport);

  /// Which transport is carrying media, for observability (§2).
  String get transportId => _stage?.id ?? 'mesh';

  /// Bring the stage up for this session and publish the local capture.
  ///
  /// Local media must already be acquired: the provider needs at least one
  /// track to establish a peer connection at all.
  Future<void> attachStage(
    RealtimeTransport transport, {
    required String sessionId,
    String trigger = 'UNKNOWN',
  }) async {
    if (_disposed) return;
    // A null local stream is allowed. Capture may have been denied or the
    // devices may be busy; mesh still lets that participant see and hear the
    // room, and refusing here would make a permission denial the difference
    // between a degraded call and no call.
    final local = _localStream;
    _stage = transport;
    try {
      await transport.open(
          sessionId: sessionId, local: local, trigger: trigger);
      await transport.publishLocal(trigger: trigger);
    } catch (e) {
      // A HALF-ATTACHED STAGE IS WORSE THAN NONE.
      //
      // Measured on a live call: open() succeeded and publishLocal() failed,
      // which left a transport row on the server with nothing published — and
      // because a second open is refused with stage:transport_exists, every
      // later retry failed too. The call was then permanently stuck with a
      // transport that carried no media.
      //
      // Unwinding makes the failure recoverable: the next attempt starts from
      // no transport instead of an unusable one.
      await detachStage();
      rethrow;
    }
    await ensureStageRemoteMedia(trigger: trigger);
  }

  /// Resolve remote media, retrying until it appears.
  ///
  /// THE DEFECT THIS FIXES, found on the real product path (2026-08-26): the
  /// party that ACCEPTS a call normally attaches before the caller has
  /// finished publishing. Resolving once at attach found nothing, and nothing
  /// made it look again — so in both directions the receiver sat in a
  /// connected call with no remote media at all. Mesh never showed this
  /// because offer/answer re-drove discovery on every change.
  ///
  /// Subscribing is incremental, so re-checking is cheap and cannot duplicate
  /// receivers. It stops as soon as media is bound and gives up rather than
  /// looping forever — a call where nobody else is publishing yet is a
  /// legitimate answer, not a failure.
  Future<void> ensureStageRemoteMedia({
    int attempts = 6,
    Duration interval = const Duration(seconds: 2),
    String trigger = 'UNKNOWN',
  }) async {
    Object? lastError;
    for (var attempt = 0; attempt < attempts; attempt++) {
      if (_disposed || _stage == null) return;
      try {
        await refreshStageRemoteMedia(trigger: trigger);
        if (_remoteByParticipant.isNotEmpty) return;
      } catch (e) {
        // A FAILED ATTEMPT MUST NOT END CONVERGENCE.
        //
        // Measured against production: subscribing races the publisher.
        // Aura records a track the moment its publisher reports it, but the
        // provider cannot forward that track until the publisher's transport
        // is actually carrying media — and asking too early is refused
        // (`cloudflare_empty_track_error`). It is intermittent: the same code
        // failed one run and passed the next.
        //
        // Without this catch a single early refusal propagated out of the
        // loop, so the receiver never tried again and sat in a connected call
        // with no remote media. Retrying is exactly the right response to
        // "not ready yet", and the attempt budget still bounds it.
        lastError = e;
        debugPrint('[rtc] stage remote media attempt ${attempt + 1} failed: $e');
      }
      if (attempt < attempts - 1) await Future<void>.delayed(interval);
    }
    if (_remoteByParticipant.isEmpty && lastError != null) {
      // Every attempt failed. Surface it rather than returning quietly — an
      // empty room and an unreachable one must not look the same.
      throw StateError('stage remote media never resolved: $lastError');
    }
  }

  /// Resolve everyone else's media and publish it into the snapshot.
  ///
  /// Called when the roster changes. Binding is deterministic — the server
  /// says which m-line carries whose track — so there is no callback to wait
  /// for and no blank tile over flowing media.
  Future<void> refreshStageRemoteMedia({String trigger = 'UNKNOWN'}) async {
    final transport = _stage;
    if (transport == null || _disposed) return;
    final next = await transport.refreshRemoteMedia(trigger: trigger);

    // PUBLISH ONLY ON CHANGE — this closes a feedback loop I created.
    //
    // Measured from the operation trace: nineteen SUBSCRIBE operations in five
    // seconds, every one succeeding, every one triggered by MEDIA_READY. The
    // cause was this method publishing unconditionally: a snapshot makes the
    // controller re-run its media-ready reconciliation, which calls back in
    // here, which publishes again. Roughly three network round-trips a second,
    // for as long as the call lasted.
    //
    // It starved the UI — which is why a retry control stopped responding and
    // an error state followed the person into other surfaces — while every
    // individual operation reported success, so nothing looked broken from the
    // inside.
    if (_sameRemoteMedia(_remoteByParticipant, next)) return;
    _remoteByParticipant = next;
    await _syncParticipantRenderers(next);
    _publish();
  }

  /// Build or retire a renderer per participant.
  ///
  /// A participant who stops publishing video loses their renderer; one who
  /// leaves entirely loses renderer and stream. Nothing is keyed by device, so
  /// reconnecting does not manufacture a second tile.
  /// `muted` IS A STREAM, NOT A SNAPSHOT.
  ///
  /// THE DEFECT THIS CLOSES (2026-08-28, three-party meeting). Both call
  /// surfaces decide whether to draw a tile with
  ///
  ///     return tracks.first.muted != true;
  ///
  /// read ONCE, at build time. A remote track arrives `muted = true` and flips
  /// to `false` only when frames actually begin to flow. Nothing listened for
  /// that transition, so a tile built inside the window rendered "camera off"
  /// and STAYED there until an unrelated rebuild happened along.
  ///
  /// It is per-viewer by construction, which is why the same call looked like a
  /// different bug to each participant, and why it survived so long: the server
  /// sees a healthy published track, the client reports `bind_complete` and a
  /// live attached renderer, and the person still sees an avatar. Every arrow
  /// in the chain is green.
  ///
  /// Several browser contexts on ONE machine sharing a single camera lengthen
  /// the muted window and turn an occasional race into the usual outcome.
  ///
  /// Republishing the snapshot is enough: the tiles derive liveness from the
  /// renderer they already hold, so they only need an excuse to look again.
  void _watchRemoteVideoLiveness(MediaStreamTrack video) {
    try {
      video.onUnMute = () {
        if (_disposed) return;
        _publish();
      };
      video.onMute = () {
        if (_disposed) return;
        _publish();
      };
      video.onEnded = () {
        if (_disposed) return;
        _publish();
      };
    } catch (_) {
      // A platform without these callbacks must not lose its picture over
      // them. The tile still renders; it just will not re-evaluate early.
    }
  }

  Future<void> _syncParticipantRenderers(
    Map<String, RemoteParticipantMedia> media,
  ) async {
    var created = 0;
    var attached = 0;
    var retired = 0;
    var rebuilt = 0;
    var failures = 0;
    String? firstError;
    final withVideo = media.values.where((m) => m.hasVideo).length;

    // Retire anyone no longer present.
    for (final id in _remoteRenderersByParticipant.keys.toList()) {
      if (media.containsKey(id) && media[id]!.hasVideo) continue;
      final renderer = _remoteRenderersByParticipant.remove(id);
      renderer?.srcObject = null;
      await renderer?.dispose();
      final stream = _remoteStreamsByParticipant.remove(id);
      await stream?.dispose();
      retired += 1;
    }

    for (final entry in media.entries) {
      final video = entry.value.video;
      if (video == null) continue;

      // A RENDERER MUST FOLLOW THE TRACK, NOT JUST THE PERSON.
      //
      // This used to skip any participant who already had a renderer, so when
      // somebody republished — camera off and on, a re-acquisition, a
      // reconnect — their tile kept the OLD track. The provider had replaced
      // it, the old one had stopped, and the tile went on rendering a corpse.
      //
      // Founder-observed 2026-08-28 in a three-party call: a participant
      // duplicated, one person's video vanished, and finally the wrong
      // person's media appeared under another name. The diagnostic said it
      // plainly — `RENDER_NONE created=0 held=2` arriving immediately after a
      // republish: the media service saw new tracks and built nothing.
      //
      // So identity decides WHICH renderer, and track identity decides
      // whether that renderer still holds the right thing.
      final existingRenderer = _remoteRenderersByParticipant[entry.key];
      if (existingRenderer != null) {
        final held = _remoteStreamsByParticipant[entry.key];
        final heldVideo = held?.getVideoTracks() ?? const <MediaStreamTrack>[];
        final heldAudio = held?.getAudioTracks() ?? const <MediaStreamTrack>[];
        final sameVideo = heldVideo.isNotEmpty && heldVideo.first.id == video.id;
        final incomingAudio = entry.value.audio;
        final sameAudio = incomingAudio == null
            ? heldAudio.isEmpty
            : heldAudio.isNotEmpty && heldAudio.first.id == incomingAudio.id;
        if (sameVideo && sameAudio) continue;

        // Something genuinely changed. Retire the stale renderer so the
        // rebuild below attaches the live tracks — and so the dead m-line
        // stops being a candidate for anything.
        _remoteRenderersByParticipant.remove(entry.key);
        existingRenderer.srcObject = null;
        await existingRenderer.dispose();
        final staleStream = _remoteStreamsByParticipant.remove(entry.key);
        await staleStream?.dispose();
        rebuilt += 1;
      }

      try {
        // THE LABEL IS THE OWNER TAG ON NATIVE. It is not a name.
        //
        // `createLocalMediaStream(label)` returns `MediaStreamNative(streamId,
        // label)`, and the second positional is `ownerTag` — so a descriptive
        // label becomes the tag. Android then resolves the renderer's source
        // with:
        //
        //     if (ownerTag.equals("local")) localStreams.get(streamId)
        //     else                          getStreamForId(streamId, ownerTag)
        //
        // and `getStreamForId` searches peer connections by id. A tag of
        // `remote-cmt…` matches no peer connection, so the renderer resolved a
        // NULL stream and drew nothing — while every call returned success.
        // The stream really is in `localStreams`; it was created there.
        //
        // Web ignores the label entirely and always tags 'local', which is why
        // the browser rendered and the phone did not. Founder-observed
        // 2026-08-28: "pixel still having no remote video".
        //
        // The identity of WHOSE media this is lives in the map key, where it
        // belongs, not in a string the platform reinterprets.
        final stream = await createLocalMediaStream(_localOwnerTag);
        await stream.addTrack(video);
        final audio = entry.value.audio;
        if (audio != null) await stream.addTrack(audio);
        final renderer = await _createRemoteRenderer();
        renderer.srcObject = stream;
        // THIS RENDERER SHOWS SOMEBODY ELSE, SO IT MUST BE AUDIBLE.
        //
        // flutter_webrtc's web renderer mutes its audio element when the
        // stream's `ownerTag == 'local'`, which is right: a local stream is
        // your own microphone and playing it back is echo. But the stage
        // transport hands over bare tracks, not a stream, so this composes one
        // with `createLocalMediaStream` — and on web that constructor stamps
        // `ownerTag = 'local'` regardless of whose media it carries
        // (dart_webrtc `factory_impl.dart`: `MediaStreamWeb(jsMs, 'local')`).
        //
        // So every SFU participant's audio arrived on a muted element. Native
        // clients route remote audio through the device and never saw it,
        // which is exactly the shape of the founder's "audio one way only"
        // (2026-08-28): the phone heard the browser, the browser heard
        // nothing. The mesh path was unaffected because its streams come from
        // `onTrack` already tagged remote.
        //
        // Stated here rather than fixed at the constructor: the stream really
        // is locally constructed, and the thing that is actually true is that
        // this renderer is not the local one.
        //
        // WEB ONLY, AND NEVER FATAL. Native routes remote audio to the device
        // and has never needed this; it also refuses the call outright when
        // the stream is not locally tagged. The first version of this fix was
        // unguarded, and on Android it threw before the renderer was
        // registered — costing the tile it was meant to give sound to. A
        // diagnostic nicety must not be able to do that, so it is scoped to
        // the platform with the defect and wrapped besides.
        if (kIsWeb) {
          try {
            renderer.muted = false;
          } catch (_) {
            // Audio routing is a platform concern; a refusal here is not a
            // reason to lose the picture.
          }
        }
        _remoteStreamsByParticipant[entry.key] = stream;
        _remoteRenderersByParticipant[entry.key] = renderer;
        _watchRemoteVideoLiveness(video);
        created += 1;
        // WHAT THE RENDERER ACTUALLY RECEIVED, not what we handed it.
        //
        // `addTrack` on a locally-created stream is a platform call on
        // native and a plain JS call on web, and the two do not fail the same
        // way. Reading the stream back distinguishes "the track is on the
        // stream the renderer is showing" from "the call returned without
        // complaining" — which is the difference between a picture and a
        // black tile, and is invisible from the server.
        attached += stream.getVideoTracks().length;
      } catch (e) {
        failures += 1;
        firstError ??= e.toString();
        debugPrint('[rtc] participant renderer failed for ${entry.key}: $e');
      }
    }

    // Bounded, counts only — no identifiers, no media, no SDP.
    unawaited(_stage?.report(
      phase: 'render',
      code: failures > 0
          ? 'render_failed'
          : created == 0
              ? 'render_none'
              : attached < created
                  ? 'render_empty_stream'
                  : 'render_attached',
      message: 'participants=${media.length} withVideo=$withVideo '
          'created=$created attachedVideoTracks=$attached '
          'retired=$retired rebuilt=$rebuilt '
          'held=${_remoteRenderersByParticipant.length} '
          'failures=$failures'
          '${firstError == null ? '' : ' err=${_shortRenderError(firstError)}'}',
    ));
  }

  /// Compact error label for a render report — never a full platform trace.
  static String _shortRenderError(String raw) {
    final text = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text.length > 80 ? '${text.substring(0, 80)}...' : text;
  }

  /// Whether two remote-media maps say the same thing.
  ///
  /// Compares participants and the identity of their tracks — a new object
  /// carrying the same tracks is not a change, and treating it as one is
  /// exactly what made the loop self-sustaining.
  bool _sameRemoteMedia(
    Map<String, RemoteParticipantMedia> a,
    Map<String, RemoteParticipantMedia> b,
  ) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      final other = b[entry.key];
      if (other == null) return false;
      if (entry.value.audio?.id != other.audio?.id) return false;
      if (entry.value.video?.id != other.video?.id) return false;
    }
    return true;
  }

  Future<void> detachStage() async {
    final transport = _stage;
    _stage = null;
    _remoteByParticipant = const <String, RemoteParticipantMedia>{};
    for (final r in _remoteRenderersByParticipant.values) {
      r.srcObject = null;
      await r.dispose();
    }
    _remoteRenderersByParticipant.clear();
    for (final st in _remoteStreamsByParticipant.values) {
      await st.dispose();
    }
    _remoteStreamsByParticipant.clear();
    if (transport == null) return;
    // Must never throw on a leave.
    try {
      await transport.close();
    } catch (e) {
      debugPrint('[rtc] stage detach failed: $e');
    }
  }

  // Camera switching, mute and camera toggling are deliberately NOT
  // transport-specific. `Helper.switchCamera` swaps the source on the SAME
  // track and `enabled` gates the same track, so the sender keeps its
  // publication either way — which is what makes a camera switch a track
  // replacement rather than a renegotiation under both transports.

  Future<void> switchCamera() async {
    if (_disposed) return;
    final tracks = _localStream?.getVideoTracks();
    if (tracks == null || tracks.isEmpty) return;
    await Helper.switchCamera(tracks.first);
  }

  // ── Media quality: evidence + adaptation ──────────────────────────────
  //
  // Quality is measured (getStats every sampling tick), reported (the
  // controller attaches the sample to the session heartbeat), and acted on
  // (a deterministic bitrate ladder caps video senders before the network
  // fails them). No lab telemetry — a small, predictable control loop.

  final Map<String, int> _prevBytesSent = <String, int>{};
  final Map<String, int> _prevBytesSentAtMs = <String, int>{};
  int? _videoBitrateCapKbps;
  int _baseVideoBitrateCapKbps = 1200;
  int _consecutiveLossy = 0;
  int _consecutiveClean = 0;
  static const int _minVideoBitrateCapKbps = 250;

  /// Participant-count scaling: a P2P mesh uploads one stream per peer, so
  /// the per-peer cap must shrink as the room grows.
  Future<void> applyParticipantScaling(int participantCount) async {
    _baseVideoBitrateCapKbps = participantCount <= 2 ? 1200 : 600;
    final cap = _videoBitrateCapKbps;
    if (cap == null || cap > _baseVideoBitrateCapKbps) {
      await _applyVideoBitrateCap(_baseVideoBitrateCapKbps);
    }
  }

  Future<void> _applyVideoBitrateCap(int kbps) async {
    _videoBitrateCapKbps = kbps;
    for (final entry in _peers.entries) {
      try {
        final senders = await entry.value.getSenders();
        for (final sender in senders) {
          if (sender.track?.kind != 'video') continue;
          final params = sender.parameters;
          final encodings = params.encodings;
          if (encodings == null || encodings.isEmpty) continue;
          for (final encoding in encodings) {
            encoding.maxBitrate = kbps * 1000;
          }
          await sender.setParameters(params);
        }
      } catch (error) {
        debugPrint(
          '[rtc] bitrate cap failed peerKey=${entry.key} err=$error',
        );
      }
    }
  }

  Future<void> _applyDegradationPreference(
    MediaStreamTrack track,
    String preference,
  ) async {
    for (final peer in _peers.values) {
      try {
        final senders = await peer.getSenders();
        for (final sender in senders) {
          if (sender.track?.id != track.id) continue;
          final params = sender.parameters;
          params.degradationPreference = preference == 'maintain-resolution'
              ? RTCDegradationPreference.MAINTAIN_RESOLUTION
              : RTCDegradationPreference.MAINTAIN_FRAMERATE;
          await sender.setParameters(params);
        }
      } catch (_) {
        // Not supported on every platform build — the cap ladder still runs.
      }
    }
  }

  /// Aggregate one quality sample across all peers and feed the adaptation
  /// ladder. Defensive throughout: stats shapes differ across platforms.
  Future<RealtimeQualitySample> collectQualitySample() async {
    double? worstLossPct;
    int? worstRttMs;
    int? worstJitterMs;
    var totalBitrateKbps = 0;
    var sawBitrate = false;

    String? candidateType;
    String? transportProtocol;
    String? networkType;

    for (final entry in Map<String, RTCPeerConnection>.from(_peers).entries) {
      List<StatsReport> reports;
      try {
        reports = await entry.value.getStats();
      } catch (_) {
        continue;
      }

      // THE SELECTED PAIR, resolved by id rather than guessed. `getStats`
      // returns a flat list, so the path is transport -> candidate-pair ->
      // local-candidate.
      final byId = <String, Map<String, dynamic>>{
        for (final r in reports)
          r.id: Map<String, dynamic>.from(r.values),
      };
      final path = _resolveSelectedPath(reports, byId);
      if (path != null) {
        // Mesh has one pair per peer. Rank so "did ANY leg need a relay"
        // survives aggregation — a single relayed leg is the answer that
        // matters, and averaging it away would hide it.
        if (_candidateRank(path.candidateType) >
            _candidateRank(candidateType)) {
          candidateType = path.candidateType;
          transportProtocol = path.protocol;
        }
        networkType ??= path.networkType;
      }

      for (final report in reports) {
        final type = report.type;
        final values = report.values;
        if (type == 'remote-inbound-rtp') {
          final rtt = _statDouble(values['roundTripTime']);
          if (rtt != null) {
            final ms = (rtt * 1000).round();
            if (worstRttMs == null || ms > worstRttMs) worstRttMs = ms;
          }
          final jitter = _statDouble(values['jitter']);
          if (jitter != null) {
            final ms = (jitter * 1000).round();
            if (worstJitterMs == null || ms > worstJitterMs) worstJitterMs = ms;
          }
          final lost = _statDouble(values['packetsLost']);
          final fraction = _statDouble(values['fractionLost']);
          if (fraction != null) {
            final pct = fraction * 100;
            if (worstLossPct == null || pct > worstLossPct) worstLossPct = pct;
          } else if (lost != null && lost > 0) {
            // Cumulative only — keep as weak signal when fractionLost absent.
            worstLossPct ??= 0;
          }
        }
        if (type == 'outbound-rtp') {
          final bytes = _statDouble(values['bytesSent'])?.round();
          final statId = '${entry.key}:${report.id}';
          if (bytes != null) {
            final nowMs = DateTime.now().millisecondsSinceEpoch;
            final prevBytes = _prevBytesSent[statId];
            final prevAt = _prevBytesSentAtMs[statId];
            if (prevBytes != null && prevAt != null && nowMs > prevAt) {
              final kbps =
                  (((bytes - prevBytes) * 8) / (nowMs - prevAt)).round();
              if (kbps >= 0) {
                totalBitrateKbps += kbps;
                sawBitrate = true;
              }
            }
            _prevBytesSent[statId] = bytes;
            _prevBytesSentAtMs[statId] = nowMs;
          }
        }
      }
    }

    final sample = RealtimeQualitySample(
      rttMs: worstRttMs,
      jitterMs: worstJitterMs,
      packetLossPct: worstLossPct == null
          ? null
          : (worstLossPct * 100).round() / 100,
      bitrateKbps: sawBitrate ? totalBitrateKbps : null,
      selectedCandidateType: candidateType,
      transportProtocol: transportProtocol,
      networkType: networkType,
    );

    await _adaptToSample(sample);
    return sample;
  }

  /// Rank so a relayed leg beats a direct one during aggregation.
  int _candidateRank(String? type) => switch (type) {
        'RELAY' => 4,
        'SRFLX' => 3,
        'PRFLX' => 2,
        'HOST' => 1,
        _ => 0,
      };

  /// Resolve the ACTIVE candidate pair for one peer connection.
  ///
  /// Prefers the transport's own `selectedCandidatePairId`; falls back to a
  /// nominated/succeeded pair, because not every platform publishes the
  /// transport report. Returns null rather than a default when nothing
  /// resolves — an unknown path must stay unknown.
  _SelectedPath? _resolveSelectedPath(
    List<StatsReport> reports,
    Map<String, Map<String, dynamic>> byId,
  ) {
    Map<String, dynamic>? pair;
    for (final r in reports) {
      if (r.type == 'transport') {
        final id = r.values['selectedCandidatePairId']?.toString();
        if (id != null && byId.containsKey(id)) {
          pair = byId[id];
          break;
        }
      }
    }
    if (pair == null) {
      for (final r in reports) {
        if (r.type != 'candidate-pair') continue;
        final v = Map<String, dynamic>.from(r.values);
        final nominated = v['nominated'] == true;
        final succeeded =
            v['state']?.toString().toLowerCase() == 'succeeded';
        if (nominated || succeeded) {
          pair = Map<String, dynamic>.from(v as Map);
          if (nominated) break;
        }
      }
    }
    if (pair == null) return null;

    final localId = pair['localCandidateId']?.toString();
    final local = localId == null ? null : byId[localId];
    if (local == null) return null;

    final type = local['candidateType']?.toString().toUpperCase();
    // For a relayed candidate the meaningful protocol is the leg to the TURN
    // server, which is what answers whether 443 was used.
    final proto = (type == 'RELAY'
            ? (local['relayProtocol'] ?? local['protocol'])
            : local['protocol'])
        ?.toString()
        .toUpperCase();
    final net = local['networkType']?.toString().toUpperCase();

    return _SelectedPath(
      candidateType: _knownCandidateType(type),
      protocol: _knownProtocol(proto),
      networkType: _knownNetworkType(net),
    );
  }

  // Only values the session schema actually defines survive. Anything else
  // is dropped rather than passed through as an invented enum member.
  String? _knownCandidateType(String? v) =>
      const {'HOST', 'SRFLX', 'PRFLX', 'RELAY'}.contains(v) ? v : null;
  String? _knownProtocol(String? v) =>
      const {'UDP', 'TCP', 'TLS'}.contains(v) ? v : null;
  String? _knownNetworkType(String? v) =>
      const {'WIFI', 'ETHERNET', 'CELLULAR', 'VPN'}.contains(v) ? v : null;

  Future<void> _adaptToSample(RealtimeQualitySample sample) async {
    final loss = sample.packetLossPct;
    if (loss == null) return;
    if (loss > 8) {
      _consecutiveClean = 0;
      _consecutiveLossy += 1;
      if (_consecutiveLossy >= 2) {
        _consecutiveLossy = 0;
        final current = _videoBitrateCapKbps ?? _baseVideoBitrateCapKbps;
        final next = (current ~/ 2).clamp(
          _minVideoBitrateCapKbps,
          _baseVideoBitrateCapKbps,
        );
        if (next < current) {
          debugPrint('[rtc] quality step-down cap=${next}kbps loss=$loss%');
          await _applyVideoBitrateCap(next);
        }
      }
    } else if (loss < 2) {
      _consecutiveLossy = 0;
      _consecutiveClean += 1;
      if (_consecutiveClean >= 6) {
        _consecutiveClean = 0;
        final current = _videoBitrateCapKbps ?? _baseVideoBitrateCapKbps;
        final next = ((current * 3) ~/ 2).clamp(
          _minVideoBitrateCapKbps,
          _baseVideoBitrateCapKbps,
        );
        if (next > current) {
          debugPrint('[rtc] quality step-up cap=${next}kbps');
          await _applyVideoBitrateCap(next);
        }
      }
    } else {
      _consecutiveLossy = 0;
      _consecutiveClean = 0;
    }
  }

  double? _statDouble(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  // ── Device selection (Phase 1 · Priority 2) ──────────────────────────────
  // Additive: preferred devices are honoured by the acquisition constraints
  // above, and switched live via replaceTrack on the EXISTING senders (no new
  // offer/answer — replaceTrack does not renegotiate). The join/signalling path
  // is untouched.

  String? get preferredVideoDeviceId => _preferredVideoDeviceId;
  String? get preferredAudioDeviceId => _preferredAudioDeviceId;
  String? get preferredAudioOutputDeviceId => _preferredAudioOutputDeviceId;
  bool get speakerphoneEnabled => _speakerphoneEnabled;

  Future<List<MediaDeviceInfo>> enumerateDevices() async {
    try {
      return await navigator.mediaDevices.enumerateDevices();
    } catch (_) {
      return const <MediaDeviceInfo>[];
    }
  }

  /// Records the preferred devices WITHOUT re-acquiring. The next acquisition
  /// (e.g. when the room joins) picks them up. Used by pre-join so the room's
  /// own getUserMedia opens the chosen camera/mic.
  void setPreferredDevices({
    String? videoDeviceId,
    String? audioDeviceId,
    String? audioOutputDeviceId,
  }) {
    if (videoDeviceId != null) {
      _preferredVideoDeviceId = videoDeviceId.isEmpty ? null : videoDeviceId;
    }
    if (audioDeviceId != null) {
      _preferredAudioDeviceId = audioDeviceId.isEmpty ? null : audioDeviceId;
    }
    if (audioOutputDeviceId != null) {
      _preferredAudioOutputDeviceId =
          audioOutputDeviceId.isEmpty ? null : audioOutputDeviceId;
    }
  }

  /// Live-switch the camera. Acquires the chosen device, swaps it onto every
  /// peer sender via replaceTrack (no renegotiation), and refreshes the local
  /// stream/renderer. Defensive: a failure leaves the current track in place.
  Future<void> switchVideoInput(String deviceId) async {
    if (_disposed || deviceId.isEmpty) return;
    _preferredVideoDeviceId = deviceId;
    final local = _localStream;
    if (local == null) return;
    final wasEnabled = _cameraEnabled;

    MediaStream? fresh;
    try {
      fresh = await navigator.mediaDevices.getUserMedia(<String, dynamic>{
        'audio': false,
        'video': <String, dynamic>{
          'deviceId': <String, dynamic>{'exact': deviceId},
          'width': <String, dynamic>{'ideal': 1280},
          'height': <String, dynamic>{'ideal': 720},
        },
      });
    } catch (error) {
      debugPrint('[rtc-media] switchVideoInput failed err=$error');
      return;
    }
    final newTrack =
        fresh.getVideoTracks().isNotEmpty ? fresh.getVideoTracks().first : null;
    if (newTrack == null) {
      await fresh.dispose();
      return;
    }
    newTrack.enabled = wasEnabled;

    await _replaceOutboundVideo(newTrack, reason: 'video-input');

    for (final old in local.getVideoTracks()) {
      try {
        await local.removeTrack(old);
        await old.stop();
      } catch (_) {}
    }
    try {
      await local.addTrack(newTrack);
      await fresh.removeTrack(newTrack);
    } catch (_) {}
    _localRenderer?.srcObject = local;
    _cameraEnabled = wasEnabled;
    _publish();
  }

  /// Live-switch the microphone (replaceTrack on audio senders).
  Future<void> switchAudioInput(String deviceId) async {
    if (_disposed || deviceId.isEmpty) return;
    _preferredAudioDeviceId = deviceId;
    final local = _localStream;
    if (local == null) return;
    final wasEnabled = _micEnabled;

    MediaStream? fresh;
    try {
      fresh = await navigator.mediaDevices.getUserMedia(<String, dynamic>{
        'audio': <String, dynamic>{
          'deviceId': <String, dynamic>{'exact': deviceId},
        },
        'video': false,
      });
    } catch (error) {
      debugPrint('[rtc-media] switchAudioInput failed err=$error');
      return;
    }
    final newTrack =
        fresh.getAudioTracks().isNotEmpty ? fresh.getAudioTracks().first : null;
    if (newTrack == null) {
      await fresh.dispose();
      return;
    }
    newTrack.enabled = wasEnabled;

    await _replaceOutboundAudio(newTrack, reason: 'audio-input');

    for (final old in local.getAudioTracks()) {
      try {
        await local.removeTrack(old);
        await old.stop();
      } catch (_) {}
    }
    try {
      await local.addTrack(newTrack);
      await fresh.removeTrack(newTrack);
    } catch (_) {}
    _micEnabled = wasEnabled;
    _publish();
  }

  /// Route audio output (speaker/headset) — applies to every renderer so the
  /// remote audio plays out of the chosen device.
  Future<void> setAudioOutput(String deviceId) async {
    if (_disposed || deviceId.isEmpty) return;
    _preferredAudioOutputDeviceId = deviceId;
    try {
      await _localRenderer?.audioOutput(deviceId);
      for (final renderer in _remoteRenderers.values) {
        await renderer.audioOutput(deviceId);
      }
    } catch (error) {
      debugPrint('[rtc-media] setAudioOutput failed err=$error');
    }
  }

  /// Thread/DM call speaker toggle (2026-08-14 repair) — binary
  /// speaker/earpiece routing for iOS/Android, via `flutter_webrtc`'s
  /// native speakerphone API (a real routing change, not a volume/gain
  /// hack). Deliberately resolved fresh per call: never persisted beyond
  /// the current session, and reset whenever session media is reset. Web
  /// has no speakerphone concept — it routes via `setAudioOutput`'s device
  /// selection instead, so this is a no-op there.
  Future<void> setSpeakerphoneEnabled(bool enabled) async {
    if (_disposed || kIsWeb) return;
    try {
      await Helper.setSpeakerphoneOn(enabled);
      _speakerphoneEnabled = enabled;
      _publish();
    } catch (error) {
      debugPrint('[rtc-media] setSpeakerphoneEnabled failed err=$error');
    }
  }

  Future<void> removePeer(String peerKey) async {
    _iceGraceTimers.remove(peerKey)?.cancel();
    _iceRestartAttempts.remove(peerKey);
    _pendingRemoteCandidates.remove(peerKey);
    _remoteDescriptionSet.remove(peerKey);
    _makingOffer.remove(peerKey);
    await _disposePeerConnection(_peers.remove(peerKey));
    await _disposeRenderer(_remoteRenderers.remove(peerKey));
    await _disposeStream(_remoteStreams.remove(peerKey));
    _publish();
  }

  Future<void> disposeAllPeers() async {
    final keys = _peers.keys.toList(growable: false);
    for (final key in keys) {
      await removePeer(key);
    }
  }

  Future<void> resetSessionMedia() async {
    // Stage teardown rides the SAME reset the product already calls on leave,
    // so cleanup semantics are unchanged: one place ends a session's media,
    // whichever transport carried it.
    await detachStage();
    await disposeAllPeers();
    await _resetLocalMediaOnly();
    if (_screenStream != null) {
      await _disposeStream(_screenStream);
      _screenStream = null;
    }
    for (final timer in _iceGraceTimers.values) {
      timer.cancel();
    }
    _iceGraceTimers.clear();
    _iceRestartAttempts.clear();
    _pendingRemoteCandidates.clear();
    _remoteDescriptionSet.clear();
    _prevBytesSent.clear();
    _prevBytesSentAtMs.clear();
    _videoBitrateCapKbps = null;
    _consecutiveLossy = 0;
    _consecutiveClean = 0;
    _ready = false;
    _micEnabled = false;
    _cameraEnabled = false;
    _isScreenSharing = false;
    _speakerphoneEnabled = false;
    _error = null;
    _publish();
  }

  Future<void> _resetLocalMediaOnly() async {
    await _disableAndDisposeStream(_localStream);
    _localStream = null;

    await _disposeRenderer(_localRenderer);
    _localRenderer = null;
  }

  Future<void> _disableAndDisposeStream(MediaStream? stream) async {
    if (stream == null) return;

    try {
      for (final track in stream.getTracks()) {
        try {
          track.enabled = false;
        } catch (_) {}
        try {
          await track.stop();
        } catch (_) {}
      }
    } catch (_) {}

    try {
      await stream.dispose();
    } catch (_) {}
  }

  Future<void> _disposeStream(MediaStream? stream) async {
    if (stream == null) return;

    try {
      for (final track in stream.getTracks()) {
        await track.stop();
      }
    } catch (_) {}

    try {
      await stream.dispose();
    } catch (_) {}
  }

  Future<void> _disposeRenderer(RTCVideoRenderer? renderer) async {
    if (renderer == null) return;

    try {
      renderer.srcObject = null;
    } catch (_) {}

    try {
      await renderer.dispose();
    } catch (_) {}
  }

  Future<void> _disposePeerConnection(RTCPeerConnection? peer) async {
    if (peer == null) return;

    try {
      await peer.close();
    } catch (_) {}

    try {
      await peer.dispose();
    } catch (_) {}
  }

  Future<void> dispose() async {
    _disposed = true;
    await resetSessionMedia();
    if (!_snapshots.isClosed) {
      await _snapshots.close();
    }
    if (!_peerHealth.isClosed) {
      await _peerHealth.close();
    }
  }

  void _publish() {
    if (_snapshots.isClosed) return;
    _snapshots.add(currentSnapshot);
  }
}
