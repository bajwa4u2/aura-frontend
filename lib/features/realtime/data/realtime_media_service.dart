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

class RealtimeMediaService {
  RealtimeMediaService();

  final StreamController<RealtimeMediaSnapshot> _snapshots =
      StreamController<RealtimeMediaSnapshot>.broadcast();

  final Map<String, RTCPeerConnection> _peers = <String, RTCPeerConnection>{};
  final Map<String, RTCVideoRenderer> _remoteRenderers =
      <String, RTCVideoRenderer>{};
  final Map<String, MediaStream> _remoteStreams = <String, MediaStream>{};
  // Perfect-negotiation: peers for which we currently have an offer in flight.
  final Map<String, bool> _makingOffer = <String, bool>{};

  MediaStream? _localStream;
  RTCVideoRenderer? _localRenderer;
  MediaStream? _screenStream;
  bool _ready = false;
  bool _micEnabled = true;
  bool _cameraEnabled = true;
  bool _isScreenSharing = false;
  String? _error;
  bool _disposed = false;
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

    Map<String, dynamic> constraints(bool wantVideo) => <String, dynamic>{
          'audio': audio,
          'video': wantVideo
              ? <String, dynamic>{
                  'facingMode': 'user',
                  'width': <String, dynamic>{'ideal': 1280},
                  'height': <String, dynamic>{'ideal': 720},
                  'frameRate': <String, dynamic>{'ideal': 24},
                }
              : false,
        };

    MediaStream? stream;
    var gotVideo = video;
    try {
      stream = await navigator.mediaDevices.getUserMedia(constraints(video));
      debugPrint(
        '[rtc-media] getUserMedia OK audio=$audio video=$video'
        ' aTracks=${stream.getAudioTracks().length}'
        ' vTracks=${stream.getVideoTracks().length}',
      );
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
    final tracks = local.getTracks();
    for (final track in tracks) {
      debugPrint(
        '[rtc-track] local track kind=${track.kind}'
        ' enabled=${track.enabled} muted=${track.muted} id=${track.id}',
      );
    }
    final kinds = <String>[];
    for (final track in tracks) {
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
    debugPrint('[rtc-track] local attached peer=$peerKey kinds=$kinds');

    // Confirm what the peer connection will actually send (senders), so a badge
    // reading "sent=[audio]" vs "[audio,video]" can be traced to a real sender
    // rather than a guessed track kind.
    try {
      final senders = await connection.getSenders();
      for (final sender in senders) {
        final t = sender.track;
        debugPrint(
          '[rtc-track] sender kind=${t?.kind} enabled=${t?.enabled}',
        );
      }
      debugPrint('[rtc-track] senders total=${senders.length} peer=$peerKey');
    } catch (e) {
      debugPrint('[rtc-track] getSenders failed peer=$peerKey err=$e');
    }
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
    };

    connection.onTrack = (RTCTrackEvent event) async {
      final kind = event.track.kind ?? '';
      if (kind == 'audio') _onTrackAudioSeen = true;
      if (kind == 'video') _onTrackVideoSeen = true;
      debugPrint(
        '[rtc-track] remote onTrack peer=$peerKey kind=$kind'
        ' streams=${event.streams.length}',
      );
      try {
        final stream = await _resolveRemoteStream(peerKey, event);
        if (stream == null) return;

        _remoteStreams[peerKey] = stream;
        final renderer = _remoteRenderers[peerKey] ?? await _createRemoteRenderer();
        renderer.srcObject = stream;
        _remoteRenderers[peerKey] = renderer;
        _error = null;
        _publish();
        debugPrint('[rtc-render] renderer stored key=$peerKey (onTrack)');
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
      debugPrint(
        '[rtc-track] remote onAddStream peer=$peerKey id=${stream.id}'
        ' a=${stream.getAudioTracks().length} v=${stream.getVideoTracks().length}',
      );
      unawaited(() async {
        try {
          _remoteStreams[peerKey] = stream;
          final renderer =
              _remoteRenderers[peerKey] ?? await _createRemoteRenderer();
          renderer.srcObject = stream;
          _remoteRenderers[peerKey] = renderer;
          _error = null;
          _publish();
          debugPrint('[rtc-render] renderer stored key=$peerKey (onAddStream)');
        } catch (error) {
          debugPrint('[rtc] onAddStream ERROR peerKey=$peerKey err=$error');
        }
      }());
    };

    connection.onConnectionState = (RTCPeerConnectionState state) async {
      debugPrint('[rtc] connectionState peerKey=$peerKey state=$state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        debugPrint('[rtc] peer REMOVED (failed/closed) peerKey=$peerKey');
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
      final sdp = offer.sdp ?? '';
      debugPrint(
        '[rtc-offer] sdp peer=$peerKey hasAudioM=${sdp.contains('m=audio')}'
        ' hasVideoM=${sdp.contains('m=video')}'
        ' sendrecv=${sdp.contains('a=sendrecv')}'
        ' sendonly=${sdp.contains('a=sendonly')}',
      );
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

    await connection.setRemoteDescription(
      RTCSessionDescription(
        (sdp['sdp'] ?? '').toString(),
        (sdp['type'] ?? 'answer').toString(),
      ),
    );
  }

  Future<void> addRemoteCandidate({
    required String peerKey,
    required Map<String, dynamic> candidate,
  }) async {
    final connection = _peers[peerKey];
    if (connection == null) return;

    final value = candidate['candidate'];
    if (value == null) return;

    await connection.addCandidate(
      RTCIceCandidate(
        value.toString(),
        candidate['sdpMid']?.toString(),
        candidate['sdpMLineIndex'] is int
            ? candidate['sdpMLineIndex'] as int
            : int.tryParse(candidate['sdpMLineIndex']?.toString() ?? ''),
      ),
    );
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

  Future<void> startScreenShare() async {
    if (_disposed || _isScreenSharing) return;

    final stream = await navigator.mediaDevices.getDisplayMedia(<String, dynamic>{
      'video': <String, dynamic>{'cursor': 'always'},
      'audio': false,
    });

    _screenStream = stream;

    final screenTracks = stream.getVideoTracks();
    if (screenTracks.isNotEmpty) {
      final screenTrack = screenTracks.first;
      for (final peer in _peers.values) {
        final senders = await peer.getSenders();
        for (final sender in senders) {
          if (sender.track?.kind == 'video') {
            await sender.replaceTrack(screenTrack);
          }
        }
      }
    }

    _isScreenSharing = true;
    _publish();
  }

  Future<void> stopScreenShare() async {
    if (_disposed || !_isScreenSharing) return;

    _isScreenSharing = false;

    final cameraTracks = _localStream?.getVideoTracks();
    if (cameraTracks != null && cameraTracks.isNotEmpty) {
      final cameraTrack = cameraTracks.first;
      for (final peer in _peers.values) {
        final senders = await peer.getSenders();
        for (final sender in senders) {
          if (sender.track?.kind == 'video') {
            await sender.replaceTrack(cameraTrack);
          }
        }
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

  Future<void> removePeer(String peerKey) async {
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
  }

  void _publish() {
    if (_snapshots.isClosed) return;
    _snapshots.add(currentSnapshot);
  }
}
