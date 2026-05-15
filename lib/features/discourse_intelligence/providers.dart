import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/net/dio_provider.dart';
import 'models.dart';

/// Discourse intelligence providers — read-only `FutureProvider`s in
/// front of the new `/v1/discourse/*` endpoints. Each returns a typed
/// page DTO; rail modules consume these and self-collapse when empty.
///
/// No caching layer here on purpose. The endpoints are bounded
/// aggregates (≤ 20 rows, capped windows), and Riverpod's autoDispose
/// + invalidate path is enough for the rail-module lifecycle. When the
/// load profile justifies a Redis materialised view on the backend,
/// these providers do not need to change — the contract stays.

final discourseIssuesProvider =
    FutureProvider<DiscourseIssuesPage>((ref) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get('/discourse/issues');
  return DiscourseIssuesPage.fromJson(res.data);
});

final accountabilityTrailProvider =
    FutureProvider<AccountabilityTrailPage>((ref) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get('/discourse/accountability');
  return AccountabilityTrailPage.fromJson(res.data);
});

final institutionParticipationProvider =
    FutureProvider<InstitutionParticipationPage>((ref) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get('/discourse/institution-participation');
  return InstitutionParticipationPage.fromJson(res.data);
});

// ─────────────────────────────────────────────────────────────────────
//   Phase 2 — sector-aware civic aggregation
// ─────────────────────────────────────────────────────────────────────

/// Family arg for the sector-scoped providers below. Wrapping the
/// optional class + institution filters into one value lets a sector
/// page invalidate / refresh the providers as a unit when the user
/// switches sector or institution context.
class DiscourseScopeArgs {
  const DiscourseScopeArgs({this.institutionClass, this.institutionId});

  final String? institutionClass;
  final String? institutionId;

  Map<String, dynamic> toQuery() => {
        if (institutionClass != null && institutionClass!.isNotEmpty)
          'class': institutionClass,
        if (institutionId != null && institutionId!.isNotEmpty)
          'institutionId': institutionId,
      };

  @override
  bool operator ==(Object other) =>
      other is DiscourseScopeArgs &&
      other.institutionClass == institutionClass &&
      other.institutionId == institutionId;

  @override
  int get hashCode => Object.hash(institutionClass, institutionId);
}

final scopedDiscourseIssuesProvider =
    FutureProvider.family<DiscourseIssuesPage, DiscourseScopeArgs>(
        (ref, args) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get(
    '/discourse/issues',
    queryParameters: args.toQuery(),
  );
  return DiscourseIssuesPage.fromJson(res.data);
});

final unansweredQuestionsProvider =
    FutureProvider.family<UnansweredQuestionsPage, DiscourseScopeArgs>(
        (ref, args) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get(
    '/discourse/unanswered-questions',
    queryParameters: args.toQuery(),
  );
  return UnansweredQuestionsPage.fromJson(res.data);
});

final responsivenessProvider =
    FutureProvider.family<ResponsivenessPage, DiscourseScopeArgs>(
        (ref, args) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get(
    '/discourse/responsiveness',
    queryParameters: args.toQuery(),
  );
  return ResponsivenessPage.fromJson(res.data);
});

final relatedInstitutionsProvider =
    FutureProvider.family<RelatedInstitutionsPage, String>(
        (ref, institutionId) async {
  if (institutionId.isEmpty) {
    return const RelatedInstitutionsPage(items: []);
  }
  final dio = ref.watch(dioProvider);
  final res = await dio.get(
    '/discourse/related-institutions',
    queryParameters: {'institutionId': institutionId},
  );
  return RelatedInstitutionsPage.fromJson(res.data);
});
