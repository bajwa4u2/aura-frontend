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
import '../domain/communication_type.dart';
import '../presentation/institution_page.dart';
import '../ui/institution_ds.dart';

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

    Future<void> onReply() async {
      final result = await context.push<dynamic>(composeReplyTarget());
      if (result == true) {
        ref.invalidate(feedItemRepliesProvider(args));
        ref.invalidate(feedItemDetailProvider(args));
      }
    }

    return InstitutionPage(
      title: 'Post',
      subtitle: 'Discussion thread for this institutional post.',
      showBack: true,
      trailing: AuraPrimaryButton(
        label: 'Reply',
        icon: Icons.reply_rounded,
        onPressed: onReply,
      ),
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
            return const InsEmptyState(
              icon: Icons.help_outline_rounded,
              title: 'Post not found',
              description:
                  'It may have been removed or is no longer visible to you.',
            );
          }
          // Phase 2 — detail-view reinforcement. When the parent post is
          // an Official Announcement we render a small reinforcement
          // strip above the card so the visit has unambiguous context
          // before the reader sees the title.
          final decoded = InsCommunicationDecoded.parse(item.title);
          final isAnnouncement = decoded.hadMarker &&
              decoded.type == InsCommunicationType.announcement;

          // Resolve a publisher name for the reinforcement strip. The
          // active workspace identity is preferred (most accurate when
          // viewing your own institution); fall back to the post's
          // author display name (for cross-institution viewers).
          final identity = ref.read(institutionIdentityProvider);
          final publisher = (identity?.name.trim().isNotEmpty ?? false)
              ? identity!.name.trim()
              : item.author.name.trim();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isAnnouncement) ...[
                _OfficialAnnouncementStrip(publisher: publisher),
                const SizedBox(height: AuraSpace.s10),
              ],
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
              Text(
                'Replies',
                style: AuraText.subtitle
                    .copyWith(fontWeight: FontWeight.w800),
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
                    return const InsEmptyState(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'No replies yet',
                      description:
                          'Be the first to reply. Replies inherit this post’s visibility.',
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
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
                    // Phase 3 — when an institution voice replies, mark
                    // the reply as an "Official response" so the reader
                    // can immediately distinguish it from member chatter.
                    if (_isOfficialInstitutionReply(reply)) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Official response',
                        style: AuraText.micro.copyWith(
                          color: AuraSurface.accentText,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                          fontSize: 10,
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

/// True when the reply author's identity context is an official
/// institution voice. Used to mark institutional replies as "Official
/// response" so they read distinctly from member chatter.
bool _isOfficialInstitutionReply(FeedReply reply) {
  final ctx = reply.author.context;
  if (ctx == null) return false;
  return ctx.type == FeedIdentityContextType.officialInstitution;
}

/// Reinforcement band rendered above the parent card on the post detail
/// screen when the post is decoded as an Official Announcement. Calm,
/// monochrome — its only job is to make the institutional weight of the
/// statement unmistakable before the reader scans the title.
///
/// Phase 3: when a publisher name is known, an additional sub-line
/// "Published by [Name]" sits beneath the eyebrow so the source of the
/// statement is part of the reinforcement, not just a separate badge.
class _OfficialAnnouncementStrip extends StatelessWidget {
  const _OfficialAnnouncementStrip({this.publisher});

  /// Display name of the publishing institution. When empty/null, the
  /// strip renders only the OFFICIAL ANNOUNCEMENT eyebrow.
  final String? publisher;

  @override
  Widget build(BuildContext context) {
    final p = publisher?.trim() ?? '';
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s12,
        vertical: AuraSpace.s10,
      ),
      decoration: BoxDecoration(
        color: AuraSurface.accentSoft,
        borderRadius: BorderRadius.circular(AuraRadius.md),
        border: Border.all(
          color: AuraSurface.accent.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(
            Icons.campaign_rounded,
            size: 16,
            color: AuraSurface.accentText,
          ),
          const SizedBox(width: AuraSpace.s8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Official Announcement',
                  style: AuraText.small.copyWith(
                    color: AuraSurface.accentText,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
                if (p.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Published by $p',
                    style: AuraText.micro.copyWith(
                      color: AuraSurface.accentText.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
