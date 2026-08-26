import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';

import 'package:aura/features/realtime/data/realtime_repository.dart';
import 'package:aura/features/realtime/data/realtime_transport.dart';
import 'package:aura/features/realtime/data/sfu_realtime_transport.dart';

/// THE TRANSPORT SEAM, EXERCISED AS PRODUCTION CODE.
///
/// Founder ruling, media-service transport seam §8 and §10. Every earlier SFU
/// proof drove Cloudflare through test-local plumbing. This one drives the
/// classes the released client will use — `RealtimeRepository` over a real
/// Dio, and `SfuRealtimeTransport` implementing the canonical
/// [RealtimeTransport] seam — so a defect in the shipped implementation fails
/// here rather than hiding behind a harness that happened to do it correctly.
///
/// Delivery is asserted, never negotiation alone. A connected transport that
/// carries no media is a FAIL: the multi-party suite once passed green while
/// delivering nothing, because it checked that the calls succeeded and never
/// checked that bytes arrived.
const _apiBase = String.fromEnvironment(
  'AURA_API_BASE',
  defaultValue: 'https://api.auraplatform.org',
);
const _hostEmail = String.fromEnvironment('AURA_CERT_EMAIL');
const _hostPassword = String.fromEnvironment('AURA_CERT_PASSWORD');
const _certPassword = String.fromEnvironment('AURA_SFU_CERT_PASSWORD');
const _certEmails = String.fromEnvironment('AURA_SFU_CERT_EMAILS');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final certEmails =
      _certEmails.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  final configured = _hostEmail.isNotEmpty &&
      _hostPassword.isNotEmpty &&
      _certPassword.isNotEmpty &&
      certEmails.isNotEmpty;

  group('Transport seam · the released client classes carry real media', () {
    test('two participants publish, bind and deliver through the seam',
        () async {
      if (!configured) {
        markTestSkipped('certification identities not provided');
        return;
      }

      final host = await _login(_hostEmail, _hostPassword);
      final guest = await _login(certEmails.first, _certPassword);

      final sessionId = await _createSession(host.token);
      await _post(host.token, '/realtime/sessions/$sessionId/invites',
          {'invitedUserId': guest.userId});
      await _post(guest.token, '/realtime/sessions/$sessionId/join', {});

      // PRODUCTION classes from here down.
      final RealtimeTransport hostTransport =
          SfuRealtimeTransport(RealtimeRepository(_dio(host.token)));
      final RealtimeTransport guestTransport =
          SfuRealtimeTransport(RealtimeRepository(_dio(guest.token)));

      MediaStream? media;
      MediaStream? guestMedia;
      try {
        debugPrint('[step] host getUserMedia');
        media = await navigator.mediaDevices
            .getUserMedia(<String, dynamic>{'audio': true, 'video': true});
        debugPrint('[step] host getUserMedia OK');
        final hasVideo = media.getVideoTracks().isNotEmpty;

        // The guest captures AUDIO ONLY.
        //
        // Two participants are normally two devices with their own cameras;
        // here one device plays both, so the guest does not also drive the
        // sensor. This is a certification shape, and it means the guest's
        // publication is audio-only in this configuration — the host is the
        // video publisher and the guest is the video subscriber.
        //
        // NOTE: this was NOT the cause of the six-minute Android hang, though
        // it was my first theory. The real cause was that a debug install does
        // not auto-grant runtime permissions, so getUserMedia blocked on a
        // dialog no one could tap. Install with `adb install -g` before
        // running on a handset.
        debugPrint('[step] guest getUserMedia');
        guestMedia = await navigator.mediaDevices
            .getUserMedia(<String, dynamic>{'audio': true, 'video': false});
        debugPrint('[step] guest getUserMedia OK');

        // ── open + publish, both sides ────────────────────────────────────
        debugPrint('[step] host open');
        await hostTransport.open(sessionId: sessionId, local: media);
        debugPrint('[step] host open OK');
        debugPrint('[step] host publish');
        await hostTransport.publishLocal();
        debugPrint('[step] host publish OK');

        debugPrint('[step] guest open');
        await guestTransport.open(sessionId: sessionId, local: guestMedia);
        debugPrint('[step] guest open OK');
        debugPrint('[step] guest publish');
        await guestTransport.publishLocal();
        debugPrint('[step] guest publish OK');

        // ── remote binding through the canonical model ────────────────────
        debugPrint('[step] guest refreshRemoteMedia');
        final remote = await guestTransport.refreshRemoteMedia();
        debugPrint('[step] guest refreshRemoteMedia OK');
        debugPrint(
          '[seam] participants=${remote.keys.length} '
          'audio=${remote.values.where((m) => m.hasAudio).length} '
          'video=${remote.values.where((m) => m.hasVideo).length}',
        );

        expect(remote, isNotEmpty,
            reason: 'the guest bound no remote media at all');
        final hostMedia = remote.values.first;
        expect(hostMedia.hasAudio, isTrue, reason: 'no remote audio bound');
        if (hasVideo) {
          expect(hostMedia.hasVideo, isTrue, reason: 'no remote video bound');
        }
        // Presentation is keyed by canonical participant identity, never by a
        // device or a provider id.
        expect(hostMedia.participantId, isNotEmpty);

        await Future<void>.delayed(const Duration(seconds: 6));

        // ── DELIVERY, not negotiation ─────────────────────────────────────
        final guestStats = await guestTransport.stats();
        final hostStats = await hostTransport.stats();
        debugPrint(
          '[seam] guestInbound=${guestStats.inboundBytes} '
          'hostOutbound=${hostStats.outboundBytes} '
          'hostUploadPaths=${hostStats.uploadPathCount}',
        );
        expect(guestStats.inboundBytes, greaterThan(0),
            reason: 'bound remote media but received no bytes');
        expect(hostStats.outboundBytes, greaterThan(0),
            reason: 'nothing was published into the SFU');
        // One upload path per TRACK. Mesh would be per track per peer.
        expect(hostStats.uploadPathCount, lessThanOrEqualTo(2),
            reason: 'publisher created more upload paths than tracks');

        // ── media controls through the seam ───────────────────────────────
        await hostTransport.setMicrophoneEnabled(false);
        await hostTransport.setMicrophoneEnabled(true);
        await hostTransport.setCameraEnabled(false);
        await hostTransport.setCameraEnabled(true);

        // ── camera source replacement through the seam (§9) ───────────────
        if (hasVideo && defaultTargetPlatform == TargetPlatform.android) {
          final before = await guestTransport.stats();
          final videoTrack = media.getVideoTracks().first;
          await Helper.switchCamera(videoTrack);
          await Future<void>.delayed(const Duration(seconds: 5));
          final after = await guestTransport.stats();
          final post = await hostTransport.stats();
          debugPrint(
            '[seam] cameraSwitch guestInboundBefore=${before.inboundBytes} '
            'after=${after.inboundBytes} hostUploadPaths=${post.uploadPathCount}',
          );
          expect(after.inboundBytes, greaterThan(before.inboundBytes),
              reason: 'the subscriber lost media across a camera switch');
          expect(post.uploadPathCount, lessThanOrEqualTo(2),
              reason: 'a camera switch created an extra upload path');
          expect(media.getVideoTracks(), hasLength(1),
              reason: 'a camera switch leaked a video track');
        }
      } finally {
        await guestTransport.close();
        await hostTransport.close();
        for (final t in media?.getTracks() ?? const <MediaStreamTrack>[]) {
          await t.stop();
        }
        await media?.dispose();
        for (final t in guestMedia?.getTracks() ?? const <MediaStreamTrack>[]) {
          await t.stop();
        }
        await guestMedia?.dispose();
        try {
          await _post(host.token, '/realtime/sessions/$sessionId/end', {});
        } catch (_) {}
      }
    }, timeout: const Timeout(Duration(minutes: 6)));
  });
}

Dio _dio(String token) => Dio(BaseOptions(
      baseUrl: _apiBase,
      headers: {'Authorization': 'Bearer $token'},
      // Without these a stalled control call hangs until the whole test times
      // out, which reports nothing useful about where it stopped.
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
      // Surface the server's own error body rather than a bare DioException,
      // which is what made the first 406 opaque.
      validateStatus: (s) => s != null && s < 400,
    ));

class _Session {
  _Session(this.token, this.userId);
  final String token;
  final String userId;
}

Future<_Session> _login(String email, String password) async {
  final r = await http.post(Uri.parse('$_apiBase/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}));
  if (r.statusCode >= 400) throw StateError('login failed $email ${r.statusCode}');
  final b = jsonDecode(r.body) as Map<String, dynamic>;
  return _Session(b['accessToken'] as String, (b['user'] as Map)['id'] as String);
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

Future<String> _createSession(String token) async {
  final data = await _post(token, '/realtime/sessions', {
    'surfaceType': 'MEETING',
    'surfaceId': 'cert-sfu-seam',
    'kind': 'VIDEO',
    'accessMode': 'INVITE_ONLY',
    'title': 'SFU transport seam certification',
  });
  return data['id'] as String;
}
