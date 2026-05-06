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

class PlanCapabilities {
  PlanCapabilities({
    required this.canSpeakOfficially,
    required this.isVerified,
    required this.hasAiEditor,
    required this.hasTranslation,
    required this.hasRealtime,
  });

  factory PlanCapabilities.fromJson(Map<String, dynamic> json) =>
      PlanCapabilities(
        canSpeakOfficially: json['canSpeakOfficially'] == true,
        isVerified: json['isVerified'] == true,
        hasAiEditor: json['hasAiEditor'] == true,
        hasTranslation: json['hasTranslation'] == true,
        hasRealtime: json['hasRealtime'] == true,
      );

  final bool canSpeakOfficially;
  final bool isVerified;
  final bool hasAiEditor;
  final bool hasTranslation;
  final bool hasRealtime;
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
        memberLimit:
            json['memberLimit'] is num ? (json['memberLimit'] as num).toInt() : null,
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

class FeatureCosts {
  FeatureCosts({
    required this.aiEditorShort,
    required this.aiEditorLong,
    required this.translationShort,
    required this.translationLong,
    required this.realtimeAudioPerMinute,
    required this.realtimeVideoPerMinute,
  });

  factory FeatureCosts.fromJson(Map<String, dynamic> json) => FeatureCosts(
        aiEditorShort: _intOf(json['aiEditorShort']),
        aiEditorLong: _intOf(json['aiEditorLong']),
        translationShort: _intOf(json['translationShort']),
        translationLong: _intOf(json['translationLong']),
        realtimeAudioPerMinute: _intOf(json['realtimeAudioPerMinute']),
        realtimeVideoPerMinute: _intOf(json['realtimeVideoPerMinute']),
      );

  final int aiEditorShort;
  final int aiEditorLong;
  final int translationShort;
  final int translationLong;
  final int realtimeAudioPerMinute;
  final int realtimeVideoPerMinute;
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
  });

  factory MonetizationConfig.fromJson(Map<String, dynamic> json) {
    final plansRaw = (json['plans'] as List?) ?? const [];
    final creditPacksRaw = (json['creditPacks'] as List?) ?? const [];

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
    );
  }

  final MonetizationMode mode;
  final List<PlanConfig> plans;
  final List<CreditPackConfig> creditPacks;
  final FeatureCosts featureCosts;
  final ProviderFlags providers;

  bool get isVisible =>
      mode == MonetizationMode.visible ||
      mode == MonetizationMode.softEnforce ||
      mode == MonetizationMode.enforce;
}

class InstitutionEntitlements {
  InstitutionEntitlements({
    required this.institutionId,
    required this.plan,
    required this.capabilities,
    required this.isVerified,
    required this.canSpeakOfficially,
    required this.memberLimit,
    required this.creditBalance,
    required this.mode,
  });

  factory InstitutionEntitlements.fromJson(Map<String, dynamic> json) =>
      InstitutionEntitlements(
        institutionId: (json['institutionId'] ?? '').toString(),
        plan: (json['plan'] ?? 'FREE').toString(),
        capabilities: PlanCapabilities.fromJson(
          Map<String, dynamic>.from(json['capabilities'] as Map? ?? const {}),
        ),
        isVerified: json['isVerified'] == true,
        canSpeakOfficially: json['canSpeakOfficially'] == true,
        memberLimit:
            json['memberLimit'] is num ? (json['memberLimit'] as num).toInt() : null,
        creditBalance:
            json['creditBalance'] is num ? (json['creditBalance'] as num).toInt() : 0,
        mode: _modeFrom(json['monetizationMode'] as String?),
      );

  final String institutionId;
  final String plan;
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

  factory CheckoutSession.fromJson(Map<String, dynamic> json) => CheckoutSession(
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

int _intOf(dynamic v) => v is num ? v.toInt() : 0;

bool _enabledOf(dynamic v) {
  if (v is Map) {
    final m = Map<String, dynamic>.from(v);
    return m['enabled'] == true;
  }
  return false;
}
