import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/shell/rail/rail_composition.dart';
import '../../../core/errors/app_error_mapper.dart';
import '../../../core/institutions/institution_access_provider.dart';
import '../../../core/media/aura_media_frame.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/ui/aura_text_block.dart';
import '../../../shared/identity/aura_identity_badge.dart';
import '../../accountability/widgets/accountability_timeline_rail.dart';
import '../../feed/data/unified_feed_providers.dart';
import '../../feed/domain/feed_item.dart';
import '../../feed/presentation/feed_interaction_bar.dart';
import '../../feed/presentation/unified_feed_card.dart';
import '../../../core/utils/relative_time.dart';
import '../../posts/data/reactions_repository.dart';
import '../data/institutions_repository.dart';
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
    final canActAsInstitution =
        identity != null && identity.id.isNotEmpty && identity.canPublishPosts;
    // Governance gate: only an authorized operator (ADMIN / OWNER /
    // authorized speaker) of THIS institution may edit or delete its
    // posts. Public and cross-institution viewers have no matching
    // identity → no controls. The backend re-checks authority on write.
    final canGovern = identity != null &&
        identity.id == institutionId &&
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

    Future<void> onDelete() async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AuraSurface.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AuraRadius.card),
          ),
          title: const Text('Delete this post', style: AuraText.subtitle),
          content: Text(
            'This removes the post from every feed and its public link. '
            'This cannot be undone.',
            style: AuraText.body.copyWith(color: AuraSurface.muted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'Cancel',
                style: AuraText.small.copyWith(color: AuraSurface.muted),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                'Delete',
                style: AuraText.small.copyWith(
                  color: AuraSurface.coRose,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      try {
        await ref
            .read(institutionsRepositoryProvider)
            .deleteInstitutionPost(institutionId, postId);
        // Remove the post from every feed surface so no orphaned card
        // remains, then drop the detail cache.
        invalidateUnifiedFeedSurfaces(ref);
        ref.invalidate(feedItemDetailProvider(args));
        if (context.mounted) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            const SnackBar(
              content: Text('Post removed'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          if (context.canPop()) context.pop();
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            SnackBar(
              content: Text(
                AppErrorMapper.from(e, feature: 'delete this post').message,
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }

    return InstitutionPage(
      title: 'Post',
      subtitle: 'Discussion thread for this institutional post.',
      showBack: true,
      // Contextual rail — keeps the institutional record connected to
      // the live discourse ecosystem around it.
      railModules: discourseDetailRailModules(),
      trailing: AuraPrimaryButton(
        label: 'Reply',
        icon: Icons.reply_rounded,
        onPressed: onReply,
      ),
      body: detailAsync.when(
        loading: () => const AuraLoadingState(message: 'Loading post…'),
        error: (e, _) => AuraErrorState(
          title: 'Could not load post',
          body: AppErrorMapper.from(e, feature: 'view this post').message,
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
          final isAnnouncement =
              decoded.hadMarker &&
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
                _OfficialAnnouncementStrip(
                  publisher: publisher,
                  publishedAt: item.publishedAt ?? item.createdAt,
                ),
                const SizedBox(height: AuraSpace.s10),
              ],
              // Detail screen renders the full replies list below — turn
              // off the inline preview to avoid duplicating the first 1–2
              // replies in two places on the same screen. Detail mode
              // lets the bundled image render in the larger, contain-by-
              // default frame instead of the feed-rhythm frame.
              UnifiedFeedCard(
                item: item,
                showReplyPreview: false,
                mediaMode: AuraMediaFrameMode.detail,
                // Focused post on its own detail screen — render the
                // title and body as full, selectable discourse text.
                bodySelectable: true,
              ),
              // R7 — participation memory continuity context. Renders
              // a calm "Resolves" / "Follow-up" reference when this
              // post carries a forward linkage. Self-collapses when
              // neither pointer is set, so quiet posts show nothing.
              if (item.hasContinuityLinkage) ...[
                const SizedBox(height: AuraSpace.s12),
                _ContinuityContextSection(item: item),
              ],
              // Share is rendered as a peer reaction (Like / Reply /
              // Repost / Share) inside the card's interaction bar above,
              // gated to public visibility — no separate share button here.
              // Governance — edit / delete, only for an authorized
              // operator of this institution (gated above; backend
              // re-enforces). Hidden from public and member viewers.
              if (canGovern) ...[
                const SizedBox(height: AuraSpace.s10),
                Row(
                  children: [
                    AuraSecondaryButton(
                      label: 'Edit',
                      icon: Icons.edit_outlined,
                      onPressed: () => context.push(
                        '/institution/$institutionId/posts/$postId/edit',
                      ),
                    ),
                    const SizedBox(width: AuraSpace.s10),
                    AuraSecondaryButton(
                      label: 'Delete',
                      icon: Icons.delete_outline_rounded,
                      onPressed: onDelete,
                    ),
                  ],
                ),
              ],
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
                style: AuraText.subtitle.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AuraSpace.s10),
              repliesAsync.when(
                loading: () =>
                    const AuraLoadingState(message: 'Loading replies…'),
                error: (e, _) => AuraErrorState(
                  title: 'Could not load replies',
                  body: AppErrorMapper.from(e, feature: 'view replies').message,
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
                      AccountabilityTimelineRail(replies: page.items),
                      if (page.items.any(
                          (r) => r.accountabilityTagWire != null))
                        const SizedBox(height: AuraSpace.s12),
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

    // Phase 4 — under an official post, non-official replies sit at
    // a slightly reduced visual weight so the institutional voice
    // stays dominant. Official responses keep full intensity.
    final isOfficial = _isOfficialInstitutionReply(reply);
    final card = Container(
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
                            style: AuraText.small.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
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
            AuraTextBlock(
              reply.body,
              style: AuraText.body.copyWith(
                color: AuraSurface.ink,
                height: 1.5,
              ),
              selectable: true,
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

    // Non-official replies dim slightly so institutional voice (and any
    // "Official response" reply) reads as the dominant track. Opacity
    // 0.85 keeps text fully readable; the contract says: keep
    // readability intact.
    return isOfficial ? card : Opacity(opacity: 0.85, child: card);
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
/// Phase 3 added "Published by [Name]" below the eyebrow.
/// Phase 4 adds:
///   * Long-form "Published X ago" timestamp under the publisher line.
///   * "Recent update from [Name]" reinforcement when the post is ≤12h
///     old, so a freshly-issued announcement reads as time-sensitive.
class _OfficialAnnouncementStrip extends StatelessWidget {
  const _OfficialAnnouncementStrip({this.publisher, this.publishedAt});

  /// Display name of the publishing institution. When empty/null, the
  /// strip renders only the OFFICIAL ANNOUNCEMENT eyebrow.
  final String? publisher;

  /// Source timestamp for the "Published X ago" line. When null, the
  /// long-form timestamp is omitted entirely — the strip degrades to
  /// just the eyebrow + publisher.
  final DateTime? publishedAt;

  @override
  Widget build(BuildContext context) {
    final p = publisher?.trim() ?? '';
    final ts = publishedAt;
    final isVeryRecent =
        ts != null &&
        DateTime.now().difference(ts) <= const Duration(hours: 12);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s12,
        vertical: AuraSpace.s10,
      ),
      decoration: BoxDecoration(
        color: AuraSurface.accentSoft,
        borderRadius: BorderRadius.circular(AuraRadius.md),
        border: Border.all(color: AuraSurface.accent.withValues(alpha: 0.35)),
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
                if (ts != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    isVeryRecent && p.isNotEmpty
                        ? 'Recent update from $p · Published ${formatPastPhrase(ts)}'
                        : 'Published ${formatPastPhrase(ts)}',
                    style: AuraText.micro.copyWith(
                      color: AuraSurface.accentText.withValues(alpha: 0.75),
                      fontWeight: FontWeight.w600,
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

/// Participation-memory continuity context.
///
/// Renders a calm "Resolves" / "Follow-up" reference card when the
/// current post carries a forward continuity pointer
/// (`resolvesPostId` / `continuesPostId`). Both pointers are
/// institution-actor-set linkages from the Phase 4 schema — they only
/// appear when an actor explicitly set them, not by content analysis.
///
/// The inverse direction (which other posts resolve/continue THIS
/// post) is not surfaced here because it requires an aggregation
/// endpoint that has not shipped — adding it would be a fresh server
/// query, kept out of this pass intentionally to avoid an unreliable
/// partial roundtrip on post detail.
///
/// Self-collapses when neither forward pointer is set; the parent
/// `if (item.hasContinuityLinkage)` gate is the formal check.
class _ContinuityContextSection extends StatelessWidget {
  const _ContinuityContextSection({required this.item});

  final FeedItem item;

  @override
  Widget build(BuildContext context) {
    final resolves = item.resolvesPostId;
    final continues = item.continuesPostId;

    return Container(
      padding: const EdgeInsets.all(AuraSpace.s14),
      decoration: BoxDecoration(
        color: AuraSurface.subtle,
        borderRadius: BorderRadius.circular(AuraRadius.r14),
        border: Border.all(color: AuraSurface.divider.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 14,
                decoration: BoxDecoration(
                  color: AuraSurface.accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: AuraSpace.s8),
              Expanded(
                child: Text(
                  'Continuity context',
                  style: AuraText.subtitle.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Linkage set by an institution actor — observational, not '
            'inferred from content.',
            style: AuraText.micro.copyWith(
              color: AuraSurface.faint,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: AuraSpace.s10),
          if (resolves != null && resolves.isNotEmpty)
            _ContinuityRow(
              label: 'Resolves',
              icon: Icons.check_circle_outline_rounded,
              color: const Color(0xFF4ADE80),
              targetPostId: resolves,
              institutionId: (item.author.id.isNotEmpty)
                  ? item.author.id
                  : null,
            ),
          if (resolves != null && continues != null) ...[
            const SizedBox(height: AuraSpace.s6),
          ],
          if (continues != null && continues.isNotEmpty)
            _ContinuityRow(
              label: 'Follow-up to',
              icon: Icons.history_rounded,
              color: const Color(0xFF60A5FA),
              targetPostId: continues,
              institutionId: (item.author.id.isNotEmpty)
                  ? item.author.id
                  : null,
            ),
        ],
      ),
    );
  }
}

class _ContinuityRow extends StatelessWidget {
  const _ContinuityRow({
    required this.label,
    required this.icon,
    required this.color,
    required this.targetPostId,
    required this.institutionId,
  });

  final String label;
  final IconData icon;
  final Color color;
  final String targetPostId;
  final String? institutionId;

  @override
  Widget build(BuildContext context) {
    // Routing: the target is an InstitutionPost id; institutionId is
    // the speaking institution (best-available proxy from the current
    // post's author). If the institutionId is absent the card is
    // non-clickable rather than guessing.
    final route = (institutionId == null || institutionId!.isEmpty)
        ? null
        : '/institution/$institutionId/posts/$targetPostId';
    final body = Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.45)),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: AuraSpace.s10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label.toUpperCase(),
                style: AuraText.micro.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  fontSize: 9.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Open the referenced post',
                style: AuraText.small.copyWith(
                  color: AuraSurface.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        if (route != null)
          const Icon(
            Icons.arrow_forward_rounded,
            size: 14,
            color: AuraSurface.muted,
          ),
      ],
    );
    if (route == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: body,
      );
    }
    return InkWell(
      borderRadius: BorderRadius.circular(AuraRadius.r10),
      onTap: () => context.push(route),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: body,
      ),
    );
  }
}
