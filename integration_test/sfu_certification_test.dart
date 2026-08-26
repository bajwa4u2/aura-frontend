import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';

/// REAL MEDIA THROUGH THE SFU, VIA AURA'S CONTROL PLANE.
///
/// Founder ruling, Phase 3 client/real-media chapter §2–§4. Run per client:
///
///     flutter test integration_test/sfu_certification_test.dart -d windows \
///       --dart-define=AURA_CERT_EMAIL=... --dart-define=AURA_CERT_PASSWORD=...
///
/// ## What makes this evidence
///
/// The publisher sends media INTO Cloudflare and then subscribes to its own
/// track back OUT of Cloudflare. Inbound RTP therefore cannot be a loopback
/// artefact or a local echo: the only path from this process's microphone back
/// to this process's receiver runs through the SFU. If Cloudflare were not
/// actually forwarding, `bytesReceived` stays zero and this fails.
///
/// Every control call goes through Aura. The client never sees the Cloudflare
/// app secret, never names a provider session or track, and could not reach
/// another session's media if it tried — subscribe takes AURA track ids, which
/// are resolved server-side inside this session.
///
/// ## What this deliberately does NOT prove
///
/// The publisher-upstream invariant (§4). That needs one publisher and several
/// SUBSCRIBERS, and a subscriber is a second Aura participant — a second real
/// identity. Proving it is a separate step and is not claimed here.
const _apiBase = String.fromEnvironment(
  'AURA_API_BASE',
  defaultValue: 'https://api.auraplatform.org',
);
const _email = String.fromEnvironment('AURA_CERT_EMAIL');
const _password = String.fromEnvironment('AURA_CERT_PASSWORD');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final configured = _email.isNotEmpty && _password.isNotEmpty;

  group('Cloudflare SFU · real media through the Aura control plane', () {
    late String token;
    late String sessionId;

    setUpAll(() async {
      if (!configured) return;
      token = await _login();
      sessionId = await _createSession(token);
    });

    tearDownAll(() async {
      if (!configured) return;
      await _post(token, '/realtime/sessions/$sessionId/stage/transport/close', {});
      await _post(token, '/realtime/sessions/$sessionId/end', {});
    });

    test('publishes into the SFU and receives its own media back out',
        () async {
      if (!configured) {
        markTestSkipped('AURA_CERT_EMAIL / AURA_CERT_PASSWORD not provided');
        return;
      }

      final pc = await createPeerConnection(<String, dynamic>{
        'iceServers': [
          {'urls': 'stun:stun.cloudflare.com:3478'}
        ],
        // Cloudflare Realtime requires a single bundled transport.
        'bundlePolicy': 'max-bundle',
        'sdpSemantics': 'unified-plan',
      });

      MediaStream? local;
      var wantedVideo = false;

      try {
        try {
          local = await navigator.mediaDevices
              .getUserMedia(<String, dynamic>{'audio': true, 'video': true});
          wantedVideo = local.getVideoTracks().isNotEmpty;
        } catch (_) {
          // A machine with no camera is a normal certification host. Audio
          // alone still proves the SFU path; video is reported honestly as
          // absent rather than silently skipped.
          local = await navigator.mediaDevices
              .getUserMedia(<String, dynamic>{'audio': true, 'video': false});
        }

        final transceivers = <RTCRtpTransceiver>[];
        for (final track in local.getTracks()) {
          transceivers.add(await pc.addTransceiver(
            track: track,
            init: RTCRtpTransceiverInit(direction: TransceiverDirection.SendOnly),
          ));
        }

        // ── A. open the transport ──────────────────────────────────────────
        final offer = await pc.createOffer();
        await pc.setLocalDescription(offer);

        final opened = await _post(
          token,
          '/realtime/sessions/$sessionId/stage/transport',
          {'offerSdp': offer.sdp},
        );
        final openNeg = opened['negotiation'] as Map<String, dynamic>;
        expect(openNeg['sdp'], isNotNull,
            reason: 'Aura did not return the provider answer');
        await pc.setRemoteDescription(
          RTCSessionDescription(openNeg['sdp'] as String, 'answer'),
        );

        await _waitForIce(pc);

        // ── B/C/D. publish real tracks ────────────────────────────────────
        final publishOffer = await pc.createOffer();
        await pc.setLocalDescription(publishOffer);

        // Read the mids from the peer connection AFTER setLocalDescription.
        // The transceiver objects captured at addTransceiver time can still
        // carry an empty mid, and an empty string satisfies the server DTO —
        // so it would sail through validation and be rejected by the provider
        // instead, which is exactly the 406 this first produced.
        final live = await pc.getTransceivers();
        final sending =
            live.where((t) => t.sender.track != null).toList(growable: false);
        final trackPayload = sending.map((t) {
          final kind = t.sender.track?.kind ?? 'audio';
          final mid = t.mid;
          expect(mid, isNotEmpty,
              reason: 'transceiver has no mid after setLocalDescription');
          return {
            'mid': mid,
            'trackType': kind == 'video' ? 'VIDEO' : 'AUDIO',
            'trackName': 'aura-$kind-$mid',
          };
        }).toList();
        debugPrint('[sfu] publishing mids=${trackPayload.map((t) => t['mid']).toList()}');

        final published = await _post(
          token,
          '/realtime/sessions/$sessionId/stage/publish',
          {'offerSdp': publishOffer.sdp, 'tracks': trackPayload},
        );
        final pubNeg = published['negotiation'] as Map<String, dynamic>;
        final auraTracks = (published['tracks'] as List).cast<Map<String, dynamic>>();
        expect(auraTracks, hasLength(trackPayload.length),
            reason: 'Aura did not record every published track');
        await pc.setRemoteDescription(
          RTCSessionDescription(pubNeg['sdp'] as String, 'answer'),
        );

        // ── E. subscribe back OUT of the SFU ──────────────────────────────
        final inbound = <String>{};
        final gotAll = Completer<void>();
        pc.onTrack = (RTCTrackEvent e) {
          inbound.add(e.track.kind ?? '?');
          if (inbound.length >= auraTracks.length && !gotAll.isCompleted) {
            gotAll.complete();
          }
        };

        final subscribed = await _post(
          token,
          '/realtime/sessions/$sessionId/stage/subscribe',
          {'trackIds': auraTracks.map((t) => t['id']).toList()},
        );

        if (subscribed['requiresImmediateRenegotiation'] == true) {
          expect(subscribed['type'], 'offer',
              reason: 'expected the provider to offer the pulled tracks');
          await pc.setRemoteDescription(
            RTCSessionDescription(subscribed['sdp'] as String, 'offer'),
          );
          final answer = await pc.createAnswer();
          await pc.setLocalDescription(answer);
          await _post(
            token,
            '/realtime/sessions/$sessionId/stage/renegotiate',
            {'answerSdp': answer.sdp},
          );
        }

        await Future.any([
          gotAll.future,
          Future<void>.delayed(const Duration(seconds: 20)),
        ]);
        await Future<void>.delayed(const Duration(seconds: 5));

        // ── the measurement ───────────────────────────────────────────────
        var outboundBytes = 0;
        var inboundBytes = 0;
        var inboundAudio = 0;
        var inboundVideo = 0;
        for (final report in await pc.getStats()) {
          final v = report.values;
          if (report.type == 'outbound-rtp') {
            outboundBytes += ((v['bytesSent'] as num?) ?? 0).toInt();
          }
          if (report.type == 'inbound-rtp') {
            final bytes = ((v['bytesReceived'] as num?) ?? 0).toInt();
            inboundBytes += bytes;
            if ('${v['kind']}' == 'video') {
              inboundVideo += bytes;
            } else {
              inboundAudio += bytes;
            }
          }
        }

        debugPrint(
          '[sfu] platform=$defaultTargetPlatform published=${auraTracks.length} '
          'inboundKinds=$inbound outboundBytes=$outboundBytes '
          'inboundBytes=$inboundBytes inboundAudio=$inboundAudio '
          'inboundVideo=$inboundVideo videoAttached=$wantedVideo',
        );

        expect(outboundBytes, greaterThan(0),
            reason: 'nothing was sent INTO the SFU');
        // The decisive assertion: this media left the process, crossed
        // Cloudflare, and came back. There is no local path for it.
        expect(inboundBytes, greaterThan(0),
            reason: 'the SFU did not forward the published media back');

        // Evidence is taken from inbound RTP, NOT from onTrack.
        //
        // Measured on Windows 2026-08-26: onTrack did not fire for receivers
        // created by the subscribe renegotiation, while inbound-rtp showed
        // megabytes arriving. The callback is therefore not a trustworthy
        // signal that remote media exists on this platform, and asserting on
        // it would have failed a run in which the SFU was working perfectly.
        // Recorded as a finding for the client migration, because the shipped
        // mesh path drives remote tiles from onTrack.
        expect(inboundAudio, greaterThan(0),
            reason: 'no audio came back through the SFU');
        if (wantedVideo) {
          expect(inboundVideo, greaterThan(0),
              reason: 'no video came back through the SFU');
        }
      } finally {
        for (final t in local?.getTracks() ?? const <MediaStreamTrack>[]) {
          await t.stop();
        }
        await local?.dispose();
        await pc.close();
      }
    }, timeout: const Timeout(Duration(minutes: 4)));
  });
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
  await done.future.timeout(
    const Duration(seconds: 30),
    onTimeout: () => throw StateError('transport never reached ICE connected'),
  );
}

Future<Map<String, dynamic>> _post(
  String token,
  String path,
  Map<String, dynamic> body,
) async {
  final r = await http.post(
    Uri.parse('$_apiBase$path'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    },
    body: jsonEncode(body),
  );
  if (r.statusCode >= 400) {
    throw StateError('$path failed ${r.statusCode}: ${r.body}');
  }
  if (r.body.isEmpty) return <String, dynamic>{};
  final decoded = jsonDecode(r.body) as Map<String, dynamic>;
  final data = decoded['data'];
  return (data is Map<String, dynamic>) ? data : decoded;
}

Future<String> _login() async {
  final r = await http.post(
    Uri.parse('$_apiBase/auth/login'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'email': _email, 'password': _password}),
  );
  if (r.statusCode >= 400) throw StateError('login failed ${r.statusCode}');
  return (jsonDecode(r.body) as Map<String, dynamic>)['accessToken'] as String;
}

Future<String> _createSession(String token) async {
  final data = await _post(token, '/realtime/sessions', {
    'surfaceType': 'MEETING',
    'surfaceId': 'cert-sfu-$defaultTargetPlatform',
    'kind': 'VIDEO',
    'accessMode': 'INVITE_ONLY',
    'title': 'Cloudflare SFU certification ($defaultTargetPlatform)',
  });
  return data['id'] as String;
}
