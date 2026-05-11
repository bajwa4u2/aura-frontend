import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_providers.dart';
import '../../../core/net/dio_provider.dart';

/// Public-UX Phase 6.1 — frontend client for the new thread + space
/// follow endpoints (`/v1/follows/thread/:id`, `/v1/follows/space/:slug`).
///
/// Distinct from `lib/core/interactions/follows_repository.dart`, which
/// targets USER + INSTITUTION pairs through the `/v1/follows` body
/// API. The two repositories don't share state — each owns its own
/// providers — so the existing actor-aware follow surface keeps its
/// behavior intact.
class ThreadSpaceFollowRepository {
  ThreadSpaceFollowRepository(this._dio);

  final Dio _dio;

  Future<bool> getThreadFollowing(String threadPostId) async {
    final id = threadPostId.trim();
    if (id.isEmpty) return false;
    try {
      final res = await _dio.get<dynamic>(
        '/follows/thread/$id/state',
      );
      return _readFollowing(res.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return false;
      rethrow;
    }
  }

  Future<bool> followThread(String threadPostId) async {
    final id = threadPostId.trim();
    if (id.isEmpty) return false;
    final res = await _dio.post<dynamic>('/follows/thread/$id');
    return _readFollowing(res.data);
  }

  Future<bool> unfollowThread(String threadPostId) async {
    final id = threadPostId.trim();
    if (id.isEmpty) return false;
    final res = await _dio.delete<dynamic>('/follows/thread/$id');
    return _readFollowing(res.data);
  }

  Future<bool> getSpaceFollowing(String slug) async {
    final s = slug.trim().toLowerCase();
    if (s.isEmpty) return false;
    try {
      final res = await _dio.get<dynamic>('/follows/space/$s/state');
      return _readFollowing(res.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return false;
      rethrow;
    }
  }

  Future<bool> followSpace(String slug) async {
    final s = slug.trim().toLowerCase();
    if (s.isEmpty) return false;
    final res = await _dio.post<dynamic>('/follows/space/$s');
    return _readFollowing(res.data);
  }

  Future<bool> unfollowSpace(String slug) async {
    final s = slug.trim().toLowerCase();
    if (s.isEmpty) return false;
    final res = await _dio.delete<dynamic>('/follows/space/$s');
    return _readFollowing(res.data);
  }

  bool _readFollowing(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      if (raw['following'] is bool) return raw['following'] as bool;
      final inner = raw['data'];
      if (inner is Map && inner['following'] is bool) {
        return inner['following'] as bool;
      }
    }
    if (raw is Map) {
      if (raw['following'] is bool) return raw['following'] as bool;
    }
    return false;
  }
}

final threadSpaceFollowRepositoryProvider =
    Provider<ThreadSpaceFollowRepository>((ref) {
  return ThreadSpaceFollowRepository(ref.watch(dioProvider));
});

/// `family<bool, threadPostId>` — true when the current user follows
/// the thread.
///
/// Auth-gated: signed-out visitors get `false` without a network call
/// (the endpoint is 401-only). Public visitors browsing public threads
/// see the unfollowed default; the FollowButton on the same surface
/// renders its signed-out variant (route to /login on tap).
final threadFollowingProvider =
    FutureProvider.family<bool, String>((ref, threadPostId) async {
  final authed = ref.watch(isAuthedProvider);
  if (!authed) return false;
  final repo = ref.watch(threadSpaceFollowRepositoryProvider);
  return repo.getThreadFollowing(threadPostId);
});

/// `family<bool, slug>` — true when the current user follows the space.
///
/// Same auth gate as `threadFollowingProvider`.
final spaceFollowingProvider =
    FutureProvider.family<bool, String>((ref, slug) async {
  final authed = ref.watch(isAuthedProvider);
  if (!authed) return false;
  final repo = ref.watch(threadSpaceFollowRepositoryProvider);
  return repo.getSpaceFollowing(slug);
});
