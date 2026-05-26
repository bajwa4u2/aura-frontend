import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../net/dio_provider.dart';

/// Apple Store §1.2 UGC compliance — client-side block plumbing.
///
/// Backend endpoints:
///   POST   /v1/blocks/:userId  { reason?, contextPostId? }
///   DELETE /v1/blocks/:userId
///   GET    /v1/blocks          → { items: [{ blocked: {...} }] }
///
/// Blocking creates a moderation notification on the backend in
/// addition to hiding the blocked user's content from the blocker's
/// feed. The frontend caches the blocked-id set in
/// [blockedUserIdsProvider] so card widgets can skip rendering
/// instantly without a round-trip.
class BlocksRepository {
  BlocksRepository(this._dio);
  final Dio _dio;

  Future<void> block(
    String userId, {
    String? reason,
    String? contextPostId,
  }) async {
    await _dio.post(
      '/blocks/$userId',
      data: {
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
        if (contextPostId != null && contextPostId.trim().isNotEmpty)
          'contextPostId': contextPostId.trim(),
      },
    );
  }

  Future<void> unblock(String userId) async {
    await _dio.delete('/blocks/$userId');
  }

  Future<List<BlockedUser>> listMine() async {
    final res = await _dio.get('/blocks');
    final body = res.data;
    if (body is Map && body['items'] is List) {
      return (body['items'] as List)
          .map((row) => BlockedUser.fromJson(row as Map))
          .toList(growable: false);
    }
    return const [];
  }
}

class BlockedUser {
  const BlockedUser({
    required this.id,
    required this.handle,
    required this.displayName,
    this.avatarUrl,
    this.createdAt,
  });

  final String id;
  final String handle;
  final String displayName;
  final String? avatarUrl;
  final DateTime? createdAt;

  factory BlockedUser.fromJson(Map j) {
    final blocked = (j['blocked'] is Map) ? j['blocked'] as Map : j;
    final created = j['createdAt'];
    return BlockedUser(
      id: blocked['id'] as String,
      handle: (blocked['handle'] ?? '') as String,
      displayName: (blocked['displayName'] ?? '') as String,
      avatarUrl: blocked['avatarUrl'] as String?,
      createdAt: created is String ? DateTime.tryParse(created) : null,
    );
  }
}

final blocksRepositoryProvider = Provider<BlocksRepository>(
  (ref) => BlocksRepository(ref.read(dioProvider)),
);

/// Set of blocked user ids the caller has issued. Used by post / card
/// widgets to instantly skip rendering after a block.
///
/// Auto-disposed when no UI surface is watching it. Re-fetched lazily.
final blockedUserIdsProvider = FutureProvider<Set<String>>((ref) async {
  final repo = ref.watch(blocksRepositoryProvider);
  try {
    final rows = await repo.listMine();
    return rows.map((r) => r.id).toSet();
  } catch (_) {
    // Treat any error as "no known blocks" — we don't want a transient
    // network failure to hide the entire feed.
    return <String>{};
  }
});

/// Imperative helper: block a user AND invalidate the cached set so
/// the feed re-filters immediately.
Future<void> blockUser(
  WidgetRef ref,
  String userId, {
  String? reason,
  String? contextPostId,
}) async {
  await ref.read(blocksRepositoryProvider).block(
        userId,
        reason: reason,
        contextPostId: contextPostId,
      );
  ref.invalidate(blockedUserIdsProvider);
}

/// Imperative helper: unblock + invalidate.
Future<void> unblockUser(WidgetRef ref, String userId) async {
  await ref.read(blocksRepositoryProvider).unblock(userId);
  ref.invalidate(blockedUserIdsProvider);
}
