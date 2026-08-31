import 'dart:convert';
import 'dart:io';

import 'package:aura/core/review/store_review_policy.dart';
import 'package:flutter_test/flutter_test.dart';

/// The prompt rules exist because a review request is the one thing an app does
/// purely for its own benefit. Everything here is about NOT asking.
void main() {
  const habitual = ReviewUsage(
    qualifyingActions: 12,
    distinctDaysUsed: 6,
    daysSinceFirstUse: 30,
    daysSinceLastPrompt: null,
    promptsShown: 0,
  );

  group('forbidden moments are refused regardless of use', () {
    for (final moment in kForbiddenReviewMoments) {
      test('$moment', () {
        // Deliberately paired with the MOST qualified user in the file: no
        // amount of happy use makes it acceptable to ask during a call.
        expect(
          evaluateReviewEligibility(moment: moment, usage: habitual),
          ReviewDecision.forbiddenMoment,
        );
      });
    }

    test('the forbidden set matches the contract exactly', () {
      final contract = jsonDecode(
        File('contracts/native_continuation_contract.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final never =
          ((contract['review'] as Map)['neverPromptAt'] as List).cast<String>();

      const namesInContract = {
        ReviewMoment.firstLaunch: 'first launch',
        ReviewMoment.signup: 'signup',
        ReviewMoment.error: 'error',
        ReviewMoment.failedPayment: 'failed payment',
        ReviewMoment.call: 'call',
        ReviewMoment.composition: 'composition',
        ReviewMoment.identityVerification: 'identity verification',
        ReviewMoment.otherConsequentialWorkflow: 'any consequential workflow',
      };
      for (final entry in namesInContract.entries) {
        expect(kForbiddenReviewMoments, contains(entry.key));
        expect(never, contains(entry.value),
            reason: '${entry.value} must be named in the contract too');
      }
    });
  });

  group('eligibility follows meaningful successful use', () {
    test('a habitual user on a settled surface is allowed', () {
      expect(
        evaluateReviewEligibility(
            moment: ReviewMoment.settledAfterSuccessfulUse, usage: habitual),
        ReviewDecision.allowed,
      );
    });

    test('a brand new user is not asked, however enthusiastic', () {
      // Twenty actions on day one is a person exploring, not a person with an
      // opinion worth publishing.
      expect(
        evaluateReviewEligibility(
          moment: ReviewMoment.settledAfterSuccessfulUse,
          usage: const ReviewUsage(
            qualifyingActions: 20,
            distinctDaysUsed: 1,
            daysSinceFirstUse: 0,
            daysSinceLastPrompt: null,
            promptsShown: 0,
          ),
        ),
        ReviewDecision.tooSoonAfterFirstUse,
      );
    });

    test('long tenure without successful use is not enough', () {
      expect(
        evaluateReviewEligibility(
          moment: ReviewMoment.settledAfterSuccessfulUse,
          usage: const ReviewUsage(
            qualifyingActions: 1,
            distinctDaysUsed: 1,
            daysSinceFirstUse: 400,
            daysSinceLastPrompt: null,
            promptsShown: 0,
          ),
        ),
        ReviewDecision.notEnoughSuccessfulUse,
      );
    });

    test('actions crammed into one day are not a habit', () {
      expect(
        evaluateReviewEligibility(
          moment: ReviewMoment.settledAfterSuccessfulUse,
          usage: const ReviewUsage(
            qualifyingActions: 50,
            distinctDaysUsed: 1,
            daysSinceFirstUse: 60,
            daysSinceLastPrompt: null,
            promptsShown: 0,
          ),
        ),
        ReviewDecision.notEnoughSuccessfulUse,
      );
    });
  });

  group('asking is rationed', () {
    test('not again soon after the last prompt', () {
      expect(
        evaluateReviewEligibility(
          moment: ReviewMoment.settledAfterSuccessfulUse,
          usage: const ReviewUsage(
            qualifyingActions: 40,
            distinctDaysUsed: 20,
            daysSinceFirstUse: 200,
            daysSinceLastPrompt: 10,
            promptsShown: 1,
          ),
        ),
        ReviewDecision.tooSoonAfterLastPrompt,
      );
    });

    test('never more than the lifetime cap', () {
      expect(
        evaluateReviewEligibility(
          moment: ReviewMoment.settledAfterSuccessfulUse,
          usage: const ReviewUsage(
            qualifyingActions: 400,
            distinctDaysUsed: 300,
            daysSinceFirstUse: 2000,
            daysSinceLastPrompt: 1000,
            promptsShown: 3,
          ),
        ),
        ReviewDecision.alreadyAskedEnough,
      );
    });

    test('the cap is checked before anything else can pass', () {
      // Ordering matters: a person past the cap must not be re-evaluated on
      // usage and let through by a future threshold change.
      final thresholds = const ReviewThresholds(maxPromptsEver: 1);
      expect(
        evaluateReviewEligibility(
          moment: ReviewMoment.settledAfterSuccessfulUse,
          usage: habitual.promptsShownCopy(1),
          thresholds: thresholds,
        ),
        ReviewDecision.alreadyAskedEnough,
      );
    });
  });

  test('there is exactly one permitted moment', () {
    // If a second permitted moment ever appears, it should have to be argued
    // for here rather than added quietly to an enum.
    final permitted = ReviewMoment.values
        .where((m) => !kForbiddenReviewMoments.contains(m))
        .toList();
    expect(permitted, [ReviewMoment.settledAfterSuccessfulUse]);
  });
}

extension on ReviewUsage {
  ReviewUsage promptsShownCopy(int value) => ReviewUsage(
        qualifyingActions: qualifyingActions,
        distinctDaysUsed: distinctDaysUsed,
        daysSinceFirstUse: daysSinceFirstUse,
        daysSinceLastPrompt: daysSinceLastPrompt,
        promptsShown: value,
      );
}
