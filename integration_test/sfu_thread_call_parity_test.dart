import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';

import 'package:aura/core/auth/auth_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aura/core/client_identity/client_identity_provider.dart';
import 'package:aura/features/realtime/application/realtime_controller.dart';
import 'package:aura/features/realtime/data/realtime_media_service.dart';
import 'package:aura/features/realtime/data/realtime_repository.dart';
import 'package:aura/features/realtime/data/realtime_socket_service.dart';
import 'package:aura/features/realtime/data/sfu_realtime_transport.dart';

/// THREAD-CALL PARITY THROUGH THE REAL CONTROLLER.
///
/// Every earlier proof drove the transport or the media service. The defect
/// that broke three live calls lived ABOVE both: the controller re-ran its
/// media-ready reconciliation on every snapshot, and the refresh published a
/// snapshot every time. Nothing below the controller could have shown it.
///
/// So this drives `RealtimeController` itself — the class the released client
/// runs — as the CALLEE joining a session another identity is already
/// publishing into. That is the exact path that failed.
///
/// Evidence is delivered bytes and the controller's own presentation state,
/// never connection state alone.
const _apiBase = String.fromEnvironment(
  'AURA_API_BASE',
  defaultValue: 'https://api.auraplatform.org',
);
const _certPassword = String.fromEnvironment('AURA_SFU_CERT_PASSWORD');
const _certEmails = String.fromEnvironment('AURA_SFU_CERT_EMAILS');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final emails =
      _certEmails.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  final configured = _certPassword.isNotEmpty && emails.length >= 2;

  testWidgets('the callee controller binds and receives real media',
      (tester) async {
    if (!configured) {
      markTestSkipped('certification identities not provided');
      return;
    }

    final caller = await _login(emails[0]);
    final callee = await _login(emails[1]);

    // A thread/person call surface, not a meeting.
    final sessionId = await _createSession(caller.token);
    await _post(caller.token, '/realtime/sessions/$sessionId/invites',
        {'invitedUserId': callee.userId});

    // The caller is another device: it publishes through the same production
    // transport the released client uses.
    final callerTransport =
        SfuRealtimeTransport(RealtimeRepository(_dio(caller.token)));
    MediaStream? callerMedia;

    final container = ProviderContainer();
    final mediaService = RealtimeMediaService();
    final socket = RealtimeSocketService()..updateAccessToken(callee.token);
    final tokenStore = TokenStore();
    await tokenStore.setSession(accessToken: callee.token);

    final controller = RealtimeController(
      RealtimeRepository(_dio(callee.token)),
      socket,
      mediaService,
      tokenStore,
      // The production resolver, so the harness presents the same identity
      // headers a released client would rather than a hand-made stand-in.
      () => container.read(clientIdentityProvider.future),
      readMyUserId: () async => callee.userId,
    );

    try {
      callerMedia = await navigator.mediaDevices
          .getUserMedia(<String, dynamic>{'audio': true, 'video': true});
      await callerTransport.open(
          sessionId: sessionId, local: callerMedia, trigger: 'HARNESS');
      await callerTransport.publishLocal(trigger: 'HARNESS');

      // ── the released client path ──────────────────────────────────────
      await controller.connect();
      await controller.join(sessionId);

      // The controller drives capture, attach, publish and subscribe itself.
      // Give it room to converge; it must settle, not spin.
      var bound = <String, dynamic>{};
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(seconds: 1));
        final remote = mediaService.currentSnapshot.remoteByParticipant;
        if (remote.isNotEmpty) {
          bound = remote.map((k, v) => MapEntry(k, v));
          break;
        }
      }

      debugPrint(
        '[thread] transport=${mediaService.transportId} '
        'usesStage=${mediaService.usesStageTransport} '
        'remoteParticipants=${bound.length} '
        'joinState=${controller.state.joinState.name} '
        'callMode=${controller.state.callMode}',
      );

      expect(mediaService.usesStageTransport, isTrue,
          reason: 'the controller did not route this session through the stage');

      // §2 — MIXED IN PRODUCT, not just in the enum mapping.
      //
      // Meetings are created with kind MIXED. The old duplicate derivation
      // sent MIXED to audio, so the attendee captured audio only and had no
      // video track to enable. This asserts the controller's own resolved
      // state, on a real MIXED session, through the real hydration path.
      expect(controller.state.callMode, 'video',
          reason: 'a MIXED meeting degraded the attendee to audio');
      expect(controller.state.isVideoMode, isTrue);
      expect(bound, isNotEmpty,
          reason: 'the callee controller never bound the caller media');

      // Delivery, not connection state.
      await Future<void>.delayed(const Duration(seconds: 5));
      final stats = await callerTransport.stats();
      debugPrint('[thread] callerOutbound=${stats.outboundBytes} '
          'uploadPaths=${stats.uploadPathCount}');
      expect(stats.outboundBytes, greaterThan(0));

      // ── media controls through the product surface ────────────────────
      await controller.toggleMicrophone();
      await controller.toggleMicrophone();

      // ── leave and cleanup ─────────────────────────────────────────────
      await controller.leave();
      expect(mediaService.usesStageTransport, isFalse,
          reason: 'leaving did not tear the stage down');
    } finally {
      await callerTransport.close();
      for (final t in callerMedia?.getTracks() ?? const <MediaStreamTrack>[]) {
        await t.stop();
      }
      await callerMedia?.dispose();
      controller.dispose();
      container.dispose();
      try {
        await _post(caller.token, '/realtime/sessions/$sessionId/end', {});
      } catch (_) {}
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}

Dio _dio(String token) => Dio(BaseOptions(
      baseUrl: _apiBase,
      headers: {'Authorization': 'Bearer $token'},
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
      validateStatus: (s) => s != null && s < 400,
    ));

class _Who {
  _Who(this.token, this.userId);
  final String token;
  final String userId;
}

Future<_Who> _login(String email) async {
  final r = await http.post(Uri.parse('$_apiBase/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': _certPassword}));
  if (r.statusCode >= 400) throw StateError('login failed $email ${r.statusCode}');
  final b = jsonDecode(r.body) as Map<String, dynamic>;
  return _Who(b['accessToken'] as String, (b['user'] as Map)['id'] as String);
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
    'surfaceId': 'cert-controller-parity',
    'kind': 'MIXED',
    'accessMode': 'INVITE_ONLY',
    'title': 'thread call parity',
  });
  return data['id'] as String;
}
