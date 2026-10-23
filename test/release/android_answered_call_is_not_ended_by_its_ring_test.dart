import 'dart:convert';
import 'dart:io';

import 'package:aura/core/notifications/android_telecom.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// AN ANSWERED CALL IS NOT ENDED BY ITS RING ENDING — ON ANDROID'S CALL STACK.
///
/// 2026-10-22, iPhone calling a Pixel 9a, both on 1.7.0 (46). The Pixel
/// accepted; the server's accept event reached the Pixel as "stop ringing";
/// the ring choke point ended the system call that was being answered:
///
///   20:31:46.887  Telecom: RINGING -> DISCONNECTED, cause REJECTED
///                 (overrode cause in EndCallTransaction)
///
/// And the other direction, the same evening: on the STAGE transport a placed
/// call was never reported connected, so Telecom held it in DIALING and timed
/// it out while the two people were talking.
///
/// The callee-side sibling of `caller_call_is_not_ended_by_its_own_answer_test`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final calls = <String>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('org.auraplatform.app/telecom'), (call) async {
      final args = call.arguments;
      final sid = args is Map ? '${args['sessionId']}' : '';
      calls.add('${call.method}:$sid');
      return true;
    });
    AndroidTelecom.instance.resetPlacedForTest();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('the accept event does not end the call this phone is answering',
      () async {
    await AndroidTelecom.instance.reportIncoming(
      'S1',
      displayName: 'M S Bajwa',
      video: false,
    );
    AndroidTelecom.instance.markAnswering('S1');
    await AndroidTelecom.instance.reportRingEnded('S1', reason: 'ended');
    expect(calls, isNot(contains('reportEnded:S1')),
        reason: 'this is the call Telecom recorded as REJECTED');

    await AndroidTelecom.instance.reportConnected('S1');
    expect(calls, contains('reportConnected:S1'));
  });

  test('a failed answer, or the call ending, still ends it', () async {
    AndroidTelecom.instance.markAnswering('S1');
    await AndroidTelecom.instance.reportEnded('S1', reason: 'failed');
    expect(calls, contains('reportEnded:S1'));
    expect(AndroidTelecom.instance.answeringHere('S1'), isFalse);
  });

  test('a ring this phone did not answer still ends', () async {
    AndroidTelecom.instance.markAnswering('S1');
    await AndroidTelecom.instance.reportRingEnded('S2', reason: 'declined');
    expect(calls, contains('reportEnded:S2'));
  });

  group('wiring', () {
    String code(String path) => const LineSplitter()
        .convert(File(path).readAsStringSync())
        .map((l) {
          final i = l.indexOf('//');
          return i < 0 ? l : l.substring(0, i);
        })
        .join('\n');

    test('accepting marks the call answering before the join starts', () {
      final lifecycle = code(
        'lib/features/realtime/application/thread_call_lifecycle_controller.dart',
      );
      final start = lifecycle.indexOf('Future<void> acceptIncomingCall(');
      expect(start, greaterThan(0));
      final mark =
          lifecycle.indexOf('AndroidTelecom.instance.markAnswering(', start);
      final join = lifecycle.indexOf('joinThreadCallSession(', start);
      expect(mark, greaterThan(start));
      expect(mark, lessThan(join));
    });

    test('the stage transport reports the system call connected', () {
      final controller =
          code('lib/features/realtime/application/realtime_controller.dart');
      final start = controller.indexOf('onMediaFlowing: (bytes) {');
      expect(start, greaterThan(0));
      final end = controller.indexOf('await _mediaService.attachStage(', start);
      expect(
        controller.substring(start, end),
        contains('_reportSystemCallConnected('),
      );
      final helper = controller.indexOf('void _reportSystemCallConnected(');
      final body = controller.substring(helper, helper + 600);
      expect(body, contains('AndroidTelecom.instance.reportConnected('));
      expect(body, contains('IosCallKit.instance.reportOutgoingConnected('));
    });

    // Founder, Pixel 9a, 2026-10-22: the ring arrived "minimized", Answer led
    // to the unlock prompt, then the conversation, then the call.
    group('a ringing call is a call over the lock screen', () {
      const kt = 'android/app/src/main/kotlin/org/auraplatform/app/';

      test('the ring screen is declared above the keyguard', () {
        final manifest =
            File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
        final start = manifest.indexOf('android:name=".IncomingCallActivity"');
        expect(start, greaterThan(0));
        final entry = manifest.substring(start, manifest.indexOf('/>', start));
        expect(entry, contains('android:showWhenLocked="true"'));
        expect(entry, contains('android:turnScreenOn="true"'));
        expect(entry, contains('android:exported="false"'));
      });

      test('the full-screen intent and both buttons open the ring screen', () {
        final presenter =
            File('${kt}IncomingCallPresenter.kt').readAsStringSync();
        expect(presenter, contains('.setFullScreenIntent(ring, true)'));
        expect(
          presenter,
          contains('if (ringScreen || action != ACTION_OPEN)'),
        );
      });

      test('answering never asks for the unlock', () {
        final activity = File('${kt}MainActivity.kt').readAsStringSync();
        expect(
          activity,
          contains(
            'dismissKeyguard = action == IncomingCallPresenter.ACTION_DECLINE',
          ),
        );
        final ring = File('${kt}IncomingCallActivity.kt').readAsStringSync();
        final accept = ring.substring(
          ring.indexOf('private fun accept()'),
          ring.indexOf('private fun decline()'),
        );
        expect(accept.indexOf('MainActivity.prepareForCall()'),
            lessThan(accept.indexOf('startActivity(')));
      });

      test('declining needs neither an unlock nor a running app', () {
        final ring = File('${kt}IncomingCallActivity.kt').readAsStringSync();
        expect(ring, contains('CallLiveness.reportDeclined('));
        final liveness = File('${kt}CallLiveness.kt').readAsStringSync();
        expect(liveness, contains('/invite/declined'));
      });

      test('Accept goes straight to the call screen', () {
        final bridge = code('lib/core/notifications/notification_bridge.dart');
        final start = bridge.indexOf('void _onNativeCallAction(');
        final body = bridge.substring(start, bridge.indexOf('void ', start + 30));
        expect(body, contains('NativeCallAction.answer'));
        expect(body, contains('AndroidTelecom.instance.markAnswering('));
        expect(body, contains('realtimeSessionJoinRoute('));
      });
    });
  });
}
