import 'dart:async';

import 'package:aura/core/auth/auth_providers.dart';
import 'package:aura/core/notifications/android_call_service.dart';
import 'package:aura/features/realtime/application/realtime_controller.dart';
import 'package:aura/features/realtime/data/realtime_event_parser.dart';
import 'package:aura/features/realtime/data/realtime_media_service.dart';
import 'package:aura/features/realtime/data/realtime_repository.dart';
import 'package:aura/features/realtime/data/realtime_socket_service.dart';
import 'package:aura/features/realtime/data/sfu_realtime_transport.dart';
import 'package:aura/features/realtime/domain/realtime_enums.dart';
import 'package:aura/features/realtime/domain/realtime_state.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// THE CALL ENGINE FOLLOWS THE SESSION (2026-10-22 realtime audit).
///
///  * The Android call service lived as long as the call SCREEN: minimising a
///    call to the pill disposed the screen and stopped it, and meetings never
///    started it, so Android took the microphone away once Aura left the
///    screen. It now follows joined state, for calls and meetings alike.
///  * A refused join (`{ok: false, reason}`) read as success.
///  * A viewer whose host ended the live was told nothing.
class _FakeSocket extends RealtimeSocketService {
  final StreamController<RealtimeParsedEvent> feed =
      StreamController<RealtimeParsedEvent>.broadcast();

  @override
  Stream<RealtimeParsedEvent> get events => feed.stream;
}

class _QuietMedia extends RealtimeMediaService {
  @override
  Future<void> resetSessionMedia() async {}
}

/// State is protected on a StateNotifier; a subclass may set it, which is
/// all these tests need to stand in for the join paths.
class _Probe extends RealtimeController {
  _Probe(RealtimeSocketService socket, {Future<String> Function()? me})
      : super(
          RealtimeRepository(_offlineDio()),
          socket,
          _QuietMedia(),
          TokenStore(),
          () async => null,
          readMyUserId: me,
        );

  void push(RealtimeState next) => state = next;
}

/// A Dio that answers nothing, so no test reaches the network.
Dio _offlineDio() => Dio()
  ..interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) => handler.reject(
        DioException(requestOptions: options, message: 'offline in tests'),
      ),
    ),
  );

RealtimeState _joined(
  String sessionId, {
  bool video = false,
  bool mediaReady = true,
}) =>
    RealtimeState.initial().copyWith(
      joinState: RealtimeJoinState.joined,
      sessionId: sessionId,
      callMode: video ? 'video' : 'audio',
      cameraEnabled: video,
      isMediaReady: mediaReady,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('a refused join is not a join', () {
    test('only an explicit ok:false refuses', () {
      expect(RealtimeJoinRefused.fromAck(null), isNull);
      expect(RealtimeJoinRefused.fromAck(const <String, dynamic>{}), isNull);
      expect(RealtimeJoinRefused.fromAck(const {'ok': true}), isNull);
    });

    test('the server reason is carried, never shown raw', () {
      final refusal = RealtimeJoinRefused.fromAck(
        const {'ok': false, 'reason': 'SESSION_AT_CAPACITY'},
      );
      expect(refusal, isNotNull);
      expect(refusal!.reason, 'SESSION_AT_CAPACITY');
      expect(
        RealtimeJoinRefused.fromAck(const {'ok': false})!.reason,
        'JOIN_REFUSED',
      );
    });
  });

  group('the Android call service follows the session', () {
    const channel = MethodChannel('org.auraplatform.app/call_service');
    final calls = <MethodCall>[];
    var startAnswer = true;

    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      AndroidCallService.instance.debugReset();
      calls.clear();
      startAnswer = true;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return call.method == 'start' ? startAnswer : true;
      });
    });

    // S24, 2026-10-28 12:05:33: joined while the camera and microphone prompt
    // was still open, the service was refused, and it was never asked again.
    test('waits for the microphone before it starts', () async {
      final c = _Probe(_FakeSocket());
      c.push(_joined('s1', video: true, mediaReady: false));
      await pumpEventQueue();
      expect(calls.where((m) => m.method == 'start'), isEmpty);

      c.push(_joined('s1', video: true));
      await pumpEventQueue();
      expect(calls.where((m) => m.method == 'start'), hasLength(1));
      c.dispose();
    });

    test('a refused start is asked again on the next change', () async {
      final c = _Probe(_FakeSocket());
      startAnswer = false;
      c.push(_joined('s1'));
      await pumpEventQueue();
      expect(calls.where((m) => m.method == 'start'), hasLength(1));
      expect(AndroidCallService.instance.activeSessionId, isNull);

      startAnswer = true;
      c.push(_joined('s1').copyWith(microphoneEnabled: true));
      await pumpEventQueue();
      expect(calls.where((m) => m.method == 'start'), hasLength(2));
      expect(AndroidCallService.instance.activeSessionId, 's1');
      c.dispose();
    });

    test('a media rebuild after it started does not stop it', () async {
      final c = _Probe(_FakeSocket());
      c.push(_joined('s1'));
      await pumpEventQueue();
      c.push(_joined('s1', mediaReady: false));
      await pumpEventQueue();
      expect(calls.where((m) => m.method == 'stop'), isEmpty);
      expect(calls.where((m) => m.method == 'start'), hasLength(1));
      c.dispose();
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      debugDefaultTargetPlatformOverride = null;
    });

    test('joined starts it once; repeats send nothing; video restates it',
        () async {
      final c = _Probe(_FakeSocket());
      c.push(_joined('s1'));
      c.push(_joined('s1'));
      await pumpEventQueue();
      expect(calls.where((m) => m.method == 'start'), hasLength(1));

      c.push(_joined('s1', video: true));
      await pumpEventQueue();
      final starts = calls.where((m) => m.method == 'start').toList();
      expect(starts, hasLength(2));
      expect((starts.last.arguments as Map)['video'], isTrue);
      c.dispose();
    });

    test('a screen going away cannot stop a joined call (minimise)',
        () async {
      final c = _Probe(_FakeSocket());
      c.push(_joined('s1'));
      await pumpEventQueue();
      // The call room's dispose() calls an unnamed stop().
      final stopped = await AndroidCallService.instance.stop();
      expect(stopped, isFalse);
      expect(calls.where((m) => m.method == 'stop'), isEmpty);
      c.dispose();
    });

    test('leaving the session stops it, naming the session', () async {
      final c = _Probe(_FakeSocket());
      c.push(_joined('s1'));
      await pumpEventQueue();
      c.push(RealtimeState.initial());
      await pumpEventQueue();
      final stops = calls.where((m) => m.method == 'stop').toList();
      expect(stops, hasLength(1));
      expect((stops.single.arguments as Map)['sessionId'], 's1');
      expect(AndroidCallService.instance.heldSessionId, isNull);
      c.dispose();
    });
  });

  group('the live has ended', () {
    test('a viewer detached with live_ended is told, and stops', () async {
      final socket = _FakeSocket();
      final c = _Probe(socket, me: () async => 'viewer-1');
      c.push(_joined('live-1').copyWith(
        participants: const [],
      ));
      socket.feed.add(const RealtimeParsedEvent(
        name: 'session:participant.left',
        payload: {'userId': 'viewer-1', 'reason': 'live_ended'},
      ));
      await pumpEventQueue();
      expect(c.debugState.liveEnded, isTrue);
      expect(c.debugState.isJoined, isFalse);
      expect(c.debugState.infoMessage, 'The live has ended.');
      c.dispose();
    });

    test('someone else leaving a live ends nothing here', () async {
      final socket = _FakeSocket();
      final c = _Probe(socket, me: () async => 'viewer-1');
      c.push(_joined('live-1'));
      socket.feed.add(const RealtimeParsedEvent(
        name: 'session:participant.left',
        payload: {'userId': 'viewer-2', 'reason': 'live_ended'},
      ));
      await pumpEventQueue();
      expect(c.debugState.liveEnded, isFalse);
      expect(c.debugState.isJoined, isTrue);
      c.dispose();
    });
  });

  group('a kept transport watches again', () {
    test('rearm refuses a transport with no connection', () {
      final transport = SfuRealtimeTransport(RealtimeRepository(_offlineDio()));
      expect(transport.rearm(), isFalse);
    });
  });
}
