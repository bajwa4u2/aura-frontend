import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/institutions/institution_access_provider.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../posts/data/reactions_repository.dart';
import '../data/institutions_repository.dart';
import '../domain/institution_post.dart';
import '../presentation/institution_page.dart';

/// Detail surface for a single InstitutionPost. Renders the parent post +
/// the reply tree under it. Reply CTA opens the compose screen with the
/// institution-post reply target wired up.
///
/// Refresh on this route round-trips through `getInstitutionPost` and
/// `listInstitutionPostReplies` so freshly-created replies appear after
/// pop+refresh — which is the manual validation the user runs to confirm
/// "Member replies to institution post → refresh → reply shows member author".
class InstitutionPostDetailScreen extends ConsumerWidget {
  const InstitutionPostDetailScreen({
    super.key,
    required this.institutionId,
    required this.postId,
  });

  final String institutionId;
  final String postId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = InstitutionPostKey(
      institutionId: institutionId,
      postId: postId,
    );
    final identity = ref.watch(institutionIdentityProvider);
    final canActAsInstitution = identity != null &&
        identity.id.isNotEmpty &&
        identity.canPublishPosts;

    final postAsync = ref.watch(institutionPostDetailProvider(key));
    final repliesAsync = ref.watch(institutionPostRepliesProvider(key));

    String composeReplyTarget() {
      final base =
          '/compose?replyToInstitutionPostId=$postId&parentInstitutionId=$institutionId&surface=dm';
      if (canActAsInstitution) {
        return '$base&asInstitution=1&institutionId=${identity.id}';
      }
      return base;
    }

    return InstitutionPage(
      title: 'Post',
      subtitle: null,
      showBack: true,
      body: postAsync.when(
        loading: () => const AuraLoadingState(message: 'Loading post…'),
        error: (e, _) => AuraErrorState(
          title: 'Could not load post',
          body: '$e',
          action: AuraSecondaryButton(
            label: 'Try again',
            icon: Icons.refresh_rounded,
            onPressed: () =>
                ref.invalidate(institutionPostDetailProvider(key)),
          ),
        ),
        data: (post) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ParentPostCard(post: post),
            const SizedBox(height: AuraSpace.s14),
            Row(
              children: [
                Text(
                  'Replies',
                  style: AuraText.subtitle.copyWith(fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                AuraPrimaryButton(
                  label: 'Reply',
                  icon: Icons.reply_rounded,
                  onPressed: () async {
                    final result = await context.push<dynamic>(
                      composeReplyTarget(),
                    );
                    if (result == true) {
                      // Compose returned with success — refresh the reply
                      // list so the new reply lands on screen.
                      ref.invalidate(
                        institutionPostRepliesProvider(key),
                      );
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: AuraSpace.s10),
            repliesAsync.when(
              loading: () =>
                  const AuraLoadingState(message: 'Loading replies…'),
              error: (e, _) => AuraErrorState(
                title: 'Could not load replies',
                body: '$e',
                action: AuraSecondaryButton(
                  label: 'Try again',
                  icon: Icons.refresh_rounded,
                  onPressed: () =>
                      ref.invalidate(institutionPostRepliesProvider(key)),
                ),
              ),
              data: (page) {
                if (page.items.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: AuraSpace.s20),
                    child: AuraEmptyState(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'No replies yet',
                      body:
                          'Be the first to reply. Replies inherit this post’s visibility.',
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < page.items.length; i++) ...[
                      _ReplyCard(reply: page.items[i]),
                      if (i < page.items.length - 1)
                        const SizedBox(height: AuraSpace.s10),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ParentPostCard extends StatelessWidget {
  const _ParentPostCard({required this.post});

  final InstitutionPost post;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AuraSpace.s16),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PostHeader(post: post),
          if (post.title.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s10),
            Text(
              post.title,
              style: AuraText.subtitle.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
          if (post.body.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s8),
            Text(
              post.body,
              style: AuraText.body
                  .copyWith(color: AuraSurface.ink, height: 1.55),
            ),
          ],
          const SizedBox(height: AuraSpace.s12),
          // Reuse the same interaction bar so likes here stay actor-aware.
          _DetailInteractionBar(
            target: InstitutionPostReactionTarget(
              institutionId: post.institutionId,
              postId: post.id,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReplyCard extends StatelessWidget {
  const _ReplyCard({required this.reply});

  final InstitutionPost reply;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AuraSpace.s14),
      decoration: BoxDecoration(
        color: AuraSurface.subtle,
        borderRadius: BorderRadius.circular(AuraRadius.md),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PostHeader(post: reply, dense: true),
          if (reply.body.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s8),
            Text(
              reply.body,
              style: AuraText.body
                  .copyWith(color: AuraSurface.ink, height: 1.5),
            ),
          ],
          const SizedBox(height: AuraSpace.s8),
          _DetailInteractionBar(
            target: InstitutionPostReactionTarget(
              institutionId: reply.institutionId,
              postId: reply.id,
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders the actor headline for an InstitutionPost: institution name when
/// `actorInstitutionId` is set, otherwise the personal user. The byline
/// always names the human speaker too so members can audit who is talking
/// for the institution.
class _PostHeader extends StatelessWidget {
  const _PostHeader({required this.post, this.dense = false});

  final InstitutionPost post;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final isInstitutionVoice = post.isInstitutionActor;
    final actorMap = isInstitutionVoice
        ? (post.actorInstitution ?? post.institution)
        : null;
    final actorName = (actorMap?['name']?.toString().trim() ?? '');
    final actorLogo = (actorMap?['logoUrl']?.toString().trim() ?? '');
    final authorMap = post.author ?? <String, dynamic>{};
    final authorName = authorMap['displayName']?.toString().trim() ??
        authorMap['handle']?.toString().trim() ??
        '';
    final authorHandle = authorMap['handle']?.toString().trim() ?? '';

    final headlineText = isInstitutionVoice && actorName.isNotEmpty
        ? actorName
        : (authorName.isNotEmpty ? authorName : 'Unknown');
    final byline = isInstitutionVoice && authorName.isNotEmpty
        ? 'via ${authorHandle.isNotEmpty ? '@$authorHandle' : authorName}'
        : (authorHandle.isNotEmpty ? '@$authorHandle' : null);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AvatarSquare(
          imageUrl: isInstitutionVoice ? actorLogo : null,
          fallback: headlineText.isNotEmpty
              ? headlineText[0].toUpperCase()
              : '?',
          size: dense ? 28 : 36,
        ),
        const SizedBox(width: AuraSpace.s10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      headlineText,
                      style: (dense ? AuraText.small : AuraText.body)
                          .copyWith(fontWeight: FontWeight.w800),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isInstitutionVoice) ...[
                    const SizedBox(width: AuraSpace.s6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AuraSurface.accentSoft,
                        borderRadius: BorderRadius.circular(AuraRadius.pill),
                      ),
                      child: Text(
                        'Institution',
                        style: AuraText.micro.copyWith(
                          color: AuraSurface.accentText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (byline != null && byline.isNotEmpty)
                Text(
                  byline,
                  style: AuraText.micro.copyWith(color: AuraSurface.faint),
                ),
            ],
          ),
        ),
        if (post.publishedAt != null)
          Text(
            _formatDate(post.publishedAt!),
            style: AuraText.micro.copyWith(color: AuraSurface.faint),
          ),
      ],
    );
  }
}

class _AvatarSquare extends StatelessWidget {
  const _AvatarSquare({
    required this.imageUrl,
    required this.fallback,
    required this.size,
  });

  final String? imageUrl;
  final String fallback;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AuraSurface.accentSoft,
        shape: BoxShape.circle,
        border: Border.all(color: AuraSurface.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: (imageUrl != null && imageUrl!.isNotEmpty)
          ? Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _initialFallback(),
            )
          : _initialFallback(),
    );
  }

  Widget _initialFallback() {
    return Center(
      child: Text(
        fallback,
        style: AuraText.small.copyWith(
          color: AuraSurface.accentText,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

String _formatDate(DateTime dt) {
  final local = dt.toLocal();
  final yyyy = local.year.toString().padLeft(4, '0');
  final mm = local.month.toString().padLeft(2, '0');
  final dd = local.day.toString().padLeft(2, '0');
  return '$yyyy-$mm-$dd';
}

// ── Reused interaction bar (Like + Reply) ─────────────────────────────────
//
// Mirrors the bar in institution_explore_screen.dart — duplicated here to
// avoid an import cycle with that file's private widgets. Both surfaces use
// the same reactions repository so state is consistent across screens.

class _DetailInteractionBar extends ConsumerWidget {
  const _DetailInteractionBar({required this.target});

  final ReactionTarget target;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(institutionIdentityProvider);
    final actor = identity != null && identity.id.isNotEmpty
        ? ReactionActor.institution(identity.id)
        : const ReactionActor.user();
    final reactionKey = ReactionStateKey(target: target, actor: actor);
    final reactionAsync = ref.watch(reactionStateProvider(reactionKey));

    Future<void> toggleLike() async {
      try {
        final repo = ref.read(reactionsRepositoryProvider);
        await repo.toggle(target, actor: actor);
        ref.invalidate(reactionStateProvider(reactionKey));
      } catch (_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update like')),
        );
      }
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
      ],
    );
  }
}
