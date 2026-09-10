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
  });

  final String proofId;
  final String institutionId;
  final ExistenceState state;

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
      );
}

class AuthorityCase {
  const AuthorityCase({
    required this.proofId,
    required this.institutionId,
    required this.userId,
    required this.state,
    required this.evidenceKind,
    required this.submittedAt,
  });

  final String proofId;
  final String institutionId;

  /// WHOSE authority. An authority claim belongs to one person, and a reviewer
  /// deciding it must be able to see which.
  final String userId;

  final AuthorityState state;
  final AuthorityEvidenceKind? evidenceKind;
  final DateTime? submittedAt;

  static AuthorityCase fromJson(Map<String, dynamic> json) => AuthorityCase(
        proofId: (json['id'] ?? '').toString(),
        institutionId: (json['institutionId'] ?? '').toString(),
        userId: (json['userId'] ?? '').toString(),
        state: AuthorityState.parse(json['state']?.toString()),
        evidenceKind: json['evidenceKind'] == null
            ? null
            : AuthorityEvidenceKind.parse(json['evidenceKind']?.toString()),
        submittedAt: DateTime.tryParse(json['submittedAt']?.toString() ?? ''),
      );
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

class InstitutionVerificationReviewRepository {
  InstitutionVerificationReviewRepository(this._dio);

  final Dio _dio;

  static const String _base = '/institutions/admin/verification';

  Future<VerificationQueue> queue() async {
    return _call(() async {
      final res = await _dio.get<Map<String, dynamic>>('$_base/queue');
      return VerificationQueue.fromJson(res.data ?? const {});
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
        final message = data['message'];
        final code = data['code'];
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

final institutionVerificationQueueProvider =
    FutureProvider.autoDispose<VerificationQueue>(
  (ref) => ref.watch(institutionVerificationReviewRepositoryProvider).queue(),
);
