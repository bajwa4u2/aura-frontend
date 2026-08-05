import 'package:dio/dio.dart';

import '../../institutions/announcements/integrity/announcement_integrity.dart';

/// Communication Governance v1.0, Roadmap Milestone 7 — Ambient Governance
/// for personal posts. Wraps `PersonalPostIntegrityController`
/// (`/posts/:id/integrity/*`), which was built "to the exact shape of
/// InstitutionPostIntegrityController" — this repository deliberately
/// reuses the same `AnnouncementIntegrity*` models the institution/
/// announcement flows already use rather than introducing parallel ones,
/// since the wire shape is genuinely identical
/// (`PublisherFacingAssessment`/`PendingRequiredAction` on the backend).
class PersonalPostIntegrityRepository {
  const PersonalPostIntegrityRepository(this._dio);

  final Dio _dio;

  Future<AnnouncementIntegrityReviewResult> requestReview(String postId) async {
    final res = await _dio.post('/posts/$postId/integrity/review');
    return AnnouncementIntegrityReviewResult.fromJson(
      Map<String, dynamic>.from(res.data as Map),
    );
  }

  Future<AnnouncementIntegrityPendingAction> acknowledge({
    required String postId,
    required String decisionId,
  }) async {
    final res = await _dio.post('/posts/$postId/integrity/$decisionId/acknowledge');
    final root = Map<String, dynamic>.from(res.data as Map);
    return AnnouncementIntegrityPendingAction.fromJson(
      Map<String, dynamic>.from(root['pendingAction'] as Map),
    );
  }

  Future<AnnouncementIntegrityPendingAction> secondReview({
    required String postId,
    required String decisionId,
  }) async {
    final res = await _dio.post('/posts/$postId/integrity/$decisionId/second-review');
    final root = Map<String, dynamic>.from(res.data as Map);
    return AnnouncementIntegrityPendingAction.fromJson(
      Map<String, dynamic>.from(root['pendingAction'] as Map),
    );
  }
}
