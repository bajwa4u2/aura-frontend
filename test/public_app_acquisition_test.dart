import 'package:aura/core/continuation/acquisition_contract.dart';
import 'package:aura/features/public/widgets/public_app_acquisition.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// WHAT CHANGED HERE, AND WHY
///
/// This file used to assert that `/p/...` was NOT an acquisition surface and
/// that eligibility was "the approved static public inventory" — a hand-kept
/// set of exact marketing paths.
///
/// That was backwards under the canonical doctrine: `/p/...` is the URL people
/// actually share, so it is precisely the surface where continuation matters,
/// while `/mission` is where it matters least. The old set also contained no
/// dynamic family at all, so every article, profile and institution page — the
/// entire shareable product — offered nothing.
///
/// Eligibility now comes from the association scope in
/// `contracts/native_continuation_contract.json`. A page offers the app exactly
/// when a link to it can reach the app.
void main() {
  group('eligibility follows the association scope', () {
    test('the canonical share family is eligible', () {
      expect(shouldShowAuraPublicAppAcquisition('/p/public-object'), isTrue);
      expect(shouldShowAuraPublicAppAcquisition('/p/art/an-essay'), isTrue);
      expect(shouldShowAuraPublicAppAcquisition('/p/u/someone'), isTrue);
    });

    test('the public object families are eligible', () {
      for (final path in const [
        '/posts/abc',
        '/articles/an-essay',
        '/announcements/a-notice',
        '/u/someone',
        '/institutions/acme',
        '/spaces/a-subject',
        '/meetings/join/ABC123',
      ]) {
        expect(shouldShowAuraPublicAppAcquisition(path), isTrue, reason: path);
      }
    });

    test('authoring surfaces are never eligible', () {
      // A public sibling never implies its editor is public, and offering to
      // continue INTO an editor is offering a door that should not open.
      for (final path in const [
        '/posts/abc/edit',
        '/articles/write',
        '/announcements/create',
        '/institutions/get-started',
      ]) {
        expect(shouldShowAuraPublicAppAcquisition(path), isFalse, reason: path);
      }
    });

    test('unassociated and private paths are never eligible', () {
      for (final path in const [
        '/media/file',
        '/private',
        '/home',
        '/messages',
        '/me',
        '/admin',
        '/settings',
        '',
        'relative/path',
      ]) {
        expect(shouldShowAuraPublicAppAcquisition(path), isFalse,
            reason: path.isEmpty ? '(empty)' : path);
      }
    });
  });

  group('the offer reflects real distribution truth', () {
    test('Android offers the store now that its listing serves', () {
      // THE PREMISE CHANGED AGAIN, ON 2026-09-12, AND SO DID THIS TEST.
      //
      // It has been through three states, and the shape of the sequence is
      // the point. Closed testing: false. Production access granted and the
      // Play Developer API reporting the production track `completed`: still
      // false, because the page answered HTTP 404 to a general visitor while
      // a known-good Play listing returned 200 from the same client. Now:
      // true, because the page serves and names the app.
      //
      // The flag never followed the console and it never followed the API. It
      // followed the fetch, which is the only thing that describes what a
      // person actually receives. Whoever changes it next should change it
      // the same way.
      //
      // The old comment here warned that a test still passing under a premise
      // that has become false is how a suite certifies something nobody
      // believes any more. That warning is why this was rewritten rather than
      // left green.
      expect(kAndroidGenerallyAvailable, isTrue);
      expect(acquisitionActionFor(TargetPlatform.android),
          AcquisitionAction.get);
      expect(storeUrlFor(TargetPlatform.android), kAndroidStoreUrl);
    });

    test('no platform claims Open before a client can route it', () {
      // Association being configured in this source tree is not the same as a
      // released client that can follow the link. Claiming Open too early
      // opens the old app at home and loses the destination.
      expect(kAndroidContinuationShipped, isFalse);
      expect(kIosContinuationShipped, isFalse);
      expect(kWindowsContinuationShipped, isFalse);
      for (final platform in const [
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.windows,
      ]) {
        expect(acquisitionActionFor(platform), isNot(AcquisitionAction.open),
            reason: '$platform must not offer Open yet');
      }
    });

    test('iOS and Windows offer Get, because those stores are open', () {
      expect(acquisitionActionFor(TargetPlatform.iOS), AcquisitionAction.get);
      expect(storeUrlFor(TargetPlatform.iOS), contains('apps.apple.com'));
      expect(
          acquisitionActionFor(TargetPlatform.windows), AcquisitionAction.get);
      expect(storeUrlFor(TargetPlatform.windows), contains('apps.microsoft.com'));
    });

    test('platforms with no Aura client are offered nothing', () {
      for (final platform in const [
        TargetPlatform.macOS,
        TargetPlatform.linux,
        TargetPlatform.fuchsia,
      ]) {
        expect(acquisitionActionFor(platform), AcquisitionAction.none);
        expect(storeUrlFor(platform), isNull);
      }
    });
  });
}
