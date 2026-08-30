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

class IdentityEvidenceSummary {
  const IdentityEvidenceSummary({
    required this.id,
    required this.kind,
    required this.discarded,
  });

  final String id;
  final IdentityEvidenceKind? kind;

  /// Policy §6 destroyed it 60 days after the review ended. Shown plainly
  /// rather than hidden — a person is owed the fact that their document is
  /// gone, and it is the reassuring half of the story, not the alarming one.
  final bool discarded;

  static IdentityEvidenceSummary fromJson(Map<String, dynamic> json) =>
      IdentityEvidenceSummary(
        id: (json['id'] ?? '').toString(),
        kind: IdentityEvidenceKind.parse(json['kind']?.toString()),
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
  });

  final String id;
  final IdentityVerificationState state;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;

  /// The reviewer's reason. The subject IS owed this — it is what makes
  /// "add a clearer photo" actionable instead of mysterious.
  final String? decisionReason;
  final String? documentType;
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
  });

  final IdentityVerificationSubmission? current;
  final List<IdentityVerificationSubmission> history;
  final bool canSubmit;

  /// Set when a rejection's cooling-off period is still running. Policy §7
  /// makes this finite; showing the date is what makes "never permanent"
  /// visible rather than merely true.
  final DateTime? retryAfter;
  final String? blockedReason;

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
    );
  }
}

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
    required List<({String mediaId, IdentityEvidenceKind kind})> evidence,
    String? documentType,
    DateTime? documentExpiresAt,
  }) async {
    final res = await _dio.post(
      '/identity-verification/me',
      data: {
        'evidence': evidence
            .map((e) => {'mediaId': e.mediaId, 'kind': e.kind.wire})
            .toList(),
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
    required List<({String mediaId, IdentityEvidenceKind kind})> evidence,
  }) async {
    final res = await _dio.post(
      '/identity-verification/me/$submissionId/evidence',
      data: {
        'evidence': evidence
            .map((e) => {'mediaId': e.mediaId, 'kind': e.kind.wire})
            .toList(),
      },
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
