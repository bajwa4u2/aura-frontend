/// The sentences a person reads when a plan, an allowance or the public
/// fair-use limit stops an action (monetization, 2026-10-08).
///
/// Plain statements of fact. None invites a purchase: the same binaries ship
/// to the stores, where a button or a word pointing at buying elsewhere is
/// not allowed. "An owner can ... on the Plan & Billing page" names where the
/// institution's plan lives, which is true on every platform.
library;

/// The public's daily fair-use limit on writing checks.
const String kFairUseDailyLimitSentence =
    "You've used today's free writing checks. They reset tomorrow.";

/// The institution's monthly allowance (and any top-ups) is spent.
const String kAllowanceUsedSentence =
    'This institution has used its allowance. An owner can add more on the '
    'Plan & Billing page.';

/// Speaking in the institution's official voice needs Pro.
const String kOfficialVoiceNeedsProSentence =
    "Official posts need the institution's Pro plan. An owner can choose one "
    'on the Plan & Billing page.';

/// Refusal codes the backend sends for these limits.
const String kFairUseDailyLimit = 'FAIR_USE_DAILY_LIMIT';
const String kCreditsRequired = 'CREDITS_REQUIRED';
const String kPlanRequiredPro = 'PLAN_REQUIRED_PRO';
const String kSeatLimitReached = 'SEAT_LIMIT_REACHED';
const String kNotActingForInstitution = 'NOT_ACTING_FOR_INSTITUTION';
