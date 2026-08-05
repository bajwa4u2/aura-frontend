import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/net/dio_provider.dart';
import '../domain/communication_continuity.dart';

/// Communication Governance v1.0, Roadmap Milestone 8. Thin wrapper over
/// the four backend endpoints — this file introduces no governance logic
/// of its own; every decision (who may act, what a status means) is made
/// server-side and simply represented here.
final continuityProvider = FutureProvider.family<ContinuityResult?, String>((
  ref,
  postId,
) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get('/posts/$postId/continuity');
  final root = res.data;
  final data = (root is Map && root['data'] != null) ? root['data'] : root;
  return ContinuityResult.fromJson(data);
});

class ContinuityRepository {
  const ContinuityRepository(this._dio);

  final Dio _dio;

  Future<void> acknowledge({
    required String postId,
    required String institutionId,
  }) async {
    await _dio.post(
      '/posts/$postId/continuity/acknowledge',
      data: {'institutionId': institutionId},
    );
  }

  Future<void> resolve({
    required String postId,
    required String institutionId,
    required String resolutionStatement,
  }) async {
    await _dio.post(
      '/posts/$postId/continuity/resolve',
      data: {
        'institutionId': institutionId,
        'resolutionStatement': resolutionStatement,
      },
    );
  }

  Future<void> reopen({
    required String postId,
    required String institutionId,
  }) async {
    await _dio.post(
      '/posts/$postId/continuity/reopen',
      data: {'institutionId': institutionId},
    );
  }
}

final continuityRepositoryProvider = Provider<ContinuityRepository>((ref) {
  return ContinuityRepository(ref.watch(dioProvider));
});
