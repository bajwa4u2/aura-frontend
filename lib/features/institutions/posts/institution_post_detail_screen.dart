import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/institutions/institution_access_provider.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../../shared/identity/aura_identity_badge.dart';
import '../../feed/data/unified_feed_providers.dart';
import '../../feed/domain/feed_item.dart';
import '../../feed/presentation/feed_interaction_bar.dart';
import '../../feed/presentation/unified_feed_card.dart';
import '../../posts/data/reactions_repository.dart';
import '../presentation/institution_page.dart';

/// Detail surface for a single InstitutionPost.
///
/// Phase 3: parent post and replies both flow through unified providers.
///   * Parent  → `feedItemDetailProvider(INSTITUTION_POST, postId)`
///   * Replies → `feedItemRepliesProvider(INSTITUTION_POST, postId)`
///
/// The legacy `institutionPostRepliesProvider` is no longer used by this
/// screen.
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
    final identity = ref.watch(institutionIdentityProvider);
    final canActAsInstitution = identity != null &&
        identity.id.isNotEmpty &&
        identity.canPublishPosts;

    final args = FeedItemDetailArgs(
      type: FeedItemType.institutionPost,
      id: postId,
    );
    final detailAsync = ref.watch(feedItemDetailProvider(args));
    final repliesAsync = ref.watch(feedItemRepliesProvider(args));

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
      body: detailAsync.when(
        loading: () => const AuraLoadingState(message: 'Loading post…'),
        error: (e, _) => AuraErrorState(
          title: 'Could not load post',
          body: '$e',
          action: AuraSecondaryButton(
            label: 'Try again',
            icon: Icons.refresh_rounded,
            onPressed: () => ref.invalidate(feedItemDetailProvider(args)),
          ),
        ),
        data: (item) {
          if (item == null) {
            return AuraEmptyState(
              icon: Icons.help_outline_rounded,
              title: 'Post not found',
              body: 'It may have been removed or is no longer visible to you.',
              action: AuraSecondaryButton(
                label: 'Back',
                icon: Icons.arrow_back_rounded,
                onPressed: () => context.pop(),
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Detail screen renders the full replies list below — turn
              // off the inline preview to avoid duplicating the first 1–2
              // replies in two places on the same screen.
              UnifiedFeedCard(item: item, showReplyPreview: false),
              const SizedBox(height: AuraSpace.s14),
              if (item.activity?.recentReply == true) ...[
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF22C55E),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Active discussion',
                      style: AuraText.micro.copyWith(
                        color: AuraSurface.muted,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AuraSpace.s8),
              ],
              Row(
                children: [
                  Text(
                    'Replies',
                    style: AuraText.subtitle
                        .copyWith(fontWeight: FontWeight.w800),
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
                        ref.invalidate(feedItemRepliesProvider(args));
                        ref.invalidate(feedItemDetailProvider(args));
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
                        ref.invalidate(feedItemRepliesProvider(args)),
                  ),
                ),
                data: (page) {
                  if (page.items.isEmpty) {
                    return const Padding(
                      padding:
                          EdgeInsets.symmetric(vertical: AuraSpace.s20),
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
                        _ReplyCard(
                          reply: page.items[i],
                          institutionId: institutionId,
                        ),
                        if (i < page.items.length - 1)
                          const SizedBox(height: AuraSpace.s10),
                      ],
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ReplyCard extends StatelessWidget {
  const _ReplyCard({required this.reply, required this.institutionId});

  final FeedReply reply;

  /// Used to wire the FeedInteractionBar to the right
  /// `InstitutionPostReactionTarget` since replies of an institution post
  /// are themselves institution posts under the same institution.
  final String institutionId;

  @override
  Widget build(BuildContext context) {
    final initial = reply.author.displayName.trim().isNotEmpty
        ? reply.author.displayName.trim()[0].toUpperCase()
        : (reply.author.handle.isNotEmpty
            ? reply.author.handle[0].toUpperCase()
            : '?');

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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AuraSurface.accentSoft,
                  shape: BoxShape.circle,
                  border: Border.all(color: AuraSurface.divider),
                ),
                clipBehavior: Clip.antiAlias,
                child: Center(
                  child: Text(
                    initial,
                    style: AuraText.small.copyWith(
                      color: AuraSurface.accentText,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AuraSpace.s10),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        reply.author.displayName.isNotEmpty
                            ? reply.author.displayName
                            : (reply.author.handle.isNotEmpty
                                ? '@${reply.author.handle}'
                                : 'Unknown'),
                        style: AuraText.small
                            .copyWith(fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (reply.author.context != null &&
                        reply.author.context!.isMeaningful) ...[
                      const SizedBox(width: AuraSpace.s6),
                      Flexible(
                        child: AuraIdentityBadge(
                          context: reply.author.context!,
                          mode: AuraIdentityBadgeMode.replyPreview,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (reply.body.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s8),
            Text(
              reply.body,
              style: AuraText.body
                  .copyWith(color: AuraSurface.ink, height: 1.5),
            ),
          ],
          const SizedBox(height: AuraSpace.s8),
          FeedInteractionBar(
            target: InstitutionPostReactionTarget(
              institutionId: institutionId,
              postId: reply.id,
            ),
          ),
        ],
      ),
    );
  }
}
