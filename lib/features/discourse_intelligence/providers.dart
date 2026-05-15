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
