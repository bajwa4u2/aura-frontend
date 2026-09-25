import 'dart:convert';
import 'dart:io';

import 'package:aura/core/notifications/android_telecom.dart';
import 'package:aura/core/notifications/ios_call_kit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// A CALL IS NOT ENDED BY BEING ANSWERED — ON THE CALLER EITHER.
///
/// Root-caused 2026-09-25 from an iPhone's own system log, TestFlight
/// 1.5.0 (40), iPhone calling a Pixel. Video both ways, no audio either way;
/// an audio-only call looked as if it never connected:
///
///   05:34:30.84  CallKit activates the outgoing call's audio session
///   05:34:35.85  Provider was asked to report that call ... ended ... reason 2
///   05:34:35.85  callservicesd: Setting disconnected reason to remote hangup
///   05:34:35.94  AudioToolboxServerHandleInterruption Stop Now ... Runner
///
/// The Pixel accepted; `participant.accepted` reached the caller; the incoming
/// call bridge projected it as "stop ringing"; its terminal choke point reported
/// the system call ended. The system call id is derived from the session id in
/// both directions, so the call it ended was the one this phone placed.
///
/// The sibling of `call_accept_is_not_termination_test.dart` (08-30), which
/// pinned the same mistake on the callee.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final calls = <String>[];

  void recordChannel(String name) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannel(name), (call) async {
      final args = call.arguments;
      final sid = args is Map ? '${args['sessionId']}' : '';
      calls.add('${call.method}:$sid');
      return true;
    });
  }

  setUp(() {
    calls.clear();
    recordChannel('org.auraplatform.app/callkit');
    recordChannel('org.auraplatform.app/telecom');
    IosCallKit.instance.resetPlacedForTest();
    AndroidTelecom.instance.resetPlacedForTest();
  });

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  group('iOS — CallKit', () {
    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.iOS);

    test('the callee answering does not end the call this phone placed',
        () async {
      await IosCallKit.instance.reportOutgoingStarted(
        'S1',
        displayName: 'Pixel',
        video: true,
      );
      // participant.accepted -> "stop ringing" -> the bridge's choke point.
      await IosCallKit.instance.reportRingEnded('S1', reason: 'ended');

      expect(calls, contains('startOutgoingCall:S1'));
      expect(calls, isNot(contains('endCall:S1')),
          reason: 'this is the call that went silent both ways');
    });

    test('ending the call still ends it', () async {
      await IosCallKit.instance.reportOutgoingStarted(
        'S1',
        displayName: 'Pixel',
        video: false,
      );
      await IosCallKit.instance.reportEnded('S1', reason: 'ended');
      expect(calls, contains('endCall:S1'));
      expect(IosCallKit.instance.placedHere('S1'), isFalse);
    });

    test('a ring that really rang here still ends', () async {
      await IosCallKit.instance.reportRingEnded('S2', reason: 'answeredElsewhere');
      expect(calls, contains('endCall:S2'));
    });
  });

  group('Android — Telecom', () {
    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);

    test('the callee answering does not end the call this phone placed',
        () async {
      await AndroidTelecom.instance.reportOutgoing(
        'S1',
        displayName: 'iPhone',
        video: true,
      );
      await AndroidTelecom.instance.reportRingEnded('S1', reason: 'ended');
      expect(calls, contains('reportOutgoing:S1'));
      expect(calls, isNot(contains('reportEnded:S1')));
    });

    test('ending the call still ends it; a real ring still ends', () async {
      await AndroidTelecom.instance.reportOutgoing(
        'S1',
        displayName: 'iPhone',
        video: false,
      );
      await AndroidTelecom.instance.reportEnded('S1', reason: 'ended');
      await AndroidTelecom.instance.reportRingEnded('S2', reason: 'ended');
      expect(calls, containsAll(<String>['reportEnded:S1', 'reportEnded:S2']));
    });
  });

  group('wiring', () {
    String code(String path) => const LineSplitter()
        .convert(File(path).readAsStringSync())
        .map((l) {
          final i = l.indexOf('//');
          return i < 0 ? l : l.substring(0, i);
        })
        .join('\n');

    // The bridge's two other direct ends — the person tapping Decline on a
    // ringing card, and a ring expiring — act only on cards ringing on this
    // phone, so they stay. The choke point is the one every socket clear
    // reaches, and it is the one that ended the caller's call.
    test('the ring choke point ends only rings', () {
      final bridge = code('lib/features/updates/incoming_call_bridge.dart');
      final start = bridge.indexOf('void _onSessionTerminated(');
      final end = bridge.indexOf('void clearAccepted(', start);
      expect(start, greaterThan(0));
      final chokePoint = bridge.substring(start, end);
      expect(chokePoint, contains('IosCallKit.instance.reportRingEnded('));
      expect(chokePoint, contains('AndroidTelecom.instance.reportRingEnded('));
      expect(chokePoint, isNot(contains('IosCallKit.instance.reportEnded(')));
      expect(chokePoint, isNot(contains('AndroidTelecom.instance.reportEnded(')));
    });

    test('the far end hanging up ends the system call where the call ends', () {
      final controller =
          code('lib/features/realtime/application/realtime_controller.dart');
      final ended = controller.indexOf("case 'session:ended':");
      final nextCase = controller.indexOf("case 'session:stale':", ended);
      expect(ended, greaterThan(0));
      final branch = controller.substring(ended, nextCase);
      expect(branch, contains('IosCallKit.instance.reportEnded('));
      expect(branch, contains('AndroidTelecom.instance.reportEnded('));
    });
  });
}
