// LOCAL-ONLY WebRTC harness for the Meetings one-way-media defect.
//
// NOT part of the app. It is a separate entrypoint with its own main(), so it
// is never in a release bundle, never registered in router.dart, and never
// classified by the route ratchets. Run it explicitly:
//
//     flutter run -d chrome -t lib/rtc_harness/main.dart
//
// then open the SAME url in a second window. The two windows are independent
// browser contexts and are the two meeting participants.
//
// ─────────────────────────────────────────────────────────────────────────────
// WHY THIS EXISTS
//
// The production defect was a RACE: a remote offer arriving while the answerer
// was still inside getUserMedia. `handleRemoteOffer` attaches local tracks once,
// guarded by isNewPeer, so a null local stream at that instant produced an
// answer with recvonly m-lines — connected, in the roster, permanently silent,
// and unrecoverable because setCameraEnabled only flips `enabled` on tracks that
// already exist and replaceTrack needs a sender to replace.
//
// The first repair attempt shipped straight to production and broke both sides,
// because "peer has zero senders" cannot tell a broken peer from a fresh
// answerer that simply has not attached yet. So the point of this harness is not
// to run the happy path — it is to make the race deterministic and to prove the
// eligibility rule refuses the transitional states.
//
// `flutter test --platform chrome` was tried first and the Dart compiler died,
// which is why this is a real app rather than a browser test.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web/web.dart' as web;

import 'package:aura/features/realtime/data/realtime_media_service.dart';

void main() => runApp(const HarnessApp());

/// Signalling stand-in. The production socket is replaced by a same-origin
/// BroadcastChannel so the harness needs no backend, no meeting and no login —
/// the WebRTC lifecycle under test is identical either way.
class Wire {
  Wire(this.role, this.onMessage) {
    _ch = web.BroadcastChannel('aura-rtc-harness');
    _ch.onmessage = ((web.MessageEvent e) {
      final data = (e.data as JSString?)?.toDart;
      if (data == null) return;
      final msg = jsonDecode(data) as Map<String, dynamic>;
      if (msg['from'] == role) return; // ignore our own traffic
      onMessage(msg);
    }).toJS;
  }

  final String role;
  final void Function(Map<String, dynamic>) onMessage;
  late final web.BroadcastChannel _ch;

  void send(Map<String, dynamic> msg) =>
      _ch.postMessage(jsonEncode({...msg, 'from': role}).toJS);
}

class HarnessApp extends StatelessWidget {
  const HarnessApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Aura RTC harness',
        theme: ThemeData.dark(useMaterial3: true),
        home: const HarnessPage(),
      );
}

class HarnessPage extends StatefulWidget {
  const HarnessPage({super.key});
  @override
  State<HarnessPage> createState() => _HarnessPageState();
}

class _HarnessPageState extends State<HarnessPage> {
  final _svc = RealtimeMediaService();
  final _log = <String>[];
  late final Wire _wire;

  String _role = 'A';
  String get _peerKey => _role == 'A' ? 'B' : 'A';
  bool _joined = false;

  /// The race switch. When on, local media acquisition is deliberately delayed
  /// so the remote offer lands first — the exact production ordering.
  bool _delayMedia = false;
  /// How long B stalls inside getUserMedia. Tunable per run (`?racems=20000`)
  /// because the offerer must itself acquire media before it can offer — a
  /// fixed 6s window closed before A's offer could reach it, so the race
  /// silently did not occur and the run looked like a pass.
  Duration _delay = const Duration(seconds: 6);

  RTCVideoRenderer? _local;
  RTCVideoRenderer? _remote;
  String _verdict = '-';
  List<String> _sent = const [];
  Timer? _poll;
  Timer? _heartbeat;
  int _beats = 0;
  int _autoRepairs = 0;
  int _reoffers = 0;

  static const _cfg = <String, dynamic>{
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'}
    ],
  };

  @override
  void initState() {
    super.initState();
    // Role and race come from the URL so each window is deterministic rather
    // than order-dependent: ?role=A|B&race=1
    final params = Uri.base.queryParameters;
    _role = (params['role'] ?? 'A').toUpperCase() == 'B' ? 'B' : 'A';
    _delayMedia = params['race'] == '1';
    final ms = int.tryParse(params['racems'] ?? '');
    if (ms != null && ms > 0) _delay = Duration(milliseconds: ms);
    // Auto-join on boot. The race window is measured in seconds and every
    // driver round-trip costs seconds, so a human- or script-issued join
    // repeatedly landed AFTER the window closed and the run looked like a pass
    // when the race had simply never happened. Joining from the page removes
    // the driver from the critical path entirely.
    if (params['auto'] == '1') {
      WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_join()));
    }
    _installChannel();

    _wire = Wire(_role, _onSignal);
    _svc.snapshots.listen((s) {
      if (!mounted) return;
      setState(() {
        _local = s.localRenderer;
        _remote = s.remoteRenderers.values.isEmpty
            ? null
            : s.remoteRenderers.values.first;
        _sent = s.sentTrackKinds;
      });
    });
    // Poll the live eligibility verdict so the transitional states are VISIBLE,
    // not inferred from a log line after the fact.
    _poll = Timer.periodic(const Duration(milliseconds: 700), (_) async {
      await _refreshState();
    });

    // PRODUCTION-EQUIVALENT HEARTBEAT SWEEP.
    //
    // Production runs this inside RealtimeController._sendHeartbeat, on this
    // exact 10s cadence, as `repairSilentPeers()` followed by a re-offer to the
    // peers it repaired and to nobody else. The harness has no controller, so it
    // performs the SAME two steps on the SAME interval rather than a
    // harness-only shortcut — otherwise the trigger would not be what ships.
    _heartbeat = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (!_joined) return;
      _beats++;
      await _heartbeatRepairSweep();
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _cmdTimer?.cancel();
    _heartbeat?.cancel();
    _svc.dispose();
    super.dispose();
  }


  /// Control channel.
  ///
  /// Flutter Web draws to a canvas, so there are no DOM buttons to click, and
  /// `globalContext['harness']` did not survive DDC's interop — the object
  /// simply was not on globalThis. Rather than fight that, state is PUBLISHED
  /// into a DOM node and commands arrive through the URL hash. Both are plain
  /// DOM, readable and writable from any driver, and neither depends on how a
  /// particular Dart compiler models the JS global.
  void _installChannel() {
    // Commands arrive in a DOM node, NOT the URL hash: Flutter Web's router
    // owns the URL and silently cleared every hash written to it, so the first
    // channel looked wired and did nothing. A node nobody else manages cannot
    // be reset out from under the harness.
    _cmdTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      final node = web.document.getElementById('harness-cmd');
      final raw = (node?.textContent ?? '').trim();
      if (raw.isEmpty || raw == _lastCmd) return;
      _lastCmd = raw;
      // Commands are seq-prefixed ("3:camoff") so the same command can be sent
      // twice in a row and still be seen as new.
      final cmd = raw.contains(':') ? raw.split(':').last : raw;
      _say('cmd $cmd');
      _runCommand(cmd);
    });
  }

  String _lastCmd = '';
  Timer? _cmdTimer;

  void _runCommand(String cmd) {
    switch (cmd) {
      case 'join':
        unawaited(_join());
        break;
      case 'repair':
        unawaited(_repair());
        break;
      case 'camoff':
        unawaited(_svc.setCameraEnabled(false));
        break;
      case 'camon':
        unawaited(_svc.setCameraEnabled(true));
        break;
      case 'micoff':
        unawaited(_svc.setMicrophoneEnabled(false));
        break;
      case 'micon':
        unawaited(_svc.setMicrophoneEnabled(true));
        break;
      default:
        break;
    }
  }

  /// Publish state where a driver can read it without interop.
  void _publishState(String json) {
    var el = web.document.getElementById('harness-state');
    if (el == null) {
      el = web.document.createElement('div');
      el.id = 'harness-state';
      (el as web.HTMLElement).style.display = 'none';
      web.document.body?.append(el);
    }
    el.textContent = json;
  }


  /// Everything a proof needs, read from LIVE WebRTC state each tick.
  Future<void> _refreshState() async {
    final snap = _svc.currentSnapshot;
    final has = _svc.hasPeer(_peerKey);
    String verdict = 'no-peer';
    int senders = 0;
    String signalling = '-';
    var remoteKinds = <String>[];
    if (has) {
      verdict = (await _svc.peerRepairVerdict(_peerKey)).name;
      final conn = _svc.debugPeer(_peerKey);
      if (conn != null) {
        signalling = conn.signalingState?.name ?? '-';
        try {
          final sn = await conn.getSenders();
          senders = sn.where((x) => x.track != null).length;
        } catch (_) {}
        try {
          final rc = await conn.getReceivers();
          remoteKinds = rc
              .map((r) => r.track?.kind)
              .whereType<String>()
              .toList();
        } catch (_) {}
      }
    }
    final rr = snap.remoteRenderers.values;
    final remoteVideoLive = rr.isNotEmpty &&
        (rr.first.srcObject?.getVideoTracks().isNotEmpty ?? false) &&
        (rr.first.srcObject!.getVideoTracks().first.muted != true);
    final remoteAudioLive = rr.isNotEmpty &&
        (rr.first.srcObject?.getAudioTracks().isNotEmpty ?? false);
    final payload = jsonEncode({
      'role': _role,
      'race': _delayMedia,
      'joined': _joined,
      'mediaReady': snap.ready,
      'cameraEnabled': snap.cameraEnabled,
      'micEnabled': snap.micEnabled,
      'sentTrackKinds': snap.sentTrackKinds,
      'verdict': verdict,
      'signalling': signalling,
      'senderCount': senders,
      'receiverKinds': remoteKinds,
      'remoteVideoLive': remoteVideoLive,
      'remoteAudioLive': remoteAudioLive,
      'error': snap.error,
      'beats': _beats,
      'autoRepairs': _autoRepairs,
      'reoffers': _reoffers,
      'log': _log.take(6).toList(),
    });
    _publishState(payload);
    if (mounted) setState(() => _verdict = verdict);
  }

  void _say(String m) {
    // ignore: avoid_print
    print('[harness:$_role] $m');
    if (mounted) setState(() => _log.insert(0, m));
  }

  Future<void> _acquire() async {
    if (_delayMedia) {
      _say('RACE: delaying getUserMedia by ${_delay.inSeconds}s');
      await Future<void>.delayed(_delay);
    }
    await _svc.ensureLocalMedia(audio: true, video: true);
    _say('local media ready sent=${_svc.currentSnapshot.sentTrackKinds}');
  }

  /// A is the offerer, B the answerer — the production role split.
  Future<void> _join() async {
    setState(() => _joined = true);
    _say('join as $_role (delayMedia=$_delayMedia)');
    if (_role == 'A') {
      await _acquire();
      final offer = await _svc.createOffer(
        peerKey: _peerKey,
        targetSocketId: _peerKey,
        configuration: _cfg,
        onIceCandidate: (c) => _wire.send({
          'type': 'ice',
          'candidate': {
            'candidate': c.candidate,
            'sdpMid': c.sdpMid,
            'sdpMLineIndex': c.sdpMLineIndex,
          },
        }),
      );
      _wire.send({'type': 'offer', 'sdp': offer.sdp});
      _say('offer sent');
    } else {
      // B does NOT await media before signalling — that is the race.
      unawaited(_acquire());
      _wire.send({'type': 'ready'});
      _say('announced ready WITHOUT waiting for media');
    }
  }

  Future<void> _onSignal(Map<String, dynamic> m) async {
    final type = m['type'];
    try {
      if (type == 'ready' && _role == 'A' && _joined) {
        _say('peer ready — (re)offering');
        return;
      }
      if (type == 'offer') {
        _say('offer received (localMedia=${_svc.currentSnapshot.ready})');
        final answer = await _svc.handleRemoteOffer(
          peerKey: _peerKey,
          targetSocketId: _peerKey,
          polite: _role == 'B',
          configuration: _cfg,
          sdp: {'sdp': m['sdp'], 'type': 'offer'},
          onIceCandidate: (c) => _wire.send({
            'type': 'ice',
            'candidate': {
              'candidate': c.candidate,
              'sdpMid': c.sdpMid,
              'sdpMLineIndex': c.sdpMLineIndex,
            },
          }),
        );
        if (answer != null) {
          _wire.send({'type': 'answer', 'sdp': answer.sdp});
          _say('answer sent sent=${_svc.currentSnapshot.sentTrackKinds}');
        }
      } else if (type == 'answer') {
        await _svc.handleRemoteAnswer(
            peerKey: _peerKey, sdp: {'sdp': m['sdp'], 'type': 'answer'});
        _say('answer applied');
      } else if (type == 'ice') {
        await _svc.addRemoteCandidate(
            peerKey: _peerKey,
            candidate: Map<String, dynamic>.from(m['candidate'] as Map));
      }
    } catch (e) {
      _say('SIGNAL ERROR $type: $e');
    }
  }

  /// Byte-for-byte the sequence RealtimeController._repairSilentPeersIfAny()
  /// performs on each heartbeat: sweep, then re-offer ONLY to repaired peers.
  Future<void> _heartbeatRepairSweep() async {
    try {
      final repaired = await _svc.repairSilentPeers();
      if (repaired.isEmpty) return;
      _autoRepairs += repaired.length;
      _say('HEARTBEAT auto-repaired $repaired');
      for (final peerKey in repaired) {
        if (!_svc.hasPeer(peerKey)) continue;
        final offer = await _svc.createOffer(
          peerKey: peerKey,
          targetSocketId: peerKey,
          configuration: _cfg,
          onIceCandidate: (c) => _wire.send({
            'type': 'ice',
            'candidate': {
              'candidate': c.candidate,
              'sdpMid': c.sdpMid,
              'sdpMLineIndex': c.sdpMLineIndex,
            },
          }),
        );
        _wire.send({'type': 'offer', 'sdp': offer.sdp});
        _reoffers++;
        _say('HEARTBEAT re-offered to $peerKey');
      }
    } catch (error) {
      _say('HEARTBEAT sweep failed: $error');
    }
  }

  /// The repair sweep the controller would run from its heartbeat.
  Future<void> _repair() async {
    final repaired = await _svc.repairSilentPeers();
    _say('repair -> ${repaired.isEmpty ? "nothing eligible" : repaired}');
    if (repaired.isNotEmpty) {
      // Adding a track requires renegotiation.
      final offer = await _svc.createOffer(
        peerKey: _peerKey,
        targetSocketId: _peerKey,
        configuration: _cfg,
        onIceCandidate: (c) => _wire.send({
          'type': 'ice',
          'candidate': {
            'candidate': c.candidate,
            'sdpMid': c.sdpMid,
            'sdpMLineIndex': c.sdpMLineIndex,
          },
        }),
      );
      _wire.send({'type': 'offer', 'sdp': offer.sdp});
      _say('re-offered after repair');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('RTC harness — participant $_role')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton(onPressed: _joined ? null : _join, child: const Text('Join')),
              OutlinedButton(
                onPressed: _joined ? null : () => setState(() => _delayMedia = !_delayMedia),
                child: Text(_delayMedia ? 'RACE: ON' : 'RACE: off'),
              ),
              OutlinedButton(onPressed: _repair, child: const Text('Run repair sweep')),
              OutlinedButton(
                onPressed: () => _svc.setCameraEnabled(!_svc.currentSnapshot.cameraEnabled),
                child: const Text('Camera on/off'),
              ),
              OutlinedButton(
                onPressed: () => _svc.setMicrophoneEnabled(!_svc.currentSnapshot.micEnabled),
                child: const Text('Mic on/off'),
              ),
            ]),
            const SizedBox(height: 8),
            Text('verdict: $_verdict   |   senders sent: $_sent',
                style: const TextStyle(fontFamily: 'monospace')),
            const SizedBox(height: 8),
            Expanded(
              child: Row(children: [
                Expanded(child: _tile('LOCAL', _local)),
                const SizedBox(width: 8),
                Expanded(child: _tile('REMOTE', _remote)),
              ]),
            ),
            SizedBox(
              height: 140,
              child: ListView(
                children: _log
                    .map((l) => Text(l,
                        style: const TextStyle(fontSize: 11, fontFamily: 'monospace')))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(String label, RTCVideoRenderer? r) => Container(
        color: Colors.black26,
        child: Column(children: [
          Text(label),
          Expanded(
            child: r == null
                ? const Center(child: Text('none'))
                : RTCVideoView(r, mirror: label == 'LOCAL'),
          ),
        ]),
      );
}
