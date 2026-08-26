import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../domain/remote_media_presentation.dart';
import 'realtime_repository.dart';
import 'realtime_transport.dart';
import 'stage_remote_binding.dart';

/// CLOUDFLARE SFU TRANSPORT.
///
/// One peer connection for the whole session, regardless of how many people
/// are in it. That is the entire point: measured on Windows and a physical
/// Pixel 9a, the publisher's upload paths stayed at 2 whether one person or
/// four were watching, where mesh would have grown to 8.
///
/// Control flows client -> Aura -> Cloudflare. This class never sees a
/// Cloudflare credential, never names a provider session or track, and could
/// not reach another Aura session's media if it tried: a subscribe carries
/// AURA track ids, which the server resolves inside the caller's own session.
class SfuRealtimeTransport implements RealtimeTransport {
  SfuRealtimeTransport(this._repository);

  final RealtimeRepository _repository;

  @override
  String get id => 'sfu';

  RTCPeerConnection? _pc;
  MediaStream? _local;
  String? _sessionId;
  final List<Map<String, dynamic>> _publishedTracks = <Map<String, dynamic>>[];

  @override
  Future<void> open({
    required String sessionId,
    required MediaStream local,
  }) async {
    _sessionId = sessionId;
    _local = local;

    final pc = await createPeerConnection(<String, dynamic>{
      // Relay credentials still come from Aura's own TURN issuance; STUN here
      // is only the provider's own reflexive discovery.
      'iceServers': [
        {'urls': 'stun:stun.cloudflare.com:3478'}
      ],
      // Cloudflare Realtime requires a single bundled transport.
      'bundlePolicy': 'max-bundle',
      'sdpSemantics': 'unified-plan',
    });
    _pc = pc;

    for (final track in local.getTracks()) {
      await pc.addTransceiver(
        track: track,
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.SendOnly),
      );
    }

    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);

    final opened = await _repository.openStageTransport(
      sessionId,
      offerSdp: offer.sdp ?? '',
    );
    final negotiation = (opened['negotiation'] as Map?)?.cast<String, dynamic>();
    final answer = negotiation?['sdp'];
    if (answer is! String || answer.isEmpty) {
      throw StateError('stage transport returned no answer [sfu:no_answer]');
    }
    await pc.setRemoteDescription(RTCSessionDescription(answer, 'answer'));
    await _waitForIce(pc);
  }

  @override
  Future<void> publishLocal() async {
    final pc = _pc;
    final sessionId = _sessionId;
    if (pc == null || sessionId == null) {
      throw StateError('publish before open [sfu:not_open]');
    }

    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);

    // Mids MUST be read from the peer connection after setLocalDescription.
    // The transceiver objects returned by addTransceiver still carry an empty
    // mid, and an empty string passes the server's validation only to be
    // refused by the provider as an opaque 406.
    final transceivers = await pc.getTransceivers();
    final sending =
        transceivers.where((t) => t.sender.track != null).toList(growable: false);

    final payload = <Map<String, dynamic>>[];
    for (final t in sending) {
      final mid = t.mid;
      if (mid.isEmpty) {
        throw StateError('transceiver has no mid after setLocalDescription '
            '[sfu:missing_mid]');
      }
      final kind = t.sender.track?.kind ?? 'audio';
      payload.add(<String, dynamic>{
        'mid': mid,
        'trackType': kind == 'video' ? 'VIDEO' : 'AUDIO',
        'trackName': 'aura-$kind-$mid',
      });
    }

    final published = await _repository.publishStageTracks(
      sessionId,
      offerSdp: offer.sdp ?? '',
      tracks: payload,
    );
    final negotiation =
        (published['negotiation'] as Map?)?.cast<String, dynamic>();
    final answer = negotiation?['sdp'];
    if (answer is! String || answer.isEmpty) {
      throw StateError('publish returned no answer [sfu:no_publish_answer]');
    }
    await pc.setRemoteDescription(RTCSessionDescription(answer, 'answer'));

    _publishedTracks
      ..clear()
      ..addAll(((published['tracks'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>()));
  }

  @override
  Future<Map<String, RemoteParticipantMedia>> refreshRemoteMedia() async {
    final pc = _pc;
    final sessionId = _sessionId;
    if (pc == null || sessionId == null) return const {};

    // The server lists only OTHER participants' live tracks in this session,
    // so there is nothing to filter out here and no way to ask for anyone
    // else's.
    final available = await _repository.listStageTracks(sessionId);
    final trackIds = available
        .map((t) => '${t['id']}')
        .where((id) => id.isNotEmpty && id != 'null')
        .toList(growable: false);
    if (trackIds.isEmpty) return const {};

    final subscribed =
        await _repository.subscribeStageTracks(sessionId, trackIds: trackIds);
    final negotiation =
        (subscribed['negotiation'] as Map?)?.cast<String, dynamic>();

    if (negotiation?['requiresImmediateRenegotiation'] == true) {
      final sdp = negotiation?['sdp'];
      if (sdp is! String || sdp.isEmpty) {
        throw StateError('subscribe asked to renegotiate without an offer '
            '[sfu:no_offer]');
      }
      await pc.setRemoteDescription(RTCSessionDescription(sdp, 'offer'));
      final answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);
      await _repository.renegotiateStage(sessionId, answerSdp: answer.sdp ?? '');
    }

    // Deterministic binding. onTrack is NOT used: measured on both Windows and
    // Android, it does not fire for receivers created by this renegotiation
    // while inbound RTP is already arriving, so a client waiting for it would
    // paint a blank tile over live media.
    final bindings = await bindRemoteMedia(
      pc: pc,
      serverBindings: ((subscribed['bindings'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList(growable: false),
    );
    return sfuRemoteMedia(bindings: bindings);
  }

  @override
  Future<void> replaceVideoSource(MediaStreamTrack track) async {
    final pc = _pc;
    if (pc == null) return;
    final senders = await pc.getSenders();
    for (final sender in senders) {
      if (sender.track?.kind != 'video') continue;
      // replaceTrack, not renegotiation: the publication, the transport and
      // the Aura session all stay exactly as they are, and subscribers keep
      // receiving without re-subscribing.
      await sender.replaceTrack(track);
      return;
    }
  }

  @override
  Future<void> setMicrophoneEnabled(bool enabled) async {
    for (final t in _local?.getAudioTracks() ?? const <MediaStreamTrack>[]) {
      t.enabled = enabled;
    }
  }

  @override
  Future<void> setCameraEnabled(bool enabled) async {
    for (final t in _local?.getVideoTracks() ?? const <MediaStreamTrack>[]) {
      t.enabled = enabled;
    }
  }

  @override
  Future<void> close() async {
    final sessionId = _sessionId;
    if (sessionId != null) {
      try {
        await _repository.closeStageTransport(sessionId);
      } catch (e) {
        // A failed server-side cleanup must never strand someone in a call
        // they are trying to leave. Aura reaps the transport regardless.
        debugPrint('[sfu] transport close (server) failed: $e');
      }
    }
    try {
      await _pc?.close();
    } catch (e) {
      debugPrint('[sfu] peer close failed: $e');
    }
    _pc = null;
    _local = null;
    _sessionId = null;
    _publishedTracks.clear();
  }

  @override
  Future<RealtimeTransportStats> stats() async {
    final pc = _pc;
    if (pc == null) {
      return const RealtimeTransportStats(
          inboundBytes: 0, outboundBytes: 0, uploadPathCount: 0);
    }
    var inbound = 0;
    var outbound = 0;
    var paths = 0;
    for (final report in await pc.getStats()) {
      final v = report.values;
      if (report.type == 'inbound-rtp') {
        inbound += ((v['bytesReceived'] as num?) ?? 0).toInt();
      } else if (report.type == 'outbound-rtp') {
        outbound += ((v['bytesSent'] as num?) ?? 0).toInt();
        paths++;
      }
    }
    return RealtimeTransportStats(
      inboundBytes: inbound,
      outboundBytes: outbound,
      uploadPathCount: paths,
    );
  }

  Future<void> _waitForIce(RTCPeerConnection pc) async {
    final done = Completer<void>();
    void check(RTCIceConnectionState s) {
      if ((s == RTCIceConnectionState.RTCIceConnectionStateConnected ||
              s == RTCIceConnectionState.RTCIceConnectionStateCompleted) &&
          !done.isCompleted) {
        done.complete();
      }
    }

    pc.onIceConnectionState = check;
    check(pc.iceConnectionState ??
        RTCIceConnectionState.RTCIceConnectionStateNew);
    await done.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () =>
          throw StateError('stage transport never connected [sfu:ice_timeout]'),
    );
  }
}
