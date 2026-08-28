import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../domain/remote_media_presentation.dart';
import 'realtime_repository.dart';
import 'realtime_transport.dart';
import 'serial_queue.dart';
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
  SfuRealtimeTransport(this._repository, {this.onLost});

  final RealtimeRepository _repository;

  /// Called ONCE when this transport is judged unrecoverable in place.
  ///
  /// THE GAP THIS CLOSES (2026-08-28). Mesh watched every peer connection
  /// (`checkPeersHealth`, `_escalateIceFailure`, `restartIce`) and could
  /// rebuild a dead one. On the stage none of that ran: `checkPeersHealth`
  /// iterates `_peers`, which is empty under SFU, and the only ICE handler
  /// here was the one-shot completer in `_waitForIce`, never re-armed. So a
  /// transport that died mid-call stayed dead until somebody hung up.
  ///
  /// Three calls died exactly that way in one evening: transport lost, then
  /// sixty seconds of silence, then `heartbeat_timeout`. Nothing detected it
  /// and nothing tried.
  ///
  /// This reports; it does not repair. The owner decides what recovery means,
  /// because re-establishing a transport is a session-level act.
  /// [iceHealthy] distinguishes the two causes that look identical from here:
  /// MY transport died, or THE OTHER PARTY went away. Media stopping proves
  /// only that nothing is arriving. When ICE is still connected the path is
  /// fine and rebuilding it would interrupt my own published media for
  /// everyone else -- actively harmful in a group call -- so the owner
  /// re-subscribes instead.
  final void Function(String reason, bool iceHealthy)? onLost;

  Timer? _iceGrace;
  Timer? _liveness;
  int _lastLivenessBytes = -1;
  int _stallTicks = 0;
  int _ticks = 0;
  bool _probing = false;
  bool _lostReported = false;
  bool _closing = false;

  @override
  String get id => 'sfu';

  RTCPeerConnection? _pc;
  String? _sessionId;
  final List<Map<String, dynamic>> _publishedTracks = <Map<String, dynamic>>[];

  /// Aura track ids already subscribed on this transport.
  ///
  /// Remote publication is not a single event: a participant can publish after
  /// we attached, or add video to an existing audio call. Refresh is therefore
  /// called repeatedly, and without this it would re-subscribe to the same
  /// tracks every time and pile up duplicate receivers.
  final Set<String> _subscribed = <String>{};

  /// What is currently bound, so a refresh that finds nothing new is free and
  /// still returns the media already being received.
  Map<String, RemoteParticipantMedia> _remote =
      const <String, RemoteParticipantMedia>{};

  /// ONE NEGOTIATION AT A TIME.
  ///
  /// There is a single peer connection per session, and negotiation is
  /// stateful: an offer must be applied, answered and acknowledged before the
  /// next one begins. The product drives this from several legitimate triggers
  /// — participant joined, media ready, join, hydrate — which can fire within
  /// the same second, and each wants to resolve remote media.
  ///
  /// Measured against production: overlapping refreshes produced repeated
  /// failures inside one second on both sides, while a strictly sequential
  /// script performing the identical calls against the identical backend
  /// succeeded every time. The protocol was never the problem.
  ///
  /// The product may therefore ask as often as it likes. Ordering is enforced
  /// here, at the transport that owns the state — never by asking the product
  /// to co-ordinate, and never with delays or debounce, which would hide a
  /// state-machine mistake rather than fix it.
  final SerialQueue _queue = SerialQueue();

  /// BOUNDED SEQUENCE TRACE.
  ///
  /// Founder ruling §6: after a second failed product proof, stop patching and
  /// record what actually happens. Every stage control operation reports its
  /// order, trigger, signalling state either side, and how long it waited
  /// behind other work — so the interleaving can be read rather than inferred.
  ///
  /// Never carries SDP, credentials, tokens or media. Best-effort: a trace
  /// that failed to send must never fail a call.
  int _seq = 0;

  Future<T> _traced<T>(
    String type,
    String trigger,
    Future<T> Function() action,
  ) async {
    final seq = ++_seq;
    final queuedAt = DateTime.now();
    return _queue.run(() async {
      final startedAt = DateTime.now();
      final before = _pc?.signalingState?.name ?? 'none';
      String result = 'ok';
      try {
        return await action();
      } catch (e) {
        result = _shortError(e);
        rethrow;
      } finally {
        final endedAt = DateTime.now();
        final after = _pc?.signalingState?.name ?? 'none';
        unawaited(_report(
          'seq=$seq op=$type trig=$trigger '
          'sigBefore=$before sigAfter=$after '
          'waitMs=${startedAt.difference(queuedAt).inMilliseconds} '
          'runMs=${endedAt.difference(startedAt).inMilliseconds} '
          'result=$result',
        ));
      }
    });
  }

  /// Compact, safe error label — never the provider's full body.
  String _shortError(Object e) {
    final text = e.toString();
    final marker = RegExp(r'\[stage:[a-z0-9_]+\]').firstMatch(text);
    if (marker != null) return marker.group(0)!;
    return text.length > 60 ? '${text.substring(0, 60)}...' : text;
  }

  Future<void> _report(String message) async {
    final sessionId = _sessionId;
    if (sessionId == null) return;
    try {
      await _repository.reportStageDiagnostic(
        sessionId,
        phase: 'trace',
        code: 'stage_op',
        message: message,
        platform: kIsWeb ? 'web' : defaultTargetPlatform.name,
      );
    } catch (_) {
      // A trace that cannot be sent must never fail a call.
    }
  }

  @override
  Future<void> report({
    required String phase,
    required String code,
    required String message,
  }) async {
    final sessionId = _sessionId;
    if (sessionId == null) return;
    try {
      await _repository.reportStageDiagnostic(
        sessionId,
        phase: phase,
        code: code,
        message: message,
        platform: kIsWeb ? 'web' : defaultTargetPlatform.name,
      );
    } catch (_) {
      // Observability must never fail a call.
    }
  }

  @override
  Future<void> open({
    required String sessionId,
    MediaStream? local,
    String trigger = 'UNKNOWN',
  }) {
    _sessionId = sessionId; // so the trace can be attributed before open runs
    return _traced('OPEN', trigger, () => _open(sessionId: sessionId, local: local));
  }

  Future<void> _open({
    required String sessionId,
    MediaStream? local,
  }) async {
    _sessionId = sessionId;

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

    final tracks = local?.getTracks() ?? const <MediaStreamTrack>[];
    if (tracks.isEmpty) {
      // RECEIVE-ONLY. Capture failed or was denied, and mesh would still let
      // this person see and hear the room — so the stage must too. The
      // provider needs m-lines to negotiate against, so they are offered as
      // recvonly rather than not at all.
      await pc.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeAudio,
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
      );
      await pc.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
      );
    } else {
      for (final track in tracks) {
        await pc.addTransceiver(
          track: track,
          init: RTCRtpTransceiverInit(direction: TransceiverDirection.SendOnly),
        );
      }
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
  Future<void> publishLocal({String trigger = 'UNKNOWN'}) =>
      _traced('PUBLISH', trigger, _publishLocal);

  Future<void> _publishLocal() async {
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

    // Nothing to publish is a legitimate state, not a failure: a receive-only
    // participant still subscribes to everyone else.
    if (sending.isEmpty) return;

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
  Future<Map<String, RemoteParticipantMedia>> refreshRemoteMedia({
    String trigger = 'UNKNOWN',
  }) =>
      _traced('SUBSCRIBE', trigger, _refreshRemoteMedia);

  Future<Map<String, RemoteParticipantMedia>> _refreshRemoteMedia() async {
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
    if (trackIds.isEmpty) return _remote;

    // RETIRE RECEIVERS FOR TRACKS THAT NO LONGER EXIST.
    //
    // `_subscribed` only ever grew. When somebody republishes — camera off and
    // on, a re-acquisition after a reconnect — the server mints NEW track rows
    // and ends the old ones, so the next reconcile subscribes again and
    // Cloudflare adds another pair of `recvonly` m-lines. The previous pair
    // stays on this peer connection for the rest of the call.
    //
    // Measured live 2026-08-28: transceivers climbing 6 → 8 → 10 → 12 → 14
    // with `receiving=12 bound=2`. Ten dead lines, two live ones.
    //
    // A track that has vanished from the session's available list is one this
    // client can no longer be receiving anything on. Closing it on OUR OWN
    // provider session drops our receiver; it does not touch the publisher's
    // track, which belongs to them.
    final availableSet = trackIds.toSet();
    final stale =
        _subscribed.where((id) => !availableSet.contains(id)).toList(growable: false);
    if (stale.isNotEmpty) {
      final retired =
          await _repository.unsubscribeStageTracks(sessionId, trackIds: stale);
      // Forget them regardless of what the provider said. If the close failed
      // we are no worse off than before, and continuing to treat a dead track
      // as subscribed would block a later re-subscribe to a track that reuses
      // the id — the one way this could make things worse.
      _subscribed.removeAll(stale);
      unawaited(_report(
        'op=RETIRE stale=${stale.length} retired=$retired '
        'subscribed=${_subscribed.length}',
      ));
    }

    // Only subscribe to what is NEW.
    //
    // THE DEFECT THIS FIXES (found on the real product path, 2026-08-26): the
    // receiver subscribed exactly once, at attach. If it attached before the
    // caller had published — which is the normal order for the party that
    // ACCEPTS a call — it found nothing and never tried again, so the callee
    // sat in a connected call with no remote media at all. Mesh never showed
    // this because offer/answer re-drove discovery on every change; binding
    // here is deterministic but had no reason to re-run.
    final fresh =
        trackIds.where((id) => !_subscribed.contains(id)).toList(growable: false);
    if (fresh.isEmpty) return _remote;

    final subscribed =
        await _repository.subscribeStageTracks(sessionId, trackIds: fresh);
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
    _subscribed.addAll(fresh);

    // Bind across ALL receiving m-lines, not just this batch: earlier
    // subscriptions are still carried on the same peer connection, and a
    // partial map would blank tiles that were working a moment ago.
    final bindings = await bindRemoteMedia(
      pc: pc,
      serverBindings: ((subscribed['bindings'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList(growable: false),
    );
    // REPORT WHAT THE BIND ACTUALLY DID.
    //
    // Cloudflare returned valid bindings with real mids for BOTH audio and
    // video in both directions (proven server-side 2026-08-28), and the tiles
    // were still black. The bind rule drops a binding on three separate
    // conditions and reports none of them, so this is the only remaining
    // unlit stretch between a correct provider response and a dark screen.
    //
    // Counts only -- no media, no identifiers beyond mids the client already
    // holds. Fire-and-forget so a diagnostic cannot break a call.
    try {
      final audit = auditRemoteBindings(
        lines: lastReceivingLines,
        serverBindings: ((subscribed['bindings'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList(growable: false),
      );
      unawaited(_repository.reportStageDiagnostic(
        sessionId,
        phase: 'bind',
        code: audit.bound == audit.serverBindings
            ? 'bind_complete'
            : audit.bound == 0
                ? 'bind_none'
                : 'bind_partial',
        message: audit.summary,
        platform: kIsWeb ? 'web' : defaultTargetPlatform.name,
      ));
    } catch (_) {
      // Never let observability fail the call.
    }

    final merged = Map<String, RemoteParticipantMedia>.from(_remote);
    sfuRemoteMedia(bindings: bindings).forEach((participantId, media) {
      final existing = merged[participantId];
      merged[participantId] = existing == null
          ? media
          : existing.copyWith(audio: media.audio, video: media.video);
    });
    _remote = merged;
    return _remote;
  }

  @override
  Future<void> replaceVideoSource(MediaStreamTrack? track) async =>
      _replaceSource(kind: 'video', track: track);

  @override
  Future<void> replaceAudioSource(MediaStreamTrack? track) async =>
      _replaceSource(kind: 'audio', track: track);

  Future<void> _replaceSource({
    required String kind,
    required MediaStreamTrack? track,
  }) async {
    final pc = _pc;
    if (pc == null) return;
    final senders = await pc.getSenders();
    for (final sender in senders) {
      if (sender.track?.kind != kind) continue;
      // replaceTrack, not renegotiation: the publication, the transport and
      // the Aura session all stay exactly as they are, and subscribers keep
      // receiving without re-subscribing.
      await sender.replaceTrack(track);
      // `_local` IS NOT OURS TO EDIT.
      //
      // An earlier version of this method rewrote `_local` here so that the
      // mute controls below would follow the replacement. That stream is the
      // SAME OBJECT the media service holds as its local capture, so editing
      // it corrupted the caller's own notion of its camera: starting a screen
      // share swapped the camera track out of the media service's stream, and
      // stopping the share then read "the camera track" back out and found
      // the SCREEN track -- replacing it with itself and never restoring the
      // camera. Measured live 2026-08-28, two REPLACE traces carrying one
      // track id.
      //
      // The sender is the authority on what is being sent. Mute reads it
      // directly (see below) and nothing needs to be mirrored anywhere.
      unawaited(_report(
        'op=REPLACE kind=$kind track=${track?.id ?? 'cleared'}',
      ));
      return;
    }
    // NO SENDER TO REPLACE. Reached when the call published no track of this
    // kind at attach — camera denied, or an audio-only join now trying to
    // share a screen. Replacement cannot help here; it needs a publish and a
    // renegotiation. Reported rather than returned silently, because a silent
    // return here is exactly the shape of the defect this method exists to
    // close.
    unawaited(_report('op=REPLACE_NO_SENDER kind=$kind'));
  }

  @override
  Future<void> setMicrophoneEnabled(bool enabled) =>
      _setSenderTracksEnabled(kind: 'audio', enabled: enabled);

  @override
  Future<void> setCameraEnabled(bool enabled) =>
      _setSenderTracksEnabled(kind: 'video', enabled: enabled);

  /// Toggle what is ACTUALLY BEING SENT.
  ///
  /// Reading the senders rather than a held stream means mute always acts on
  /// the current track, including one that arrived by replacement. The stream
  /// this transport was opened with can go stale the moment a source is
  /// replaced; the sender cannot.
  Future<void> _setSenderTracksEnabled({
    required String kind,
    required bool enabled,
  }) async {
    final pc = _pc;
    if (pc == null) return;
    for (final sender in await pc.getSenders()) {
      final track = sender.track;
      if (track == null || track.kind != kind) continue;
      track.enabled = enabled;
    }
  }

  @override
  Future<void> close() async {
    // Deliberate teardown. Set BEFORE anything can change ICE state, so the
    // watch above cannot mistake a leave for a failure.
    _closing = true;
    _iceGrace?.cancel();
    _iceGrace = null;
    _liveness?.cancel();
    _liveness = null;
    // Stop accepting negotiation work first: anything still queued must not
    // mutate a session that is being torn down.
    _queue.close();
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
    _sessionId = null;
    _publishedTracks.clear();
    _subscribed.clear();
    _remote = const <String, RemoteParticipantMedia>{};
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
    try {
      await done.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw StateError(
            'stage transport never connected [sfu:ice_timeout]'),
      );
    } finally {
      // RE-ARM, ALWAYS. The connect wait replaced this handler with a closure
      // whose completer is already finished, so leaving it in place is the
      // same as having no monitor at all -- which is precisely what shipped.
      _armTransportWatch(pc);
      _armLivenessProbe(pc);
    }
  }

  /// IS MEDIA STILL ARRIVING?
  ///
  /// TWO WRONG SIGNALS PRECEDED THIS, both measured on real calls
  /// (2026-08-28), and the pair of mistakes is the useful part.
  ///
  /// ICE STATE IS TOO SLOW. Pulling the network does not move ICE out of
  /// `connected` until consent freshness expires, about THIRTY SECONDS on
  /// both Chrome and Android. A fifteen-second outage froze the video and
  /// produced no state change at all.
  ///
  /// CANDIDATE-PAIR BYTES ARE TOO PERMISSIVE. Chosen next precisely because
  /// they keep counting when everyone is muted -- but they also keep counting
  /// STUN consent traffic when NO MEDIA IS FLOWING, so the probe watched a
  /// number rise through an entire outage and reported health. Avoiding a
  /// false positive that way bought a guaranteed false negative.
  ///
  /// So: measure the thing the person actually loses -- RECEIVED MEDIA.
  ///
  /// The silent-call trap that pushed me to candidate-pair is handled without
  /// giving up the signal: stall detection ARMS ONLY AFTER MEDIA HAS BEEN SEEN
  /// TO FLOW. A call that never had inbound RTP -- everyone muted, cameras off,
  /// or a receive-nothing session -- never arms, so it cannot be torn down for
  /// being quiet. What is detected is media that WAS arriving and STOPPED,
  /// which is exactly the frozen-video condition and nothing else.
  void _armLivenessProbe(RTCPeerConnection pc) {
    _liveness?.cancel();
    _lastLivenessBytes = -1;
    _stallTicks = 0;
    _ticks = 0;
    _liveness = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (_closing || _lostReported) return;
      // NO OVERLAPPING PROBES. Timer.periodic does not await its callback, so
      // a slow getStats() would let two ticks read the SAME byte count and
      // each count it as a stall -- reaching the threshold in half the time
      // and tearing down a healthy call.
      if (_probing) return;
      _probing = true;
      final int bytes;
      try {
        bytes = await _mediaBytesReceived(pc);
      } finally {
        _probing = false;
      }
      _ticks += 1;
      if (bytes < 0) return; // unreadable tick; not evidence of anything

      // A PROBE THAT NEVER SPEAKS CANNOT BE DEBUGGED. Twice now the trace came
      // back empty and there was no way to tell a probe that saw health from
      // one that was not running. It says where it stands every ~30s.
      if (_ticks % 10 == 0) {
        unawaited(_report('op=LIVE bytes=$bytes stall=$_stallTicks '
            'armed=${_lastLivenessBytes >= 0}'));
      }

      if (bytes > _lastLivenessBytes) {
        if (_stallTicks > 0) {
          unawaited(_report('op=LIVE state=resumed afterTicks=$_stallTicks'));
        }
        _lastLivenessBytes = bytes;
        _stallTicks = 0;
        return;
      }
      // Not yet armed: media has never been seen to flow, so there is nothing
      // to have stopped.
      if (_lastLivenessBytes <= 0) return;

      _stallTicks += 1;
      // Six ticks is about eighteen seconds of media that WAS arriving and is
      // now not. Comfortably inside the sixty seconds the server waits before
      // dropping the participant, and long enough that a brief stutter or a
      // slow keyframe does not qualify.
      if (_stallTicks >= 6) {
        _declareLost('media_stalled_${_stallTicks * 3}s');
      }
    });
  }

  /// Bytes of MEDIA received, or -1 when stats cannot be read.
  Future<int> _mediaBytesReceived(RTCPeerConnection pc) async {
    try {
      var rtp = 0;
      for (final report in await pc.getStats()) {
        if (report.type != 'inbound-rtp') continue;
        rtp += ((report.values['bytesReceived'] as num?) ?? 0).toInt();
      }
      return rtp;
    } catch (_) {
      return -1;
    }
  }

  /// Watch ICE for the rest of the transport's life, not just until it
  /// connects.
  ///
  /// This is the FAST PATH, kept alongside the byte probe rather than replaced
  /// by it. ICE state is too slow to be the only signal -- consent freshness
  /// runs about thirty seconds -- but when the stack does declare `failed`
  /// there is no reason to wait eighteen seconds for bytes to confirm what it
  /// already knows.
  void _armTransportWatch(RTCPeerConnection pc) {
    pc.onIceConnectionState = (RTCIceConnectionState state) {
      switch (state) {
        case RTCIceConnectionState.RTCIceConnectionStateConnected:
        case RTCIceConnectionState.RTCIceConnectionStateCompleted:
          if (_iceGrace != null) {
            _iceGrace?.cancel();
            _iceGrace = null;
            unawaited(_report('op=ICE state=recovered'));
          }
          return;

        case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
          // Most disconnects heal. Give it a window before escalating.
          _iceGrace?.cancel();
          _iceGrace = Timer(const Duration(seconds: 10), () {
            _declareLost('ice_disconnected_10s');
          });
          unawaited(_report('op=ICE state=disconnected grace=10s'));
          return;

        case RTCIceConnectionState.RTCIceConnectionStateFailed:
          _declareLost('ice_failed');
          return;

        case RTCIceConnectionState.RTCIceConnectionStateClosed:
          _iceGrace?.cancel();
          _iceGrace = null;
          return;

        default:
          return;
      }
    };
  }

  /// Report loss ONCE, and never while deliberately closing.
  ///
  /// A transport being torn down passes through the same ICE states as one
  /// that died. Recovering a call the person is leaving would be worse than
  /// the defect this fixes.
  void _declareLost(String reason) {
    _iceGrace?.cancel();
    _iceGrace = null;
    _liveness?.cancel();
    _liveness = null;
    if (_lostReported || _closing) return;
    _lostReported = true;
    final ice = _pc?.iceConnectionState;
    final iceHealthy =
        ice == RTCIceConnectionState.RTCIceConnectionStateConnected ||
            ice == RTCIceConnectionState.RTCIceConnectionStateCompleted;
    unawaited(
        _report('op=ICE state=lost reason=$reason iceHealthy=$iceHealthy'));
    onLost?.call(reason, iceHealthy);
  }
}
