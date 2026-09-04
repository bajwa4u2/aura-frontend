// TRACK B3 — iOS SHARE EXTENSION, CAPTURE-ONLY.
//
// A share extension is a SECOND PROCESS: its own lifetime, launched by another
// application, running outside the app the person signed into. The founder
// ruling is that it captures and does nothing else — it must not carry Aura's
// authentication authority, publish, send, choose an acting identity, choose a
// destination, or infer either from recent use.
//
// "Capture-only" is worth nothing as a promise in a comment. What makes it
// true is that the process is GIVEN NOTHING TO BE TRUSTED WITH: no keychain
// access group, no token in the App Group, no network client, no composer with
// a Post button. This file asserts those absences, because an absence is
// exactly what a future change would quietly fill in.
//
// None of it can be executed here — no macOS, so no build and no device. B3 is
// IMPLEMENTED / UNVERIFIED and never PASS.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _extensionSwift = 'ios/ShareExtension/ShareViewController.swift';
const _extensionPlist = 'ios/ShareExtension/Info.plist';
const _extensionEntitlements = 'ios/ShareExtension/ShareExtension.entitlements';
const _runnerEntitlements = 'ios/Runner/Runner.entitlements';
const _appSwift = 'ios/Runner/ShareIntake.swift';
const _pbxproj = 'ios/Runner.xcodeproj/project.pbxproj';

String _read(String path) {
  final file = File(path);
  if (!file.existsSync()) throw StateError('$path is missing.');
  return file.readAsStringSync();
}

/// Source with comment lines removed, so a gate judges CODE.
///
/// These files document the constructs they must not contain. A gate that
/// tripped on its own rationale would teach the next person to delete the
/// rationale, which is the opposite of what it is for.
String _codeOnly(String source) => source
    .split('\n')
    .where((line) {
      final trimmed = line.trimLeft();
      return !trimmed.startsWith('//') &&
          !trimmed.startsWith('*') &&
          !trimmed.startsWith('/*') &&
          !trimmed.startsWith('<!--');
    })
    .join('\n');

void main() {
  group('the extension holds no authority', () {
    test('its entitlements are the App Group and nothing else', () {
      final entitlements = _read(_extensionEntitlements);
      expect(entitlements.contains('com.apple.security.application-groups'),
          isTrue);

      final code = _codeOnly(entitlements);
      for (final forbidden in const [
        // A shared keychain is how the extension would come to hold a
        // session, and a process the person did not open must never be able
        // to act as them.
        'keychain-access-groups',
        'associated-domains',
        'aps-environment',
        'com.apple.developer.usernotifications',
      ]) {
        expect(
          code.contains(forbidden),
          isFalse,
          reason: '$forbidden would make this process addressable or '
              'trustable. It is neither.',
        );
      }
    });

    test('it holds no token, session or credential', () {
      final code = _codeOnly(_read(_extensionSwift));
      for (final forbidden in const [
        'accessToken',
        'refreshToken',
        'SecItem',
        'keychain',
        'Keychain',
        'URLSession',
        'Authorization',
      ]) {
        expect(
          code.contains(forbidden),
          isFalse,
          reason: 'The extension must be unable to authenticate or reach the '
              'network. "$forbidden" would give it one of those.',
        );
      }
    });

    test('it chooses no destination and no identity', () {
      final code = _codeOnly(_read(_extensionSwift));
      for (final forbidden in const [
        'conversation',
        'destination',
        'recent',
        'lastUsed',
        'actingIdentity',
        'institution',
      ]) {
        expect(
          code.toLowerCase().contains(forbidden.toLowerCase()),
          isFalse,
          reason: 'Where a share goes, and who it goes as, are decided in '
              'Aura by a person. "$forbidden" here would be the beginning of '
              'a second answer.',
        );
      }
    });

    test('it publishes nothing — there is no send at all', () {
      final code = _codeOnly(_read(_extensionSwift));
      for (final forbidden in const ['publish', 'upload', 'POST', 'httpBody']) {
        expect(code.contains(forbidden), isFalse);
      }
    });
  });

  group('capture is not composition', () {
    test('no compose sheet, and therefore no Post button', () {
      final swift = _read(_extensionSwift);
      // SLComposeServiceViewController is the template default: a text box
      // with a Post button. A Post button is a promise to publish, and this
      // process must not.
      expect(_codeOnly(swift).contains('SLComposeServiceViewController'),
          isFalse);
      expect(swift.contains('final class ShareViewController: UIViewController'),
          isTrue);
    });

    test('the Info.plist names a principal class, not a storyboard', () {
      final plist = _read(_extensionPlist);
      expect(plist.contains('NSExtensionPrincipalClass'), isTrue);
      expect(
        plist.contains('<key>NSExtensionMainStoryboard</key>'),
        isFalse,
        reason: 'The template storyboard brings the compose sheet with it.',
      );
      expect(
        plist.contains('com.apple.share-services'),
        isTrue,
      );
    });

    test('what it offers to accept is specific, not everything', () {
      final plist = _read(_extensionPlist);
      expect(plist.contains('NSExtensionActivationRule'), isTrue);
      // TRUEPREDICATE accepts every share on the device and turns most of
      // them into a refusal a person could not have predicted. Appearing in
      // a share sheet is a promise.
      expect(plist.contains('TRUEPREDICATE'), isFalse);
    });
  });

  group('the App Group is transit, not storage', () {
    test('the app moves content out and deletes what it found', () {
      final swift = _read(_appSwift);
      expect(swift.contains('moveItem'), isTrue);
      expect(
        swift.contains('removeItem(at: directory)'),
        isTrue,
        reason: 'Two processes can read that container. Content left in it '
            'stays readable by a process the person did not open.',
      );
    });

    test('a half-written share is never picked up', () {
      final swift = _read(_appSwift);
      // The manifest is written last and is what makes a share visible, so a
      // directory without one is either still being written or belongs to an
      // extension that was killed mid-capture.
      expect(swift.contains('manifest.json'), isTrue);
      expect(swift.contains('fileExists(atPath: manifestURL.path)'), isTrue);
    });

    test('two shares waiting do not overwrite each other', () {
      final swift = _read(_appSwift);
      // Someone can share twice without opening Aura in between. Each transit
      // directory is drained and their payloads carried in one envelope.
      expect(swift.contains('for directory in ordered'), isTrue);
      expect(swift.contains('sorted'), isTrue);
    });

    test('nothing is ever written into the group by the app', () {
      final code = _codeOnly(_read(_appSwift));
      expect(code.contains('write(to:'), isFalse);
      expect(code.contains('createDirectory(at: transit'), isFalse);
    });
  });

  group('the handoff does not reach for a private door', () {
    test('it uses the documented open, not the responder-chain trick', () {
      final code = _codeOnly(_read(_extensionSwift));
      expect(code.contains('extensionContext?.open('), isTrue);
      // Walking the responder chain until UIApplication turns up, then
      // calling openURL: on it, is a way past a restriction rather than a use
      // of the API — on an app already working through an App Store
      // rejection. The app drains the container on resume instead, so the
      // share is waiting whether Aura opens now or in an hour.
      expect(code.contains('responder'), isFalse);
      expect(code.contains('UIApplication.shared'), isFalse);
      expect(code.contains('sharedApplication'), isFalse);
    });

    test('the handoff URL has an empty host so the path survives', () {
      // With a host ("aura://share/incoming") Flutter reports the route as
      // `/incoming` and the person lands nowhere.
      expect(
        _read(_extensionSwift).contains('aura:///share/incoming'),
        isTrue,
      );
    });
  });

  group('one channel, and the same shape as Android', () {
    test('the iOS side answers on the shared channel name', () {
      const name = 'org.auraplatform.app/share_intake';
      expect(_read(_appSwift).contains(name), isTrue);
      expect(_read('ios/Runner/AppDelegate.swift').contains('ShareIntake.channelName'),
          isTrue);
    });

    test('it answers the same two methods Android does', () {
      final swift = _read(_appSwift);
      expect(swift.contains('"consumePendingShare"'), isTrue);
      expect(swift.contains('"releaseSharedContent"'), isTrue);
    });

    test('the manifest speaks the envelope the Dart adapter parses', () {
      final swift = _read(_appSwift);
      for (final key in const [
        'platform',
        'payloads',
        'refusals',
        'receivedAt',
        'subject',
      ]) {
        expect(swift.contains('"$key"'), isTrue, reason: '$key is missing.');
      }
    });
  });

  group('the Xcode target is actually wired', () {
    test('the extension target exists and is an app extension', () {
      final project = _read(_pbxproj);
      expect(project.contains('ShareExtension'), isTrue);
      expect(
        project.contains('com.apple.product-type.app-extension'),
        isTrue,
      );
    });

    test('the app embeds it, and depends on it', () {
      final project = _read(_pbxproj);
      expect(project.contains('Embed App Extensions'), isTrue);
      // dstSubfolderSpec 13 is PlugIns. An extension copied anywhere else is
      // shipped and never loaded.
      expect(project.contains('dstSubfolderSpec = 13'), isTrue);
      expect(project.contains('ShareExtension.appex'), isTrue);
      expect(project.contains('PBXTargetDependency'), isTrue);
    });

    test('its version tracks the app, which Apple requires', () {
      final project = _read(_pbxproj);
      // A mismatch between an extension's version and its containing app's
      // fails App Store validation. Both read the same Flutter build values.
      expect(project.contains(r'MARKETING_VERSION = "$(FLUTTER_BUILD_NAME)"'),
          isTrue);
      expect(
        project.contains(r'CURRENT_PROJECT_VERSION = "$(FLUTTER_BUILD_NUMBER)"'),
        isTrue,
      );
      // And the app itself still reads the same values, so the two can never
      // drift apart into an App Store validation failure.
      expect(
        project.contains(r'CURRENT_PROJECT_VERSION = "$(FLUTTER_BUILD_NUMBER)"'),
        isTrue,
      );
    });

    test('the extension is signed with its own entitlements', () {
      expect(
        _read(_pbxproj).contains(
            'CODE_SIGN_ENTITLEMENTS = ShareExtension/ShareExtension.entitlements'),
        isTrue,
      );
    });
  });

  group('the app declares the group it reads from', () {
    test('Runner carries the App Group entitlement', () {
      expect(
        _read(_runnerEntitlements)
            .contains('com.apple.security.application-groups'),
        isTrue,
      );
    });

    test('both sides name the same group', () {
      const group = 'group.org.auraplatform.app';
      for (final path in const [
        _runnerEntitlements,
        _extensionEntitlements,
        _extensionSwift,
        _appSwift,
      ]) {
        expect(_read(path).contains(group), isTrue, reason: '$path disagrees.');
      }
    });

    test('Runner keeps every entitlement it already had', () {
      // Adding a capability must not quietly drop one. Push and Universal
      // Links are both load-bearing and both were already there.
      final entitlements = _read(_runnerEntitlements);
      expect(entitlements.contains('aps-environment'), isTrue);
      expect(
        entitlements.contains('com.apple.developer.associated-domains'),
        isTrue,
      );
    });
  });

  group('the ceiling is the same at every door', () {
    test('the extension refuses at the same size the rest of Aura does', () {
      // A smaller ceiling here would mean a file Aura accepts from the picker
      // is refused from the share sheet, for a reason nobody could work out.
      expect(
        _read(_extensionSwift).contains('150 * 1024 * 1024'),
        isTrue,
      );
    });
  });

  group('the plists are well formed', () {
    test('each parses as XML', () {
      for (final path in const [
        _extensionPlist,
        _extensionEntitlements,
        _runnerEntitlements,
      ]) {
        final content = _read(path);
        expect(content.trimLeft().startsWith('<?xml'), isTrue,
            reason: '$path is not a plist.');
        // Crude, deliberately: a real parser is not available here, so this
        // catches the failure that actually happens — an unbalanced edit.
        expect(
          '<dict>'.allMatches(content).length,
          '</dict>'.allMatches(content).length,
          reason: '$path has unbalanced dictionaries.',
        );
        expect(
          '<array>'.allMatches(content).length,
          '</array>'.allMatches(content).length,
          reason: '$path has unbalanced arrays.',
        );
      }
    });

    test('the extension declares a bundle id under the app', () {
      // An app extension must live inside its container app's identifier
      // namespace, or the App ID cannot be created.
      expect(
        _read(_pbxproj)
            .contains('PRODUCT_BUNDLE_IDENTIFIER = org.auraplatform.app.ShareExtension'),
        isTrue,
      );
    });
  });
}
