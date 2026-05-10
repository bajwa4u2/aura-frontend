/// Mirrors the backend CompatibilityVerdict contract from
/// `aura-backend/src/platform/release-governance/compatibility.types.ts`.
///
/// Slice C is the first user-visible slice but stays controlled:
///   - compatible / null  → no UI
///   - degraded           → non-blocking soft-warn banner
///   - blocked            → blocking screen, action depends on `action`
///   - maintenance        → maintenance screen
///
/// Defaults are deliberately legacy-safe: any parse miss collapses to
/// `compatible / none` so a backend hiccup never locks the user out.
library;

enum CompatibilityStatus {
  compatible,
  degraded,
  blocked,
  maintenance;

  static CompatibilityStatus fromWire(String? raw) {
    switch (raw) {
      case 'degraded':
        return CompatibilityStatus.degraded;
      case 'blocked':
        return CompatibilityStatus.blocked;
      case 'maintenance':
        return CompatibilityStatus.maintenance;
      case 'compatible':
      default:
        return CompatibilityStatus.compatible;
    }
  }
}

enum CompatibilityAction {
  none,
  softWarn,
  forceUpdate,
  showMaintenance;

  static CompatibilityAction fromWire(String? raw) {
    switch (raw) {
      case 'soft_warn':
        return CompatibilityAction.softWarn;
      case 'force_update':
        return CompatibilityAction.forceUpdate;
      case 'show_maintenance':
        return CompatibilityAction.showMaintenance;
      case 'none':
      default:
        return CompatibilityAction.none;
    }
  }
}

class CompatibilityVerdict {
  const CompatibilityVerdict({
    required this.status,
    required this.action,
    required this.message,
    required this.minSupportedVersion,
    required this.recommendedVersion,
    required this.latestVersion,
    required this.storeUrl,
    required this.policyMatched,
    required this.evaluatedDistribution,
    required this.evaluatedChannel,
  });

  final CompatibilityStatus status;
  final CompatibilityAction action;
  final String? message;
  final String? minSupportedVersion;
  final String? recommendedVersion;
  final String? latestVersion;
  final String? storeUrl;
  final bool policyMatched;
  final String evaluatedDistribution;
  final String evaluatedChannel;

  /// Default verdict used when bootstrap is still loading or the request
  /// failed. Always renders no UI — this is the legacy-safe fallback.
  static const compatible = CompatibilityVerdict(
    status: CompatibilityStatus.compatible,
    action: CompatibilityAction.none,
    message: null,
    minSupportedVersion: null,
    recommendedVersion: null,
    latestVersion: null,
    storeUrl: null,
    policyMatched: false,
    evaluatedDistribution: 'unknown',
    evaluatedChannel: 'production',
  );

  /// Parses a JSON map (the response data payload after the standard
  /// envelope is stripped). Tolerates partial/missing fields by falling
  /// back to compatible defaults.
  static CompatibilityVerdict fromJson(Map<String, dynamic> json) {
    final identity = json['evaluatedIdentity'];
    final identityMap = identity is Map<String, dynamic>
        ? identity
        : const <String, dynamic>{};
    return CompatibilityVerdict(
      status: CompatibilityStatus.fromWire(json['status'] as String?),
      action: CompatibilityAction.fromWire(json['action'] as String?),
      message: _string(json['message']),
      minSupportedVersion: _string(json['minSupportedVersion']),
      recommendedVersion: _string(json['recommendedVersion']),
      latestVersion: _string(json['latestVersion']),
      storeUrl: _string(json['storeUrl']),
      policyMatched: json['policyMatched'] == true,
      evaluatedDistribution:
          _string(identityMap['distribution']) ?? 'unknown',
      evaluatedChannel:
          _string(identityMap['channel']) ?? 'production',
    );
  }

  static String? _string(dynamic v) {
    if (v is String) {
      final t = v.trim();
      return t.isEmpty ? null : t;
    }
    return null;
  }
}
