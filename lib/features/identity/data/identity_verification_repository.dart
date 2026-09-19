import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/net/dio_provider.dart';

/// Where a person's identity verification stands.
///
/// Mirrors the backend's own vocabulary rather than inventing a client-side
/// simplification. Policy §7 makes the difference between "we could not tell"
/// and "we determined this is false" load-bearing — a client that folded them
/// into one `failed` would make it impossible to say the right thing.
enum IdentityVerificationState {
  pendingReview,
  needsMoreInfo,
  rejected,
  approved,
  withdrawn,
  /// The wire sent something this build does not know. Rendered as "in
  /// review" rather than guessed at: an unknown state must never be presented
  /// as a decision, in either direction.
  unknown;

  static IdentityVerificationState parse(String? raw) {
    switch ((raw ?? '').trim().toUpperCase()) {
      case 'PENDING_REVIEW':
        return IdentityVerificationState.pendingReview;
      case 'NEEDS_MORE_INFO':
        return IdentityVerificationState.needsMoreInfo;
      case 'REJECTED':
        return IdentityVerificationState.rejected;
      case 'APPROVED':
        return IdentityVerificationState.approved;
      case 'WITHDRAWN':
        return IdentityVerificationState.withdrawn;
      default:
        return IdentityVerificationState.unknown;
    }
  }

  bool get isOpen =>
      this == IdentityVerificationState.pendingReview ||
      this == IdentityVerificationState.needsMoreInfo ||
      this == IdentityVerificationState.unknown;
}

/// The two evidence roles Policy §1 authorizes. Not a document taxonomy.
enum IdentityEvidenceKind {
  governmentId,
  /// A photograph of the submitter for a reviewer to compare against the
  /// document. Deliberately not called liveness anywhere in this client: a
  /// static photo proves no such thing, and the wording a person reads should
  /// not claim more than the process delivers.
  selfieComparison;

  String get wire => this == IdentityEvidenceKind.governmentId
      ? 'GOVERNMENT_ID'
      : 'SELFIE_COMPARISON';

  String get label => this == IdentityEvidenceKind.governmentId
      ? 'Photo ID'
      : 'Photo of you';

  String get help => this == IdentityEvidenceKind.governmentId
      ? 'A government-issued document — passport, national ID or driving licence. All four corners visible, text readable.'
      : 'A clear photo of your face, so a reviewer can see you are the person on the document.';

  static IdentityEvidenceKind? parse(String? raw) {
    switch ((raw ?? '').trim().toUpperCase()) {
      case 'GOVERNMENT_ID':
        return IdentityEvidenceKind.governmentId;
      case 'SELFIE_COMPARISON':
        return IdentityEvidenceKind.selfieComparison;
      default:
        return null;
    }
  }
}

/// WHICH DOCUMENT, because the document decides which sides a reviewer needs
/// (founder, 2026-09-19). A driving licence has a back that carries real
/// information; a passport's photo page carries everything. The capture used
/// to take one image whatever the document was.
enum IdentityDocumentKind {
  passport,
  drivingLicence,
  identityCard,
  residencePermit;

  String get wire => switch (this) {
        IdentityDocumentKind.passport => 'PASSPORT',
        IdentityDocumentKind.drivingLicence => 'DRIVING_LICENCE',
        IdentityDocumentKind.identityCard => 'IDENTITY_CARD',
        IdentityDocumentKind.residencePermit => 'RESIDENCE_PERMIT',
      };

  String get label => switch (this) {
        IdentityDocumentKind.passport => 'Passport',
        IdentityDocumentKind.drivingLicence => 'Driving licence',
        IdentityDocumentKind.identityCard => 'Identity card',
        IdentityDocumentKind.residencePermit => 'Residence permit',
      };

  static IdentityDocumentKind? parse(String? raw) =>
      switch ((raw ?? '').trim().toUpperCase()) {
        'PASSPORT' => IdentityDocumentKind.passport,
        'DRIVING_LICENCE' => IdentityDocumentKind.drivingLicence,
        'IDENTITY_CARD' => IdentityDocumentKind.identityCard,
        'RESIDENCE_PERMIT' => IdentityDocumentKind.residencePermit,
        _ => null,
      };
}

/// Which part of the document an image shows.
enum IdentityEvidenceSide {
  photoPage,
  front,
  back;

  String get wire => switch (this) {
        IdentityEvidenceSide.photoPage => 'PHOTO_PAGE',
        IdentityEvidenceSide.front => 'FRONT',
        IdentityEvidenceSide.back => 'BACK',
      };

  String get label => switch (this) {
        IdentityEvidenceSide.photoPage => 'Photo page',
        IdentityEvidenceSide.front => 'Front',
        IdentityEvidenceSide.back => 'Back',
      };

  static IdentityEvidenceSide? parse(String? raw) =>
      switch ((raw ?? '').trim().toUpperCase()) {
        'PHOTO_PAGE' => IdentityEvidenceSide.photoPage,
        'FRONT' => IdentityEvidenceSide.front,
        'BACK' => IdentityEvidenceSide.back,
        _ => null,
      };
}

/// The sides one document needs, as the server states them.
class DocumentSideRule {
  const DocumentSideRule({required this.required, this.optional = const []});

  final List<IdentityEvidenceSide> required;

  /// Accepted when supplied, never demanded (a residence permit's back).
  final List<IdentityEvidenceSide> optional;

  static DocumentSideRule fromJson(Map<String, dynamic> json) {
    List<IdentityEvidenceSide> sides(dynamic raw) => ((raw as List?) ?? const [])
        .map((e) => IdentityEvidenceSide.parse(e?.toString()))
        .whereType<IdentityEvidenceSide>()
        .toList(growable: false);
    return DocumentSideRule(
      required: sides(json['required']),
      optional: sides(json['optional']),
    );
  }
}

/// ONLY for a server older than the sides rule, which sends no
/// `documentSides`. The server's answer always wins when it gives one; this is
/// what it said on 2026-09-19, so an older deploy still gets a usable form.
const Map<IdentityDocumentKind, DocumentSideRule> kFallbackDocumentSides = {
  IdentityDocumentKind.passport:
      DocumentSideRule(required: [IdentityEvidenceSide.photoPage]),
  IdentityDocumentKind.drivingLicence: DocumentSideRule(
    required: [IdentityEvidenceSide.front, IdentityEvidenceSide.back],
  ),
  IdentityDocumentKind.identityCard: DocumentSideRule(
    required: [IdentityEvidenceSide.front, IdentityEvidenceSide.back],
  ),
  IdentityDocumentKind.residencePermit: DocumentSideRule(
    required: [IdentityEvidenceSide.front],
    optional: [IdentityEvidenceSide.back],
  ),
};

/// THE VERIFICATION IN FORCE — recognised before anything is asked.
///
/// A verified person who opened this screen used to be shown the empty
/// first-time form again (2026-09-19). This is what the server says Aura
/// already knows, so the screen can say it back instead.
class VerifiedIdentity {
  const VerifiedIdentity({
    required this.verifiedAt,
    required this.expiresAt,
    required this.documentKind,
    required this.documentType,
    required this.verifiedLegalName,
  });

  final DateTime? verifiedAt;
  final DateTime? expiresAt;
  final IdentityDocumentKind? documentKind;
  final String? documentType;

  /// The legal name as the reviewer read it. Null for approvals made before
  /// names were recorded; never filled in from the profile name.
  final String? verifiedLegalName;

  String? get documentLabel => documentKind?.label ?? documentType;

  static VerifiedIdentity? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final json = Map<String, dynamic>.from(raw);
    String? text(Object? v) {
      final s = (v ?? '').toString().trim();
      return s.isEmpty ? null : s;
    }

    return VerifiedIdentity(
      verifiedAt: _date(json['verifiedAt']),
      expiresAt: _date(json['expiresAt']),
      documentKind: IdentityDocumentKind.parse(json['documentKind']?.toString()),
      documentType: text(json['documentType']),
      verifiedLegalName: text(json['verifiedLegalName']),
    );
  }
}

class IdentityEvidenceSummary {
  const IdentityEvidenceSummary({
    required this.id,
    required this.kind,
    required this.discarded,
    this.side,
  });

  final String id;
  final IdentityEvidenceKind? kind;

  /// Which side of the document this image shows. Null for the photo of the
  /// person and for evidence sent before sides were recorded.
  final IdentityEvidenceSide? side;

  /// Policy §6 destroyed it 60 days after the review ended. Shown plainly
  /// rather than hidden — a person is owed the fact that their document is
  /// gone, and it is the reassuring half of the story, not the alarming one.
  final bool discarded;

  static IdentityEvidenceSummary fromJson(Map<String, dynamic> json) =>
      IdentityEvidenceSummary(
        id: (json['id'] ?? '').toString(),
        kind: IdentityEvidenceKind.parse(json['kind']?.toString()),
        side: IdentityEvidenceSide.parse(json['side']?.toString()),
        discarded: json['discarded'] == true,
      );
}

class IdentityVerificationSubmission {
  const IdentityVerificationSubmission({
    required this.id,
    required this.state,
    required this.submittedAt,
    required this.reviewedAt,
    required this.decisionReason,
    required this.documentType,
    required this.evidence,
    this.documentKind,
  });

  final String id;
  final IdentityVerificationState state;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;

  /// The reviewer's reason. The subject IS owed this — it is what makes
  /// "add a clearer photo" actionable instead of mysterious.
  final String? decisionReason;
  final String? documentType;
  final IdentityDocumentKind? documentKind;
  final List<IdentityEvidenceSummary> evidence;

  static IdentityVerificationSubmission fromJson(Map<String, dynamic> json) =>
      IdentityVerificationSubmission(
        id: (json['id'] ?? '').toString(),
        state: IdentityVerificationState.parse(json['state']?.toString()),
        submittedAt: _date(json['submittedAt']),
        reviewedAt: _date(json['reviewedAt']),
        decisionReason: (json['decisionReason'] as String?)?.trim().isEmpty ?? true
            ? null
            : (json['decisionReason'] as String).trim(),
        documentType: json['documentType']?.toString(),
        documentKind: IdentityDocumentKind.parse(json['documentKind']?.toString()),
        evidence: ((json['evidence'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => IdentityEvidenceSummary.fromJson(Map<String, dynamic>.from(e)))
            .toList(growable: false),
      );
}

class IdentityVerificationStatus {
  const IdentityVerificationStatus({
    required this.current,
    required this.history,
    required this.canSubmit,
    required this.retryAfter,
    required this.blockedReason,
    this.verified,
    this.documentSides = kFallbackDocumentSides,
  });

  final IdentityVerificationSubmission? current;
  final List<IdentityVerificationSubmission> history;
  final bool canSubmit;

  /// Set when a rejection's cooling-off period is still running. Policy §7
  /// makes this finite; showing the date is what makes "never permanent"
  /// visible rather than merely true.
  final DateTime? retryAfter;
  final String? blockedReason;

  /// The verification in force, or null. When set, the person is shown it
  /// and is not offered the first-time form.
  final VerifiedIdentity? verified;

  /// Which sides each document needs — the server's rule.
  final Map<IdentityDocumentKind, DocumentSideRule> documentSides;

  bool get isVerified => verified != null;

  DocumentSideRule sidesFor(IdentityDocumentKind kind) =>
      documentSides[kind] ?? kFallbackDocumentSides[kind]!;

  static Map<IdentityDocumentKind, DocumentSideRule> _sides(dynamic raw) {
    if (raw is! Map) return kFallbackDocumentSides;
    final out = <IdentityDocumentKind, DocumentSideRule>{};
    raw.forEach((key, value) {
      final kind = IdentityDocumentKind.parse(key?.toString());
      if (kind != null && value is Map) {
        out[kind] = DocumentSideRule.fromJson(Map<String, dynamic>.from(value));
      }
    });
    return out.isEmpty ? kFallbackDocumentSides : out;
  }

  static IdentityVerificationStatus fromJson(Map<String, dynamic> json) {
    final current = json['current'];
    return IdentityVerificationStatus(
      current: current is Map
          ? IdentityVerificationSubmission.fromJson(
              Map<String, dynamic>.from(current))
          : null,
      history: ((json['history'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => IdentityVerificationSubmission.fromJson(
              Map<String, dynamic>.from(e)))
          .toList(growable: false),
      canSubmit: json['canSubmit'] == true,
      retryAfter: _date(json['retryAfter']),
      blockedReason: (json['blockedReason'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['blockedReason'] as String).trim(),
      verified: VerifiedIdentity.fromJson(json['verified']),
      documentSides: _sides(json['documentSides']),
    );
  }
}

/// One image or photo being sent, with the side it shows.
typedef IdentityEvidencePiece = ({
  String mediaId,
  IdentityEvidenceKind kind,
  IdentityEvidenceSide? side,
});

List<Map<String, dynamic>> _evidenceWire(List<IdentityEvidencePiece> evidence) =>
    evidence
        .map((e) => {
              'mediaId': e.mediaId,
              'kind': e.kind.wire,
              if (e.kind == IdentityEvidenceKind.governmentId && e.side != null)
                'side': e.side!.wire,
            })
        .toList();

DateTime? _date(dynamic value) {
  final raw = (value ?? '').toString().trim();
  if (raw.isEmpty) return null;
  return DateTime.tryParse(raw);
}

Map<String, dynamic> _unwrap(dynamic data) {
  if (data is Map && data['data'] is Map) {
    return Map<String, dynamic>.from(data['data'] as Map);
  }
  if (data is Map) return Map<String, dynamic>.from(data);
  return <String, dynamic>{};
}

class IdentityVerificationRepository {
  IdentityVerificationRepository(this._dio);

  final Dio _dio;

  Future<IdentityVerificationStatus> mine() async {
    final res = await _dio.get('/identity-verification/me');
    return IdentityVerificationStatus.fromJson(_unwrap(res.data));
  }

  /// Submit. `evidence` carries media ids already uploaded through the
  /// ordinary media door — this client never posts bytes to an identity
  /// endpoint, because a second upload path would be a second set of rules
  /// about what may be uploaded.
  Future<IdentityVerificationSubmission> submit({
    required IdentityDocumentKind documentKind,
    required List<IdentityEvidencePiece> evidence,
    String? documentType,
    DateTime? documentExpiresAt,
  }) async {
    final res = await _dio.post(
      '/identity-verification/me',
      data: {
        'documentKind': documentKind.wire,
        'evidence': _evidenceWire(evidence),
        if (documentType != null && documentType.trim().isNotEmpty)
          'documentType': documentType.trim(),
        if (documentExpiresAt != null)
          'documentExpiresAt':
              documentExpiresAt.toUtc().toIso8601String().split('T').first,
      },
    );
    return IdentityVerificationSubmission.fromJson(_unwrap(res.data));
  }

  Future<IdentityVerificationSubmission> addEvidence({
    required String submissionId,
    required List<IdentityEvidencePiece> evidence,
  }) async {
    final res = await _dio.post(
      '/identity-verification/me/$submissionId/evidence',
      data: {'evidence': _evidenceWire(evidence)},
    );
    return IdentityVerificationSubmission.fromJson(_unwrap(res.data));
  }

  Future<IdentityVerificationSubmission> withdraw(String submissionId) async {
    final res =
        await _dio.post('/identity-verification/me/$submissionId/withdraw');
    return IdentityVerificationSubmission.fromJson(_unwrap(res.data));
  }
}

final identityVerificationRepositoryProvider =
    Provider<IdentityVerificationRepository>(
  (ref) => IdentityVerificationRepository(ref.watch(dioProvider)),
);

final identityVerificationStatusProvider =
    FutureProvider.autoDispose<IdentityVerificationStatus>(
  (ref) => ref.watch(identityVerificationRepositoryProvider).mine(),
);

/// ── WHAT AURA HAS VERIFIED, BY CLASS ──────────────────────────────────────
///
/// Verification is LAYERED and the classes are INDEPENDENT. A person may hold
/// none, one or several, and they are never collapsed into a single "verified"
/// truth, because each substantiates a different claim: holding an institution
/// affiliation says nothing about whether anyone ever checked who the person
/// is, and one badge covering both would state something untrue.
///
/// Distinct from [IdentityVerificationStatus], which is the SUBMISSION
/// lifecycle for the IDENTITY class alone — where a request stands with a
/// reviewer. This is the standing grant across all three classes, including
/// the two that have no submission flow at all.
enum PersonVerificationClass { identity, institutionAffiliation, roleOrCredential }

enum PersonVerificationClassState { notVerified, verified, revoked, expired }

class PersonVerificationClassView {
  const PersonVerificationClassView({
    required this.verificationClass,
    required this.state,
    required this.classSubtype,
    required this.issuingAuthority,
    required this.expiresAt,
  });

  final PersonVerificationClass verificationClass;
  final PersonVerificationClassState state;
  final String? classSubtype;
  final String? issuingAuthority;
  final DateTime? expiresAt;

  static PersonVerificationClassView fromJson(Map<String, dynamic> json) {
    PersonVerificationClass cls() {
      switch ((json['verificationClass'] ?? '').toString()) {
        case 'INSTITUTION_AFFILIATION':
          return PersonVerificationClass.institutionAffiliation;
        case 'ROLE_OR_CREDENTIAL':
          return PersonVerificationClass.roleOrCredential;
        default:
          return PersonVerificationClass.identity;
      }
    }

    PersonVerificationClassState state() {
      switch ((json['state'] ?? '').toString()) {
        case 'VERIFIED':
          return PersonVerificationClassState.verified;
        case 'REVOKED':
          return PersonVerificationClassState.revoked;
        case 'EXPIRED':
          return PersonVerificationClassState.expired;
        default:
          return PersonVerificationClassState.notVerified;
      }
    }

    String? text(Object? v) {
      final s = (v ?? '').toString().trim();
      return s.isEmpty ? null : s;
    }

    final expires = text(json['expiresAt']);
    return PersonVerificationClassView(
      verificationClass: cls(),
      state: state(),
      classSubtype: text(json['classSubtype']),
      issuingAuthority: text(json['issuingAuthority']),
      expiresAt: expires == null ? null : DateTime.tryParse(expires),
    );
  }
}

final personVerificationClassesProvider =
    FutureProvider.autoDispose<List<PersonVerificationClassView>>((ref) async {
  final res = await ref.watch(dioProvider).get('/users/me/verification');
  final data = res.data;
  final inner = data is Map && data['data'] is Map ? data['data'] : data;
  final classes = (inner as Map)['classes'] as List? ?? const [];
  return [
    for (final c in classes)
      PersonVerificationClassView.fromJson(Map<String, dynamic>.from(c as Map)),
  ];
});
