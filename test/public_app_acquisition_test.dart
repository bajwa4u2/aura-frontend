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
    test('Android offers nothing while Play access is closed testing', () {
      // The Play link is real, but a general visitor cannot install from it.
      // Offering "Get Aura" there advertises distribution that, for the person
      // being offered it, does not exist.
      expect(kAndroidGenerallyAvailable, isFalse);
      expect(acquisitionActionFor(TargetPlatform.android),
          AcquisitionAction.none);
      expect(storeUrlFor(TargetPlatform.android), isNull);
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
