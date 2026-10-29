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

    // S24, 2026-10-28: declined at 12:07:09, left RINGING in Telecom until
    // Android timed it out at 12:09:05, and the 12:07:45 call was refused.
    test('a ring declined or run out here ends the Android copy too', () {
      final bridge = code('lib/features/updates/incoming_call_bridge.dart');
      String body(String start, String end) {
        final a = bridge.indexOf(start);
        expect(a, greaterThan(0), reason: start);
        final b = bridge.indexOf(end, a);
        expect(b, greaterThan(a), reason: end);
        return bridge.substring(a, b);
      }

      expect(
        body('void remove(String id', 'void removeBySession(')
            .replaceAll(RegExp(r'\s+'), ' '),
        contains('AndroidTelecom.instance.reportRingEnded(sid, reason: reason)'),
      );
      expect(
        body('void evictExpired()', 'void clear()'),
        contains('AndroidTelecom.instance.reportRingEnded('),
      );
      final overlay =
          code('lib/features/realtime/presentation/incoming_live_overlay.dart');
      final timer = overlay.indexOf('_ringTimer = Timer(_ringTimeout');
      expect(timer, greaterThan(0));
      expect(
        overlay
            .substring(timer, overlay.indexOf('markRead(id)', timer))
            .replaceAll(RegExp(r'\s+'), ''),
        contains(".remove(id,reason:'expired')"),
      );
    });

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

    // Accept to connected, Pixel 9a, 2026-10-22: 8.6 s, of which 2.5 s was
    // loading the session and re-opening the socket after Accept.
    group('the ring is spent getting ready', () {
      test('a native ring warms the session and socket', () {
        final receiver = File(
          'android/app/src/main/kotlin/org/auraplatform/app/AuraCallPushReceiver.kt',
        ).readAsStringSync();
        expect(receiver, contains('MainActivity.notifyRinging(data)'));
        final bridge = code('lib/core/notifications/notification_bridge.dart');
        expect(bridge, contains('.warmForIncoming(sessionId)'));
        final controller =
            code('lib/features/realtime/application/realtime_controller.dart');
        final warm = controller.substring(
          controller.indexOf('void warmForIncoming('),
          controller.indexOf('Future<void> _warmSocket('),
        );
        expect(warm, contains('_repository.loadSessionBundle(id)'));
        expect(warm, contains('_warmSocket()'));
        expect(warm, isNot(contains('joinSession')),
            reason: 'a ring is not an answer');
      });

      test('the in-app ring and the iPhone ring warm up too', () {
        final overlay = code(
          'lib/features/realtime/presentation/incoming_live_overlay.dart',
        );
        final ring = overlay.substring(
          overlay.indexOf('void _ensureRingTimer('),
          overlay.indexOf('void _cancelRingTimer('),
        );
        expect(ring, contains('.warmForIncoming(ringingSessionId)'));
        final app = code('lib/app/aura_app.dart');
        final ios = app.substring(
          app.indexOf('callKit.onIncomingCall ='),
          app.indexOf('callKit.onAnswer ='),
        );
        expect(ios, contains('.warmForIncoming(sessionId)'));
      });

      // Hang-up, 2026-10-22: the person who tapped Leave waited 2.5 s on the
      // call screen; the web caller, told the other side had left, 6.5 s.
      test('leaving shows the call over before the transport has closed', () {
        final controller =
            code('lib/features/realtime/application/realtime_controller.dart');
        final start = controller.indexOf('Future<void> _terminateSession(');
        final body = controller.substring(
          start,
          controller.indexOf('} finally {', start),
        );
        expect(body, contains('unawaited(Future.wait(farewells));'));
        expect(body, isNot(contains("await _socketService.emitAck('session:leave'")));
        expect(body, isNot(contains('await _repository.leaveSession(')));
        expect(
          body.indexOf('state = _copyWithDetachedMediaState('),
          lessThan(body.indexOf('await _mediaService.resetSessionMedia()')),
        );
      });

      test('the join opens the socket alongside its REST calls', () {
        final controller =
            code('lib/features/realtime/application/realtime_controller.dart');
        final start = controller.indexOf('Future<void> _performJoin(');
        final body = controller.substring(
          start,
          controller.indexOf("'session:join'", start),
        );
        final connect = body.indexOf('final socketReady = connect();');
        expect(connect, greaterThan(0));
        expect(connect, lessThan(body.indexOf('await hydrateSession(')));
        expect(body, contains('await socketReady;'));
      });
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

      // 1.7.0 (47), first video call after install: the camera prompt cannot
      // show above the keyguard, took Aura behind it, and the join timed out.
      test('a call missing a permission asks for the unlock first', () {
        final activity = File('${kt}MainActivity.kt').readAsStringSync();
        expect(activity, contains('(answering && !hasCallPermissions(data))'));
        final check = activity.substring(
          activity.indexOf('private fun hasCallPermissions('),
          activity.indexOf('/** Whether this activity is currently allowed'),
        );
        expect(check, contains('RECORD_AUDIO'));
        expect(check, contains('IncomingCallPresenter.isVideo(data)'));
        expect(check, contains('CAMERA'));
      });

      // 2026-10-22: locked, no call, Aura's conversation open and operable.
      test('the lock screen comes back the moment the call ends', () {
        final service = File('${kt}AuraCallService.kt').readAsStringSync();
        final stop = service.substring(
          service.indexOf('ACTION_STOP ->'),
          service.indexOf('override fun onTaskRemoved'),
        );
        expect(stop, contains('MainActivity.onCallEnded()'));
        final activity = File('${kt}MainActivity.kt').readAsStringSync();
        expect(activity, contains('activity.releaseLockScreenIfNoCall()'));
      });

      test('a call ribbon asks again while shown, and an ended call has none',
          () {
        final screen = code(
          'lib/features/conversation/presentation/conversation_screen.dart',
        );
        final provider = screen.substring(
          screen.indexOf('final conversationActiveLiveProvider'),
          screen.indexOf('class ConversationScreen'),
        );
        expect(provider, contains('ref.invalidateSelf'));
        expect(
          screen,
          contains(
            'if (productState == CallProductState.ended) return const SizedBox.shrink();',
          ),
        );
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
