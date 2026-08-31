/// THE PLATFORM HALF OF STORE REVIEW.
///
/// Policy lives in `store_review_policy.dart`; this only carries out a decision
/// that has already been made there.
///
/// Each platform's OWN mechanism is used, never an imitation of one:
///   Android — Google Play In-App Review
///   iOS     — SKStoreReviewController
///   Windows — the Microsoft Store listing, because Windows has no in-app
///             review sheet. Sending someone to the real listing is honest;
///             a custom rating UI would not be.
///
/// The platform APIs deliberately report nothing back — not whether a sheet
/// appeared, not what was chosen. That is a feature. An app that could observe
/// the outcome could act on it, and acting on it is rating manipulation.
library;

import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';

import '../continuation/acquisition_contract.dart';
import 'store_review_policy.dart';

/// Persistence for review state. Kept as an interface so the policy path is
/// testable without a real store or platform channel.
abstract class ReviewUsageStore {
  Future<ReviewUsage> read();
  Future<void> recordPromptShown();
}

/// Outcome of an attempt. `requested` means Aura asked the platform, NOT that
/// a sheet was shown — only the OS knows that, and it does not say.
enum ReviewAttempt {
  requested,
  openedStoreListing,
  refusedByPolicy,
  unsupportedPlatform,
}

class StoreReviewService {
  StoreReviewService({
    required ReviewUsageStore usage,
    InAppReview? review,
    TargetPlatform? platformOverride,
  })  : _usage = usage,
        _review = review ?? InAppReview.instance,
        _platform = platformOverride ?? defaultTargetPlatform;

  final ReviewUsageStore _usage;
  final InAppReview _review;
  final TargetPlatform _platform;

  /// Asks for a review if — and only if — policy permits it at this moment.
  ///
  /// The moment is a required argument. A caller that must state where it is
  /// cannot ask from inside a call or an error screen by accident.
  Future<ReviewAttempt> maybeAsk(ReviewMoment moment) async {
    final decision = evaluateReviewEligibility(
      moment: moment,
      usage: await _usage.read(),
    );
    if (decision != ReviewDecision.allowed) {
      return ReviewAttempt.refusedByPolicy;
    }

    switch (_platform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        if (!await _review.isAvailable()) {
          return ReviewAttempt.unsupportedPlatform;
        }
        await _usage.recordPromptShown();
        await _review.requestReview();
        return ReviewAttempt.requested;

      case TargetPlatform.windows:
        // No in-app sheet exists on Windows. The listing is the real thing,
        // and it is opened only once policy has already said yes — this is
        // not a shortcut around eligibility.
        await _usage.recordPromptShown();
        await _review.openStoreListing(microsoftStoreId: _microsoftStoreId);
        return ReviewAttempt.openedStoreListing;

      default:
        return ReviewAttempt.unsupportedPlatform;
    }
  }

  /// Product id from the canonical store destination, so this cannot drift
  /// away from the contract by being typed a second time.
  static String get _microsoftStoreId =>
      Uri.parse(kWindowsStoreUrl).pathSegments.last;
}
