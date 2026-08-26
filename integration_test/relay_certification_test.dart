import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';

/// CLOUDFLARE TURN RELAY CERTIFICATION, PER PLATFORM.
///
/// Founder ruling, Cloudflare migration Phase 1. Run per client:
///
///     flutter test integration_test/relay_certification_test.dart -d windows \
///       --dart-define=AURA_CERT_EMAIL=... --dart-define=AURA_CERT_PASSWORD=...
///
/// ## What makes this evidence rather than a green tick
///
/// A relay test that merely "connects" proves nothing: two peers on one host
/// connect over host candidates without a TURN server being involved at all.
/// So this constrains the path twice over —
///
///   1. `iceTransportPolicy: 'relay'` forbids host and server-reflexive
///      candidates outright; and
///   2. the ICE server list is reduced to the single
///      `turns:...:443?transport=tcp` URL, so even the relay that *is*
///      permitted has exactly one way to exist.
///
/// If Cloudflare TURN over TLS/443 does not work on this platform, this cannot
/// silently pass — there is no remaining path for it to pass on.
///
/// Credentials are minted through the REAL Aura backend
/// (`POST /realtime/turn-credentials`), not handed to the client, because the
/// ruling requires the issuance path itself to be exercised. The account must
/// be named in `REALTIME_RELAY_CERTIFICATION_IDENTITIES` server-side; every
/// other identity keeps the legacy relay.
const _apiBase = String.fromEnvironment(
  'AURA_API_BASE',
  defaultValue: 'https://api.auraplatform.org',
);
const _email = String.fromEnvironment('AURA_CERT_EMAIL');
const _password = String.fromEnvironment('AURA_CERT_PASSWORD');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final configured = _email.isNotEmpty && _password.isNotEmpty;

  group('Cloudflare TURN · relay-only certification', () {
    late String token;
    late String sessionId;
    late List<Map<String, dynamic>> iceServers;

    setUpAll(() async {
      if (!configured) return;
      token = await _login();
      sessionId = await _createSession(token);
      iceServers = await _issueCredentials(token, sessionId);
    });

    tearDownAll(() async {
      if (!configured) return;
      // A certification must not leave a live session behind. The ruling lists
      // "no stale session" as its own gate, and the measured production defect
      // this migration sits beside was exactly that.
      await _endSession(token, sessionId);
    });

    test('the backend issues CLOUDFLARE credentials for this identity', () {
      if (!configured) {
        markTestSkipped('AURA_CERT_EMAIL / AURA_CERT_PASSWORD not provided');
        return;
      }
      final urls = _urlsOf(iceServers);
      expect(urls, isNotEmpty);
      expect(
        urls.any((u) => u.contains('cloudflare')),
        isTrue,
        reason: 'issuance served a non-Cloudflare relay: $urls',
      );
    });

    test('the issued set carries TURN/TLS on 443', () {
      if (!configured) {
        markTestSkipped('not configured');
        return;
      }
      expect(
        _urlsOf(iceServers).any(_isTls443),
        isTrue,
        reason:
            'no turns: URL on 443 — the capability this migration exists for',
      );
    });

    test('media traverses Cloudflare TURN over TLS/443 on this platform',
        () async {
      if (!configured) {
        markTestSkipped('not configured');
        return;
      }

      final tls443 = _urlsOf(iceServers).where(_isTls443).toList();
      final server =
          iceServers.firstWhere((s) => _urlsOfOne(s).any(_isTls443));

      // ONE url only. Nothing else can carry this connection.
      final config = <String, dynamic>{
        'iceServers': [
          {
            'urls': tls443,
            'username': server['username'],
            'credential': server['credential'],
          }
        ],
        'iceTransportPolicy': 'relay',
        'sdpSemantics': 'unified-plan',
      };

      final a = await createPeerConnection(config);
      final b = await createPeerConnection(config);
      MediaStream? local;
      var mediaAttached = false;

      try {
        // Real audio where the platform has a capture device. Where it does
        // not, say so rather than quietly certifying a data channel as media.
        try {
          local = await navigator.mediaDevices
              .getUserMedia(<String, dynamic>{'audio': true, 'video': false});
          for (final t in local.getTracks()) {
            await a.addTrack(t, local);
          }
          mediaAttached = true;
        } catch (e) {
          debugPrint('[cert] no capture device, falling back to data only: $e');
        }

        final connected = Completer<void>();
        var inboundKind = '';
        b.onTrack = (RTCTrackEvent e) => inboundKind = e.track.kind ?? '';
        a.onIceCandidate = (c) => b.addCandidate(c);
        b.onIceCandidate = (c) => a.addCandidate(c);
        a.onConnectionState = (s) {
          if (s == RTCPeerConnectionState.RTCPeerConnectionStateConnected &&
              !connected.isCompleted) {
            connected.complete();
          }
        };

        final dc = await a.createDataChannel('probe', RTCDataChannelInit());
        final offer = await a.createOffer();
        await a.setLocalDescription(offer);
        await b.setRemoteDescription(offer);
        final answer = await b.createAnswer();
        await b.setLocalDescription(answer);
        await a.setRemoteDescription(answer);

        await connected.future.timeout(
          const Duration(seconds: 45),
          onTimeout: () => throw StateError(
            'no relay-only connection over TLS/443 on '
            '$defaultTargetPlatform — Cloudflare TURN did not carry it',
          ),
        );

        await dc.send(RTCDataChannelMessage('aura-relay-probe'));
        await Future<void>.delayed(const Duration(seconds: 3));

        final pair = await _selectedPair(a);
        expect(pair, isNotNull, reason: 'no succeeded candidate pair');

        expect(pair!['localType'], 'relay',
            reason: 'local candidate was not a relay candidate');
        expect(pair['remoteType'], 'relay',
            reason: 'remote candidate was not a relay candidate');

        final bytes = (pair['bytesSent'] as num?) ?? 0;
        expect(bytes, greaterThan(0),
            reason: 'connected but nothing was actually transmitted');

        debugPrint(
          '[cert] platform=$defaultTargetPlatform RELAY-ONLY TLS/443 PASS '
          'url=$tls443 localType=${pair['localType']} '
          'remoteType=${pair['remoteType']} '
          'relayProtocol=${pair['relayProtocol']} '
          'bytesSent=${pair['bytesSent']} bytesReceived=${pair['bytesReceived']} '
          'mediaAttached=$mediaAttached inbound=$inboundKind',
        );
      } finally {
        // Device/media cleanup is itself a gate.
        for (final t in local?.getTracks() ?? const <MediaStreamTrack>[]) {
          await t.stop();
        }
        await local?.dispose();
        await a.close();
        await b.close();
      }
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('an ORDINARY call still connects on the production ICE set',
        () async {
      if (!configured) {
        markTestSkipped('not configured');
        return;
      }

      // The preservation half of the migration. The test above deliberately
      // forbids every path except the relay, which is the opposite of how a
      // real call behaves — most connect directly and never touch TURN. This
      // one takes the ICE set exactly as the backend issued it, with no
      // transport policy at all, and asks the only question that matters after
      // a provider flip: does an ordinary call still work?
      final config = <String, dynamic>{
        'iceServers': iceServers,
        'sdpSemantics': 'unified-plan',
      };

      final a = await createPeerConnection(config);
      final b = await createPeerConnection(config);
      MediaStream? local;

      try {
        try {
          local = await navigator.mediaDevices
              .getUserMedia(<String, dynamic>{'audio': true, 'video': false});
          for (final t in local.getTracks()) {
            await a.addTrack(t, local);
          }
        } catch (e) {
          debugPrint('[cert] ordinary: no capture device: $e');
        }

        final connected = Completer<void>();
        var inboundKind = '';
        b.onTrack = (RTCTrackEvent e) => inboundKind = e.track.kind ?? '';
        a.onIceCandidate = (c) => b.addCandidate(c);
        b.onIceCandidate = (c) => a.addCandidate(c);
        a.onConnectionState = (s) {
          if (s == RTCPeerConnectionState.RTCPeerConnectionStateConnected &&
              !connected.isCompleted) {
            connected.complete();
          }
        };

        final offer = await a.createOffer();
        await a.setLocalDescription(offer);
        await b.setRemoteDescription(offer);
        final answer = await b.createAnswer();
        await b.setLocalDescription(answer);
        await a.setRemoteDescription(answer);

        await connected.future.timeout(
          const Duration(seconds: 45),
          onTimeout: () => throw StateError(
            'an ordinary call did NOT connect on $defaultTargetPlatform after '
            'the relay provider changed — this is a regression',
          ),
        );

        await Future<void>.delayed(const Duration(seconds: 3));
        final pair = await _selectedPair(a);
        expect(pair, isNotNull);
        expect((pair!['bytesSent'] as num?) ?? 0, greaterThan(0));

        debugPrint(
          '[cert] platform=$defaultTargetPlatform ORDINARY CALL PASS '
          'localType=${pair['localType']} remoteType=${pair['remoteType']} '
          'bytesSent=${pair['bytesSent']} inbound=$inboundKind',
        );
      } finally {
        for (final t in local?.getTracks() ?? const <MediaStreamTrack>[]) {
          await t.stop();
        }
        await local?.dispose();
        await a.close();
        await b.close();
      }
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}

bool _isTls443(String u) => u.startsWith('turns:') && u.contains(':443');

List<String> _urlsOfOne(Map<String, dynamic> s) {
  final raw = s['urls'];
  if (raw is List) return raw.map((e) => '$e').toList();
  return raw == null ? <String>[] : ['$raw'];
}

List<String> _urlsOf(List<Map<String, dynamic>> servers) =>
    servers.expand(_urlsOfOne).toList();

Future<Map<String, dynamic>?> _selectedPair(RTCPeerConnection pc) async {
  final reports = await pc.getStats();
  Map<dynamic, dynamic>? chosen;
  for (final r in reports) {
    if (r.type != 'candidate-pair') continue;
    final v = r.values;
    if ('${v['state']}' != 'succeeded') continue;
    chosen ??= v;
    if (v['nominated'] == true) {
      chosen = v;
      break;
    }
  }
  if (chosen == null) return null;

  Map<dynamic, dynamic>? byId(String? id) {
    if (id == null) return null;
    for (final r in reports) {
      if (r.id == id) return r.values;
    }
    return null;
  }

  final localC = byId('${chosen['localCandidateId']}');
  final remoteC = byId('${chosen['remoteCandidateId']}');
  return {
    'localType': '${localC?['candidateType']}',
    'remoteType': '${remoteC?['candidateType']}',
    'relayProtocol': '${localC?['relayProtocol']}',
    'url': '${localC?['url']}',
    'bytesSent': chosen['bytesSent'],
    'bytesReceived': chosen['bytesReceived'],
  };
}

Future<String> _login() async {
  final r = await http.post(
    Uri.parse('$_apiBase/auth/login'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'email': _email, 'password': _password}),
  );
  if (r.statusCode >= 400) {
    throw StateError('login failed ${r.statusCode}');
  }
  return (jsonDecode(r.body) as Map<String, dynamic>)['accessToken'] as String;
}

Future<String> _createSession(String token) async {
  final r = await http.post(
    Uri.parse('$_apiBase/realtime/sessions'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    },
    body: jsonEncode({
      'surfaceType': 'MEETING',
      'surfaceId': 'cert-turn-$defaultTargetPlatform',
      'kind': 'AUDIO',
      'accessMode': 'INVITE_ONLY',
      'title': 'Cloudflare TURN certification ($defaultTargetPlatform)',
    }),
  );
  if (r.statusCode >= 400) {
    throw StateError('session create failed ${r.statusCode}: ${r.body}');
  }
  final body = jsonDecode(r.body) as Map<String, dynamic>;
  return (body['data'] as Map<String, dynamic>)['id'] as String;
}

Future<List<Map<String, dynamic>>> _issueCredentials(
    String token, String sessionId) async {
  final r = await http.post(
    Uri.parse('$_apiBase/realtime/turn-credentials'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    },
    body: jsonEncode({'sessionId': sessionId}),
  );
  if (r.statusCode >= 400) {
    throw StateError('turn-credentials failed ${r.statusCode}: ${r.body}');
  }
  final body = jsonDecode(r.body) as Map<String, dynamic>;
  final data = (body['data'] ?? body) as Map<String, dynamic>;
  return (data['iceServers'] as List).cast<Map<String, dynamic>>();
}

Future<void> _endSession(String token, String sessionId) async {
  await http.post(
    Uri.parse('$_apiBase/realtime/sessions/$sessionId/end'),
    headers: {'Authorization': 'Bearer $token'},
  );
}
