/// WHEN — AND WHEN NOT — TO ASK SOMEONE TO RATE AURA.
///
/// Governed by the `review` section of
/// `contracts/native_continuation_contract.json`.
///
/// This file is pure policy and holds no platform code, because the interesting
/// part is not "how do I call the review API", it is "am I allowed to". Every
/// bad review prompt anyone has ever met was technically correct and asked at
/// the wrong moment.
///
/// TWO RULES THAT ARE NOT NEGOTIABLE
/// --------------------------------
/// 1. Never inside a consequential workflow. Not at first launch, not at
///    signup, not on an error, not during a call, not while composing, not
///    during identity verification. Someone in the middle of something that
///    matters is not being asked for an opinion, they are being interrupted.
/// 2. Never conditioned on sentiment. There is no "did you like it?" gate, no
///    reward, no custom stars. Filtering who gets asked by predicted rating is
///    manipulation, and the platform APIs deliberately return no outcome so an
///    app cannot react to one.
library;

/// The moment a prompt is being considered at.
///
/// Naming the moment is required rather than optional: a caller that has to
/// state where it is cannot accidentally ask from inside a checkout, a call or
/// an error screen.
enum ReviewMoment {
  /// A calm surface reached under the person's own steam, after something
  /// worked. The only moment a prompt is ever permitted.
  settledAfterSuccessfulUse,

  // Everything below is enumerated so it can be REFUSED by name. They exist in
  // this enum precisely so a caller cannot pass them by accident and get a
  // prompt anyway.
  firstLaunch,
  signup,
  error,
  failedPayment,
  call,
  composition,
  identityVerification,
  otherConsequentialWorkflow,
}

/// Moments at which a prompt is forbidden outright.
const Set<ReviewMoment> kForbiddenReviewMoments = {
  ReviewMoment.firstLaunch,
  ReviewMoment.signup,
  ReviewMoment.error,
  ReviewMoment.failedPayment,
  ReviewMoment.call,
  ReviewMoment.composition,
  ReviewMoment.identityVerification,
  ReviewMoment.otherConsequentialWorkflow,
};

/// What the app has observed about this person's use.
class ReviewUsage {
  const ReviewUsage({
    required this.qualifyingActions,
    required this.distinctDaysUsed,
    required this.daysSinceFirstUse,
    required this.daysSinceLastPrompt,
    required this.promptsShown,
  });

  /// Things that actually worked: a post published, an article read to the
  /// end, a meeting completed. Not taps, not launches.
  final int qualifyingActions;

  /// Days on which Aura was used at all. Ten actions in one sitting is
  /// enthusiasm; ten actions across five days is a habit, and only the second
  /// is evidence the product is worth rating.
  final int distinctDaysUsed;

  final int daysSinceFirstUse;

  /// `null` when never prompted.
  final int? daysSinceLastPrompt;

  final int promptsShown;
}

/// Thresholds. Deliberately conservative — the cost of asking too early is a
/// one-star review, and the cost of asking too late is nothing at all.
class ReviewThresholds {
  const ReviewThresholds({
    this.minQualifyingActions = 5,
    this.minDistinctDaysUsed = 3,
    this.minDaysSinceFirstUse = 7,
    this.minDaysSinceLastPrompt = 120,
    this.maxPromptsEver = 3,
  });

  final int minQualifyingActions;
  final int minDistinctDaysUsed;
  final int minDaysSinceFirstUse;
  final int minDaysSinceLastPrompt;
  final int maxPromptsEver;
}

/// Why a prompt was or was not permitted. Returned rather than logged so the
/// decision is testable and explainable instead of a silent boolean.
enum ReviewDecision {
  allowed,
  forbiddenMoment,
  notEnoughSuccessfulUse,
  tooSoonAfterFirstUse,
  tooSoonAfterLastPrompt,
  alreadyAskedEnough,
}

/// Decides whether Aura may ask for a store review right now.
ReviewDecision evaluateReviewEligibility({
  required ReviewMoment moment,
  required ReviewUsage usage,
  ReviewThresholds thresholds = const ReviewThresholds(),
}) {
  // The moment is checked FIRST and unconditionally. No amount of qualifying
  // use makes it acceptable to ask during a call.
  if (kForbiddenReviewMoments.contains(moment)) {
    return ReviewDecision.forbiddenMoment;
  }
  if (usage.promptsShown >= thresholds.maxPromptsEver) {
    return ReviewDecision.alreadyAskedEnough;
  }
  if (usage.daysSinceFirstUse < thresholds.minDaysSinceFirstUse) {
    return ReviewDecision.tooSoonAfterFirstUse;
  }
  if (usage.qualifyingActions < thresholds.minQualifyingActions ||
      usage.distinctDaysUsed < thresholds.minDistinctDaysUsed) {
    return ReviewDecision.notEnoughSuccessfulUse;
  }
  final since = usage.daysSinceLastPrompt;
  if (since != null && since < thresholds.minDaysSinceLastPrompt) {
    return ReviewDecision.tooSoonAfterLastPrompt;
  }
  return ReviewDecision.allowed;
}
