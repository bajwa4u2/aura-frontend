/// Domain model for the Communication Integrity System's publisher-facing
/// contract on institution announcements (Milestone 1, Class D).
///
/// Deliberately separate from Writing Assistance (`composition_models.dart`)
/// — these are two different capabilities with two different mental
/// models, and this file exists partly so the two are never accidentally
/// merged into one screen concept. See
/// capability/COMMUNICATION_INTEGRITY_SYSTEM_ANNOUNCEMENT_INTEGRATION_PLAN.md
/// in aura-backend for the full contract this mirrors.
library;

enum AnnouncementIntegrityOutcome {
  continueOutcome,
  requireAcknowledgement,
  requireAdditionalReviewer,
  requireInstitutionalApproval,
  publicationProhibited,
  unknown,
}

extension AnnouncementIntegrityOutcomeX on AnnouncementIntegrityOutcome {
  static AnnouncementIntegrityOutcome fromWire(String? value) {
    switch (value) {
      case 'CONTINUE':
        return AnnouncementIntegrityOutcome.continueOutcome;
      case 'REQUIRE_ACKNOWLEDGEMENT':
        return AnnouncementIntegrityOutcome.requireAcknowledgement;
      case 'REQUIRE_ADDITIONAL_REVIEWER':
        return AnnouncementIntegrityOutcome.requireAdditionalReviewer;
      case 'REQUIRE_INSTITUTIONAL_APPROVAL':
        return AnnouncementIntegrityOutcome.requireInstitutionalApproval;
      case 'PUBLICATION_PROHIBITED':
        return AnnouncementIntegrityOutcome.publicationProhibited;
      default:
        return AnnouncementIntegrityOutcome.unknown;
    }
  }

  /// Plain-language framing for the publisher — never the raw enum, never
  /// heuristic/confidence language. What this communication needs before
  /// it can carry the institution's name, not a verdict on the writer.
  String get publisherLabel {
    switch (this) {
      case AnnouncementIntegrityOutcome.continueOutcome:
        return 'Ready to publish';
      case AnnouncementIntegrityOutcome.requireAcknowledgement:
        return 'Review before publishing';
      case AnnouncementIntegrityOutcome.requireAdditionalReviewer:
        return 'Needs a second reviewer';
      case AnnouncementIntegrityOutcome.requireInstitutionalApproval:
        return 'Needs institutional approval';
      case AnnouncementIntegrityOutcome.publicationProhibited:
        return 'Cannot be published as written';
      case AnnouncementIntegrityOutcome.unknown:
        return 'Review status unavailable';
    }
  }
}

class AnnouncementIntegrityAssessment {
  const AnnouncementIntegrityAssessment({
    required this.overallStatus,
    required this.summaryExplanation,
    required this.decisionExplanation,
    required this.reviewedAt,
  });

  final String overallStatus;
  final String summaryExplanation;
  final String decisionExplanation;
  final String reviewedAt;

  factory AnnouncementIntegrityAssessment.fromJson(Map<String, dynamic> json) {
    return AnnouncementIntegrityAssessment(
      overallStatus: json['overallStatus']?.toString() ?? 'CLEAR',
      summaryExplanation: json['summaryExplanation']?.toString() ?? '',
      decisionExplanation: json['decisionExplanation']?.toString() ?? '',
      reviewedAt: json['reviewedAt']?.toString() ?? '',
    );
  }

  /// Plain-language framing of overallStatus — publishers see this, not
  /// the raw CLEAR/ATTENTION/SIGNIFICANT_CONCERN/CRITICAL_CONCERN enum.
  String get statusLabel {
    switch (overallStatus) {
      case 'CLEAR':
        return 'No concerns found';
      case 'ATTENTION':
        return 'Worth a second look';
      case 'SIGNIFICANT_CONCERN':
        return 'A concern should be resolved';
      case 'CRITICAL_CONCERN':
        return 'Multiple concerns should be resolved';
      default:
        return overallStatus;
    }
  }
}

class AnnouncementIntegritySatisfaction {
  const AnnouncementIntegritySatisfaction({
    required this.satisfiedAt,
    required this.satisfiedByUserId,
    required this.satisfactionType,
  });

  final String satisfiedAt;
  final String satisfiedByUserId;
  final String satisfactionType;

  factory AnnouncementIntegritySatisfaction.fromJson(
    Map<String, dynamic> json,
  ) {
    return AnnouncementIntegritySatisfaction(
      satisfiedAt: json['satisfiedAt']?.toString() ?? '',
      satisfiedByUserId: json['satisfiedByUserId']?.toString() ?? '',
      satisfactionType: json['satisfactionType']?.toString() ?? '',
    );
  }
}

class AnnouncementIntegrityPendingAction {
  const AnnouncementIntegrityPendingAction({
    required this.decisionId,
    required this.outcome,
    required this.reason,
    required this.satisfied,
    this.satisfaction,
  });

  final String decisionId;
  final AnnouncementIntegrityOutcome outcome;
  final String reason;
  final bool satisfied;
  final AnnouncementIntegritySatisfaction? satisfaction;

  factory AnnouncementIntegrityPendingAction.fromJson(
    Map<String, dynamic> json,
  ) {
    final satisfaction = json['satisfaction'];
    return AnnouncementIntegrityPendingAction(
      decisionId: json['decisionId']?.toString() ?? '',
      outcome: AnnouncementIntegrityOutcomeX.fromWire(
        json['outcome']?.toString(),
      ),
      reason: json['reason']?.toString() ?? '',
      satisfied: json['satisfied'] == true,
      satisfaction: satisfaction is Map
          ? AnnouncementIntegritySatisfaction.fromJson(
              Map<String, dynamic>.from(satisfaction),
            )
          : null,
    );
  }

  /// True once this decision no longer blocks publish — either it never
  /// required an action (CONTINUE) or the required action was satisfied.
  bool get clearsPublish =>
      outcome == AnnouncementIntegrityOutcome.continueOutcome || satisfied;
}

class AnnouncementIntegrityReviewResult {
  const AnnouncementIntegrityReviewResult({
    required this.assessment,
    required this.pendingAction,
  });

  final AnnouncementIntegrityAssessment assessment;
  final AnnouncementIntegrityPendingAction pendingAction;

  factory AnnouncementIntegrityReviewResult.fromJson(
    Map<String, dynamic> json,
  ) {
    return AnnouncementIntegrityReviewResult(
      assessment: AnnouncementIntegrityAssessment.fromJson(
        Map<String, dynamic>.from(json['assessment'] as Map),
      ),
      pendingAction: AnnouncementIntegrityPendingAction.fromJson(
        Map<String, dynamic>.from(json['pendingAction'] as Map),
      ),
    );
  }
}
