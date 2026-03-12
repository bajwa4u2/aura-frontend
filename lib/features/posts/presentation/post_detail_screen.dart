import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../feed/domain/post.dart';
import 'widgets/post_card.dart';

Map<String, dynamic> _asMap(dynamic v) {
  if (v is Map) return Map<String, dynamic>.from(v);
  return <String, dynamic>{};
}

List<dynamic> _asList(dynamic v) {
  if (v is List) return v;
  return const <dynamic>[];
}

Post _postFromAny(dynamic body) {
  if (body is Map) {
    final map = Map<String, dynamic>.from(body);

    final directPost = map['post'];
    if (directPost is Map) {
      return Post.fromJson(Map<String, dynamic>.from(directPost));
    }

    final data = map['data'];
    if (data is Map) {
      final dataMap = Map<String, dynamic>.from(data);

      final nestedPost = dataMap['post'];
      if (nestedPost is Map) {
        return Post.fromJson(Map<String, dynamic>.from(nestedPost));
      }

      return Post.fromJson(dataMap);
    }

    return Post.fromJson(map);
  }

  throw StateError('Unexpected post response');
}

List<Post> _repliesFromAny(dynamic body) {
  if (body is List) {
    return body
        .whereType<Map>()
        .map((e) => Post.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  if (body is! Map) return const <Post>[];

  final root = _asMap(body);

  final directItems = _asList(root['items']);
  if (directItems.isNotEmpty) {
    return directItems
        .whereType<Map>()
        .map((e) => Post.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  final directReplies = _asList(root['replies']);
  if (directReplies.isNotEmpty) {
    return directReplies
        .whereType<Map>()
        .map((e) => Post.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  final data = root['data'];

  if (data is List) {
    return data
        .whereType<Map>()
        .map((e) => Post.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  if (data is Map) {
    final dataMap = _asMap(data);

    final nestedItems = _asList(dataMap['items']);
    if (nestedItems.isNotEmpty) {
      return nestedItems
          .whereType<Map>()
          .map((e) => Post.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    final nestedReplies = _asList(dataMap['replies']);
    if (nestedReplies.isNotEmpty) {
      return nestedReplies
          .whereType<Map>()
          .map((e) => Post.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
  }

  return const <Post>[];
}

final postProvider = FutureProvider.family<Post, String>((ref, id) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get('/posts/$id');
  return _postFromAny(res.data);
});

final repliesProvider = FutureProvider.family<List<Post>, String>((ref, id) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get('/posts/$id/replies');
  return _repliesFromAny(res.data);
});

class PostDetailScreen extends ConsumerWidget {
  const PostDetailScreen({
    super.key,
    required this.postId,
  });

  final String postId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postAsync = ref.watch(postProvider(postId));
    final repliesAsync = ref.watch(repliesProvider(postId));

    return AuraScaffold(
      title: 'Post',
      actions: [
        IconButton(
          onPressed: () => context.push('/compose?replyTo=$postId'),
          icon: const Icon(Icons.reply_outlined),
          tooltip: 'Reply',
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AuraSpace.s16,
          AuraSpace.s12,
          AuraSpace.s16,
          AuraSpace.s24,
        ),
        children: [
          postAsync.when(
            data: (post) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PostCard(
                    post: post,
                    compact: false,
                  ),
                ],
              );
            },
            loading: () => const _LoadingCard(),
            error: (e, _) => AuraCard(
              child: Text(
                'Could not load post: $e',
                style: AuraText.body,
              ),
            ),
          ),
          const SizedBox(height: AuraSpace.s18),
          Row(
            children: [
              Text('Replies', style: AuraText.title),
              const SizedBox(width: AuraSpace.s8),
              repliesAsync.when(
                data: (items) => Text(
                  '${items.length}',
                  style: AuraText.small.copyWith(
                    color: AuraSurface.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s10),
          repliesAsync.when(
            data: (items) {
              if (items.isEmpty) {
                return AuraCard(
                  child: Text(
                    'No replies yet.',
                    style: AuraText.body,
                  ),
                );
              }

              return Column(
                children: items
                    .map(
                      (reply) => Padding(
                        padding: const EdgeInsets.only(bottom: AuraSpace.s10),
                        child: PostCard(
                          post: reply,
                          compact: false,
                        ),
                      ),
                    )
                    .toList(),
              );
            },
            loading: () => const _LoadingCard(),
            error: (e, _) => AuraCard(
              child: Text(
                'Could not load replies: $e',
                style: AuraText.body,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      child: Padding(
        padding: const EdgeInsets.all(AuraSpace.s12),
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: AuraSpace.s10),
            Expanded(
              child: Text(
                'Loading…',
                style: AuraText.body,
              ),
            ),
          ],
        ),
      ),
    );
  }
}