import 'dart:async';

import 'package:aura/core/auth/auth_providers.dart';
import 'package:aura/core/notifications/android_call_service.dart';
import 'package:aura/core/notifications/ios_call_kit.dart';
import 'package:aura/features/realtime/application/realtime_controller.dart';
import 'package:aura/features/realtime/data/realtime_event_parser.dart';
import 'package:aura/features/realtime/data/realtime_media_service.dart';
import 'package:aura/features/realtime/data/realtime_repository.dart';
import 'package:aura/features/realtime/data/realtime_socket_service.dart';
import 'package:aura/features/realtime/domain/realtime_enums.dart';
import 'package:aura/features/realtime/domain/realtime_state.dart';
import 'package:aura/features/realtime/presentation/incoming_live_overlay.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// THE SYSTEM CALL SURFACES AGREE WITH AURA (2026-10-22 realtime audit).
///
///  * CallKit's Mute was dropped: the iPhone call screen said "muted" while
///    the microphone stayed live. Both directions now carry it.
///  * A cellular call holding Aura's call left the microphone and camera on.
///  * Answer and Decline could not be named by a screen reader or reached by
///    keyboard.
class _FakeSocket extends RealtimeSocketService {
  final StreamController<RealtimeParsedEvent> feed =
      StreamController<RealtimeParsedEvent>.broadcast();

  @override
  Stream<RealtimeParsedEvent> get events => feed.stream;
}

Dio _offlineDio() => Dio()
  ..interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) => handler.reject(
        DioException(requestOptions: options, message: 'offline in tests'),
      ),
    ),
  );

/// Records the media acts instead of performing them.
class _Probe extends RealtimeController {
  _Probe()
      : super(
          RealtimeRepository(_offlineDio()),
          _FakeSocket(),
          RealtimeMediaService(),
          TokenStore(),
          () async => null,
        );

  final mic = <({bool enabled, bool fromSystem})>[];
  final camera = <bool>[];

  void push(RealtimeState next) => state = next;

  @override
  Future<void> setMicrophone(bool enabled, {bool fromSystem = false}) async {
    mic.add((enabled: enabled, fromSystem: fromSystem));
    state = state.copyWith(microphoneEnabled: enabled);
  }

  @override
  Future<void> setCamera(bool desired) async {
    camera.add(desired);
    state = state.copyWith(cameraEnabled: desired);
  }
}

RealtimeState _inCall({bool mic = true, bool camera = true}) =>
    RealtimeState.initial().copyWith(
      joinState: RealtimeJoinState.joined,
      sessionId: 's1',
      microphoneEnabled: mic,
      cameraEnabled: camera,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => AndroidCallService.instance.debugReset());

  group('system hold stops capture, and resuming restores it', () {
    test('held turns off what was on; resumed turns it back on', () async {
      final c = _Probe()..push(_inCall());
      await c.setSystemHold('s1', held: true);
      expect(c.mic.single, (enabled: false, fromSystem: true));
      expect(c.camera.single, isFalse);

      await c.setSystemHold('s1', held: false);
      expect(c.mic.last, (enabled: true, fromSystem: true));
      expect(c.camera.last, isTrue);
      c.dispose();
    });

    test('what was off before the hold stays off after it', () async {
      final c = _Probe()..push(_inCall(mic: false, camera: false));
      await c.setSystemHold('s1', held: true);
      await c.setSystemHold('s1', held: false);
      expect(c.mic, isEmpty);
      expect(c.camera, isEmpty);
      c.dispose();
    });

    test('a hold for another call changes nothing here', () async {
      final c = _Probe()..push(_inCall());
      await c.setSystemHold('other', held: true);
      expect(c.mic, isEmpty);
      expect(c.camera, isEmpty);
      c.dispose();
    });
  });

  group('CallKit mute travels both ways', () {
    const channel = MethodChannel('org.auraplatform.app/callkit');
    final calls = <MethodCall>[];

    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return true;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      debugDefaultTargetPlatformOverride = null;
      IosCallKit.instance.onMuted = null;
    });

    test('the system screen\'s Mute reaches Aura', () async {
      final seen = <({String sessionId, bool muted})>[];
      IosCallKit.instance.onMuted =
          (sessionId, muted) async => seen.add((sessionId: sessionId, muted: muted));
      // The native side reaches Dart only once CallKit has been started.
      await IosCallKit.instance.start();
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        channel.name,
        channel.codec.encodeMethodCall(const MethodCall('onCallEvent', {
          'event': 'muted',
          'sessionId': 's1',
          'muted': true,
        })),
        (_) {},
      );
      expect(seen.single, (sessionId: 's1', muted: true));
    });

    test('a mute inside Aura is mirrored to the system screen', () async {
      final ok = await IosCallKit.instance.setMuted('s1', muted: true);
      expect(ok, isTrue);
      final call = calls.singleWhere((c) => c.method == 'setMuted');
      expect(call.arguments, {'sessionId': 's1', 'muted': true});
    });
  });

  group('Answer and Decline can be named and reached', () {
    testWidgets('screen readers read the action, keyboard activates it',
        (tester) async {
      var answered = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: IncomingCallButton(
              icon: Icons.videocam_rounded,
              label: 'Answer video call',
              color: Colors.white,
              background: Colors.green,
              size: 54,
              onTap: () => answered++,
            ),
          ),
        ),
      ));

      expect(find.bySemanticsLabel('Answer video call'), findsOneWidget);

      // Tab to it and press Enter: no pointer involved.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(answered, 1);
    });
  });
}
