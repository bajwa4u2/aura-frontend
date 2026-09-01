import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// ONE INCOMING CALL, ONE USER-VISIBLE RING.
///
/// An iPhone is one physical device reachable several ways: a PushKit VoIP
/// push that CallKit presents, an ordinary APNs alert, a realtime socket, and
/// Aura's own in-app card. Those are delivery mechanisms. They must not become
/// competing user experiences.
///
/// Build 1.4.0 (35) shipped with two of them presenting at once and with the
/// banner never retiring, which is the shape of the publicly disclosed
/// incoming-call defects. This file pins the wiring that separates DELIVERY
/// REDUNDANCY (kept, deliberately) from PRESENTATION DUPLICATION (removed).
///
/// Wiring, not behaviour: the behaviour lives in Swift and in the backend, and
/// is covered by ios/RunnerTests/RunnerTests.swift and the jest suites. What a
/// Dart test can hold is the seam — and the seam is what a future calling
/// reconstruction would quietly unhook.
/// The PAIRED backend checkout, resolved rather than assumed.
///
/// The assertions in the backend group read a DIFFERENT REPOSITORY, so a
/// hardcoded sibling path silently changes meaning the moment either side is
/// checked out somewhere else — which is exactly what happened once the
/// calling work moved into an isolated git worktree: the path still resolved,
/// to a checkout that did not contain the work, and seven seams failed for a
/// reason that had nothing to do with the seams.
///
/// Resolution is deterministic and deliberately NOT content-seeking. It never
/// asks which directory contains the expected text — a resolver that shopped
/// for a passing tree could always satisfy itself, and would not be a test.
/// It asks only which directory is a backend checkout, in a fixed order:
/// an explicit override, then the worktree that pairs with an isolated client
/// checkout, then the ordinary sibling.
const String _defaultBackendRoot = '../aura-backend';

String? _resolveBackendRoot() {
  final override = Platform.environment['AURA_BACKEND_ROOT'];
  final here = Directory.current.path.replaceAll(r'\', '/').split('/').last;
  final candidates = <String>[
    if (override != null && override.trim().isNotEmpty) override.trim(),
    if (here.endsWith('-calling')) '$_defaultBackendRoot-calling',
    _defaultBackendRoot,
  ];
  for (final root in candidates) {
    if (Directory('$root/src/common/devices').existsSync()) return root;
  }
  return null;
}

String _read(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: 'missing source file: $path');
  return file.readAsStringSync();
}

/// Source with comments removed.
///
/// Both Swift and Dart here explain, in prose, the very thing the assertion
/// forbids — "DELIBERATELY NOT GATED ON callKitAllowed", "Deliberately NOT
/// reportEnded". A scan that reads comments would fail on its own
/// documentation, and one that could be satisfied by moving a call behind a
/// comment marker would not be a scan at all.
String _stripComments(String source) {
  final out = StringBuffer();
  var i = 0;
  while (i < source.length) {
    if (source.startsWith('//', i)) {
      final end = source.indexOf('\n', i);
      if (end == -1) break;
      i = end;
      continue;
    }
    if (source.startsWith('/*', i)) {
      final end = source.indexOf('*/', i + 2);
      i = end == -1 ? source.length : end + 2;
      continue;
    }
    out.write(source[i]);
    i++;
  }
  return out.toString();
}

String _bodyAfter(String source, String opener) {
  final start = source.indexOf(opener);
  expect(start, isNot(-1), reason: 'could not find: $opener');

  // Skip the parameter list before hunting for the body. Dart named
  // parameters are themselves braced — `{String reason = 'ended'}` — so
  // "first brace after the name" finds the signature, not the function.
  var cursor = start + opener.length;
  final paren = source.indexOf('(', start);
  if (paren != -1 && paren < (source.indexOf('{', start) == -1 ? source.length : source.indexOf('{', start)) + 1) {
    var depth = 0;
    for (var p = paren; p < source.length; p++) {
      if (source[p] == '(') depth++;
      if (source[p] == ')') {
        depth--;
        if (depth == 0) {
          cursor = p + 1;
          break;
        }
      }
    }
  }

  var i = source.indexOf('{', cursor);
  expect(i, isNot(-1), reason: 'no opening brace after: $opener');
  var depth = 0;
  final from = i;
  for (; i < source.length; i++) {
    final c = source[i];
    if (c == '{') depth++;
    if (c == '}') {
      depth--;
      if (depth == 0) return source.substring(from, i + 1);
    }
  }
  fail('unbalanced braces after: $opener');
}

void main() {
  const delegate = 'ios/Runner/AppDelegate.swift';
  const bridgeDart = 'lib/features/updates/incoming_call_bridge.dart';
  const callKitDart = 'lib/core/notifications/ios_call_kit.dart';

  group('the ring retires on iOS, not just on Android', () {
    test('a native path exists to clear a delivered call notification', () {
      final source = _read(delegate);
      expect(source, contains('import UserNotifications'));
      expect(source, contains('case "clearCallNotifications":'));
      expect(source, contains('removeDeliveredNotifications(withIdentifiers:'));
      expect(
        source,
        contains('removePendingNotificationRequests(withIdentifiers:'),
        reason: 'a scheduled-but-undelivered ring must retire too',
      );
    });

    test('clearing is NOT gated on the CallKit capability', () {
      // In China, and whenever the storefront is unresolved, the banner is the
      // ONLY incoming-call surface — so clearing it matters more there, not
      // less. Gating this on callKitAllowed would leave exactly those users
      // with a permanent stale ring.
      final source = _read(delegate);
      final start = source.indexOf('case "clearCallNotifications":');
      final end = source.indexOf('case "voipToken":', start);
      expect(start, isNot(-1));
      expect(end, greaterThan(start));
      expect(
        _stripComments(source.substring(start, end)).contains('callKitAllowed'),
        isFalse,
        reason: 'the China fallback surface must still be clearable',
      );
    });

    test('the matcher reads every transport payload shape', () {
      // An APNs alert nests under `data`; FCM puts the map at the top level and
      // also flattens it under gcm.notification.*. A matcher that knew one
      // shape would leave the other transport's banner on screen.
      final matcher = _bodyAfter(
        _read(delegate),
        'func notificationBelongsToCall(',
      );
      expect(matcher, contains('info["sessionId"]'));
      expect(matcher, contains('info["data"]'));
      expect(matcher, contains('gcm.notification.sessionId'));
      expect(
        matcher,
        contains('guard !sessionId.isEmpty else { return false }'),
        reason: 'an empty id must not match, or a malformed terminal clears the tray',
      );
    });

    test('the Dart bridge exposes the clear, addressed by canonical call identity', () {
      final source = _read(callKitDart);
      expect(source, contains('Future<void> clearCallNotifications(String sessionId)'));
      expect(source, contains("invokeMethod<bool>('clearCallNotifications'"));
      expect(source, contains("'sessionId': sessionId.trim()"));
    });
  });

  group('every terminal state retires every representation', () {
    test('the terminal choke point clears CallKit AND the notification', () {
      // _onSessionTerminated is where declined, cancelled, expired, answered
      // elsewhere and superseded all converge.
      final body = _bodyAfter(
        _read(bridgeDart),
        'void _onSessionTerminated(String sessionId',
      );
      expect(body, contains('_guard.recordClear(sessionId)'));
      expect(body, contains('IosCallKit.instance.reportEnded(sessionId'));
      expect(
        body,
        contains('IosCallKit.instance.clearCallNotifications(sessionId)'),
        reason: 'reporting the CallKit call ended does nothing to the banner beside it',
      );
    });

    test('accepting retires the banner WITHOUT reporting the call ended', () {
      final body = _bodyAfter(_read(bridgeDart), 'void clearAccepted(String sessionId)');
      expect(body, contains('IosCallKit.instance.reportConnected(trimmed)'));
      expect(body, contains('IosCallKit.instance.clearCallNotifications(trimmed)'));
      expect(
        _stripComments(body).contains('reportEnded'),
        isFalse,
        reason: 'reporting ended on accept is the build-30 defect — it hangs up the call',
      );
    });

    test('a late duplicate delivery cannot re-present a resolved call', () {
      // The tombstone is what makes socket + push convergence safe: whichever
      // transport arrives second is absorbed, in foreground, background and
      // cold launch alike.
      final source = _read(bridgeDart);
      expect(source, contains('_guard.shouldShow(sessionId)'));
      final terminated = _bodyAfter(source, 'void _onSessionTerminated(String sessionId');
      final accepted = _bodyAfter(source, 'void clearAccepted(String sessionId)');
      expect(terminated, contains('_guard.recordClear'));
      expect(
        accepted,
        contains('_guard.recordClear'),
        reason: 'an accepted call must be tombstoned too, or a late push re-rings it',
      );
    });

    test('deduplication is by canonical call identity, not by notification id alone', () {
      final add = _bodyAfter(_read(bridgeDart), 'void addIncoming(Map<String, dynamic> payload)');
      expect(add, contains("_str(item['id']) == id"));
      expect(add, contains("_str(itemData['sessionId']) == sessionId"));
    });
  });

  group('the backend presents once per physical device', () {
    final backendRoot = _resolveBackendRoot();
    final authority =
        '${backendRoot ?? _defaultBackendRoot}/src/common/devices/multi-device-authority.ts';
    final fanout =
        '${backendRoot ?? _defaultBackendRoot}/src/communications/push/push-notification.service.ts';
    final fcm =
        '${backendRoot ?? _defaultBackendRoot}/src/communications/push/adapters/fcm-push.adapter.ts';
    final apns =
        '${backendRoot ?? _defaultBackendRoot}/src/communications/push/adapters/apns-push.adapter.ts';

    bool _backendPresent() {
      if (backendRoot != null) return true;
      markTestSkipped(
        'SKIPPED, NOT PASSED: no paired aura-backend checkout was resolved, so '
        'the four backend seams below were not asserted. Set AURA_BACKEND_ROOT '
        'to certify them from a client-only checkout.',
      );
      return false;
    }

    test('routing reasons about physical devices, not delivery endpoints', () {
      if (!_backendPresent()) return; // client-only checkout
      final source = _read(authority);
      expect(source, contains('export function physicalDeviceKeyOf'));
      expect(source, contains('export function resolvePhysicalDevices'));
      expect(source, contains('export function selectPresentingEndpoint'));
      expect(
        source,
        contains('companionsByPresenter'),
        reason: 'a companion must travel with its own phone\'s wave',
      );
    });

    test('phone identity is never derived from a rotating token', () {
      if (!_backendPresent()) return;
      final body = _bodyAfter(
        _read(authority),
        'export function physicalDeviceKeyOf(device: CommunicationDevice): string',
      );
      expect(body, contains('device.installationId'));
      expect(
        _stripComments(body).contains('token'),
        isFalse,
        reason: 'tokens rotate; grouping by one would split a phone in two',
      );
    });

    test('the governed ring policy is preserved, not regressed', () {
      if (!_backendPresent()) return;
      expect(
        _read(authority),
        contains("export const DEFAULT_RING_POLICY: RingPolicy = 'PREFERRED_FIRST_THEN_ALL'"),
      );
    });

    test('the companion is delivered, and only its presentation is conditioned', () {
      if (!_backendPresent()) return;
      final source = _read(fanout);
      // Delivered unconditionally; presenting only when the phone's presenting
      // transport actually took the call. See the outcome group below.
      expect(source, contains('presentationOwnedElsewhere: presenterDelivered'));
      expect(
        source,
        contains('routing.companionsByPresenter[device.id]'),
        reason: 'delivery redundancy is the safety net and must survive',
      );
    });

    test('an iPhone already rung by CallKit raises no second banner', () {
      if (!_backendPresent()) return;
      expect(
        _read(fcm),
        contains('isCallInvite && (isAndroidDevice || presentationOwnedElsewhere)'),
      );
    });

    test('collapse reaches APNs as a header, on the alert path only', () {
      if (!_backendPresent()) return;
      final source = _read(apns);
      expect(source, contains("'apns-collapse-id'"));
      expect(
        source,
        contains("...(!isVoipInvite && collapseId ?"),
        reason: 'collapse on a VoIP push is unverified, and a rejected VoIP push is silence',
      );
    });
  });

  group('the native half is actually executed by CI', () {
    test('the certification workflow runs the RunnerTests target', () {
      // The jurisdiction policy and the notification matcher are Swift. Dart
      // can only pin their wiring, so without this gate the behavioural half
      // of the iOS incoming-call system would be written and never run.
      final ci = _read('codemagic.yaml');
      expect(ci, contains('-only-testing:RunnerTests'));
      expect(ci, contains('-workspace ios/Runner.xcworkspace'));
    });

    test('a run that executes no native test is a failure, not a pass', () {
      // This lane has already been burned by suites that skipped everything,
      // exited 0 and were recorded as passes.
      final ci = _read('codemagic.yaml');
      expect(ci, contains(r'EXECUTED=$(grep -oE "Executed [0-9]+ test"'));
      expect(ci, contains('NATIVE VERDICT=NO_COVERAGE'));
    });
  });

  group('presentation authority is established, not inferred', () {
    test('a successful CallKit report retracts any banner that also arrived', () {
      // This is the moment the ambiguity ends: "will CallKit present?" was a
      // prediction until reportNewIncomingCall returned without error.
      final handler = _bodyAfter(
        _read('ios/Runner/AppDelegate.swift'),
        'didReceiveIncomingPushWith payload',
      );
      final established = handler.indexOf('AppDelegate.reconcilePresentationOwnership');
      final emitted = handler.indexOf('self.emit("incomingCall"', established);
      expect(established, isNot(-1),
          reason: 'CallKit presenting must retract the competing banner');
      expect(emitted, greaterThan(established));
    });

    test('retraction sweeps twice, so a fallback still in flight is caught', () {
      // The server checks for an acknowledgement at an instant and may already
      // have committed to a banner that lands after CallKit presents. Clearing
      // only what is on screen at that moment would miss it.
      final body = _bodyAfter(
        _read('ios/Runner/AppDelegate.swift'),
        'private static func reconcilePresentationOwnership(sessionId: String)',
      );
      expect(body, contains('clearDeliveredCallNotifications(sessionId: sessionId)'));
      expect(
        body,
        contains('asyncAfter'),
        reason: 'one bounded second sweep past the grace period, not a poll',
      );
    });

    test('the system-lapse signal uses the API iOS actually provides', () {
      // iOS exposes no "the call UI disappeared" callback. It does expose the
      // call ENDING, via CXCallObserver, which is the honest proxy.
      final source = _read('ios/Runner/AppDelegate.swift');
      expect(source, contains('extension AppDelegate: CXCallObserverDelegate'));
      expect(source, contains('callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall)'));
      expect(source, contains('callController.callObserver.setDelegate(self, queue: nil)'));
      expect(source, contains('emit("systemPresentationLapsed"'));
    });

    test('a lapse is never reported to Dart as a terminal call state', () {
      final body = _bodyAfter(
        _read('ios/Runner/AppDelegate.swift'),
        'func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall)',
      );
      expect(
        _stripComments(body).contains('emit("end"'),
        isFalse,
        reason: 'the system UI retiring is not the call ending',
      );
      expect(body, contains('guard call.hasEnded else { return }'));
    });

    test('Dart treats a lapse as recovery, not as a hang-up', () {
      final app = _read('lib/app/aura_app.dart');
      expect(app, contains('callKit.onSystemPresentationLapsed'));
      final handler = _bodyAfter(app, 'callKit.onSystemPresentationLapsed = (sessionId) async');
      expect(handler, contains('evictExpired()'));
      expect(
        _stripComments(handler).contains('reportEnded'),
        isFalse,
        reason: 'a lapsed system surface must not end a call the person can still answer',
      );
    });
  });

  group('the fallback is decided by delivery outcome, not by registration', () {
    final backendRoot = _resolveBackendRoot();
    final fanout =
        '${backendRoot ?? _defaultBackendRoot}/src/communications/push/push-notification.service.ts';

    bool _backendPresent() {
      if (backendRoot != null) return true;
      markTestSkipped(
        'SKIPPED, NOT PASSED: no paired aura-backend checkout was resolved, so '
        'the fallback-outcome seams below were not asserted. Set '
        'AURA_BACKEND_ROOT to certify them from a client-only checkout.',
      );
      return false;
    }

    test('suppression is conditioned on the presenting send actually succeeding', () {
      if (!_backendPresent()) return;
      final source = _read(fanout);
      expect(source, contains("presenterResult.status === 'SENT'"));
      expect(source, contains('presentationOwnedElsewhere: presenterDelivered'));
      expect(
        _stripComments(source).contains('presentationOwnedElsewhere: true'),
        isFalse,
        reason: 'an unconditional true is the registration-inferred bug returning',
      );
    });

    test('a failed presenting send is observable, not silent', () {
      if (!_backendPresent()) return;
      expect(_read(fanout), contains('call.invite.fallback_presents'));
    });
  });
}
