/// Mirrors backend `MonetizationConfig` (provider-agnostic).
///
/// All numeric values, plan codes, product codes, and limits are server-driven.
/// No values in this file are hardcoded — every accessor reads from the JSON
/// payload returned by GET /v1/monetization/config.
library;

enum MonetizationMode { disabled, visible, softEnforce, enforce }

MonetizationMode _modeFrom(String? raw) {
  switch ((raw ?? '').trim().toLowerCase()) {
    case 'visible':
      return MonetizationMode.visible;
    case 'soft_enforce':
      return MonetizationMode.softEnforce;
    case 'enforce':
      return MonetizationMode.enforce;
    case 'disabled':
    default:
      return MonetizationMode.disabled;
  }
}

/// C2 — FOUNDER RULING: VERIFICATION IS NOT PURCHASABLE. `isVerified`
/// was removed from the commercial capability map — verification is a
/// governed fact from the verification authority, never a plan feature.
/// C2 taxonomy closeout — `hasAiEditor`/`hasTranslation`/`hasRealtime`
/// deleted with their backend counterparts: zero consumers, and they
/// falsely presented credit-metered plan-independent features as tier
/// capabilities.
class PlanCapabilities {
  PlanCapabilities({required this.canSpeakOfficially});

  factory PlanCapabilities.fromJson(Map<String, dynamic> json) =>
      PlanCapabilities(canSpeakOfficially: json['canSpeakOfficially'] == true);

  final bool canSpeakOfficially;
}

class PlanConfig {
  PlanConfig({
    required this.code,
    required this.label,
    required this.description,
    required this.capabilities,
    required this.memberLimit,
    required this.productCode,
  });

  factory PlanConfig.fromJson(Map<String, dynamic> json) => PlanConfig(
    code: (json['code'] ?? '').toString(),
    label: (json['label'] ?? '').toString(),
    description: (json['description'] ?? '').toString(),
    capabilities: PlanCapabilities.fromJson(
      Map<String, dynamic>.from(json['capabilities'] as Map? ?? const {}),
    ),
    memberLimit: json['memberLimit'] is num
        ? (json['memberLimit'] as num).toInt()
        : null,
    productCode: json['productCode'] as String?,
  );

  final String code;
  final String label;
  final String description;
  final PlanCapabilities capabilities;
  final int? memberLimit;
  final String? productCode;
}

class CreditPackConfig {
  CreditPackConfig({
    required this.code,
    required this.credits,
    required this.displayPrice,
  });

  factory CreditPackConfig.fromJson(Map<String, dynamic> json) =>
      CreditPackConfig(
        code: (json['code'] ?? '').toString(),
        credits: json['credits'] is num ? (json['credits'] as num).toInt() : 0,
        displayPrice: json['displayPrice'] as String?,
      );

  final String code;
  final int credits;
  final String? displayPrice;
}

/// What one piece of institution work costs from the allowance. Calls and
/// meetings are included, never metered (founder decision 5, 2026-10-07), so
/// the per-minute realtime costs that stood here are gone.
class FeatureCosts {
  FeatureCosts({
    required this.aiEditorShort,
    required this.aiEditorLong,
    required this.translationShort,
    required this.translationLong,
  });

  factory FeatureCosts.fromJson(Map<String, dynamic> json) => FeatureCosts(
    aiEditorShort: _intOf(json['aiEditorShort']),
    aiEditorLong: _intOf(json['aiEditorLong']),
    translationShort: _intOf(json['translationShort']),
    translationLong: _intOf(json['translationLong']),
  );

  final int aiEditorShort;
  final int aiEditorLong;
  final int translationShort;
  final int translationLong;
}

/// One Pro tier as the backend publishes it (founder price list,
/// 2026-10-07). Seats count staff only; the community is never counted.
class PlanTier {
  PlanTier({
    required this.tier,
    required this.label,
    required this.audience,
    required this.seatLimit,
    required this.monthlyAllowance,
    required this.monthlyCents,
    required this.yearlyCents,
    required this.monthlyProductCode,
    required this.yearlyProductCode,
  });

  factory PlanTier.fromJson(Map<String, dynamic> json) => PlanTier(
    tier: (json['tier'] ?? '').toString(),
    label: (json['label'] ?? '').toString(),
    audience: (json['audience'] ?? '').toString(),
    seatLimit: json['seatLimit'] is num
        ? (json['seatLimit'] as num).toInt()
        : null,
    monthlyAllowance: _intOf(json['monthlyAllowance']),
    monthlyCents: _intOf(json['monthlyCents']),
    yearlyCents: _intOf(json['yearlyCents']),
    monthlyProductCode: (json['monthlyProductCode'] ?? '').toString(),
    yearlyProductCode: (json['yearlyProductCode'] ?? '').toString(),
  );

  final String tier;
  final String label;
  final String audience;

  /// Null means no staff-seat limit.
  final int? seatLimit;
  final int monthlyAllowance;
  final int monthlyCents;
  final int yearlyCents;
  final String monthlyProductCode;
  final String yearlyProductCode;
}

class ProviderFlags {
  ProviderFlags({
    required this.stripe,
    required this.appleIap,
    required this.googlePlay,
    required this.windowsStore,
  });

  factory ProviderFlags.fromJson(Map<String, dynamic> json) => ProviderFlags(
    stripe: _enabledOf(json['stripe']),
    appleIap: _enabledOf(json['appleIap']),
    googlePlay: _enabledOf(json['googlePlay']),
    windowsStore: _enabledOf(json['windowsStore']),
  );

  final bool stripe;
  final bool appleIap;
  final bool googlePlay;
  final bool windowsStore;
}

class MonetizationConfig {
  MonetizationConfig({
    required this.mode,
    required this.plans,
    required this.creditPacks,
    required this.featureCosts,
    required this.providers,
    this.tiers = const [],
    this.nonprofitDiscountPercent = 0,
  });

  factory MonetizationConfig.fromJson(Map<String, dynamic> json) {
    final plansRaw = (json['plans'] as List?) ?? const [];
    final creditPacksRaw = (json['creditPacks'] as List?) ?? const [];
    final tiersRaw = (json['tiers'] as List?) ?? const [];

    return MonetizationConfig(
      mode: _modeFrom(json['monetizationMode'] as String?),
      plans: plansRaw
          .whereType<Map>()
          .map((e) => PlanConfig.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false),
      creditPacks: creditPacksRaw
          .whereType<Map>()
          .map((e) => CreditPackConfig.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false),
      featureCosts: FeatureCosts.fromJson(
        Map<String, dynamic>.from(json['featureCosts'] as Map? ?? const {}),
      ),
      providers: ProviderFlags.fromJson(
        Map<String, dynamic>.from(json['providers'] as Map? ?? const {}),
      ),
      tiers: tiersRaw
          .whereType<Map>()
          .map((e) => PlanTier.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false),
      nonprofitDiscountPercent: _intOf(json['nonprofitDiscountPercent']),
    );
  }

  final MonetizationMode mode;
  final List<PlanConfig> plans;
  final List<CreditPackConfig> creditPacks;
  final FeatureCosts featureCosts;
  final ProviderFlags providers;

  /// The Pro tiers, in the order the backend publishes them.
  final List<PlanTier> tiers;

  /// Discount for confirmed nonprofits, schools and faith institutions.
  final int nonprofitDiscountPercent;

  PlanTier? tierByCode(String? code) {
    if (code == null) return null;
    for (final t in tiers) {
      if (t.tier == code) return t;
    }
    return null;
  }

  bool get isVisible =>
      mode == MonetizationMode.visible ||
      mode == MonetizationMode.softEnforce ||
      mode == MonetizationMode.enforce;
}

class InstitutionEntitlements {
  InstitutionEntitlements({
    required this.institutionId,
    required this.plan,
    this.planLabel = '',
    required this.capabilities,
    required this.isVerified,
    required this.canSpeakOfficially,
    required this.memberLimit,
    required this.creditBalance,
    required this.mode,
    this.planTier,
    this.seatLimit,
    this.seatsUsed,
    this.allowanceBalance = 0,
    this.allowanceMonthly = 0,
    this.allowanceResetsAt,
    this.grantEndsAt,
  });

  factory InstitutionEntitlements.fromJson(Map<String, dynamic> json) =>
      InstitutionEntitlements(
        institutionId: (json['institutionId'] ?? '').toString(),
        plan: (json['plan'] ?? 'FREE').toString(),
        planLabel: (() {
          final config = json['planConfig'];
          final label = config is Map
              ? (config['label'] ?? '').toString().trim()
              : '';
          return label;
        })(),
        capabilities: PlanCapabilities.fromJson(
          Map<String, dynamic>.from(json['capabilities'] as Map? ?? const {}),
        ),
        isVerified: json['isVerified'] == true,
        canSpeakOfficially: json['canSpeakOfficially'] == true,
        memberLimit: json['memberLimit'] is num
            ? (json['memberLimit'] as num).toInt()
            : null,
        creditBalance: json['creditBalance'] is num
            ? (json['creditBalance'] as num).toInt()
            : 0,
        mode: _modeFrom(json['monetizationMode'] as String?),
        planTier: json['planTier'] as String?,
        seatLimit: json['seatLimit'] is num
            ? (json['seatLimit'] as num).toInt()
            : null,
        seatsUsed: json['seatsUsed'] is num
            ? (json['seatsUsed'] as num).toInt()
            : null,
        allowanceBalance: _intOf(json['allowanceBalance']),
        allowanceMonthly: _intOf(json['allowanceMonthly']),
        allowanceResetsAt: _dateOf(json['allowanceResetsAt']),
        grantEndsAt: _dateOf(json['grantEndsAt']),
      );

  final String institutionId;
  final String plan;

  /// The Pro tier (COMMUNITY, ORGANISATION, PUBLIC_BODY_*); null on Free.
  final String? planTier;

  /// Staff seats on this plan; null means no limit.
  final int? seatLimit;

  /// Staff seats in use; null when the server could not count them.
  final int? seatsUsed;

  /// What is left of this month's allowance (or of the grant's credits).
  final int allowanceBalance;

  /// The full monthly allowance (or the grant's credits while it runs).
  final int allowanceMonthly;
  final DateTime? allowanceResetsAt;

  /// Set while the 30-day Institutional Grant is running.
  final DateTime? grantEndsAt;

  bool get grantRunning =>
      grantEndsAt != null && grantEndsAt!.isAfter(DateTime.now());

  bool get isPro => plan == 'PRO';

  /// Customer-facing plan name from the config wire. Retired enum values
  /// (legacy VERIFIED/TRUSTED rows) resolve to a neutral legacy label
  /// backend-side, so retired vocabulary never reaches this surface.
  final String planLabel;

  /// The label when present, else the raw plan code.
  String get displayName => planLabel.isNotEmpty ? planLabel : plan;
  final PlanCapabilities capabilities;
  final bool isVerified;
  final bool canSpeakOfficially;
  final int? memberLimit;
  final int creditBalance;
  final MonetizationMode mode;
}

class CheckoutSession {
  CheckoutSession({
    required this.provider,
    required this.externalSessionId,
    required this.url,
    required this.productCode,
  });

  factory CheckoutSession.fromJson(Map<String, dynamic> json) =>
      CheckoutSession(
        provider: (json['provider'] ?? '').toString(),
        externalSessionId: (json['externalSessionId'] ?? '').toString(),
        url: json['url'] as String?,
        productCode: (json['productCode'] ?? '').toString(),
      );

  final String provider;
  final String externalSessionId;
  final String? url;
  final String productCode;
}

enum InstitutionGrantStatus { pending, approved, declined }

/// The 30-day Institutional Grant (founder decisions, 2026-10-07): asked
/// for by an owner, decided by Aura, once per institution and per person.
class InstitutionGrant {
  InstitutionGrant({
    required this.id,
    required this.status,
    required this.requestedTier,
    this.declineReason,
    this.startsAt,
    this.endsAt,
    this.endedAt,
  });

  factory InstitutionGrant.fromJson(Map<String, dynamic> json) =>
      InstitutionGrant(
        id: (json['id'] ?? '').toString(),
        status: switch ((json['status'] ?? '').toString()) {
          'APPROVED' => InstitutionGrantStatus.approved,
          'DECLINED' => InstitutionGrantStatus.declined,
          _ => InstitutionGrantStatus.pending,
        },
        requestedTier: (json['requestedTier'] ?? '').toString(),
        declineReason: json['declineReason'] as String?,
        startsAt: _dateOf(json['startsAt']),
        endsAt: _dateOf(json['endsAt']),
        endedAt: _dateOf(json['endedAt']),
      );

  final String id;
  final InstitutionGrantStatus status;
  final String requestedTier;
  final String? declineReason;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final DateTime? endedAt;

  bool get running =>
      status == InstitutionGrantStatus.approved &&
      endedAt == null &&
      endsAt != null &&
      endsAt!.isAfter(DateTime.now());
}

int _intOf(dynamic v) => v is num ? v.toInt() : 0;

/// Instants stay as the server sent them; presentation localises them through
/// AuraTemporal, the one place human-facing time is converted.
DateTime? _dateOf(dynamic v) =>
    v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;

bool _enabledOf(dynamic v) {
  if (v is Map) {
    final m = Map<String, dynamic>.from(v);
    return m['enabled'] == true;
  }
  return false;
}
