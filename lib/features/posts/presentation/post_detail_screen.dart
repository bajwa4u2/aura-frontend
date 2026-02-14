import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';
import '../../feed/domain/post.dart';
import 'widgets/post_card.dart';

Post _postFromAny(dynamic body) {
  if (body is Map) {
    final map = Map<String, dynamic>.from(body);
    final maybePost = map['post'] ?? map['data'];
    if (maybePost is Map) {
      return Post.fromJson(Map<String, dynamic>.from(maybePost));
    }
    return Post.fromJson(map);
  }
  throw StateError('Unexpected post response');
}

final postProvider = FutureProvider.family<Post, String>((ref, id) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get('/posts/$id');
  return _postFromAny(res.data);
});

final repliesProvider = FutureProvider.family<List<Post>, String>((ref, id) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get('/posts/$id/replies');
  final raw = res.data;

  final List items;
  if (raw is Map) {
    final m = Map<String, dynamic>.from(raw);
    items = (m['data'] as List?) ?? (m['items'] as List?) ?? const <dynamic>[];
  } else if (raw is List) {
    items = raw;
  } else {
    items = const <dynamic>[];
  }

  return items.whereType<Map>().map((e) => Post.fromJson(Map<String, dynamic>.from(e))).toList();
});

class PostDetailScreen extends ConsumerWidget {
  const PostDetailScreen({super.key, required this.postId});
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
        )
      ],
      body: ListView(
        padding: EdgeInsets.fromLTRB(AuraSpace.s16, AuraSpace.s12, AuraSpace.s16, AuraSpace.s24),
        children: [
          postAsync.when(
            data: (p) => PostCard(post: p, compact: false),
            loading: () => Padding(
              padding: EdgeInsets.all(AuraSpace.s12),
              child: const Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => AuraCard(child: Text('Could not load post: $e', style: AuraText.body)),
          ),
          SizedBox(height: AuraSpace.s18),
          Text('Replies', style: AuraText.title),
          SizedBox(height: AuraSpace.s10),
          repliesAsync.when(
            data: (items) {
              if (items.isEmpty) {
                return AuraCard(child: Text('No replies yet.', style: AuraText.body));
              }
              return Column(
                children: items
                    .map(
                      (r) => Padding(
                        padding: EdgeInsets.only(bottom: AuraSpace.s10),
                        child: PostCard(post: r, compact: false),
                      ),
                    )
                    .toList(),
              );
            },
            loading: () => Padding(
              padding: EdgeInsets.all(AuraSpace.s12),
              child: const Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => AuraCard(child: Text('Could not load replies: $e', style: AuraText.body)),
          ),
        ],
      ),
    );
  }
}
