import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

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
  });

  final bool ready;
  final bool micEnabled;
  final bool cameraEnabled;
  final RTCVideoRenderer? localRenderer;
  final Map<String, RTCVideoRenderer> remoteRenderers;
  final String? error;
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
  });
  final int? rttMs;
  final int? jitterMs;
  final double? packetLossPct;
  final int? bitrateKbps;

  bool get hasAny =>
      rttMs != null ||
      jitterMs != null ||
      packetLossPct != null ||
      bitrateKbps != null;
}

class RealtimeMediaService {
  RealtimeMediaService();

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
  RTCVideoRenderer? _localRenderer;
  MediaStream? _screenStream;
  bool _ready = false;
  bool _micEnabled = true;
  bool _cameraEnabled = true;
  bool _isScreenSharing = false;
  String? _error;
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
        error: _error,
        isScreenSharing: _isScreenSharing,
        sentTrackKinds: List<String>.from(_lastSentTrackKinds),
        onTrackAudioSeen: _onTrackAudioSeen,
        onTrackVideoSeen: _onTrackVideoSeen,
        localVideoTrackPresent:
            _localStream?.getVideoTracks().isNotEmpty ?? false,
        remoteVideoRendererAttached:
            _remoteStreams.values.any((s) => s.getVideoTracks().isNotEmpty),
        cameraUnavailable: _cameraUnavailable,
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
      if (video && audio) {
        try {
          stream = await navigator.mediaDevices.getUserMedia(constraints(false));
          gotVideo = false;
          _cameraUnavailable = true;
          debugPrint(
            '[rtc-media] degraded to AUDIO-ONLY (camera busy)'
            ' aTracks=${stream.getAudioTracks().length}',
          );
        } catch (audioError) {
          debugPrint('[rtc-media] audio-only ALSO failed err=$audioError');
        }
      }
    }

    if (stream == null) {
      // Nothing acquired at all — surface the error but do NOT rethrow, so the
      // caller stays joined (they can retry via the camera/mic toggle).
      await renderer.dispose();
      _error = 'Camera and microphone are unavailable. '
          'Another app or browser may be using them.';
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
    _error = _cameraUnavailable
        ? 'Camera unavailable in this browser. '
            'Another browser or app may be using it — joined with audio only.'
        : null;
    _publish();
  }

  Future<void> _attachLocalTracks(
    RTCPeerConnection connection,
    String peerKey,
  ) async {
    final local = _localStream;
    if (local == null) {
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
    final stream = existing ?? await createLocalMediaStream('remote-$peerKey');
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

  Future<void> setCameraEnabled(bool enabled) async {
    final videoTracks =
        _localStream?.getVideoTracks() ?? const <MediaStreamTrack>[];
    // No video track means we degraded to audio-only (camera busy in another
    // app/browser). Don't claim the camera is "on" — that produced the
    // misleading cam=true / localVid=false badge. Stay off until a real
    // re-acquire succeeds.
    if (enabled && videoTracks.isEmpty) {
      _cameraEnabled = false;
      _publish();
      return;
    }
    _cameraEnabled = enabled;
    await _setTrackEnabled(tracks: videoTracks, enabled: enabled);
    _publish();
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
      for (final entry in _peers.entries) {
        final peer = entry.value;
        final senders = await peer.getSenders();
        var replaced = false;
        for (final sender in senders) {
          if (sender.track?.kind == 'video') {
            await sender.replaceTrack(screenTrack);
            replaced = true;
          }
        }
        if (!replaced) {
          try {
            final sendStream =
                _localStream ?? await createLocalMediaStream('screen-share');
            await peer.addTrack(screenTrack, sendStream);
            needsRenegotiation = true;
          } catch (error) {
            debugPrint(
              '[rtc] screen addTrack failed peerKey=${entry.key} err=$error',
            );
          }
        }
      }
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
    for (final peer in _peers.values) {
      try {
        final senders = await peer.getSenders();
        for (final sender in senders) {
          if (sender.track?.kind == 'video') {
            // Audio-only meetings have no camera track to restore — clear the
            // sender instead of leaving a dead screen track on the wire.
            await sender.replaceTrack(cameraTrack);
          }
        }
      } catch (error) {
        debugPrint('[rtc] stopScreenShare restore failed err=$error');
      }
    }

    await _disposeStream(_screenStream);
    _screenStream = null;
    _publish();
  }

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

    for (final entry in Map<String, RTCPeerConnection>.from(_peers).entries) {
      List<StatsReport> reports;
      try {
        reports = await entry.value.getStats();
      } catch (_) {
        continue;
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
    );

    await _adaptToSample(sample);
    return sample;
  }

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

    for (final peer in _peers.values) {
      try {
        for (final sender in await peer.getSenders()) {
          if (sender.track?.kind == 'video') {
            await sender.replaceTrack(newTrack);
          }
        }
      } catch (error) {
        debugPrint('[rtc-media] switchVideoInput replaceTrack err=$error');
      }
    }

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

    for (final peer in _peers.values) {
      try {
        for (final sender in await peer.getSenders()) {
          if (sender.track?.kind == 'audio') {
            await sender.replaceTrack(newTrack);
          }
        }
      } catch (error) {
        debugPrint('[rtc-media] switchAudioInput replaceTrack err=$error');
      }
    }

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
