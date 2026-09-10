import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/net/dio_provider.dart';

/// WHERE AN INSTITUTION'S OWN VERIFICATION STANDS.
///
/// Mirrors the backend's vocabulary exactly rather than inventing a client-side
/// simplification. The three proofs are never collapsed into one badge, and the
/// two lifecycles are tracked separately, because the policy they come from
/// says so in as many words: an institution may exist and be confirmed while
/// the person in front of you has no authority to speak for it, and vice versa.
enum ExistenceState {
  notStarted,
  submitted,
  automatedCheck,
  manualReview,
  confirmed,
  rejected,
  needsInfo,

  /// The wire sent something this build does not know.
  ///
  /// Rendered as "in review", never as a decision in either direction. A build
  /// that guessed would eventually tell somebody they were verified, or that
  /// they were refused, on the strength of a string it had never seen.
  unknown;

  static ExistenceState parse(String? raw) {
    switch ((raw ?? '').trim().toUpperCase()) {
      case 'NOT_STARTED':
        return ExistenceState.notStarted;
      case 'SUBMITTED':
        return ExistenceState.submitted;
      case 'AUTOMATED_CHECK':
        return ExistenceState.automatedCheck;
      case 'MANUAL_REVIEW':
        return ExistenceState.manualReview;
      case 'CONFIRMED':
        return ExistenceState.confirmed;
      case 'REJECTED':
        return ExistenceState.rejected;
      case 'NEEDS_INFO':
        return ExistenceState.needsInfo;
      default:
        return ExistenceState.unknown;
    }
  }

  /// Waiting on somebody here, rather than on us.
  bool get awaitingUs => this == ExistenceState.needsInfo;
}

enum AuthorityState {
  notStarted,
  submitted,
  underReview,
  needsInfo,
  confirmed,
  rejected,

  /// Not folded into anything else, ever. §5.19 calls it "a distinct,
  /// honestly-labeled state, never folded into any newly-defined evidenced
  /// category" — showing it as "verified" would be the exact laundering the
  /// migration was written to avoid.
  legacyUnverified,
  suspended,
  revoked,
  unknown;

  static AuthorityState parse(String? raw) {
    switch ((raw ?? '').trim().toUpperCase()) {
      case 'NOT_STARTED':
        return AuthorityState.notStarted;
      case 'SUBMITTED':
        return AuthorityState.submitted;
      case 'UNDER_REVIEW':
        return AuthorityState.underReview;
      case 'NEEDS_INFO':
        return AuthorityState.needsInfo;
      case 'CONFIRMED':
        return AuthorityState.confirmed;
      case 'REJECTED':
        return AuthorityState.rejected;
      case 'LEGACY_UNVERIFIED':
        return AuthorityState.legacyUnverified;
      case 'SUSPENDED':
        return AuthorityState.suspended;
      case 'REVOKED':
        return AuthorityState.revoked;
      default:
        return AuthorityState.unknown;
    }
  }

  bool get awaitingUs => this == AuthorityState.needsInfo;
}

/// §1.4 — graduated, never binary. DOMAIN_ONLY is a legitimate permanent
/// destination, so it is worded as a statement of what was checked rather than
/// as a shortfall.
enum ExistenceConfidence {
  domainOnly,
  documentReviewed,
  registryConfirmed,
  unknown;

  static ExistenceConfidence parse(String? raw) {
    switch ((raw ?? '').trim().toUpperCase()) {
      case 'DOMAIN_ONLY':
        return ExistenceConfidence.domainOnly;
      case 'DOCUMENT_REVIEWED':
        return ExistenceConfidence.documentReviewed;
      case 'REGISTRY_CONFIRMED':
        return ExistenceConfidence.registryConfirmed;
      default:
        return ExistenceConfidence.unknown;
    }
  }

  String get label {
    switch (this) {
      case ExistenceConfidence.domainOnly:
        return 'Confirmed by domain';
      case ExistenceConfidence.documentReviewed:
        return 'Confirmed by document';
      case ExistenceConfidence.registryConfirmed:
        return 'Confirmed against a register';
      case ExistenceConfidence.unknown:
        return 'Confirmed';
    }
  }
}

/// §2.7's menu. Any ONE item suffices, and the client says so.
enum AuthorityEvidenceKind {
  existingHolderApproval,
  appointmentLetter,
  registryOfficerListing,
  governmentCredential,
  foundingFirstClaimant,
  unknown;

  static AuthorityEvidenceKind parse(String? raw) {
    switch ((raw ?? '').trim().toUpperCase()) {
      case 'EXISTING_HOLDER_APPROVAL':
        return AuthorityEvidenceKind.existingHolderApproval;
      case 'APPOINTMENT_LETTER':
        return AuthorityEvidenceKind.appointmentLetter;
      case 'REGISTRY_OFFICER_LISTING':
        return AuthorityEvidenceKind.registryOfficerListing;
      case 'GOVERNMENT_CREDENTIAL':
        return AuthorityEvidenceKind.governmentCredential;
      case 'FOUNDING_FIRST_CLAIMANT':
        return AuthorityEvidenceKind.foundingFirstClaimant;
      default:
        return AuthorityEvidenceKind.unknown;
    }
  }

  String get wire {
    switch (this) {
      case AuthorityEvidenceKind.existingHolderApproval:
        return 'EXISTING_HOLDER_APPROVAL';
      case AuthorityEvidenceKind.appointmentLetter:
        return 'APPOINTMENT_LETTER';
      case AuthorityEvidenceKind.registryOfficerListing:
        return 'REGISTRY_OFFICER_LISTING';
      case AuthorityEvidenceKind.governmentCredential:
        return 'GOVERNMENT_CREDENTIAL';
      case AuthorityEvidenceKind.foundingFirstClaimant:
        return 'FOUNDING_FIRST_CLAIMANT';
      case AuthorityEvidenceKind.unknown:
        return 'UNKNOWN';
    }
  }

  String get label {
    switch (this) {
      case AuthorityEvidenceKind.existingHolderApproval:
        return 'Approval from someone who already represents it';
      case AuthorityEvidenceKind.appointmentLetter:
        return 'An appointment or authorisation letter';
      case AuthorityEvidenceKind.registryOfficerListing:
        return 'A register listing you as an officer';
      case AuthorityEvidenceKind.governmentCredential:
        return 'A government credential for your position';
      case AuthorityEvidenceKind.foundingFirstClaimant:
        return 'You are the first person claiming it';
      case AuthorityEvidenceKind.unknown:
        return 'Something else';
    }
  }
}

/// THE 120-DAY MIGRATION STANDING, for this person at this institution.
///
/// `NOT_ANCHORED` is the state worth being careful about and the one a client
/// is most likely to get wrong: no notice has been DELIVERED, so nothing is
/// running. Rendering a countdown from today would invent a deadline against
/// somebody who was never told.
class MigrationPosture {
  const MigrationPosture({
    required this.reason,
    required this.deadlineAt,
    required this.daysRemaining,
    required this.authorityGovernanceBlocked,
    required this.institutionVoiceBlocked,
  });

  /// NOT_ANCHORED | SATISFIED | IN_WINDOW | WINDOW_ELAPSED
  final String reason;

  /// §6 — the specific date, never relative phrasing. Null while unanchored.
  final DateTime? deadlineAt;
  final int? daysRemaining;

  /// §3.2 — blocked from the moment the notice lands.
  final bool authorityGovernanceBlocked;

  /// §3.3 — blocked only once the window has run out. Day-to-day work
  /// continues for the whole window, deliberately.
  final bool institutionVoiceBlocked;

  bool get running => reason == 'IN_WINDOW' || reason == 'WINDOW_ELAPSED';

  static MigrationPosture fromJson(Map<String, dynamic>? json) {
    final j = json ?? const <String, dynamic>{};
    return MigrationPosture(
      // An unreadable posture is treated as NOT running rather than as a
      // deadline nobody can see the date of.
      reason: (j['reason'] ?? 'NOT_ANCHORED').toString(),
      deadlineAt: DateTime.tryParse(j['deadlineAt']?.toString() ?? ''),
      daysRemaining: j['daysRemaining'] is int ? j['daysRemaining'] as int : null,
      authorityGovernanceBlocked: j['authorityGovernanceBlocked'] == true,
      institutionVoiceBlocked: j['institutionVoiceBlocked'] == true,
    );
  }
}

/// One proof's standing, and what this person may do about it right now.
class ProofStanding<S> {
  const ProofStanding({
    required this.state,
    required this.available,
    required this.infoRequested,
    required this.acceptsEvidence,
  });

  final S state;

  /// WHAT THE SERVER SAYS IS POSSIBLE, projected from the frozen transition
  /// table. The client renders affordances from THIS and never from its own
  /// opinion about the state — the founder's rule is that a button may exist
  /// only where an edge does, and this is the field that makes that true
  /// rather than merely intended.
  final List<String> available;

  /// What a reviewer asked for. Null unless they asked.
  final String? infoRequested;

  final bool acceptsEvidence;

  bool canSubmit(String target) => available.contains(target);
}

class InstitutionVerificationStanding {
  const InstitutionVerificationStanding({
    required this.institutionId,
    required this.category,
    required this.requiresManualReview,
    required this.existence,
    required this.existenceConfidence,
    required this.accepted,
    required this.requirementNotEnumerated,
    required this.authority,
    required this.authorityEvidenceKind,
    required this.menu,
    required this.migration,
  });

  final String institutionId;
  final String? category;

  /// §1.3 — some categories always need human sign-off. Surfaced so the wait
  /// is explained rather than experienced as the system having stalled.
  final bool requiresManualReview;

  final ProofStanding<ExistenceState> existence;
  final ExistenceConfidence? existenceConfidence;

  /// §1.2's category-specific list. EMPTY where the policy enumerates nothing,
  /// and the screen says so plainly rather than showing an empty box.
  final List<String> accepted;
  final bool requirementNotEnumerated;

  final ProofStanding<AuthorityState> authority;
  final AuthorityEvidenceKind? authorityEvidenceKind;

  /// The whole §2.7 menu. Always offered, never narrowed to a suggestion.
  final List<AuthorityEvidenceKind> menu;

  /// The 120-day standing, delivered with everything else.
  final MigrationPosture migration;

  static InstitutionVerificationStanding fromJson(Map<String, dynamic> json) {
    final existence = (json['existence'] as Map?)?.cast<String, dynamic>() ?? {};
    final authority = (json['authority'] as Map?)?.cast<String, dynamic>() ?? {};

    List<String> strings(dynamic v) =>
        (v as List?)?.map((e) => e.toString()).toList(growable: false) ?? const [];

    return InstitutionVerificationStanding(
      institutionId: (json['institutionId'] ?? '').toString(),
      category: json['category']?.toString(),
      requiresManualReview: json['requiresManualReview'] == true,
      existence: ProofStanding<ExistenceState>(
        state: ExistenceState.parse(existence['state']?.toString()),
        available: strings(existence['available']),
        infoRequested: existence['infoRequested']?.toString(),
        acceptsEvidence: existence['acceptsEvidence'] == true,
      ),
      existenceConfidence: existence['confidence'] == null
          ? null
          : ExistenceConfidence.parse(existence['confidence']?.toString()),
      accepted: strings(existence['accepted']),
      requirementNotEnumerated: existence['requirementNotEnumerated'] == true,
      authority: ProofStanding<AuthorityState>(
        state: AuthorityState.parse(authority['state']?.toString()),
        available: strings(authority['available']),
        infoRequested: authority['infoRequested']?.toString(),
        acceptsEvidence: authority['acceptsEvidence'] == true,
      ),
      authorityEvidenceKind: authority['evidenceKind'] == null
          ? null
          : AuthorityEvidenceKind.parse(authority['evidenceKind']?.toString()),
      menu: strings(authority['menu'])
          .map(AuthorityEvidenceKind.parse)
          .where((k) => k != AuthorityEvidenceKind.unknown)
          .toList(growable: false),
      migration: MigrationPosture.fromJson(
        (json['migration'] as Map?)?.cast<String, dynamic>(),
      ),
    );
  }
}

/// A piece of evidence being offered. Deliberately carries NO submitter:
/// provenance comes from the authenticated caller or it is not provenance, and
/// the server sets it from the token.
class SuppliedEvidence {
  const SuppliedEvidence({this.mediaId, this.reference});

  final String? mediaId;
  final String? reference;

  Map<String, dynamic> toJson() => {
        if (mediaId != null) 'mediaId': mediaId,
        if (reference != null) 'reference': reference,
      };
}

/// Raised with a message a PERSON can act on.
///
/// The server's refusals are already written for the person who hit them — the
/// two-mappers defect on this release was a repository turning a specific
/// reason into a generic sentence and a screen re-mapping it again, so the
/// reason died as "Please try again". The raw message is preserved here.
class InstitutionVerificationException implements Exception {
  const InstitutionVerificationException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

class InstitutionVerificationRepository {
  InstitutionVerificationRepository(this._dio);

  final Dio _dio;

  String _base(String institutionId) => '/institutions/$institutionId/verification';

  Future<InstitutionVerificationStanding> standing(String institutionId) async {
    return _call(() async {
      final res = await _dio.get<Map<String, dynamic>>(_base(institutionId));
      return InstitutionVerificationStanding.fromJson(res.data ?? const {});
    });
  }

  /// Idempotent by design on the server: pressing it twice discards nothing.
  Future<InstitutionVerificationStanding> start(
    String institutionId,
    String category,
  ) async {
    return _call(() async {
      final res = await _dio.post<Map<String, dynamic>>(
        '${_base(institutionId)}/start',
        data: {'category': category},
      );
      return InstitutionVerificationStanding.fromJson(res.data ?? const {});
    });
  }

  Future<InstitutionVerificationStanding> submitExistence(
    String institutionId,
    List<SuppliedEvidence> evidence,
  ) async {
    return _call(() async {
      final res = await _dio.post<Map<String, dynamic>>(
        '${_base(institutionId)}/existence',
        data: {'evidence': evidence.map((e) => e.toJson()).toList()},
      );
      return InstitutionVerificationStanding.fromJson(res.data ?? const {});
    });
  }

  Future<InstitutionVerificationStanding> submitAuthority(
    String institutionId, {
    required AuthorityEvidenceKind evidenceKind,
    required List<SuppliedEvidence> evidence,
    String? relationship,
  }) async {
    return _call(() async {
      final res = await _dio.post<Map<String, dynamic>>(
        '${_base(institutionId)}/authority',
        data: {
          'evidenceKind': evidenceKind.wire,
          if (relationship != null) 'relationship': relationship,
          'evidence': evidence.map((e) => e.toJson()).toList(),
        },
      );
      return InstitutionVerificationStanding.fromJson(res.data ?? const {});
    });
  }

  /// ONE mapper, and it preserves the server's own words.
  Future<T> _call<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map) {
        final message = data['message'];
        final code = data['code'];
        if (message is String && message.trim().isNotEmpty) {
          return Future<T>.error(
            InstitutionVerificationException(message, code: code?.toString()),
          );
        }
      }
      // Only where the server said nothing usable. Never a replacement for a
      // reason it did give.
      return Future<T>.error(
        const InstitutionVerificationException(
          'We could not reach verification just now. Your progress is saved.',
        ),
      );
    }
  }
}

final institutionVerificationRepositoryProvider =
    Provider<InstitutionVerificationRepository>(
  (ref) => InstitutionVerificationRepository(ref.watch(dioProvider)),
);

final institutionVerificationStandingProvider = FutureProvider.autoDispose
    .family<InstitutionVerificationStanding, String>((ref, institutionId) {
  return ref
      .watch(institutionVerificationRepositoryProvider)
      .standing(institutionId);
});
