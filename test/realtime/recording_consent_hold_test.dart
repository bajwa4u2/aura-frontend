import 'dart:async';

import 'package:aura/core/auth/auth_providers.dart';
import 'package:aura/features/realtime/application/realtime_controller.dart';
import 'package:aura/features/realtime/data/realtime_event_parser.dart';
import 'package:aura/features/realtime/data/realtime_media_service.dart';
import 'package:aura/features/realtime/data/realtime_repository.dart';
import 'package:aura/features/realtime/data/realtime_socket_service.dart';
import 'package:aura/features/realtime/domain/realtime_enums.dart';
import 'package:aura/features/realtime/domain/realtime_state.dart';
import 'package:aura/features/realtime/presentation/widgets/consent_prompts.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// NOTHING IS PUBLISHED BEFORE A YES (realtime audit, 22 Oct 2026).
///
/// Someone joining a meeting that is being recorded is asked first. Until
/// they allow it the call engine opens no microphone or camera and offers
/// nothing to anyone; the server's own refusal to publish them is a question
/// to ask, never a failure.
class _Socket extends RealtimeSocketService {
  final feed = StreamController<RealtimeParsedEvent>.broadcast();
  final emitted = <String>[];

  @override
  Stream<RealtimeParsedEvent> get events => feed.stream;

  @override
  bool get isConnected => true;

  @override
  Future<Map<String, dynamic>> emitAck(
    String event,
    Map<String, dynamic> payload,
  ) async {
    emitted.add(event);
    return const {'ok': true};
  }
}

class _Media extends RealtimeMediaService {
  int captures = 0;

  @override
  Future<void> ensureLocalMedia({
    required bool audio,
    required bool video,
  }) async {
    captures++;
  }

  @override
  Future<void> resetSessionMedia() async {}
}

class _Repository extends RealtimeRepository {
  _Repository()
      : super(Dio()
          ..interceptors.add(InterceptorsWrapper(
            onRequest: (o, h) => h.reject(
              DioException(requestOptions: o, message: 'offline in tests'),
            ),
          )));

  final answers = <bool>[];

  @override
  Future<void> respondToRecordingConsent(
    String sessionId, {
    required bool accept,
  }) async {
    answers.add(accept);
  }
}

class _Probe extends RealtimeController {
  _Probe(this.socket, this.media, this.repository)
      : super(repository, socket, media, TokenStore(), () async => null);

  final _Socket socket;
  final _Media media;
  final _Repository repository;

  void push(RealtimeState next) => state = next;
}

RealtimeState _heldInMeeting() => RealtimeState.initial().copyWith(
      joinState: RealtimeJoinState.joined,
      sessionId: 's1',
      callMode: 'video',
      recordingConsentRequired: true,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the join ack decides the hold', () {
    expect(recordingConsentRequiredIn(null), isFalse);
    expect(recordingConsentRequiredIn(const {'ok': true}), isFalse);
    expect(
      recordingConsentRequiredIn(const {
        'recording': {'state': 'RECORDING', 'consentRequired': false},
      }),
      isFalse,
    );
    expect(
      recordingConsentRequiredIn(const {
        'recording': {'state': 'RECORDING', 'consentRequired': true},
      }),
      isTrue,
    );
  });

  test('consent refusals are recognised from HTTP and from signalling', () {
    final req = RequestOptions(path: '/realtime/stage/publish');
    DioException refused(Object data) => DioException(
          requestOptions: req,
          response: Response(requestOptions: req, statusCode: 409, data: data),
        );
    expect(
      isRecordingConsentRefusal(
          refused({'code': 'RECORDING_CONSENT_REQUIRED'})),
      isTrue,
    );
    expect(
      isRecordingConsentRefusal(refused({
        'error': {'code': 'RECORDING_CONSENT_DECLINED'},
      })),
      isTrue,
    );
    expect(
      isRecordingConsentRefusal(
          const {'ok': false, 'code': 'RECORDING_CONSENT_REQUIRED'}),
      isTrue,
    );
    expect(isRecordingConsentRefusal(refused({'code': 'SESSION_FULL'})),
        isFalse);
    expect(isRecordingConsentRefusal(const {'ok': true}), isFalse);
  });

  test('held: no capture and no offer, by any path, until Allow', () async {
    final c = _Probe(_Socket(), _Media(), _Repository());
    c.push(_heldInMeeting());

    await c.retryMedia();
    await c.retryConnection();
    c.socket.feed.add(RealtimeParsedEvent(
      name: 'session:offer',
      payload: const {
        'sessionId': 's1',
        'fromSocketId': 'peer-1',
        'sdp': {'type': 'offer', 'sdp': 'v=0'},
      },
    ));
    await pumpEventQueue();

    expect(c.media.captures, 0, reason: 'no microphone or camera opened');
    expect(c.socket.emitted, isNot(contains('session:offer')));
    expect(c.socket.emitted, isNot(contains('session:answer')));
    expect(c.socket.emitted, isNot(contains('session:audio.set')));

    await c.grantRecordingConsent();
    await pumpEventQueue();

    expect(c.repository.answers, [true], reason: 'the server is told first');
    expect(c.state.recordingConsentRequired, isFalse);
    expect(c.media.captures, 1, reason: 'Allow opens the held media');
    c.dispose();
  });

  group('why a go-live request stayed private', () {
    test('declined, expired, someone left', () {
      expect(goLiveCancelledWords('declined', 'Bilal'),
          'Bilal chose to stay private.');
      expect(goLiveCancelledWords('expired', ''),
          'No one answered in time. The call stays private.');
      expect(goLiveCancelledWords('participant_left', 'Bilal'),
          'Bilal left, so the call stays private.');
    });
    test('anything else says nothing', () {
      expect(goLiveCancelledWords('unknown', 'Bilal'), isNull);
    });
  });
}
