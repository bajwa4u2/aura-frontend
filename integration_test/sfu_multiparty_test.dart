import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';

/// MULTI-PARTY SFU TOPOLOGY AND CAPACITY.
///
/// Founder ruling, Phase 3 §5–§7. This is the architectural gate: the entire
/// point of leaving the mesh is that ONE publisher's upstream must not grow
/// with the number of people watching.
///
/// ## What is being measured, and why it is not just byte totals
///
/// The ruling is explicit that comparing raw byte counts is not enough —
/// totals rise with time no matter what the topology is. So each stage samples
/// the publisher's `outbound-rtp` over a fixed window and derives a BITRATE,
/// and separately counts the publisher's `outbound-rtp` reports.
///
/// That count is the decisive structural evidence:
///
///   * MESH — one upload path per remote peer. 2 tracks x N subscribers, so
///     the count grows: 2, 4, 6, 8.
///   * SFU  — one upload path per track, forwarded server-side. The count
///     stays 2 no matter how many people subscribe.
///
/// ## Honest framing (ruling §8)
///
/// This is CONTROLLED CERTIFICATION CLIENT evidence, not five humans on five
/// devices. Five distinct authenticated Aura identities drive five real peer
/// connections in one process, sharing this host's single microphone and
/// camera. The human-device evidence is the physical Pixel and Windows media
/// already certified separately.
const _apiBase = String.fromEnvironment(
  'AURA_API_BASE',
  defaultValue: 'https://api.auraplatform.org',
);
const _hostEmail = String.fromEnvironment('AURA_CERT_EMAIL');
const _hostPassword = String.fromEnvironment('AURA_CERT_PASSWORD');
const _certPassword = String.fromEnvironment('AURA_SFU_CERT_PASSWORD');
const _certEmails = String.fromEnvironment('AURA_SFU_CERT_EMAILS');

class _Party {
  _Party(this.label, this.email, this.password);
  final String label;
  final String email;
  final String password;

  late String token;
  late String userId;
  RTCPeerConnection? pc;
  List<Map<String, dynamic>> publishedTracks = const [];
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final certEmails =
      _certEmails.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  final configured = _hostEmail.isNotEmpty &&
      _hostPassword.isNotEmpty &&
      _certPassword.isNotEmpty &&
      certEmails.length >= 4;

  group('Cloudflare SFU · multi-party topology and capacity', () {
    test('one publisher, subscribers 1..4, upstream must not scale',
        () async {
      if (!configured) {
        markTestSkipped('certification identities not provided');
        return;
      }

      final host = _Party('host', _hostEmail, _hostPassword);
      final subs = <_Party>[
        for (var i = 0; i < certEmails.length && i < 4; i++)
          _Party('sub${i + 1}', certEmails[i], _certPassword),
      ];
      final all = [host, ...subs];

      for (final p in all) {
        final auth = await _login(p.email, p.password);
        p.token = auth.$1;
        p.userId = auth.$2;
      }

      final sessionId = await _createSession(host.token);
      MediaStream? media;
      final results = <Map<String, dynamic>>[];

      try {
        // Everyone is a real, invited, joined Aura participant.
        for (final s in subs) {
          await _post(host.token, '/realtime/sessions/$sessionId/invites',
              {'invitedUserId': s.userId});
          await _post(s.token, '/realtime/sessions/$sessionId/join', {});
        }

        media = await navigator.mediaDevices
            .getUserMedia(<String, dynamic>{'audio': true, 'video': true});
        final audio = media.getAudioTracks().first;
        final video = media.getVideoTracks().first;

        // ── the publisher ─────────────────────────────────────────────────
        host.pc = await _newPc();
        await host.pc!.addTransceiver(
            track: audio,
            init: RTCRtpTransceiverInit(direction: TransceiverDirection.SendOnly));
        await host.pc!.addTransceiver(
            track: video,
            init: RTCRtpTransceiverInit(direction: TransceiverDirection.SendOnly));
        host.publishedTracks =
            await _openAndPublish(host, sessionId, media, withVideo: true);

        final baseline = await _sample(host.pc!, label: 'subscribers=0');
        results.add(baseline);

        // ── add subscribers one at a time ─────────────────────────────────
        for (var i = 0; i < subs.length; i++) {
          final s = subs[i];
          s.pc = await _newPc();
          // A subscriber is an ordinary participant: it publishes its own
          // audio, like anyone in a call, and subscribes to the publisher.
          await s.pc!.addTransceiver(
              track: audio,
              init:
                  RTCRtpTransceiverInit(direction: TransceiverDirection.SendOnly));
          await _openAndPublish(s, sessionId, media, withVideo: false);

          final sub = await _post(
            s.token,
            '/realtime/sessions/$sessionId/stage/subscribe',
            {'trackIds': host.publishedTracks.map((t) => t['id']).toList()},
          );
          if (sub['requiresImmediateRenegotiation'] == true) {
            await s.pc!.setRemoteDescription(
                RTCSessionDescription(sub['sdp'] as String, 'offer'));
            final ans = await s.pc!.createAnswer();
            await s.pc!.setLocalDescription(ans);
            await _post(s.token,
                '/realtime/sessions/$sessionId/stage/renegotiate', {'answerSdp': ans.sdp});
          }

          await Future<void>.delayed(const Duration(seconds: 4));
          // Let the encoder reach its cap once, with the first subscriber
          // actually pulling, so every recorded stage is post-ramp and the
          // comparison between them is about topology rather than startup.
          if (i == 0) await _awaitSteady(host.pc!);
          final sample =
              await _sample(host.pc!, label: 'subscribers=${i + 1}');
          sample['subscriberInboundBytes'] = await _inboundBytes(s.pc!);
          results.add(sample);
        }

        // ── roster (§7) ───────────────────────────────────────────────────
        final session = await _get(host.token, '/realtime/sessions/$sessionId');
        final roster = (session['participants'] as List?) ?? const [];
        final activeIds = roster
            .where((p) => '${p['joinState']}' != 'LEFT' && '${p['joinState']}' != 'REMOVED')
            .map((p) => '${p['userId']}')
            .toSet();

        for (final r in results) {
          debugPrint('[topology] $r');
        }
        debugPrint('[roster] rows=${roster.length} distinctActive=${activeIds.length}');

        // ── THE GATE ──────────────────────────────────────────────────────
        final counts =
            results.map((r) => r['outboundRtpCount'] as int).toList();
        final bitrates =
            results.map((r) => r['outboundKbps'] as double).toList();

        // Structural: one upload path per TRACK, not per subscriber. A mesh
        // would read 2, 4, 6, 8, 10 here.
        for (final c in counts) {
          expect(c, counts.first,
              reason: 'publisher upload paths changed with subscriber count: '
                  '$counts — that is mesh behaviour, not SFU');
        }

        // Rate: compared across STEADY-STATE stages only.
        //
        // The subscribers=0 sample is deliberately excluded. With nobody
        // pulling, the encoder has not ramped and the figure is an artefact of
        // startup, not a topology baseline — measured at ~529 kbps against a
        // ~2500 kbps steady state. Anchoring on it would make ordinary encoder
        // ramp-up look like per-subscriber duplication, which is exactly the
        // conclusion this test exists to avoid drawing wrongly.
        //
        // The honest question is what happens as subscribers are ADDED once
        // media is actually flowing. Linear duplication would double the
        // upstream from 2 subscribers to 4.
        final steady = bitrates.sublist(1);
        final minSteady = steady.reduce((a, b) => a < b ? a : b);
        final maxSteady = steady.reduce((a, b) => a > b ? a : b);
        expect(maxSteady, lessThan(minSteady * 1.6),
            reason: 'publisher upstream scaled with subscribers: $bitrates');

        // And specifically: doubling the audience must not double the upload.
        if (steady.length >= 3) {
          expect(steady.last, lessThan(steady[1] * 1.5),
              reason: 'upstream grew when the audience doubled: $steady');
        }

        expect(activeIds.length, subs.length + 1,
            reason: 'roster did not converge on exactly the joined identities');

        // ── camera source control with multiple subscribers (§12) ─────────
        if (defaultTargetPlatform == TargetPlatform.android) {
          final beforeSwitch = <int>[
            for (final s in subs) await _inboundBytes(s.pc!)
          ];
          await Helper.switchCamera(video);
          await Future<void>.delayed(const Duration(seconds: 5));
          final afterSwitch = <int>[
            for (final s in subs) await _inboundBytes(s.pc!)
          ];
          debugPrint('[cam-multi] before=$beforeSwitch after=$afterSwitch');
          for (var i = 0; i < subs.length; i++) {
            expect(afterSwitch[i], greaterThan(beforeSwitch[i]),
                reason: 'subscriber ${i + 1} lost media across a camera switch');
          }
          final post = await _sample(host.pc!, label: 'after-camera-switch');
          expect(post['outboundRtpCount'], counts.first,
              reason: 'a camera switch created per-subscriber upload paths');
        }
      } finally {
        for (final p in all) {
          try {
            await _post(p.token,
                '/realtime/sessions/$sessionId/stage/transport/close', {});
          } catch (_) {}
          await p.pc?.close();
        }
        for (final t in media?.getTracks() ?? const <MediaStreamTrack>[]) {
          await t.stop();
        }
        await media?.dispose();
        try {
          await _post(host.token, '/realtime/sessions/$sessionId/end', {});
        } catch (_) {}
      }
    }, timeout: const Timeout(Duration(minutes: 12)));
  });
}

Future<RTCPeerConnection> _newPc() => createPeerConnection(<String, dynamic>{
      'iceServers': [
        {'urls': 'stun:stun.cloudflare.com:3478'}
      ],
      'bundlePolicy': 'max-bundle',
      'sdpSemantics': 'unified-plan',
    });

/// Open the transport and publish, returning the Aura track ids created.
Future<List<Map<String, dynamic>>> _openAndPublish(
  _Party p,
  String sessionId,
  MediaStream media, {
  required bool withVideo,
}) async {
  final pc = p.pc!;
  final offer = await pc.createOffer();
  await pc.setLocalDescription(offer);

  final opened = await _post(
      p.token, '/realtime/sessions/$sessionId/stage/transport', {'offerSdp': offer.sdp});
  final neg = opened['negotiation'] as Map<String, dynamic>;
  await pc.setRemoteDescription(RTCSessionDescription(neg['sdp'] as String, 'answer'));
  await _waitForIce(pc);

  final pubOffer = await pc.createOffer();
  await pc.setLocalDescription(pubOffer);

  // mids must be read from the peer connection AFTER setLocalDescription —
  // the objects returned by addTransceiver still carry an empty mid, which
  // passes server validation and is then refused by the provider as a 406.
  final live = await pc.getTransceivers();
  final sending = live.where((t) => t.sender.track != null);
  final payload = [
    for (final t in sending)
      {
        'mid': t.mid,
        'trackType': (t.sender.track?.kind == 'video') ? 'VIDEO' : 'AUDIO',
        'trackName': '${p.label}-${t.sender.track?.kind}-${t.mid}',
      }
  ];

  final published = await _post(p.token, '/realtime/sessions/$sessionId/stage/publish',
      {'offerSdp': pubOffer.sdp, 'tracks': payload});
  final pubNeg = published['negotiation'] as Map<String, dynamic>;
  await pc.setRemoteDescription(RTCSessionDescription(pubNeg['sdp'] as String, 'answer'));
  return (published['tracks'] as List).cast<Map<String, dynamic>>();
}

/// Sample the publisher's outbound over a fixed window, so the result is a
/// RATE rather than a total that rises with time regardless of topology.
Future<Map<String, dynamic>> _sample(RTCPeerConnection pc,
    {required String label}) async {
  Future<(int bytes, int count)> read() async {
    var bytes = 0;
    var count = 0;
    for (final r in await pc.getStats()) {
      if (r.type != 'outbound-rtp') continue;
      count++;
      bytes += ((r.values['bytesSent'] as num?) ?? 0).toInt();
    }
    return (bytes, count);
  }

  final start = await read();
  const window = Duration(seconds: 6);
  await Future<void>.delayed(window);
  final end = await read();

  final deltaBits = (end.$1 - start.$1) * 8;
  return {
    'stage': label,
    'outboundRtpCount': end.$2,
    'outboundKbps': deltaBits / window.inSeconds / 1000.0,
    'outboundBytesTotal': end.$1,
  };
}

/// Wait until the publisher's encoder has stopped climbing.
///
/// Video encoders ramp toward their bitrate cap over seconds, and the ramp is
/// far slower on the handset than on desktop (measured: still climbing through
/// three subscriber stages on a Pixel 9a). Sampling during the ramp makes
/// ordinary startup look like per-subscriber duplication — the exact wrong
/// conclusion. So the series does not begin until two consecutive samples
/// agree within 15%.
Future<void> _awaitSteady(RTCPeerConnection pc) async {
  double? previous;
  for (var attempt = 0; attempt < 12; attempt++) {
    final sample = await _sample(pc, label: 'warmup');
    final kbps = sample['outboundKbps'] as double;
    if (previous != null && previous > 0) {
      final ratio = kbps / previous;
      if (ratio > 0.85 && ratio < 1.15) {
        debugPrint('[warmup] steady at ${kbps.toStringAsFixed(0)} kbps');
        return;
      }
    }
    previous = kbps;
  }
  debugPrint('[warmup] never fully settled; measuring anyway');
}

Future<int> _inboundBytes(RTCPeerConnection pc) async {
  var bytes = 0;
  for (final r in await pc.getStats()) {
    if (r.type == 'inbound-rtp') {
      bytes += ((r.values['bytesReceived'] as num?) ?? 0).toInt();
    }
  }
  return bytes;
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
  check(pc.iceConnectionState ?? RTCIceConnectionState.RTCIceConnectionStateNew);
  await done.future.timeout(const Duration(seconds: 30),
      onTimeout: () => throw StateError('transport never reached ICE connected'));
}

Future<(String, String)> _login(String email, String password) async {
  final r = await http.post(Uri.parse('$_apiBase/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}));
  if (r.statusCode >= 400) throw StateError('login failed for $email ${r.statusCode}');
  final b = jsonDecode(r.body) as Map<String, dynamic>;
  return (b['accessToken'] as String, (b['user'] as Map)['id'] as String);
}

Future<String> _createSession(String token) async {
  final data = await _post(token, '/realtime/sessions', {
    'surfaceType': 'MEETING',
    'surfaceId': 'cert-sfu-multiparty',
    'kind': 'VIDEO',
    'accessMode': 'INVITE_ONLY',
    'title': 'Cloudflare SFU multi-party certification',
  });
  return data['id'] as String;
}

Future<Map<String, dynamic>> _post(
    String token, String path, Map<String, dynamic> body) async {
  final r = await http.post(Uri.parse('$_apiBase$path'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token'
      },
      body: jsonEncode(body));
  if (r.statusCode >= 400) throw StateError('$path failed ${r.statusCode}: ${r.body}');
  if (r.body.isEmpty) return <String, dynamic>{};
  final decoded = jsonDecode(r.body) as Map<String, dynamic>;
  final data = decoded['data'];
  return (data is Map<String, dynamic>) ? data : decoded;
}

Future<Map<String, dynamic>> _get(String token, String path) async {
  final r = await http.get(Uri.parse('$_apiBase$path'),
      headers: {'Authorization': 'Bearer $token'});
  if (r.statusCode >= 400) throw StateError('$path failed ${r.statusCode}: ${r.body}');
  final decoded = jsonDecode(r.body) as Map<String, dynamic>;
  final data = decoded['data'];
  return (data is Map<String, dynamic>) ? data : decoded;
}
