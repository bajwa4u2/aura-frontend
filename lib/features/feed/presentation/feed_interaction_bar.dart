import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/institutions/institution_access_provider.dart';
import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_space.dart';
import '../../posts/data/reactions_repository.dart';

/// Like / Reply / Repost row used by every feed surface.
///
/// Was previously `_ExploreInteractionBar` private to the institution
/// explore screen — promoted to a public widget so [UnifiedFeedCard] (and any
/// other feed-shape consumer) can wire real reactions instead of placeholder
/// stat pills. Behaviour is unchanged from the explore version.
///
/// `target` is polymorphic over `PostReactionTarget` (user posts) and
/// `InstitutionPostReactionTarget` (institution posts) — the reactions
/// service routes the toggle/state calls to the right backend surface.
class FeedInteractionBar extends ConsumerWidget {
  const FeedInteractionBar({super.key, required this.target});

  final ReactionTarget target;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(institutionIdentityProvider);
    final actor = identity != null && identity.id.isNotEmpty
        ? ReactionActor.institution(identity.id)
        : const ReactionActor.user();
    final canActAsInstitution =
        actor.isInstitution && (identity?.canPublishPosts ?? false);

    final reactionKey = ReactionStateKey(target: target, actor: actor);
    final reactionAsync = ref.watch(reactionStateProvider(reactionKey));

    Future<void> toggleLike() async {
      try {
        final repo = ref.read(reactionsRepositoryProvider);
        await repo.toggle(target, actor: actor);
        ref.invalidate(reactionStateProvider(reactionKey));
      } catch (e) {
        if (!context.mounted) return;
        if (e is DioException && e.response?.statusCode == 403) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Only institution speakers can react as institution.',
              ),
            ),
          );
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update like')),
        );
      }
    }

    String composeReplyTarget() {
      final replyKey = target is InstitutionPostReactionTarget
          ? 'replyToInstitutionPostId=${target.postId}'
              '&parentInstitutionId='
              '${(target as InstitutionPostReactionTarget).institutionId}'
          : 'replyTo=${target.postId}';
      final base = '/compose?$replyKey&surface=dm';
      if (actor.isInstitution && canActAsInstitution) {
        return '$base&asInstitution=1'
            '&institutionId=${actor.actorInstitutionId}';
      }
      return base;
    }

    final liked = reactionAsync.maybeWhen(
      data: (s) => s.liked,
      orElse: () => false,
    );
    final likeLabel = reactionAsync.maybeWhen(
      data: (s) {
        final base = s.liked ? 'Liked' : 'Like';
        return s.likeCount > 0 ? '$base · ${s.likeCount}' : base;
      },
      orElse: () => 'Like',
    );

    Future<void> doRepost() async {
      final controller = TextEditingController();
      try {
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Repost'),
            content: TextField(
              controller: controller,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Add a short line (optional)…',
              ),
            ),
            actions: [
              AuraGhostButton(
                label: 'Cancel',
                onPressed: () => Navigator.of(ctx).pop(false),
              ),
              AuraPrimaryButton(
                label: 'Repost',
                onPressed: () => Navigator.of(ctx).pop(true),
              ),
            ],
          ),
        );
        if (ok != true) return;

        final text = controller.text.trim();
        final dio = ref.read(dioProvider);
        if (target is InstitutionPostReactionTarget) {
          final t = target as InstitutionPostReactionTarget;
          final body = <String, dynamic>{};
          if (text.isNotEmpty) body['text'] = text;
          if (canActAsInstitution) {
            body['asInstitution'] = true;
            body['actorInstitutionId'] = actor.actorInstitutionId;
          }
          await dio.post(
            '/institutions/${t.institutionId}/posts/${t.postId}/repost',
            data: body,
          );
        } else {
          final body = <String, dynamic>{};
          if (text.isNotEmpty) body['text'] = text;
          if (canActAsInstitution) {
            body['asInstitution'] = true;
            body['institutionId'] = actor.actorInstitutionId;
          }
          await dio.post('/posts/${target.postId}/repost', data: body);
        }
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reposted')),
        );
      } catch (_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not repost')),
        );
      } finally {
        controller.dispose();
      }
    }

    return Wrap(
      spacing: AuraSpace.s8,
      runSpacing: AuraSpace.s8,
      children: [
        AuraActionPill(
          icon: liked ? Icons.favorite : Icons.favorite_border,
          label: likeLabel,
          onTap: toggleLike,
          active: liked,
        ),
        AuraActionPill(
          icon: Icons.reply_outlined,
          label: 'Reply',
          onTap: () => context.push(composeReplyTarget()),
        ),
        AuraActionPill(
          icon: Icons.repeat_rounded,
          label: 'Repost',
          onTap: doRepost,
        ),
      ],
    );
  }
}
