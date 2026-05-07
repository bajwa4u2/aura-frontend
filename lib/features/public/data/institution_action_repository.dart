import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/net/dio_provider.dart';

/// Public-UX Phase 4 — institution-action client.
///
/// Calls the new institution-post PATCH endpoints:
///   * `PATCH /v1/institutions/:institutionId/posts/:postId/accountability`
///   * `PATCH /v1/institutions/:institutionId/posts/:postId/paid-action`
///
/// Both endpoints are ADMIN/OWNER-only on the backend (gated by the
/// existing `InstitutionRoleGuard`). The frontend gates the UI to
/// avoid round-tripping a 403 — the bottom sheet that triggers these
/// only renders when the current user holds an admin role on the
/// replying institution.
class InstitutionActionRepository {
  InstitutionActionRepository(this._dio);

  final Dio _dio;

  Future<void> setAccountability({
    required String institutionId,
    required String postId,
    required String? tag, // null clears
  }) async {
    final iid = institutionId.trim();
    final pid = postId.trim();
    if (iid.isEmpty || pid.isEmpty) {
      throw Exception('Institution and post id are required.');
    }
    await _dio.patch<dynamic>(
      '/institutions/$iid/posts/$pid/accountability',
      data: {'tag': tag},
    );
  }

  Future<void> setPaidAction({
    required String institutionId,
    required String postId,
    required String? kind, // null clears
  }) async {
    final iid = institutionId.trim();
    final pid = postId.trim();
    if (iid.isEmpty || pid.isEmpty) {
      throw Exception('Institution and post id are required.');
    }
    await _dio.patch<dynamic>(
      '/institutions/$iid/posts/$pid/paid-action',
      data: {'kind': kind},
    );
  }
}

final institutionActionRepositoryProvider =
    Provider<InstitutionActionRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return InstitutionActionRepository(dio);
});
