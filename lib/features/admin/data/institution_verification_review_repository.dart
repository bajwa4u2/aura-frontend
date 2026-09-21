import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/net/dio_provider.dart';
import '../../institutions/verification/data/institution_verification_repository.dart';

/// THE REVIEWER'S SIDE OF INSTITUTION VERIFICATION.
///
/// Deliberately reuses the owner-side vocabulary rather than defining a second
/// set of states. A reviewer and an owner looking at the same case must be
/// looking at the same fact; two parsers would eventually disagree about what
/// LEGACY_UNVERIFIED means, and the reviewer's copy is the one that would be
/// used to make a decision.
class ExistenceCase {
  const ExistenceCase({
    required this.proofId,
    required this.institutionId,
    required this.state,
    required this.category,
    required this.categoryNeedsReview,
    required this.priority,
    required this.submittedAt,
    this.institutionName,
    this.institutionSlug,
    this.domain,
    this.websiteUrl,
    this.jurisdiction,
  });

  final String proofId;
  final String institutionId;
  final ExistenceState state;

  /// NAMED, NOT ONLY IDENTIFIED — the same rule [AuthorityCase] keeps. The
  /// card asks whether this institution exists, so it has to say which
  /// institution: a cuid gives a reviewer nothing to check a registration
  /// document against.
  final String? institutionName;
  final String? institutionSlug;

  /// The identifying facts a reviewer compares the evidence to. Null where
  /// the institution never supplied one — absent is a fact about the record,
  /// not a gap to paper over.
  final String? domain;
  final String? websiteUrl;
  final String? jurisdiction;

  /// What to call this case. Falls back through slug to the id, so the card
  /// always has a headline even for a record carrying neither.
  String get title => institutionName ?? institutionSlug ?? institutionId;

  /// Null where the legacy class did not map cleanly. NOT a failure — §5.19
  /// asks for a one-time admin review pass for exactly this, and it is why
  /// [categoryNeedsReview] exists as a separate signal.
  final String? category;
  final bool categoryNeedsReview;

  /// §4.3 — high-risk categories get priority placement during the migration
  /// surge. The server decides this; the client only orders by it.
  final bool priority;

  final DateTime? submittedAt;

  static ExistenceCase fromJson(Map<String, dynamic> json) => ExistenceCase(
        proofId: (json['id'] ?? '').toString(),
        institutionId: (json['institutionId'] ?? '').toString(),
        state: ExistenceState.parse(json['state']?.toString()),
        category: json['category']?.toString(),
        categoryNeedsReview: json['categoryNeedsReview'] == true,
        priority: json['priority'] == true,
        submittedAt: DateTime.tryParse(json['submittedAt']?.toString() ?? ''),
        institutionName: _text(json['institutionName']),
        institutionSlug: _text(json['institutionSlug']),
        domain: _text(json['institutionDomain']),
        websiteUrl: _text(json['institutionWebsiteUrl']),
        jurisdiction: _text(json['institutionJurisdiction']),
      );
}

/// Empty and whitespace read as absent. A blank headline is worse than the
/// fallback it would silently beat.
String? _text(Object? v) {
  final s = (v ?? '').toString().trim();
  return s.isEmpty ? null : s;
}

class AuthorityCase {
  const AuthorityCase({
    required this.proofId,
    required this.institutionId,
    required this.userId,
    required this.state,
    required this.evidenceKind,
    required this.submittedAt,
    this.institutionName,
    this.institutionSlug,
    this.claimantHandle,
  });

  final String proofId;
  final String institutionId;

  /// WHOSE authority. An authority claim belongs to one person, and a reviewer
  /// deciding it must be able to see which.
  final String userId;

  final AuthorityState state;
  final AuthorityEvidenceKind? evidenceKind;
  final DateTime? submittedAt;

  /// WHO AND WHICH, IN THE LIST ITSELF. A queue of cuids is a queue an
  /// operator has to open one row at a time to read.
  final String? institutionName;
  final String? institutionSlug;
  final String? claimantHandle;

  /// What to call this case before the detail loads.
  String get title => institutionName ?? institutionSlug ?? institutionId;

  static AuthorityCase fromJson(Map<String, dynamic> json) {
    String? text(Object? v) {
      final s = (v ?? '').toString().trim();
      return s.isEmpty ? null : s;
    }

    return AuthorityCase(
      proofId: (json['id'] ?? '').toString(),
      institutionId: (json['institutionId'] ?? '').toString(),
      userId: (json['userId'] ?? '').toString(),
      state: AuthorityState.parse(json['state']?.toString()),
      evidenceKind: json['evidenceKind'] == null
          ? null
          : AuthorityEvidenceKind.parse(json['evidenceKind']?.toString()),
      submittedAt: DateTime.tryParse(json['submittedAt']?.toString() ?? ''),
      institutionName: text(json['institutionName']),
      institutionSlug: text(json['institutionSlug']),
      claimantHandle: text(json['claimantHandle']),
    );
  }
}

class VerificationQueue {
  const VerificationQueue({required this.existence, required this.authority});

  final List<ExistenceCase> existence;
  final List<AuthorityCase> authority;

  bool get isEmpty => existence.isEmpty && authority.isEmpty;

  static VerificationQueue fromJson(Map<String, dynamic> json) {
    List<T> parse<T>(dynamic raw, T Function(Map<String, dynamic>) f) =>
        ((raw as List?) ?? const [])
            .whereType<Map>()
            .map((e) => f(e.cast<String, dynamic>()))
            .toList(growable: false);

    return VerificationQueue(
      existence: parse(json['existence'], ExistenceCase.fromJson),
      authority: parse(json['authority'], AuthorityCase.fromJson),
    );
  }
}

/// ONE AUTHORITY CLAIM, LAID OUT FOR COMPARISON (founder, 2026-09-19).
///
/// The reviewer must be able to say three things from one place: this is the
/// already-verified person, this is the institution, and the evidence supports
/// the role claimed. So the verified legal name, identity status and expiry,
/// the institution, the claimed role, the evidence on both proofs and the
/// claim's history arrive together. Files are LISTED, never fetched: opening
/// one is a separate, audited act.
class AuthorityClaimDetail {
  const AuthorityClaimDetail({
    required this.proofId,
    required this.institutionId,
    required this.claimantUserId,
    required this.state,
    required this.evidenceKind,
    required this.claimedRole,
    required this.claimedRelationship,
    required this.infoRequested,
    required this.decisionReason,
    required this.submittedAt,
    required this.reviewerIsClaimant,
    required this.claimantName,
    required this.claimantHandle,
    required this.identityVerified,
    required this.verifiedLegalName,
    required this.legalNameRetained,
    required this.roleOnRecord,
    required this.identityVerifiedAt,
    required this.identityExpiresAt,
    required this.identityDocument,
    required this.institutionName,
    required this.institutionSlug,
    required this.institutionDomain,
    required this.institutionWebsite,
    required this.institutionJurisdiction,
    required this.existenceProofId,
    required this.existenceState,
    required this.existenceConfidence,
    required this.existenceCategory,
    required this.evidence,
    required this.transitions,
  });

  final String proofId;
  final String institutionId;
  final String claimantUserId;
  final AuthorityState state;
  final AuthorityEvidenceKind? evidenceKind;
  final String? claimedRole;
  final String? claimedRelationship;
  final String? infoRequested;
  final String? decisionReason;
  final DateTime? submittedAt;

  /// The reviewer IS the claimant. Nobody decides their own authority; the
  /// screen says so and offers no decision.
  final bool reviewerIsClaimant;

  final String? claimantName;
  final String? claimantHandle;

  /// Whether the claimant's identity is verified RIGHT NOW. Authority can
  /// only be confirmed for a verified person.
  final bool identityVerified;

  /// The name the identity reviewer read on the document. Null for approvals
  /// made before legal names were recorded — the reviewer is told so rather
  /// than shown the profile name in its place.
  final String? verifiedLegalName;

  /// Whether the earlier process retained a legal name at all. FALSE is a
  /// real answer and is said out loud: "verified name not retained under the
  /// prior process" is what a reviewer must reason with, and inventing a name
  /// from profile data would be a claim nobody checked (founder, 2026-09-19).
  final bool legalNameRetained;

  /// The membership role Aura holds for this person at this institution —
  /// distinct from what they CLAIM in this request. A reviewer compares both.
  final String? roleOnRecord;
  final DateTime? identityVerifiedAt;
  final DateTime? identityExpiresAt;
  final String? identityDocument;

  final String? institutionName;
  final String? institutionSlug;
  final String? institutionDomain;
  final String? institutionWebsite;
  final String? institutionJurisdiction;

  final String? existenceProofId;
  final ExistenceState? existenceState;
  final ExistenceConfidence? existenceConfidence;
  final String? existenceCategory;

  final List<AuthorityClaimEvidence> evidence;
  final List<AuthorityClaimTransition> transitions;

  static AuthorityClaimDetail fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> map(dynamic v) =>
        v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
    String? text(Object? v) {
      final s = (v ?? '').toString().trim();
      return s.isEmpty ? null : s;
    }

    DateTime? date(Object? v) => DateTime.tryParse(v?.toString() ?? '');
    List<T> list<T>(dynamic raw, T Function(Map<String, dynamic>) f) =>
        ((raw as List?) ?? const [])
            .whereType<Map>()
            .map((e) => f(Map<String, dynamic>.from(e)))
            .toList(growable: false);

    final proof = map(json['proof']);
    final claimant = map(json['claimant']);
    final person = map(claimant['person']);
    final identity = map(claimant['identity']);
    final institution = map(json['institution']);
    final existence = json['existence'] is Map ? map(json['existence']) : null;
    final kind = text(identity['documentKind']);

    return AuthorityClaimDetail(
      proofId: (proof['id'] ?? '').toString(),
      institutionId: (proof['institutionId'] ?? '').toString(),
      claimantUserId: (proof['userId'] ?? '').toString(),
      state: AuthorityState.parse(proof['state']?.toString()),
      evidenceKind: proof['evidenceKind'] == null
          ? null
          : AuthorityEvidenceKind.parse(proof['evidenceKind']?.toString()),
      claimedRole: text(proof['claimedRole']),
      claimedRelationship: text(proof['claimedRelationship']),
      infoRequested: text(proof['infoRequested']),
      decisionReason: text(proof['decisionReason']),
      submittedAt: date(proof['submittedAt']),
      reviewerIsClaimant: json['reviewerIsClaimant'] == true,
      claimantName: text(person['displayName']),
      claimantHandle: text(person['handle']),
      identityVerified: (identity['status'] ?? '').toString() == 'VERIFIED',
      verifiedLegalName: text(identity['verifiedLegalName']),
      // An older server sends no flag; a name being present is then the
      // answer, and its absence stays honestly unknown-but-not-retained.
      legalNameRetained: identity['legalNameRetained'] is bool
          ? identity['legalNameRetained'] == true
          : text(identity['verifiedLegalName']) != null,
      roleOnRecord: text(map(claimant['roleOnRecord'])['title']) ??
          text(map(claimant['roleOnRecord'])['role']),
      identityVerifiedAt: date(identity['verifiedAt']),
      identityExpiresAt: date(identity['expiresAt']),
      identityDocument: kind == null
          ? text(identity['documentType'])
          : switch (kind) {
              'PASSPORT' => 'Passport',
              'DRIVING_LICENCE' => 'Driving licence',
              'IDENTITY_CARD' => 'Identity card',
              'RESIDENCE_PERMIT' => 'Residence permit',
              _ => kind,
            },
      institutionName: text(institution['name']),
      institutionSlug: text(institution['slug']),
      institutionDomain: text(institution['domain']),
      institutionWebsite: text(institution['websiteUrl']),
      institutionJurisdiction: text(institution['jurisdiction']),
      existenceProofId: existence == null ? null : text(existence['id']),
      existenceState: existence == null
          ? null
          : ExistenceState.parse(existence['state']?.toString()),
      existenceConfidence: existence == null || existence['confidence'] == null
          ? null
          : ExistenceConfidence.parse(existence['confidence']?.toString()),
      existenceCategory: existence == null ? null : text(existence['category']),
      evidence: list(json['evidence'], AuthorityClaimEvidence.fromJson),
      transitions: list(json['transitions'], AuthorityClaimTransition.fromJson),
    );
  }
}

/// One document or reference on the claim — never the file itself.
class AuthorityClaimEvidence {
  const AuthorityClaimEvidence({
    required this.id,
    required this.forAuthority,
    required this.authorityKind,
    required this.reference,
    required this.hasFile,
    required this.mimeType,
    required this.fileName,
    required this.submittedByClaimant,
    required this.submittedAt,
    required this.superseded,
    required this.discarded,
    this.alsoSubmittedForExistence = false,
  });

  final String id;

  /// Supplied for the authority question (true) or the institution-exists
  /// question (false). The same document supplied for both is two rows.
  final bool forAuthority;
  final AuthorityEvidenceKind? authorityKind;
  final String? reference;
  final bool hasFile;
  final String? mimeType;
  final String? fileName;
  final bool submittedByClaimant;
  final DateTime? submittedAt;
  final bool superseded;
  final bool discarded;

  /// ONE DOCUMENT, BOTH QUESTIONS. The same file was supplied for the
  /// institution's own proof as well, so a reviewer can decide both from it
  /// instead of asking for a second copy of the same registration.
  final bool alsoSubmittedForExistence;

  bool get isPdf => (mimeType ?? '').toLowerCase() == 'application/pdf';

  static AuthorityClaimEvidence fromJson(Map<String, dynamic> json) {
    String? text(Object? v) {
      final s = (v ?? '').toString().trim();
      return s.isEmpty ? null : s;
    }

    return AuthorityClaimEvidence(
      id: (json['id'] ?? '').toString(),
      forAuthority: (json['for'] ?? '').toString() != 'EXISTENCE',
      authorityKind: json['authorityKind'] == null
          ? null
          : AuthorityEvidenceKind.parse(json['authorityKind']?.toString()),
      reference: text(json['reference']),
      hasFile: json['hasFile'] == true,
      mimeType: text(json['mimeType']),
      fileName: text(json['fileName']),
      submittedByClaimant: json['submittedByClaimant'] == true,
      submittedAt: DateTime.tryParse(json['submittedAt']?.toString() ?? ''),
      superseded: json['superseded'] == true,
      discarded: json['discarded'] == true,
      alsoSubmittedForExistence: json['alsoSubmittedForExistence'] == true,
    );
  }
}

class AuthorityClaimTransition {
  const AuthorityClaimTransition({
    required this.fromState,
    required this.toState,
    required this.actor,
    required this.reason,
    required this.at,
  });

  final String fromState;
  final String toState;
  final String actor;
  final String? reason;
  final DateTime? at;

  static AuthorityClaimTransition fromJson(Map<String, dynamic> json) {
    final reason = (json['reason'] ?? '').toString().trim();
    return AuthorityClaimTransition(
      fromState: (json['fromState'] ?? '').toString(),
      toState: (json['toState'] ?? '').toString(),
      actor: (json['actor'] ?? '').toString(),
      reason: reason.isEmpty ? null : reason,
      at: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    );
  }
}

/// THE SUCCESS ENVELOPE ALSO NESTS.
///
/// Responses arrive as `{ok: true, data: {...}}`. Passing the whole body to a
/// parser finds none of its keys and every field falls to its "unknown"
/// default -- which, for the queue, is an empty queue that looks like
/// a quiet day.
///
/// It is the same mistake as reading the refusal at the top level, on the other
/// side of the same response. `identity_verification_repository.dart` has done
/// this correctly since it was written; this is that `_unwrap`.
Map<String, dynamic> _unwrap(dynamic data) {
  if (data is Map && data['data'] is Map) {
    return Map<String, dynamic>.from(data['data'] as Map);
  }
  if (data is Map) return Map<String, dynamic>.from(data);
  return <String, dynamic>{};
}

class InstitutionVerificationReviewRepository {
  InstitutionVerificationReviewRepository(this._dio);

  final Dio _dio;

  static const String _base = '/institutions/admin/verification';

  Future<VerificationQueue> queue() async {
    return _call(() async {
      final res = await _dio.get<Map<String, dynamic>>('$_base/queue');
      return VerificationQueue.fromJson(_unwrap(res.data));
    });
  }

  // ── existence ─────────────────────────────────────────────────────────────

  Future<void> takeExistence(String proofId) =>
      _post('$_base/existence/$proofId/review');

  Future<void> confirmExistence(String proofId, String confidence, {String? reason}) =>
      _post('$_base/existence/$proofId/confirm', {
        'confidence': confidence,
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason,
      });

  Future<void> rejectExistence(String proofId, String reason) =>
      _post('$_base/existence/$proofId/reject', {'reason': reason});

  Future<void> requestExistenceInfo(String proofId, String infoRequested) =>
      _post('$_base/existence/$proofId/needs-info', {'infoRequested': infoRequested});

  // ── authority ─────────────────────────────────────────────────────────────

  /// The claim beside the verified person it belongs to.
  Future<AuthorityClaimDetail> authorityDetail(String proofId) async {
    return _call(() async {
      final res = await _dio.get<Map<String, dynamic>>('$_base/authority/$proofId');
      return AuthorityClaimDetail.fromJson(_unwrap(res.data));
    });
  }

  /// Open ONE document. The server records who opened it BEFORE it signs the
  /// file, so this is a POST and nothing prefetches it. Returns a short-lived
  /// URL, which is never stored.
  Future<String> openEvidence(String evidenceId) async {
    return _call(() async {
      final res = await _dio.post<Map<String, dynamic>>(
        '$_base/evidence/$evidenceId/view',
      );
      final body = _unwrap(res.data);
      final url = (body['url'] ?? body['deliveryUrl'] ?? '').toString();
      if (url.isEmpty) {
        throw const InstitutionVerificationException(
          'That document could not be opened. Its opening was still recorded.',
        );
      }
      return url;
    });
  }

  Future<void> takeAuthority(String proofId) =>
      _post('$_base/authority/$proofId/review');

  Future<void> confirmAuthority(String proofId, {String? reason}) =>
      _post('$_base/authority/$proofId/confirm', {
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason,
      });

  Future<void> rejectAuthority(String proofId, String reason) =>
      _post('$_base/authority/$proofId/reject', {'reason': reason});

  Future<void> requestAuthorityInfo(String proofId, String infoRequested) =>
      _post('$_base/authority/$proofId/needs-info', {'infoRequested': infoRequested});

  Future<void> revokeAuthority(String proofId, String reason) =>
      _post('$_base/authority/$proofId/revoke', {'reason': reason});

  Future<void> _post(String path, [Map<String, dynamic>? body]) =>
      _call(() async {
        await _dio.post<Map<String, dynamic>>(path, data: body);
      });

  /// ONE mapper, preserving the server's own words.
  ///
  /// A reviewer refused for a reason needs to read that reason, not a generic
  /// sentence. The server already refuses invalid steps precisely — telling a
  /// reviewer "that did not work" when it said "that step is part of this
  /// process, but not one you can take" would send them looking for a bug.
  Future<T> _call<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map) {
        // THE ENVELOPE NESTS UNDER `error`.
        //
        // This read the TOP level, where the API carries only `ok` and
        // `error` -- so `message` was always null and EVERY server refusal
        // fell through to the offline sentence below. A person refused for a
        // specific, actionable reason would have read "we could not reach
        // verification just now" instead.
        //
        // The unit tests did not catch it because they hand-built the payload
        // at the top level: a double of a shape nobody checked. The Windows
        // certification against the real stack did.
        final envelope = data['error'] is Map
            ? (data['error'] as Map)
            : data;
        final message = envelope['message'];
        final code = envelope['code'];
        if (message is String && message.trim().isNotEmpty) {
          return Future<T>.error(
            InstitutionVerificationException(message, code: code?.toString()),
          );
        }
      }
      return Future<T>.error(
        const InstitutionVerificationException(
          'That did not reach the review service. Nothing was decided.',
        ),
      );
    }
  }
}

final institutionVerificationReviewRepositoryProvider =
    Provider<InstitutionVerificationReviewRepository>(
  (ref) => InstitutionVerificationReviewRepository(ref.watch(dioProvider)),
);

final authorityClaimDetailProvider = FutureProvider.autoDispose
    .family<AuthorityClaimDetail, String>((ref, proofId) {
  return ref
      .watch(institutionVerificationReviewRepositoryProvider)
      .authorityDetail(proofId);
});

final institutionVerificationQueueProvider =
    FutureProvider.autoDispose<VerificationQueue>(
  (ref) => ref.watch(institutionVerificationReviewRepositoryProvider).queue(),
);
