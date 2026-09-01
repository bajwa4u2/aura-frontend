import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// CALLKIT MUST NOT BE ACTIVE IN THE CHINA MAINLAND APP STORE.
///
/// Apple rejected Aura Platform 1.4.0 (35) on 2026-08-31 under Guideline 5 —
/// Legal, submission 472dba81-4065-4648-8a29-12ff48549ce4:
///
///   "the Chinese Ministry of Industry and Information Technology (MIIT)
///    requested that CallKit functionality be deactivated in all apps
///    available on the China App Store ... the app currently includes CallKit
///    functionality and has China listed as an available territory"
///
/// Build 35 introduced a jurisdiction-constrained native capability globally,
/// with no jurisdiction-aware policy in front of it. The correction is a single
/// canonical capability decision keyed on the App Store storefront.
///
/// NONE OF THIS IS OBSERVABLE FROM A DART UNIT TEST. `IosCallKit` is inert off
/// iOS and the gate lives entirely in Swift, so a device is the only place the
/// behaviour itself can be exercised. What IS observable from here is the
/// WIRING — and the wiring is the thing a future iOS calling reconstruction
/// would remove by accident. It is therefore what gets pinned, in the same
/// idiom as call_accept_is_not_termination_test.dart.
///
/// The companion behavioural tests live in ios/RunnerTests/RunnerTests.swift
/// and run under the iOS test target.
String _read(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: 'missing source file: $path');
  return file.readAsStringSync();
}

/// Swift source with every comment removed.
///
/// The forbidden-API scan runs over this rather than the raw file, for two
/// reasons that point the same way: the doc comments here legitimately NAME
/// `Locale.current` and the rest in order to explain why none of them can
/// establish a storefront, and a scan that could be satisfied by moving a call
/// behind a comment marker would not be a scan at all.
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

/// Extract a brace-balanced Swift body that begins at [opener].
String _bodyAfter(String source, String opener) {
  final start = source.indexOf(opener);
  expect(start, isNot(-1), reason: 'could not find: $opener');
  var i = source.indexOf('{', start + opener.length - 1);
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
  const policyPath = 'ios/Runner/CallCapabilityPolicy.swift';
  const delegatePath = 'ios/Runner/AppDelegate.swift';

  group('the canonical capability policy', () {
    test('exists, and is the only place a country is named', () {
      final policy = _read(policyPath);
      final delegate = _read(delegatePath);

      expect(policy, contains('enum CallCapabilityPolicy'));
      expect(policy, contains('static let chinaMainlandStorefront = "CHN"'));

      // The decision is made in one file. If a "CHN" comparison ever appears in
      // AppDelegate, the policy has been bypassed rather than consulted.
      expect(
        delegate.contains('"CHN"'),
        isFalse,
        reason: 'AppDelegate must consult CallCapabilityPolicy, never compare a country code',
      );
    });

    test('China mainland is prohibited, and it is the only prohibited storefront', () {
      final policy = _read(policyPath);
      expect(
        policy,
        contains('callKitProhibitedStorefronts: Set<String> = [chinaMainlandStorefront]'),
        reason: 'MIIT names the China App Store; HKG/MAC/TWN are separate storefronts',
      );
      expect(
        _bodyAfter(policy, 'static func capability(forStorefront raw: String?)'),
        contains('callKitProhibitedStorefronts.contains(code) ? .prohibited : .available'),
      );
    });

    test('an unresolved storefront withholds CallKit — it is never read as "not China"', () {
      final policy = _read(policyPath);
      final decision = _bodyAfter(policy, 'static func capability(forStorefront raw: String?)');

      // nil, empty and whitespace all fall through the guard to `.withheld`.
      expect(decision, contains('return .withheld'));
      expect(decision, contains('trimmingCharacters'));
      expect(decision, contains('!code.isEmpty'));
    });

    test('only `available` permits CallKit', () {
      final policy = _read(policyPath);
      expect(
        policy,
        contains('var allowsCallKit: Bool { self == .available }'),
        reason: 'withheld and prohibited must both answer false',
      );
    });

    test('the capability starts withheld, so the gate fails closed', () {
      final policy = _read(policyPath);
      final delegate = _read(delegatePath);
      expect(
        policy,
        contains('private(set) var capability: CallKitCapability = .withheld'),
      );
      expect(
        delegate,
        contains('private var callCapability: CallKitCapability = .withheld'),
        reason: 'a forgotten start(), a hang or a StoreKit outage must leave CallKit off',
      );
    });
  });

  group('the storefront is the authority', () {
    test('resolved from StoreKit, using the API available on the 13.0 floor', () {
      final policy = _read(policyPath);
      expect(policy, contains('import StoreKit'));
      expect(
        policy,
        contains('SKPaymentQueue.default().storefront?.countryCode'),
        reason: 'StoreKit 2 Storefront.current is iOS 15+, above Aura\'s deployment target',
      );
    });

    test('the device is never the authority', () {
      // Every one of these describes where a handset is, not which storefront
      // the app was distributed through.
      const forbidden = <String>[
        'Locale.current',
        'NSLocale',
        'TimeZone',
        'NSTimeZone',
        'isoCountryCode',
        'mobileCountryCode',
        'CTTelephonyNetworkInfo',
        'CTCarrier',
        'preferredLanguages',
        'regionCode',
      ];
      for (final path in [policyPath, delegatePath]) {
        final source = _stripComments(_read(path));
        for (final needle in forbidden) {
          expect(
            source.contains(needle),
            isFalse,
            reason: '$path must not establish jurisdiction from the device ($needle)',
          );
        }
      }
    });

    test('storefront changes are observed, and never persisted as identity', () {
      final policy = _read(policyPath);
      expect(
        policy,
        contains('UIApplication.didBecomeActiveNotification'),
        reason: 'changing an Apple Account region always backgrounds and re-foregrounds the app',
      );
      // A runtime distribution fact, not a profile attribute.
      for (final needle in ['UserDefaults', 'NSUserDefaults', 'Keychain']) {
        expect(
          policy.contains(needle),
          isFalse,
          reason: 'the storefront must be re-established each launch, never stored ($needle)',
        );
      }
    });
  });

  group('the CallKit stack is built only by an affirmative permitted storefront', () {
    test('launch does not build the stack — it asks the authority', () {
      final delegate = _read(delegatePath);
      final launch = _bodyAfter(delegate, 'didFinishLaunchingWithOptions launchOptions');

      expect(
        launch,
        contains('storefrontAuthority.start'),
        reason: 'the capability must be resolved before anything CallKit is constructed',
      );
      // Build 35's defect, exactly: these two ran unconditionally on launch.
      expect(
        launch.contains('activateCallKitStack()'),
        isFalse,
        reason: 'build 35 constructed CallKit unconditionally at launch; that is the rejection',
      );
      expect(
        RegExp(r'CXProvider\(').hasMatch(launch),
        isFalse,
        reason: 'no CXProvider may be created on the launch path',
      );
      expect(
        launch.contains('PKPushRegistry('),
        isFalse,
        reason: 'no VoIP registration may be made on the launch path',
      );
    });

    test('the provider and the VoIP registration are created in one gated place', () {
      final delegate = _read(delegatePath);
      final activate = _bodyAfter(delegate, 'private func activateCallKitStack()');

      expect(activate, contains('CXProvider('));
      expect(activate, contains('PKPushRegistry('));
      expect(activate, contains('desiredPushTypes = [.voIP]'));

      // Exactly one construction site each, so there is exactly one thing to gate.
      expect(
        RegExp(r'CXProvider\(configuration').allMatches(delegate).length,
        1,
        reason: 'a second provider construction site would be a second, ungated gate',
      );
      expect(
        RegExp(r'desiredPushTypes = \[\.voIP\]').allMatches(delegate).length,
        1,
        reason: 'VoIP registration is the real gate — it must have one site',
      );
    });

    test('activation is reached only through the capability check', () {
      final delegate = _read(delegatePath);
      final apply = _bodyAfter(delegate, 'private func applyCallCapability(_ capability');
      expect(apply, contains('if capability.allowsCallKit {'));
      expect(apply, contains('activateCallKitStack()'));
      expect(apply, contains('retractCallKitStack()'));
    });
  });

  group('every CallKit path is gated', () {
    test('the VoIP push handler cannot report a call in a prohibited jurisdiction', () {
      final delegate = _read(delegatePath);
      final handler = _bodyAfter(delegate, 'didReceiveIncomingPushWith payload');

      final gate = handler.indexOf('guard callKitAllowed');
      final report = handler.indexOf('reportNewIncomingCall');
      expect(gate, isNot(-1), reason: 'the push handler must consult the capability');
      expect(
        gate < report,
        isTrue,
        reason: 'the jurisdiction gate must precede every reportNewIncomingCall',
      );

      // The call is not dropped — it is handed to Aura's in-app surface.
      final gated = handler.substring(gate, report);
      expect(
        gated,
        contains('emit("incomingCall"'),
        reason: 'China keeps Aura calling; only the CallKit integration is removed',
      );
    });

    test('the Dart-driven answer path is gated', () {
      final delegate = _read(delegatePath);
      final handle = _bodyAfter(delegate, 'private func handle(_ call: FlutterMethodCall');

      final connected = handle.indexOf('case "callConnected":');
      final request = handle.indexOf('callController.request(', connected);
      expect(connected, isNot(-1));
      expect(request, isNot(-1));
      expect(
        handle.substring(connected, request),
        contains('guard callKitAllowed'),
        reason: 'callController.request IS a CallKit invocation and needs the gate',
      );
    });

    test('the end-call and token paths are gated', () {
      final delegate = _read(delegatePath);
      final handle = _bodyAfter(delegate, 'private func handle(_ call: FlutterMethodCall');

      final endCall = handle.indexOf('case "endCall":');
      final voipToken = handle.indexOf('case "voipToken":');
      expect(
        handle.substring(endCall, handle.indexOf('case "callConnected":')),
        contains('guard callKitAllowed'),
      );
      expect(
        handle.substring(voipToken),
        contains('callKitAllowed ? currentVoipToken : nil'),
        reason: 'no VoIP token may be handed to Dart where no registration was made',
      );
    });

    test('the stale-call sweep is gated', () {
      final delegate = _read(delegatePath);
      final sweep = _bodyAfter(delegate, 'private func endStaleCalls(keeping current: UUID)');
      expect(
        sweep.indexOf('guard callKitAllowed') < sweep.indexOf('reportCall(with:'),
        isTrue,
        reason: 'callObserver and reportCall are CallKit and must not run ungated',
      );
    });

    test('a VoIP token arriving after the jurisdiction closed is not registered', () {
      final delegate = _read(delegatePath);
      final didUpdate = _bodyAfter(delegate, 'didUpdate pushCredentials');
      expect(
        didUpdate.indexOf('guard callKitAllowed') < didUpdate.indexOf('emit("voipToken"'),
        isTrue,
        reason: 'registering a late token would re-arm the VoIP delivery just disarmed',
      );
    });
  });

  group('retraction disarms delivery without ending the call', () {
    test('VoIP delivery is disarmed before the provider is torn down', () {
      final delegate = _read(delegatePath);
      final retract = _bodyAfter(delegate, 'private func retractCallKitStack()');

      final disarm = retract.indexOf('desiredPushTypes = []');
      final invalidate = retract.indexOf('p.invalidate()');
      expect(disarm, isNot(-1), reason: 'the server must stop sending VoIP pushes');
      expect(
        disarm < invalidate,
        isTrue,
        reason: 'tearing the provider down first leaves a push with nothing able to report it',
      );
    });

    test('retraction does not tell Aura the call ended', () {
      final delegate = _read(delegatePath);
      final retract = _bodyAfter(delegate, 'private func retractCallKitStack()');
      expect(
        retract.contains('emit("end"'),
        isFalse,
        reason: 'onEnd runs handleTerminal(declined) — retracting the system UI must not hang up',
      );
    });

    test('the token invalidation signal is NOT gated, so the backend row retires', () {
      final delegate = _read(delegatePath);
      final invalidated = _bodyAfter(delegate, 'didInvalidatePushTokenFor type: PKPushType');
      expect(invalidated, contains('emit("voipTokenInvalidated"'));
      expect(
        invalidated.contains('guard callKitAllowed'),
        isFalse,
        reason: 'suppressing this would leave the server pushing VoIP to a device that cannot report',
      );
    });
  });

  group('the iOS capability declaration still matches the binary', () {
    test('voip background mode remains declared, because permitted storefronts still use it', () {
      final plist = _read('ios/Runner/Info.plist');
      expect(
        plist,
        contains('<string>voip</string>'),
        reason: 'CallKit + PushKit remain live outside China; the declaration stays truthful',
      );
    });
  });
}
