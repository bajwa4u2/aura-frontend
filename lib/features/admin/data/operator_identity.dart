/// IDENTITY VERIFICATION, AS AN OPERATOR RESPONSIBILITY.
///
/// Aura has held a complete identity-verification authority for some time —
/// submissions, private evidence custody, two governed evidence roles, an
/// audited per-evidence read, a verdict writer, rejection cooling-off, and
/// notifications on all three outcomes. Four admin routes serve it.
///
/// THE OPERATOR CONSOLE HAD NEVER CALLED ONE OF THEM. The worklist produced an
/// identity row and pointed it at the person's subject page, which offers
/// `Grant a class` — a DIFFERENT authority that writes a verification record
/// with no evidence, no completeness check, and no submission to resolve. An
/// operator summoned by the queue could grant somebody's identity without
/// looking at the document they submitted, and the submission stayed open.
///
/// This is the missing half. Nothing here reinvents the authority: every state,
/// every verdict and every rule below is the server's, read from it and named
/// as it names them.
///
/// WHAT THIS DELIBERATELY DOES NOT DO
/// ----------------------------------
///   * It never holds an image or a URL. The detail read returns evidence as
///     an id and a KIND; fetching bytes is a separate act that writes an audit
///     row naming who looked at whose document. Opening the queue must never
///     be a bulk disclosure of identity documents.
///   * It never calls `SELFIE_COMPARISON` liveness. The schema's own comment
///     is explicit: a static image proves no such thing, and renaming it would
///     claim an assurance the manual path does not deliver.
///   * It adds no verdict the authority does not have. Three decisions exist.
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/identity/person_identity_model.dart';
import '../../../core/net/dio_provider.dart';
import '../domain/operator_signal.dart';
import 'operator_cache.dart';

/// The evidence ROLES Policy 1 authorises. Two, and not a document taxonomy.
enum IdentityEvidenceKind {
  /// A government-issued identity document.
  governmentId,

  /// A photograph of the submitter, FOR A REVIEWER TO COMPARE against the
  /// document. Not liveness, and never described as liveness.
  selfieComparison,

  /// A role this build does not recognise. Shown as sent rather than dropped:
  /// an unfamiliar evidence role is still evidence.
  unknown;

  static IdentityEvidenceKind parse(String? wire) =>
      switch ((wire ?? '').trim().toUpperCase()) {
        'GOVERNMENT_ID' => IdentityEvidenceKind.governmentId,
        'SELFIE_COMPARISON' => IdentityEvidenceKind.selfieComparison,
        _ => IdentityEvidenceKind.unknown,
      };

  /// What the operator is being shown, in the product's words.
  String get label => switch (this) {
        IdentityEvidenceKind.governmentId => 'Government ID',
        IdentityEvidenceKind.selfieComparison => 'Photograph to compare',
        IdentityEvidenceKind.unknown => 'Evidence',
      };

  /// What it is FOR — the sentence that stops a reviewer over-reading it.
  String get purpose => switch (this) {
        IdentityEvidenceKind.governmentId =>
          'The document the person submitted.',
        IdentityEvidenceKind.selfieComparison =>
          'For you to compare against the document. This is not a liveness '
              'check and proves nothing on its own.',
        IdentityEvidenceKind.unknown =>
          'A kind of evidence this build does not recognise.',
      };
}

/// The submission states the authority defines. Not a workflow invented here.
enum IdentitySubmissionState {
  pendingReview,
  needsMoreInfo,
  rejected,
  approved,
  withdrawn,
  unknown;

  static IdentitySubmissionState parse(String? wire) =>
      switch ((wire ?? '').trim().toUpperCase()) {
        'PENDING_REVIEW' => IdentitySubmissionState.pendingReview,
        'NEEDS_MORE_INFO' => IdentitySubmissionState.needsMoreInfo,
        'REJECTED' => IdentitySubmissionState.rejected,
        'APPROVED' => IdentitySubmissionState.approved,
        'WITHDRAWN' => IdentitySubmissionState.withdrawn,
        _ => IdentitySubmissionState.unknown,
      };

  String get wire => switch (this) {
        IdentitySubmissionState.pendingReview => 'PENDING_REVIEW',
        IdentitySubmissionState.needsMoreInfo => 'NEEDS_MORE_INFO',
        IdentitySubmissionState.rejected => 'REJECTED',
        IdentitySubmissionState.approved => 'APPROVED',
        IdentitySubmissionState.withdrawn => 'WITHDRAWN',
        IdentitySubmissionState.unknown => 'UNKNOWN',
      };

  String get label => switch (this) {
        IdentitySubmissionState.pendingReview => 'Waiting for a reviewer',
        IdentitySubmissionState.needsMoreInfo => 'More needed',
        IdentitySubmissionState.rejected => 'Refused',
        IdentitySubmissionState.approved => 'Verified',
        IdentitySubmissionState.withdrawn => 'Withdrawn',
        IdentitySubmissionState.unknown => 'Unknown',
      };

  /// Whether an operator can still decide this. The authority refuses a second
  /// decision, so offering one would be offering a conflict.
  bool get awaitsDecision =>
      this == IdentitySubmissionState.pendingReview ||
      this == IdentitySubmissionState.needsMoreInfo;
}

/// One piece of evidence — its ROLE and whether it still exists. Never bytes.
class IdentityEvidence {
  const IdentityEvidence({
    required this.id,
    required this.kind,
    required this.discarded,
  });

  final String id;
  final IdentityEvidenceKind kind;

  /// The bytes were destroyed on schedule. The ROW survives as proof that
  /// evidence of this kind existed, which is a different fact from "there was
  /// never any evidence" and must not be shown as the same thing.
  final bool discarded;

  static IdentityEvidence fromJson(Map<String, dynamic> json) =>
      IdentityEvidence(
        id: (json['id'] ?? '').toString(),
        kind: IdentityEvidenceKind.parse(json['kind']?.toString()),
        discarded: json['discarded'] == true,
      );
}

/// A prior submission by the same person.
///
/// "What happened previously" is one of the questions a reviewer must answer,
/// and answering it from memory is how the same claim gets decided two
/// different ways.
class IdentityPriorSubmission {
  const IdentityPriorSubmission({
    required this.id,
    required this.state,
    required this.submittedAt,
    this.reviewedAt,
    this.decisionReason,
  });

  final String id;
  final IdentitySubmissionState state;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final String? decisionReason;

  static IdentityPriorSubmission fromJson(Map<String, dynamic> json) =>
      IdentityPriorSubmission(
        id: (json['id'] ?? '').toString(),
        state: IdentitySubmissionState.parse(json['state']?.toString()),
        submittedAt: _date(json['submittedAt']),
        reviewedAt: _date(json['reviewedAt']),
        decisionReason: _text(json['decisionReason']),
      );
}

/// A row in the review queue: who is waiting, and how long.
class IdentityQueueItem {
  const IdentityQueueItem({
    required this.id,
    required this.userId,
    required this.subject,
    required this.state,
    required this.evidenceCount,
    this.tier,
    this.documentType,
    this.submittedAt,
  });

  final String id;
  final String userId;

  /// Canonical person identity. The queue used to return `userId` alone, so a
  /// reviewer choosing what to work on next was reading cuids.
  final AuraPersonIdentity subject;

  final IdentitySubmissionState state;

  /// How many pieces of evidence exist. A COUNT, never the evidence.
  final int evidenceCount;

  final String? tier;
  final String? documentType;
  final DateTime? submittedAt;

  int get ageDays => submittedAt == null
      ? 0
      : DateTime.now().difference(submittedAt!).inDays;

  static IdentityQueueItem fromJson(Map<String, dynamic> json) =>
      IdentityQueueItem(
        id: (json['id'] ?? '').toString(),
        userId: (json['userId'] ?? '').toString(),
        subject: AuraPersonIdentity.fromJson(
          json['subject'] is Map
              ? Map<String, dynamic>.from(json['subject'] as Map)
              : const <String, dynamic>{},
        ),
        state: IdentitySubmissionState.parse(json['state']?.toString()),
        evidenceCount: (json['evidenceCount'] as num?)?.toInt() ?? 0,
        tier: _text(json['tier']),
        documentType: _text(json['documentType']),
        submittedAt: _date(json['submittedAt']),
      );
}

/// One submission, as a reviewer must be able to read it.
class IdentitySubmission {
  const IdentitySubmission({
    required this.id,
    required this.state,
    required this.subject,
    required this.evidence,
    required this.history,
    this.tier,
    this.documentType,
    this.documentExpiresAt,
    this.submittedAt,
    this.reviewedAt,
    this.decisionReason,
    this.reviewerName,
    this.evidenceDiscardedAt,
  });

  final String id;
  final IdentitySubmissionState state;
  final AuraPersonIdentity subject;
  final List<IdentityEvidence> evidence;
  final List<IdentityPriorSubmission> history;

  final String? tier;
  final String? documentType;
  final DateTime? documentExpiresAt;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final String? decisionReason;
  final String? reviewerName;

  /// When the raw evidence was destroyed on schedule. Non-null means the
  /// images are gone and only the verdict and metadata remain.
  final DateTime? evidenceDiscardedAt;

  bool get awaitsDecision => state.awaitsDecision;

  /// Evidence that can still be opened.
  Iterable<IdentityEvidence> get readable =>
      evidence.where((e) => !e.discarded);

  /// Whether the roles the authority requires for approval are all present.
  ///
  /// Asked HERE so the console can say what is missing before an operator
  /// commits, rather than letting them find out from a rejected request. The
  /// server enforces it regardless — this never becomes the rule, only an
  /// earlier statement of it.
  List<IdentityEvidenceKind> get missingForApproval {
    final present = readable.map((e) => e.kind).toSet();
    return [
      IdentityEvidenceKind.governmentId,
      IdentityEvidenceKind.selfieComparison,
    ].where((k) => !present.contains(k)).toList();
  }

  bool get canApproveOnEvidence => missingForApproval.isEmpty;

  static IdentitySubmission fromJson(Map<String, dynamic> json) {
    final body = json['data'] is Map
        ? Map<String, dynamic>.from(json['data'] as Map)
        : json;
    final reviewer = body['reviewedBy'];
    return IdentitySubmission(
      id: (body['id'] ?? '').toString(),
      state: IdentitySubmissionState.parse(body['state']?.toString()),
      subject: AuraPersonIdentity.fromJson(
        body['subject'] is Map
            ? Map<String, dynamic>.from(body['subject'] as Map)
            : const <String, dynamic>{},
      ),
      evidence: body['evidence'] is List
          ? (body['evidence'] as List)
              .whereType<Map>()
              .map((e) => IdentityEvidence.fromJson(
                    Map<String, dynamic>.from(e),
                  ))
              .toList()
          : const [],
      history: body['history'] is List
          ? (body['history'] as List)
              .whereType<Map>()
              .map((e) => IdentityPriorSubmission.fromJson(
                    Map<String, dynamic>.from(e),
                  ))
              .toList()
          : const [],
      tier: _text(body['tier']),
      documentType: _text(body['documentType']),
      documentExpiresAt: _date(body['documentExpiresAt']),
      submittedAt: _date(body['submittedAt']),
      reviewedAt: _date(body['reviewedAt']),
      decisionReason: _text(body['decisionReason']),
      reviewerName: reviewer is Map
          ? _text(Map<String, dynamic>.from(reviewer)['displayName'])
          : null,
      evidenceDiscardedAt: _date(body['evidenceDiscardedAt']),
    );
  }
}

/// Where one piece of evidence can be looked at, once.
///
/// Obtaining this WRITES AN AUDIT ROW naming who looked at whose identity
/// document, which is why it is a POST and why nothing prefetches it.
class IdentityEvidenceView {
  const IdentityEvidenceView({
    required this.evidenceId,
    required this.url,
    this.contentType,
  });

  final String evidenceId;
  final String url;
  final String? contentType;

  static IdentityEvidenceView fromJson(String evidenceId, dynamic raw) {
    final body = raw is Map ? Map<String, dynamic>.from(raw) : const {};
    final inner = body['data'] is Map
        ? Map<String, dynamic>.from(body['data'] as Map)
        : body;
    return IdentityEvidenceView(
      evidenceId: evidenceId,
      url: (inner['url'] ?? inner['deliveryUrl'] ?? '').toString(),
      contentType: _text(inner['contentType'] ?? inner['mimeType']),
    );
  }
}

String? _text(dynamic v) {
  final s = (v ?? '').toString().trim();
  return s.isEmpty ? null : s;
}

DateTime? _date(dynamic v) {
  final s = (v ?? '').toString().trim();
  return s.isEmpty ? null : DateTime.tryParse(s);
}

// ─────────────────────────────────────────────────────────────────────────────

class OperatorIdentityRepository {
  const OperatorIdentityRepository(this._dio);

  final Dio _dio;

  static List<Map<String, dynamic>> _items(dynamic raw) {
    final body = raw is Map ? Map<String, dynamic>.from(raw) : const {};
    final inner = body['data'] ?? body['items'] ?? raw;
    if (inner is List) {
      return inner.whereType<Map>().map(Map<String, dynamic>.from).toList();
    }
    if (inner is Map && inner['items'] is List) {
      return (inner['items'] as List)
          .whereType<Map>()
          .map(Map<String, dynamic>.from)
          .toList();
    }
    return const [];
  }

  Future<List<IdentityQueueItem>> queue({String? state}) async {
    final res = await _dio.get(
      '/v1/admin/identity-verification/queue',
      queryParameters: {if (state != null && state.isNotEmpty) 'state': state},
    );
    return _items(res.data).map(IdentityQueueItem.fromJson).toList();
  }

  Future<IdentitySubmission> submission(String id) async {
    final res = await _dio.get('/v1/admin/identity-verification/$id');
    final body = res.data is Map
        ? Map<String, dynamic>.from(res.data as Map)
        : <String, dynamic>{};
    return IdentitySubmission.fromJson(body);
  }

  /// Open ONE piece of evidence. Audited server-side before the door opens.
  Future<IdentityEvidenceView> viewEvidence(String evidenceId) async {
    final res = await _dio.post(
      '/v1/admin/identity-verification/evidence/$evidenceId/view',
    );
    return IdentityEvidenceView.fromJson(evidenceId, res.data);
  }

  /// The verdict. `reason` is required by the authority for every decision.
  Future<void> decide(
    String submissionId, {
    required String decision,
    required String reason,
    String? documentType,
  }) async {
    await _dio.post(
      '/v1/admin/identity-verification/$submissionId/decide',
      data: {
        'decision': decision,
        'reason': reason,
        if (documentType != null && documentType.isNotEmpty)
          'documentType': documentType,
      },
    );
  }
}

final operatorIdentityRepositoryProvider =
    Provider<OperatorIdentityRepository>((ref) {
  return OperatorIdentityRepository(ref.watch(dioProvider));
});

/// The review queue, as a signal — a read failure must not read as an empty
/// queue, and an operator without the grant must be told which grant.
final identityQueueProvider = FutureProvider.autoDispose<
    OperatorSignal<List<IdentityQueueItem>>>((ref) async {
  cacheOperatorReading(ref);
  try {
    final rows = await ref.watch(operatorIdentityRepositoryProvider).queue();
    return OperatorSignal.complete(rows, readAt: DateTime.now());
  } on DioException catch (e) {
    final code = e.response?.statusCode;
    if (code == 401 || code == 403) {
      return const OperatorSignal.unauthorized(needs: 'identity verification');
    }
    return const OperatorSignal.unavailable(detail: 'could not be read');
  }
});

final identitySubmissionProvider = FutureProvider.autoDispose
    .family<OperatorSignal<IdentitySubmission>, String>((ref, id) async {
  try {
    final row =
        await ref.watch(operatorIdentityRepositoryProvider).submission(id);
    return OperatorSignal.complete(row, readAt: DateTime.now());
  } on DioException catch (e) {
    final code = e.response?.statusCode;
    if (code == 401 || code == 403) {
      return const OperatorSignal.unauthorized(needs: 'identity verification');
    }
    if (code == 404) {
      return const OperatorSignal.unavailable(detail: 'no longer exists');
    }
    return const OperatorSignal.unavailable(detail: 'could not be read');
  }
});

/// The person's OPEN submission, if any — for the subject page.
///
/// A person subject should say "an identity decision is waiting on this
/// person" where one is, and link to it. Derived from the queue rather than a
/// second endpoint: one read, one truth.
final openIdentitySubmissionForPersonProvider = Provider.autoDispose
    .family<IdentityQueueItem?, String>((ref, userId) {
  final queue = ref.watch(identityQueueProvider).valueOrNull;
  final rows = queue?.value;
  if (rows == null) return null;
  for (final row in rows) {
    if (row.userId == userId && row.state.awaitsDecision) return row;
  }
  return null;
});
