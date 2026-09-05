import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A CALL AURA PLACES MUST REACH THE SYSTEM CALL REGISTER.
///
/// CallKit has known Aura's calls in one direction since 1.4.0: incoming calls
/// are reported through `reportNewIncomingCall`. Outgoing calls were never
/// reported at all — `CXStartCallAction` appeared nowhere in the project — so
/// iOS had no record of a call Aura placed. No entry in Recents, no
/// participation in audio routing, and no defined relationship to a cellular
/// call arriving during it.
///
/// NONE OF THAT BEHAVIOUR IS OBSERVABLE FROM A DART UNIT TEST. The gate lives
/// in Swift and only a device can exercise it. What IS observable is the
/// WIRING, and the wiring is what a future calling reconstruction would remove
/// by accident. Pinned here in the same idiom as
/// china_callkit_jurisdiction_gate_test.dart.
/// Read at load time, so `expect` cannot be used here — it throws
/// `OutsideTestException` outside a test body.
String _read(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    throw StateError('Scoped native surface is missing: $path');
  }
  return file.readAsStringSync();
}

void main() {
  final appDelegate = _read('ios/Runner/AppDelegate.swift');
  final callKit = _read('lib/core/notifications/ios_call_kit.dart');
  final conversation =
      _read('lib/features/conversation/presentation/conversation_screen.dart');
  final realtime =
      _read('lib/features/realtime/application/realtime_controller.dart');

  group('iOS outgoing CallKit', () {
    test('the outgoing call is reported with CXStartCallAction', () {
      expect(appDelegate.contains('CXStartCallAction'), isTrue,
          reason: 'Without a start action iOS has nothing to log, and an '
              'outgoing Aura call appears in no call register.');
      expect(appDelegate.contains('case "startOutgoingCall":'), isTrue);
      expect(appDelegate.contains('reportOutgoingCall(with: uuid, startedConnectingAt:'),
          isTrue,
          reason: 'Recents distinguishes a call that connected from one that '
              'did not; without this it cannot.');
    });

    test('the jurisdiction gate wraps it, and refusal is not failure', () {
      final start = appDelegate.substring(
        appDelegate.indexOf('case "startOutgoingCall":'),
        appDelegate.indexOf('case "callOutgoingConnected":'),
      );
      expect(start.contains('guard callKitAllowed'), isTrue,
          reason: 'A prohibited storefront must not reach CallKit. This is the '
              'same authority the incoming path consults.');
      // The Dart side must treat a refusal as "not reported", never as a
      // failed call.
      expect(
        callKit.contains('never as "not called"') ||
            callKit.contains('`false` is an ordinary'),
        isTrue,
        reason: 'The contract that a refusal does not fail the call must be '
            'stated where callers read it.',
      );
    });

    test('one session is one call UUID, whichever direction it began in', () {
      final start = appDelegate.substring(
        appDelegate.indexOf('case "startOutgoingCall":'),
        appDelegate.indexOf('case "callOutgoingConnected":'),
      );
      expect(start.contains('callUuid(for: sessionId)'), isTrue,
          reason: 'Minting a fresh UUID for an outgoing call would give one '
              'session two system calls and break every mapping keyed on it.');
    });

    test('Aura does not act on its own start request', () {
      expect(appDelegate.contains('startingLocally'), isTrue,
          reason: 'The outgoing twin of answeringLocally. Without it the '
              'provider delegate treats Aura\'s own request as an instruction '
              'to place a call, starting a second session for the call already '
              'being started.');
      final delegate = appDelegate.substring(
        appDelegate.indexOf('perform action: CXStartCallAction'),
      );
      expect(delegate.contains('startingLocally.remove(action.callUUID)'), isTrue);
      expect(delegate.contains('action.fail()'), isTrue,
          reason: 'A system-originated start has no Aura session, conversation '
              'or acting identity. Failing is honest; inventing one is not.');
    });

    test('direction is decided natively, never guessed in Dart', () {
      expect(appDelegate.contains('outgoingCalls'), isTrue);
      final connected = appDelegate.substring(
        appDelegate.indexOf('case "callOutgoingConnected":'),
        appDelegate.indexOf('case "clearCallNotifications":'),
      );
      expect(connected.contains('outgoingCalls.contains(uuid)'), isTrue,
          reason: 'The media layer that observes "the far side is here" is the '
              'same code for a call received and a call placed. Native knows '
              'the direction; Dart must not have to.');
    });

    test('the outgoing report is wired to the real call-start path', () {
      expect(conversation.contains('reportOutgoingStarted('), isTrue,
          reason: 'Placed at _startCall, after startLive returns the session '
              'id both sides map by.');
      final idx = conversation.indexOf('reportOutgoingStarted(');
      final before = conversation.substring(0, idx);
      expect(before.lastIndexOf('startLive(') < idx, isTrue,
          reason: 'The report needs the session id, so it cannot precede it.');
    });

    test('connected is reported when the far side actually arrives', () {
      expect(realtime.contains('reportOutgoingConnected('), isTrue,
          reason: 'Without a connected timestamp the call register shows an '
              'outgoing entry with no duration.');
      expect(realtime.contains('_reportedMediaEstablished = false;'), isTrue,
          reason: 'The latch must retire on leave, or the next placed call '
              'inherits this one\'s report.');
    });

    test('remote media is observed on BOTH transports, not just mesh', () {
      // This used to assert `snapshot.remoteRenderers.isNotEmpty` alone — the
      // device-keyed map that only the MESH transport fills. On an SFU call
      // that map is permanently empty and the stage populates
      // `remoteRenderersByParticipant` instead, so the one hook that noticed
      // remote media never fired at all on SFU calls. The test passed the
      // whole time, because it was checking a spelling rather than a question.
      expect(realtime.contains('snapshot.remoteRenderers.isNotEmpty'), isTrue,
          reason: 'Mesh remote media.');
      expect(
          realtime.contains('snapshot.remoteRenderersByParticipant.isNotEmpty'),
          isTrue,
          reason: 'Stage/SFU remote media. Without this, the far side arriving '
              'is invisible on every SFU call.');
    });

    test('media is reported as evidence, never asserted as connected', () {
      // The endpoint is the only place that can observe a usable media path,
      // but it reports EVIDENCE. The backend decides CONNECTED, and only once
      // both sides have reported — one endpoint hearing silence must never be
      // able to tell the product the call connected.
      expect(realtime.contains('reportMediaEstablished('), isTrue,
          reason: 'The observation has to reach the call authority.');
      expect(realtime.contains('_hasRemoteMedia(snapshot)'), isTrue,
          reason: 'One predicate for "we can hear the other side", shared by '
              'the OS report and the backend report.');
    });
  });
}
