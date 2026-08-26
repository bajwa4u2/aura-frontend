import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';

import 'package:aura/core/auth/auth_providers.dart';
import 'package:aura/core/client_identity/client_identity_provider.dart';
import 'package:aura/features/realtime/application/realtime_controller.dart';
import 'package:aura/features/realtime/data/realtime_media_service.dart';
import 'package:aura/features/realtime/data/realtime_repository.dart';
import 'package:aura/features/realtime/data/realtime_socket_service.dart';
import 'package:aura/features/realtime/data/sfu_realtime_transport.dart';

/// 3, 4 AND 5 PARTICIPANT PARITY AT THE CONTROLLER LAYER.
///
/// The participant under test is a real `RealtimeController` — the class the
/// released client runs. The others are separate identities publishing through
/// the production transport, standing in for other devices.
///
/// They share ONE local capture deliberately. Opening five cameras on one
/// machine is a property of the harness, not of the product, and it has already
/// hung a handset once; the thing being certified is what the controller does
/// with other people's media, not whether Windows will open a webcam five
/// times.
///
/// Every assertion is about the product's own presentation state: how many
/// people it believes are present, that each appears exactly once, and that the
/// media it bound genuinely belongs to them.
const _apiBase = String.fromEnvironment(
  'AURA_API_BASE',
  defaultValue: 'https://api.auraplatform.org',
);
const _certPassword = String.fromEnvironment('AURA_SFU_CERT_PASSWORD');
const _certEmails = String.fromEnvironment('AURA_SFU_CERT_EMAILS');
const _extraEmail = String.fromEnvironment('AURA_EXTRA_EMAIL');
const _extraPassword = String.fromEnvironment('AURA_EXTRA_PASSWORD');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final certEmails =
      _certEmails.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  /// Everyone available, controller first.
  List<({String email, String password})> roster() => [
        for (final e in certEmails) (email: e, password: _certPassword),
        if (_extraEmail.isNotEmpty)
          (email: _extraEmail, password: _extraPassword),
      ];

  for (final total in <int>[3, 4, 5]) {
    testWidgets('$total participants: one identity each, media owned correctly',
        (tester) async {
      final people = roster();
      if (_certPassword.isEmpty || people.length < total) {
        markTestSkipped('need $total identities, have ${people.length}');
        return;
      }

      final me = await _login(people.first.email, people.first.password);
      final others = <_Who>[];
      for (var i = 1; i < total; i++) {
        others.add(await _login(people[i].email, people[i].password));
      }

      // The controller's identity creates the session, so the canary puts it
      // on the stage and everyone who joins inherits that transport.
      final sessionId = await _createSession(me.token);
      for (final o in others) {
        await _post(me.token, '/realtime/sessions/$sessionId/invites',
            {'invitedUserId': o.userId});
        await _post(o.token, '/realtime/sessions/$sessionId/join', {});
      }

      final transports = <SfuRealtimeTransport>[];
      MediaStream? shared;
      final container = ProviderContainer();
      final mediaService = RealtimeMediaService();
      final socket = RealtimeSocketService()..updateAccessToken(me.token);
      final tokenStore = TokenStore();
      await tokenStore.setSession(accessToken: me.token);

      final controller = RealtimeController(
        RealtimeRepository(_dio(me.token)),
        socket,
        mediaService,
        tokenStore,
        () => container.read(clientIdentityProvider.future),
        readMyUserId: () async => me.userId,
      );

      try {
        shared = await navigator.mediaDevices
            .getUserMedia(<String, dynamic>{'audio': true, 'video': true});

        for (final o in others) {
          final t = SfuRealtimeTransport(RealtimeRepository(_dio(o.token)));
          transports.add(t);
          await t.open(sessionId: sessionId, local: shared, trigger: 'HARNESS');
          await t.publishLocal(trigger: 'HARNESS');
        }

        await controller.connect();
        await controller.join(sessionId);

        var remote = <String, dynamic>{};
        for (var i = 0; i < 25; i++) {
          await Future<void>.delayed(const Duration(seconds: 1));
          final r = mediaService.currentSnapshot.remoteByParticipant;
          if (r.length >= others.length) {
            remote = r.map((k, v) => MapEntry(k, v));
            break;
          }
          remote = r.map((k, v) => MapEntry(k, v));
        }

        debugPrint(
          '[party$total] usesStage=${mediaService.usesStageTransport} '
          'remote=${remote.length} expected=${others.length} '
          'distinctIds=${remote.keys.toSet().length} '
          'joinState=${controller.state.joinState.name}',
        );

        expect(mediaService.usesStageTransport, isTrue);

        // Canonical participant count, and EXACTLY ONE presentation identity
        // each — the property the device-keyed model could not guarantee.
        expect(remote.length, others.length,
            reason: 'controller did not bind every other participant');
        expect(remote.keys.toSet().length, remote.length,
            reason: 'a participant appeared under more than one identity');

        // Ownership: every bound entry is keyed by the participant it belongs
        // to, and none of them is this participant.
        final myParticipantId = controller.state.participants
            .firstWhere((p) => p.userId == me.userId,
                orElse: () => controller.state.participants.first)
            .id;
        expect(remote.keys.contains(myParticipantId), isFalse,
            reason: 'the controller bound its own media as remote');

        // Delivery, per publisher.
        var delivered = 0;
        for (final t in transports) {
          delivered += (await t.stats()).outboundBytes;
          expect((await t.stats()).uploadPathCount, lessThanOrEqualTo(2),
              reason: 'a publisher grew upload paths with the audience');
        }
        debugPrint('[party$total] publisherOutboundTotal=$delivered');
        expect(delivered, greaterThan(0));

        // Control plane must be quiet once converged.
        final before = mediaService.currentSnapshot.remoteByParticipant.length;
        await Future<void>.delayed(const Duration(seconds: 8));
        expect(mediaService.currentSnapshot.remoteByParticipant.length, before,
            reason: 'presentation state kept changing after convergence');

        await controller.leave();
        expect(mediaService.usesStageTransport, isFalse,
            reason: 'leaving did not tear the stage down');
      } finally {
        for (final t in transports) {
          try {
            await t.close();
          } catch (_) {}
        }
        for (final t in shared?.getTracks() ?? const <MediaStreamTrack>[]) {
          await t.stop();
        }
        await shared?.dispose();
        controller.dispose();
        container.dispose();
        try {
          await _post(me.token, '/realtime/sessions/$sessionId/end', {});
        } catch (_) {}
      }
    }, timeout: const Timeout(Duration(minutes: 6)));
  }
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

Future<_Who> _login(String email, String password) async {
  final r = await http.post(Uri.parse('$_apiBase/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}));
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
    'surfaceId': 'cert-party-controller',
    'kind': 'MIXED',
    'accessMode': 'INVITE_ONLY',
    'title': 'multi-party controller parity',
  });
  return data['id'] as String;
}
