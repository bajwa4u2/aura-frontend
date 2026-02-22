import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/net/dio_provider.dart';
import '../../../../core/ui/aura_card.dart';
import '../../../../core/ui/aura_space.dart';
import '../../../../core/ui/aura_text.dart';
import '../../../feed/domain/post.dart';

String? _resolveAvatarUrl(WidgetRef ref, String? raw) {
  final url = (raw ?? '').trim();
  if (url.isEmpty) return null;

  // Already absolute
  if (url.startsWith('http://') || url.startsWith('https://')) return url;

  // Backend stores avatarUrl like: /uploads/<file>
  // We must load it from API host, not from the frontend origin.
  final dio = ref.read(dioProvider);
  var base = dio.options.baseUrl; // e.g. https://api.aura.../v1
  if (base.endsWith('')) base = base.substring(0, base.length - 3);
  while (base.endsWith('/')) {
    base = base.substring(0, base.length - 1);
  }

  if (!url.startsWith('/')) return '$base/$url';
  return '$base$url';
}

final isLikedProvider = FutureProvider.family<bool, String>((ref, postId) async {
  final dio = ref.watch(dioProvider);

  // Backend route: GET /v1/reactions/:postId
  final res = await dio.get('/reactions/$postId');

  if (res.data is Map) {
    final m = Map<String, dynamic>.from(res.data as Map);
    return (m['liked'] == true) || (m['isLiked'] == true);
  }

  return false;
});

final isSavedProvider = FutureProvider.family<bool, String>((ref, postId) async {
  final dio = ref.watch(dioProvider);

  // Backend route: GET /v1/saves/:postId
  final res = await dio.get('/saves/$postId');

  if (res.data is Map) {
    final m = Map<String, dynamic>.from(res.data as Map);
    return (m['saved'] == true) || (m['isSaved'] == true);
  }

  return false;
});

class PostCard extends ConsumerWidget {
  const PostCard({super.key, required this.post, this.compact = false});
  final Post post;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = post.author;
    final displayName = a?.displayName ?? '';
    final handle = a?.handle ?? '';
    final subtitle = a == null ? '' : '@$handle${displayName.isNotEmpty ? ' • $displayName' : ''}';

    final avatarResolved = _resolveAvatarUrl(ref, a?.avatarUrl);

    return AuraCard(
      padding: EdgeInsets.all(compact ? AuraSpace.s14 : AuraSpace.s16),
      onTap: () => context.push('/posts/${post.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (a != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0x332E2A26),
                  backgroundImage: (avatarResolved != null) ? NetworkImage(avatarResolved) : null,
                  child: (avatarResolved == null)
                      ? Text(
                          displayName.isNotEmpty ? displayName[0].toUpperCase() : 'A',
                          style: AuraText.body,
                        )
                      : null,
                ),
                SizedBox(width: AuraSpace.s10),
                Expanded(
                  child: InkWell(
                    onTap: () => context.push('/u/$handle'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName.isEmpty ? '@$handle' : displayName,
                          style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
                        ),
                        if (subtitle.isNotEmpty)
                          Text(
                            subtitle,
                            style: AuraText.small,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          if (a != null) SizedBox(height: AuraSpace.s12),
          if (post.repostOfPostId != null && post.repostOfPostId!.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(bottom: AuraSpace.s8),
              child: Text(
                'Repost',
                style: AuraText.small.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          Text(
            post.text,
            maxLines: compact ? 4 : null,
            overflow: compact ? TextOverflow.ellipsis : TextOverflow.visible,
            style: AuraText.body.copyWith(height: 1.45),
          ),
          SizedBox(height: AuraSpace.s12),
          _ActionRow(postId: post.id),
        ],
      ),
    );
  }
}

class _ActionRow extends ConsumerWidget {
  const _ActionRow({required this.postId});
  final String postId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liked = ref.watch(isLikedProvider(postId));
    final saved = ref.watch(isSavedProvider(postId));

    Future<void> toggleLike() async {
      final dio = ref.read(dioProvider);

      // Backend route: POST /v1/reactions/:postId/toggle
      await dio.post('/reactions/$postId/toggle');

      ref.invalidate(isLikedProvider(postId));
    }

    Future<void> toggleSave() async {
      final dio = ref.read(dioProvider);

      // Backend route: POST /v1/saves/:postId/toggle
      await dio.post('/saves/$postId/toggle');

      ref.invalidate(isSavedProvider(postId));
    }

    Future<void> repost() async {
      final controller = TextEditingController();

      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('Repost'),
            content: TextField(
              controller: controller,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Add a short line (optional)…',
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Repost')),
            ],
          );
        },
      );

      if (ok != true) return;

      final text = controller.text.trim();
      final dio = ref.read(dioProvider);

      final payload = <String, dynamic>{};
      if (text.isNotEmpty) payload['text'] = text;

      // Backend route: POST /v1/posts/:id/repost
      await dio.post('/posts/$postId/repost', data: payload);

      ref.invalidate(isLikedProvider(postId));
      ref.invalidate(isSavedProvider(postId));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reposted')));
      }
    }

    return Row(
      children: [
        IconButton(
          tooltip: 'Repost',
          onPressed: repost,
          icon: const Icon(Icons.repeat),
        ),
        IconButton(
          tooltip: 'Appreciate',
          onPressed: toggleLike,
          icon: liked.when(
            data: (v) => Icon(v ? Icons.favorite : Icons.favorite_border),
            loading: () => const Icon(Icons.favorite_border),
            error: (_, __) => const Icon(Icons.favorite_border),
          ),
        ),
        IconButton(
          tooltip: 'Save',
          onPressed: toggleSave,
          icon: saved.when(
            data: (v) => Icon(v ? Icons.bookmark : Icons.bookmark_border),
            loading: () => const Icon(Icons.bookmark_border),
            error: (_, __) => const Icon(Icons.bookmark_border),
          ),
        ),
        const Spacer(),
        IconButton(
          tooltip: 'Reply',
          onPressed: () => context.push('/compose?replyTo=$postId'),
          icon: const Icon(Icons.reply_outlined),
        ),
      ],
    );
  }
}
