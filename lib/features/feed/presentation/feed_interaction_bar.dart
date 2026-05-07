import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/institutions/institution_access_provider.dart';
import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_space.dart';
import '../../posts/data/reactions_repository.dart';
import '../data/unified_feed_providers.dart';
import '../domain/feed_item.dart' show FeedInteraction;

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
  const FeedInteractionBar({
    super.key,
    required this.target,
    this.visibility = FeedInteraction.empty,
  });

  final ReactionTarget target;

  /// Aura interaction visibility & counts as projected by the backend.
  /// The bar always renders Like / Reply / Repost actions; numeric counts
  /// only render when the corresponding `canView*Count` flag is true.
  /// Default is `FeedInteraction.empty` (all flags closed), so any caller
  /// that forgets to pass real visibility will never accidentally expose a
  /// count.
  final FeedInteraction visibility;

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
        // Phase 3 — refresh the per-actor reaction state for the bar
        // and the feed surfaces so the snapshot in surrounding cards
        // updates without requiring navigation.
        ref.invalidate(reactionStateProvider(reactionKey));
        invalidateUnifiedFeedSurfaces(ref);
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
    // Like label honors the visibility flag: state ("Like"/"Liked") is
    // always shown so the viewer knows whether they reacted, but the
    // count is appended only when canViewLikeCount=true. We never render
    // "0", "—", or placeholders.
    final likeLabel = reactionAsync.maybeWhen(
      data: (s) {
        final base = s.liked ? 'Liked' : 'Like';
        if (visibility.canViewLikeCount && s.likeCount > 0) {
          return '$base · ${s.likeCount}';
        }
        return base;
      },
      orElse: () => 'Like',
    );

    String replyLabel() {
      if (visibility.canViewReplyCount && visibility.replyCount > 0) {
        return 'Reply · ${visibility.replyCount}';
      }
      return 'Reply';
    }

    String repostLabel() {
      if (visibility.canViewRepostCount && visibility.repostCount > 0) {
        return 'Repost · ${visibility.repostCount}';
      }
      return 'Repost';
    }

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
        // Phase 3 — refresh feed surfaces so the new repost lands on
        // public/member home and the source post's repost count updates
        // without requiring a navigate-away/return cycle.
        invalidateUnifiedFeedSurfaces(ref);
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
          label: replyLabel(),
          // Phase 3 — await the compose result so we can refresh feed
          // counts when the user actually publishes the reply. The
          // compose screen pops with `true` on successful publish.
          onTap: () async {
            final result =
                await context.push<dynamic>(composeReplyTarget());
            if (result == true) invalidateUnifiedFeedSurfaces(ref);
          },
        ),
        AuraActionPill(
          icon: Icons.repeat_rounded,
          label: repostLabel(),
          onTap: doRepost,
        ),
      ],
    );
  }
}
