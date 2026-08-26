import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';

import 'package:aura/features/realtime/data/realtime_media_service.dart';
import 'package:aura/features/realtime/data/realtime_repository.dart';
import 'package:aura/features/realtime/data/sfu_realtime_transport.dart';

/// THE RELEASED MEDIA SERVICE, CARRYING REAL MEDIA OVER THE STAGE.
///
/// Founder ruling, released-client wiring §1 and §3. The previous proof drove
/// `SfuRealtimeTransport` directly. This drives `RealtimeMediaService` — the
/// class that actually owns media for every Aura call — through
/// `attachStage`, `refreshStageRemoteMedia` and `resetSessionMedia`, and reads
/// the result off the SNAPSHOT the product renders from.
///
/// What that adds over the transport proof: the canonical
/// `remoteByParticipant` really reaches the snapshot, mute/camera and camera
/// switching behave through the service rather than the transport, and the
/// product's existing teardown path tears the stage down too.
///
/// What it still does NOT prove: the actual call UI, ringing and accept. Those
/// need the server to select SFU for the session and two operated clients.
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

  group('RealtimeMediaService · stage transport', () {
    test('publishes, binds a participant, delivers bytes and tears down',
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

      // The released media service is the subject here.
      final service = RealtimeMediaService();
      final guestTransport =
          SfuRealtimeTransport(RealtimeRepository(_dio(guest.token)));
      MediaStream? guestMedia;

      try {
        // ── the publisher, through the real service ─────────────────────
        await service.ensureLocalMedia(audio: true, video: true);
        expect(service.currentSnapshot.ready, isTrue,
            reason: 'local capture never became ready');
        expect(service.usesStageTransport, isFalse,
            reason: 'no stage should be attached before the server selects it');

        await service.attachStage(
          SfuRealtimeTransport(RealtimeRepository(_dio(host.token))),
          sessionId: sessionId,
        );
        expect(service.usesStageTransport, isTrue);
        expect(service.transportId, 'sfu',
            reason: 'the service must report which transport is carrying media');

        // ── a real second participant to bind to ────────────────────────
        guestMedia = await navigator.mediaDevices
            .getUserMedia(<String, dynamic>{'audio': true, 'video': false});
        await guestTransport.open(sessionId: sessionId, local: guestMedia);
        await guestTransport.publishLocal();

        await service.refreshStageRemoteMedia();
        // The guest subscribes too. Without this it only ever publishes, so
        // asserting on ITS inbound bytes measures a direction nothing was
        // sending in — which is how the first run of this test "failed"
        // while the service was working correctly.
        final guestRemote = await guestTransport.refreshRemoteMedia();
        expect(guestRemote, isNotEmpty,
            reason: 'the guest bound no media from the service publisher');

        // ── the SNAPSHOT is what the product renders ─────────────────────
        final snapshot = service.currentSnapshot;
        final remote = snapshot.remoteByParticipant;
        debugPrint(
          '[svc] transport=${service.transportId} '
          'remoteParticipants=${remote.length} '
          'audio=${remote.values.where((m) => m.hasAudio).length} '
          'video=${remote.values.where((m) => m.hasVideo).length}',
        );

        expect(remote, isNotEmpty,
            reason: 'the service snapshot exposed no remote participant');
        final bound = remote.values.first;
        expect(bound.participantId, isNotEmpty,
            reason: 'remote media is keyed by participant identity');
        expect(bound.hasAudio, isTrue);

        await Future<void>.delayed(const Duration(seconds: 6));

        // ── DELIVERY, not negotiation ───────────────────────────────────
        final guestStats = await guestTransport.stats();
        debugPrint('[svc] guestInbound=${guestStats.inboundBytes}');
        expect(guestStats.inboundBytes, greaterThan(0),
            reason: 'the service published but nothing was delivered');

        // ── controls through the service, not the transport ──────────────
        await service.setMicrophoneEnabled(false);
        await service.setMicrophoneEnabled(true);
        await service.setCameraEnabled(false);
        await service.setCameraEnabled(true);

        if (defaultTargetPlatform == TargetPlatform.android) {
          final before = await guestTransport.stats();
          // The product's own camera control — unchanged by this migration,
          // because switching swaps the source on the same published track.
          await service.switchCamera();
          await Future<void>.delayed(const Duration(seconds: 5));
          final after = await guestTransport.stats();
          debugPrint(
            '[svc] cameraSwitch before=${before.inboundBytes} '
            'after=${after.inboundBytes}',
          );
          expect(after.inboundBytes, greaterThan(before.inboundBytes),
              reason: 'the subscriber lost media across a camera switch');
        }

        // ── the product's OWN teardown path must end the stage ───────────
        await service.resetSessionMedia();
        expect(service.usesStageTransport, isFalse,
            reason: 'resetSessionMedia left the stage transport attached');
        expect(service.currentSnapshot.remoteByParticipant, isEmpty,
            reason: 'remote media survived session reset');
      } finally {
        await guestTransport.close();
        for (final t in guestMedia?.getTracks() ?? const <MediaStreamTrack>[]) {
          await t.stop();
        }
        await guestMedia?.dispose();
        try {
          await service.resetSessionMedia();
        } catch (_) {}
        try {
          await _post(host.token, '/realtime/sessions/$sessionId/end', {});
        } catch (_) {}
      }
    }, timeout: const Timeout(Duration(minutes: 6)));

    test('the receiver converges when the other side publishes AFTER it attaches',
        () async {
      if (!configured) {
        markTestSkipped('certification identities not provided');
        return;
      }

      // THE REAL PRODUCT DEFECT, reproduced (2026-08-26).
      //
      // The party that ACCEPTS a call normally attaches before the caller has
      // finished publishing. Resolving remote media once at that moment found
      // nothing, and nothing made it look again — so in BOTH directions the
      // receiver sat in a connected call with no remote media. Two real calls
      // between two browsers showed it: caller had media, receiver never did.
      final host = await _login(_hostEmail, _hostPassword);
      final guest = await _login(certEmails.first, _certPassword);

      final sessionId = await _createSession(host.token);
      await _post(host.token, '/realtime/sessions/$sessionId/invites',
          {'invitedUserId': guest.userId});
      await _post(guest.token, '/realtime/sessions/$sessionId/join', {});

      final service = RealtimeMediaService();
      final guestTransport =
          SfuRealtimeTransport(RealtimeRepository(_dio(guest.token)));
      MediaStream? guestMedia;

      try {
        await service.ensureLocalMedia(audio: true, video: false);

        // The other side publishes only AFTER the receiver has already
        // attached — the normal order for the party that accepts a call.
        //
        // This is deliberately NOT awaited before attachStage: the product
        // gets no second chance either, so neither does the test. Nothing
        // below calls refresh by hand. If convergence inside attachStage does
        // not find the late publication, nothing will, and the receiver ends
        // up exactly where the two real browser calls left it.
        guestMedia = await navigator.mediaDevices
            .getUserMedia(<String, dynamic>{'audio': true, 'video': false});
        final publishLate = Future<void>.delayed(
          const Duration(seconds: 3),
          () async {
            await guestTransport.open(sessionId: sessionId, local: guestMedia!);
            await guestTransport.publishLocal();
          },
        );

        await service.attachStage(
          SfuRealtimeTransport(RealtimeRepository(_dio(host.token))),
          sessionId: sessionId,
        );
        await publishLate;

        final remote = service.currentSnapshot.remoteByParticipant;
        debugPrint('[converge] remoteParticipants=${remote.length}');
        expect(remote, isNotEmpty,
            reason: 'the receiver never bound media published after it attached');
        expect(remote.values.first.hasAudio, isTrue);
      } finally {
        await guestTransport.close();
        for (final t in guestMedia?.getTracks() ?? const <MediaStreamTrack>[]) {
          await t.stop();
        }
        await guestMedia?.dispose();
        try {
          await service.resetSessionMedia();
        } catch (_) {}
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
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
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
    'surfaceId': 'cert-sfu-service',
    'kind': 'VIDEO',
    'accessMode': 'INVITE_ONLY',
    'title': 'SFU media service certification',
  });
  return data['id'] as String;
}
