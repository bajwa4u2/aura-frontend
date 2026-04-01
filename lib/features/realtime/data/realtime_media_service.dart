import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';

class RealtimeMediaSnapshot {
  const RealtimeMediaSnapshot({
    required this.ready,
    required this.micEnabled,
    required this.cameraEnabled,
    required this.localRenderer,
    required this.remoteRenderers,
    required this.error,
  });

  final bool ready;
  final bool micEnabled;
  final bool cameraEnabled;
  final RTCVideoRenderer? localRenderer;
  final Map<String, RTCVideoRenderer> remoteRenderers;
  final String? error;
}

class RealtimeMediaService {
  RealtimeMediaService();

  final StreamController<RealtimeMediaSnapshot> _snapshots =
      StreamController<RealtimeMediaSnapshot>.broadcast();

  final Map<String, RTCPeerConnection> _peers = <String, RTCPeerConnection>{};
  final Map<String, RTCVideoRenderer> _remoteRenderers =
      <String, RTCVideoRenderer>{};
  final Map<String, MediaStream> _remoteStreams = <String, MediaStream>{};

  MediaStream? _localStream;
  RTCVideoRenderer? _localRenderer;
  bool _ready = false;
  bool _micEnabled = true;
  bool _cameraEnabled = true;
  String? _error;
  bool _disposed = false;

  Stream<RealtimeMediaSnapshot> get snapshots => _snapshots.stream;

  RealtimeMediaSnapshot get currentSnapshot => RealtimeMediaSnapshot(
        ready: _ready,
        micEnabled: _micEnabled,
        cameraEnabled: _cameraEnabled,
        localRenderer: _localRenderer,
        remoteRenderers: Map<String, RTCVideoRenderer>.from(_remoteRenderers),
        error: _error,
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

    await _resetLocalMediaOnly();

    try {
      final renderer = RTCVideoRenderer();
      await renderer.initialize();

      final stream = await navigator.mediaDevices.getUserMedia(<String, dynamic>{
        'audio': audio,
        'video': video
            ? <String, dynamic>{
                'facingMode': 'user',
                'width': <String, dynamic>{'ideal': 1280},
                'height': <String, dynamic>{'ideal': 720},
                'frameRate': <String, dynamic>{'ideal': 24},
              }
            : false,
      });

      renderer.srcObject = stream;
      _localRenderer = renderer;
      _localStream = stream;
      _ready = true;
      _micEnabled = audio;
      _cameraEnabled = video;
      _error = null;
      _publish();
    } catch (error) {
      _error = error.toString();
      _ready = false;
      _publish();
      rethrow;
    }
  }

  Future<RTCPeerConnection> _ensurePeer({
    required String peerKey,
    required Map<String, dynamic> configuration,
    required void Function(RTCIceCandidate candidate) onIceCandidate,
  }) async {
    final existing = _peers[peerKey];
    if (existing != null) return existing;

    final connection = await createPeerConnection(configuration);
    final local = _localStream;
    if (local != null) {
      for (final track in local.getTracks()) {
        await connection.addTrack(track, local);
      }
    }

    connection.onIceCandidate = onIceCandidate;

    connection.onTrack = (RTCTrackEvent event) async {
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
        _error = error.toString();
        _publish();
      }
    };

    connection.onConnectionState = (RTCPeerConnectionState state) async {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
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

    final offer = await connection.createOffer(<String, dynamic>{
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': true,
    });
    await connection.setLocalDescription(offer);
    return offer;
  }

  Future<RTCSessionDescription> handleRemoteOffer({
    required String peerKey,
    required String? targetSocketId,
    required Map<String, dynamic> configuration,
    required Map<String, dynamic> sdp,
    required void Function(RTCIceCandidate candidate) onIceCandidate,
  }) async {
    final connection = await _ensurePeer(
      configuration: configuration,
      onIceCandidate: onIceCandidate,
      peerKey: peerKey,
    );

    await connection.setRemoteDescription(
      RTCSessionDescription(
        (sdp['sdp'] ?? '').toString(),
        (sdp['type'] ?? 'offer').toString(),
      ),
    );

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
    _cameraEnabled = enabled;
    await _setTrackEnabled(
      tracks: _localStream?.getVideoTracks() ?? const <MediaStreamTrack>[],
      enabled: enabled,
    );
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
    _ready = false;
    _micEnabled = false;
    _cameraEnabled = false;
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
