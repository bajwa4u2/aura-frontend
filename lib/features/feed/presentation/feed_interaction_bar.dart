import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_providers.dart';
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
/// stat pills.
///
/// `target` is polymorphic over `PostReactionTarget` (user posts) and
/// `InstitutionPostReactionTarget` (institution posts) — the reactions
/// service routes the toggle/state calls to the right backend surface.
///
/// R1 hardening:
///  * concurrent-tap guard per action (like / repost / reply)
///  * optimistic like + rollback on backend failure
///  * canonical provider invalidation after success
class FeedInteractionBar extends ConsumerStatefulWidget {
  const FeedInteractionBar({
    super.key,
    required this.target,
    this.visibility = FeedInteraction.empty,
  });

  final ReactionTarget target;

  /// Aura interaction visibility & counts as projected by the backend.
  /// The bar always renders Like / Reply / Repost actions; numeric counts
  /// only render when the corresponding `canView*Count` flag is true.
  final FeedInteraction visibility;

  @override
  ConsumerState<FeedInteractionBar> createState() => _FeedInteractionBarState();
}

class _FeedInteractionBarState extends ConsumerState<FeedInteractionBar> {
  bool _likeBusy = false;
  bool _repostBusy = false;
  bool _replyBusy = false;

  // Optimistic overrides. Set the moment the user taps Like; cleared
  // after the canonical provider re-fetch completes or on backend failure.
  bool? _optimisticLiked;
  int? _optimisticLikeCount;

  @override
  Widget build(BuildContext context) {
    final target = widget.target;
    final visibility = widget.visibility;

    final isAuthed = ref.watch(isAuthedProvider);
    final identity = ref.watch(institutionIdentityProvider);
    final actor = identity != null && identity.id.isNotEmpty
        ? ReactionActor.institution(identity.id)
        : const ReactionActor.user();
    final canActAsInstitution =
        actor.isInstitution && (identity?.canPublishPosts ?? false);

    final reactionKey = ReactionStateKey(target: target, actor: actor);
    final reactionAsync = ref.watch(reactionStateProvider(reactionKey));

    // Signed-out interactions route the visitor to sign-in rather than
    // firing a guaranteed 401 against the auth-gated toggle endpoint.
    void goSignIn() {
      final redirect = GoRouterState.of(context).uri.toString();
      context.go(
        '/login?redirect=${Uri.encodeComponent(redirect)}',
      );
    }

    Future<void> toggleLike() async {
      if (!isAuthed) {
        goSignIn();
        return;
      }
      if (_likeBusy) return;

      final providerLiked = reactionAsync.maybeWhen(
        data: (s) => s.liked,
        orElse: () => false,
      );
      final providerCount = reactionAsync.maybeWhen(
        data: (s) => s.likeCount > 0 ? s.likeCount : visibility.likeCount,
        orElse: () => visibility.likeCount,
      );
      final nextLiked = !providerLiked;
      final nextCount = (providerCount + (nextLiked ? 1 : -1))
          .clamp(0, 1 << 31)
          .toInt();

      setState(() {
        _likeBusy = true;
        _optimisticLiked = nextLiked;
        _optimisticLikeCount = nextCount;
      });

      try {
        final repo = ref.read(reactionsRepositoryProvider);
        final result = await repo.toggle(target, actor: actor);
        if (!mounted) return;
        // Server-confirmed state. Replace the optimistic snapshot with the
        // server's truth and invalidate canonical surfaces so other cards
        // (post detail, sibling feeds) re-converge.
        setState(() {
          _optimisticLiked = result.liked;
          _optimisticLikeCount = result.likeCount;
        });
        ref.invalidate(reactionStateProvider(reactionKey));
        invalidateUnifiedFeedSurfaces(ref);
      } catch (e) {
        if (!mounted) return;
        // Rollback: drop optimistic override so the bar reverts to the
        // provider's truth (which never changed locally).
        setState(() {
          _optimisticLiked = null;
          _optimisticLikeCount = null;
        });
        if (!context.mounted) return;
        if (e is DioException && e.response?.statusCode == 403) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Only institution speakers can react as institution.',
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not update like')),
          );
        }
      } finally {
        if (mounted) setState(() => _likeBusy = false);
      }
    }

    String composeReplyTarget() {
      final replyKey = target is InstitutionPostReactionTarget
          ? 'replyToInstitutionPostId=${target.postId}'
              '&parentInstitutionId='
              '${target.institutionId}'
          : 'replyTo=${target.postId}';
      final base = '/compose?$replyKey&surface=dm';
      if (actor.isInstitution && canActAsInstitution) {
        return '$base&asInstitution=1'
            '&institutionId=${actor.actorInstitutionId}';
      }
      return base;
    }

    Future<void> openReply() async {
      if (!isAuthed) {
        goSignIn();
        return;
      }
      if (_replyBusy) return;
      setState(() => _replyBusy = true);
      try {
        final result = await context.push<dynamic>(composeReplyTarget());
        if (result == true) {
          ref.invalidate(reactionStateProvider(reactionKey));
          invalidateUnifiedFeedSurfaces(ref);
        }
      } finally {
        if (mounted) setState(() => _replyBusy = false);
      }
    }

    final providerLiked = reactionAsync.maybeWhen(
      data: (s) => s.liked,
      orElse: () => false,
    );
    final liked = _optimisticLiked ?? providerLiked;

    // Display count: prefer optimistic (matches just-tapped UX), otherwise
    // the per-actor toggle response, otherwise the public payload count.
    // Never renders 0/placeholders — gated by canViewLikeCount below.
    final providerCount = reactionAsync.maybeWhen(
      data: (s) => s.likeCount > 0 ? s.likeCount : visibility.likeCount,
      orElse: () => visibility.likeCount,
    );
    final displayedLikeCount = _optimisticLikeCount ?? providerCount;
    final likeLabel = (() {
      final base = liked ? 'Liked' : 'Like';
      if (visibility.canViewLikeCount && displayedLikeCount > 0) {
        return '$base · $displayedLikeCount';
      }
      return base;
    })();

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
      if (!isAuthed) {
        goSignIn();
        return;
      }
      if (_repostBusy) return;
      final controller = TextEditingController();
      setState(() => _repostBusy = true);
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
          final t = target;
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
        if (mounted) setState(() => _repostBusy = false);
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
          onTap: openReply,
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
