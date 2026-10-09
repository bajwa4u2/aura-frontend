import 'dart:io';

import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/monetization/presentation/institution_billing_screen.dart';

/// C-21 — A STORE BINARY MAY NOT INVITE YOU TO PAY SOMEWHERE ELSE.
///
/// The institution billing screen rendered a full price catalogue and, beneath
/// it, a card naming `app.auraplatform.org` and telling the reader to sign in
/// there to upgrade. On iOS that is a call to action directing customers to a
/// purchasing mechanism other than in-app purchase — **App Store Review
/// Guideline 3.1.1**, with 3.1.3 close behind.
///
/// What makes it worth holding in a test rather than a checklist is WHEN it
/// appears. The screen is gated on `config.mode`, a SERVER flag. Nothing is
/// decided at build time, so on the day monetization is switched on every
/// installed binary begins showing it — no submission, no review, and no way
/// back except another release. The register called this exactly: *"no build
/// gate"*.
///
/// Two separate questions, deliberately two separate rules:
///
///   * may this build TAKE money      → [billingPurchaseAllowed]
///   * may it tell you to SPEND IT elsewhere → [billingMayInviteExternalPurchase]
///
/// Desktop may do both. A store binary may do neither. Showing the plan you
/// are already on is not a purchase invitation and is untouched.
void main() {
  group('a store binary may not run a checkout', () {
    test('iOS and Android may not', () {
      for (final p in [TargetPlatform.iOS, TargetPlatform.android]) {
        expect(billingPurchaseAllowed(isWeb: false, platform: p), isFalse,
            reason: '$p');
      }
    });

    test('the web may', () {
      expect(billingPurchaseAllowed(isWeb: true, platform: null), isTrue);
    });

    test('desktop may', () {
      for (final p in [
        TargetPlatform.windows,
        TargetPlatform.macOS,
        TargetPlatform.linux,
      ]) {
        expect(billingPurchaseAllowed(isWeb: false, platform: p), isTrue,
            reason: '$p');
      }
    });
  });

  group('a store binary may not invite you elsewhere either', () {
    test('THE DEFECT: iOS must not be shown the external purchase card', () {
      expect(
        billingMayInviteExternalPurchase(
          isWeb: false,
          platform: TargetPlatform.iOS,
        ),
        isFalse,
        reason: 'naming app.auraplatform.org and telling the reader to sign in '
            'there to upgrade is a 3.1.1 call to action',
      );
    });

    // Founder, 9 Oct 2026: "we stay with web through stripe", and give
    // owners clarity in the store apps. Apple allows the link on the UNITED
    // STATES storefront only (3.1.1(a)); the App Store country decides.
    test('iOS on the US App Store may, while the server allows it', () {
      expect(
        billingMayInviteExternalPurchase(
          isWeb: false,
          platform: TargetPlatform.iOS,
          appStoreCountry: 'USA',
          appStoreWebLinkUnitedStates: true,
        ),
        isTrue,
      );
      expect(
        billingMayInviteExternalPurchase(
          isWeb: false,
          platform: TargetPlatform.iOS,
          appStoreCountry: 'USA',
          appStoreWebLinkUnitedStates: false,
        ),
        isFalse,
        reason: 'the server switch turns it off without a release',
      );
    });

    test('any other App Store country, or an unknown one, may not', () {
      for (final country in ['GBR', 'PAK', 'CAN', null]) {
        expect(
          billingMayInviteExternalPurchase(
            isWeb: false,
            platform: TargetPlatform.iOS,
            appStoreCountry: country,
            appStoreWebLinkUnitedStates: true,
          ),
          isFalse,
          reason: '$country',
        );
      }
    });

    test('Android is held to the same rule, until Aura enrolls in the Play US links program', () {
      expect(
        billingMayInviteExternalPurchase(
          isWeb: false,
          platform: TargetPlatform.android,
        ),
        isFalse,
      );
    });

    test('the web and desktop may, because they are not store binaries', () {
      expect(
        billingMayInviteExternalPurchase(isWeb: true, platform: null),
        isTrue,
      );
      for (final p in [
        TargetPlatform.windows,
        TargetPlatform.macOS,
        TargetPlatform.linux,
      ]) {
        expect(billingMayInviteExternalPurchase(isWeb: false, platform: p),
            isTrue,
            reason: '$p');
      }
    });
  });

  group('the wiring', () {
    final src = File(
      'lib/features/monetization/presentation/institution_billing_screen.dart',
    ).readAsStringSync();

    test('the external-purchase card is behind the invitation rule', () {
      expect(src, contains('if (_mayInviteExternalPurchase(config))'));
      expect(src, contains('_MobilePurchaseNotice(institutionId: institutionId)'));
      expect(src, contains('const _BillingNotInThisAppNotice()'));
    });

    test('the replacement names no destination and no price', () {
      final notice = src.substring(
        src.indexOf('class _BillingNotInThisAppNotice'),
        src.indexOf('class _MobilePurchaseNotice'),
      );
      expect(notice, isNot(contains('auraplatform.org')),
          reason: 'naming where to pay is the call to action itself');
      expect(notice, isNot(contains('http')));
      expect(notice.toLowerCase(), isNot(contains('upgrade')));
      expect(notice.toLowerCase(), isNot(contains('buy')));
    });

    test('the reason is kept where the decision is made', () {
      expect(src, contains('Guideline 3.1.1'));
      expect(src, contains('SERVER flag'));
    });
  });
}
