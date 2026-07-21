import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/media/aura_attachment_image.dart';
import '../../../core/media/aura_media_frame.dart';
import '../../../core/media/aura_media_viewer.dart';
import '../../../core/media/canonical_media_thumb.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/substrate_chip.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/ui/aura_text_block.dart';
import '../../../core/utils/relative_time.dart';
import '../../../shared/identity/aura_identity_badge.dart';
import '../../public/widgets/mention_text.dart' show ResolvedTagText;
import '../../institutions/domain/communication_type.dart';
import '../../posts/data/reactions_repository.dart';
import '../../posts/presentation/widgets/post_card/post_card_utils.dart';
import '../../share/aura_share_sheet.dart';
import '../../topics/topic.dart';
import '../domain/feed_item.dart';
import 'feed_interaction_bar.dart';

/// Single render path for every feed surface.
///
/// Phase 1 scope: tap-to-navigate to the target route, author tap to profile,
/// shell-aware route adaptation, visibility badges. Like/reply/repost
/// affordances are shown but route to the existing detail screen for now;
/// Phase 3 will wire reactions and reply actions in-line.
class UnifiedFeedCard extends ConsumerWidget {
  const UnifiedFeedCard({
    super.key,
    required this.item,
    this.showVisibilityBadge = true,
    this.showInteractionBar = true,
    this.showReplyPreview = true,
    this.mediaMode = AuraMediaFrameMode.feed,
    this.bodySelectable = false,
  });

  final FeedItem item;

  /// Whether to render the visibility chip (PUBLIC / MEMBER_ONLY / INTERNAL).
  /// Off on surfaces where everything is the same visibility (e.g. profile).
  final bool showVisibilityBadge;

  /// When false, hides the like/reply/repost row. Useful for compact preview
  /// surfaces (search, activity).
  final bool showInteractionBar;

  /// Phase 5.1 — when false, the inline reply-preview block doesn't render.
  /// Detail screens turn this off because they already render the full
  /// reply list below the parent card; rendering both would duplicate the
  /// first 1–2 replies.
  final bool showReplyPreview;

  /// Media frame mode for any image rendered inside this card. Feed
  /// surfaces leave this at [AuraMediaFrameMode.feed]; detail screens
  /// (InstitutionPostDetailScreen) pass [AuraMediaFrameMode.detail]
  /// so the image gets the larger, contain-by-default detail frame
  /// instead of the bounded feed-rhythm frame.
  final AuraMediaFrameMode mediaMode;

  /// When true the title and body render as selectable, full-length
  /// discourse text instead of the truncated, tap-to-navigate preview.
  ///
  /// Detail screens (InstitutionPostDetailScreen) opt in: the card is
  /// the focused post there, so the reader must be able to select,
  /// copy, and quote it in full. Feed surfaces leave this false — the
  /// card stays a preview whose whole surface navigates on tap, and
  /// making the body selectable there would swallow that tap.
  final bool bodySelectable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentPath = GoRouterState.of(context).uri.path;
    final adaptedTarget = FeedRouting.adaptTargetRoute(
      item.targetRoute,
      currentPath: currentPath,
    );
    final adaptedProfile = FeedRouting.adaptProfileRoute(
      item.author.profileRoute,
      currentPath: currentPath,
    );

    // Phase 2 — per-type visual weight. The decoded marker drives subtle
    // differences (border, title weight, secondary indicator) so types
    // FEEL different without leaving the design system.
    final officialPost = _isOfficialInstitutionPost(item);
    final InsCommunicationDecoded? decodedTitle = officialPost
        ? InsCommunicationDecoded.parse(item.title)
        : null;
    final isAnnouncement =
        decodedTitle?.hadMarker == true &&
        decodedTitle!.type == InsCommunicationType.announcement;
    final isAdvisory =
        decodedTitle?.hadMarker == true &&
        decodedTitle!.type == InsCommunicationType.advisory;
    final isUpdate =
        decodedTitle?.hadMarker == true &&
        decodedTitle!.type == InsCommunicationType.update;

    // Per-type title weight, shared by the truncated preview and the
    // selectable detail rendering so both read identically.
    final titleStyle = AuraText.body.copyWith(
      color: AuraSurface.ink,
      fontWeight: isAnnouncement
          ? FontWeight.w900
          : isUpdate
          ? FontWeight.w700
          : FontWeight.w800,
      fontSize: isAnnouncement ? 17 : null,
      height: 1.35,
    );

    // Phase 4 — time decay. Older official posts are intentionally
    // "quieter": ≤24 h reads at full intensity, 24–72 h sits at a
    // calmer accent, >72 h drops to the divider color so an old
    // statement no longer competes with fresh institutional speech.
    final ageBucket = _ageBucketFor(item);
    final accentBorder = isAnnouncement
        ? AuraSurface.accent.withValues(alpha: ageBucket.accentBorderAlpha)
        : AuraSurface.divider;

    return InkWell(
      onTap: adaptedTarget.isEmpty ? null : () => context.push(adaptedTarget),
      borderRadius: BorderRadius.circular(AuraRadius.card),
      child: Container(
        padding: EdgeInsets.fromLTRB(
          AuraSpace.s14,
          // Announcements get a slightly thicker top edge accent. Inner
          // padding adjusts so the visual weight feels load-bearing.
          isAnnouncement ? AuraSpace.s14 - 1 : AuraSpace.s14,
          AuraSpace.s14,
          AuraSpace.s14,
        ),
        decoration: BoxDecoration(
          color: AuraSurface.card,
          borderRadius: BorderRadius.circular(AuraRadius.card),
          border: Border.all(
            color: accentBorder,
            width: isAnnouncement ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.signal != null) ...[
              _SignalLabel(signal: item.signal!),
              const SizedBox(height: AuraSpace.s8),
            ],
            // Visual distinction: top-level institution posts are
            // institutional speech (announcements), not chat. The OFFICIAL
            // eyebrow optionally carries a TYPE token (Announcement / Update
            // / Notice / Advisory) decoded from the stored title marker.
            // Phase 3 — adds an inline NEW chip when the post was
            // published within the last 24 hours, so a freshly-issued
            // announcement reads as an attention item without animation.
            if (officialPost) ...[
              Row(
                children: [
                  _OfficialPill(
                    type: decodedTitle?.hadMarker == true
                        ? decodedTitle!.type
                        : null,
                    ageBucket: ageBucket,
                  ),
                  // Phase 4 — NEW chip is suppressed past 72 h so old
                  // posts can't masquerade as fresh.
                  if (_isRecentlyPublished(item) &&
                      ageBucket != _AgeBucket.stale) ...[
                    const SizedBox(width: 6),
                    const _NewChip(),
                  ],
                ],
              ),
              const SizedBox(height: AuraSpace.s6),
            ],
            _AuthorRow(
              author: item.author,
              publishedAt: item.publishedAt ?? item.createdAt,
              profileRoute: adaptedProfile,
            ),
            // Phase 3 — explicit "Verified institution" reinforcement
            // for official posts when the existing identity badge is
            // not present (i.e. backend didn't ship a context). Avoids
            // duplication when the badge already conveys the signal.
            if (officialPost && !_authorBadgeShown(item)) ...[
              const SizedBox(height: 4),
              const _VerifiedInstitutionLine(),
            ],
            // Phase 4 — "Source: Verified institution" sub-line for
            // official posts whose author identity is explicitly
            // verified. Only renders when verification is *known* to
            // be true; never renders when the data is missing so we
            // can't accidentally claim authority.
            if (officialPost && _isAuthorExplicitlyVerified(item)) ...[
              const SizedBox(height: 2),
              Text(
                'Source: Verified institution',
                style: AuraText.micro.copyWith(
                  color: AuraSurface.faint,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
            if (_shouldRenderSecondary(item)) ...[
              const SizedBox(height: AuraSpace.s6),
              _SecondaryAttributionLine(
                attribution: item.secondaryAttribution!,
                currentPath: currentPath,
              ),
            ],
            if (item.voice != null && item.voice!.type.rendersLabel) ...[
              const SizedBox(height: 2),
              _VoiceLabelLine(voice: item.voice!),
            ],
            if (isAdvisory) ...[
              const SizedBox(height: AuraSpace.s8),
              const _AdvisoryIndicator(),
            ],
            if (item.title != null && item.title!.trim().isNotEmpty) ...[
              const SizedBox(height: AuraSpace.s10),
              // Strip the [OFFICIAL:TYPE] marker before rendering. Legacy
              // posts (no marker) round-trip the title verbatim. On detail
              // surfaces the title is selectable and shown in full; in the
              // feed it stays a two-line, tap-through preview.
              if (bodySelectable)
                AuraTextBlock(
                  InsCommunicationDecoded.parse(item.title).cleanTitle,
                  style: titleStyle,
                  selectable: true,
                )
              else
                Text(
                  InsCommunicationDecoded.parse(item.title).cleanTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: titleStyle,
                ),
              // Phase 3 — under-title intent text. Reinforces what the
              // reader is meant to do with this statement without being
              // prescriptive. Update intentionally has no extra line so
              // routine posts stay calm.
              if (decodedTitle?.hadMarker == true &&
                  _intentLabelFor(decodedTitle!.type) != null) ...[
                const SizedBox(height: 2),
                Text(
                  _intentLabelFor(decodedTitle.type)!,
                  style: AuraText.small.copyWith(
                    color: AuraSurface.faint,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              // Phase 4 — soft urgency for ≤12 h announcements. Plain
              // text reinforcement, not a chip — calm but visible.
              if (isAnnouncement && _isVeryRecent(item)) ...[
                const SizedBox(height: 2),
                Text(
                  'Recent update',
                  style: AuraText.micro.copyWith(
                    color: AuraSurface.accentText,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    fontSize: 10,
                  ),
                ),
              ],
            ],
            if (item.body.trim().isNotEmpty) ...[
              const SizedBox(height: AuraSpace.s8),
              // Detail surfaces render the full body as selectable
              // discourse text; the feed keeps a six-line tap-through
              // preview so the whole card stays a navigation target.
              if (bodySelectable)
                ResolvedTagText(
                  item.body,
                  tagReferences: item.tagReferences,
                  style: AuraText.body.copyWith(
                    color: AuraSurface.ink,
                    height: 1.5,
                  ),
                  selectable: true,
                )
              else
                // AXR-1 — governed tags render highlighted in the feed
                // preview (styling only; the card stays the tap target).
                ResolvedTagText(
                  item.body,
                  tagReferences: item.tagReferences,
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                  style: AuraText.body.copyWith(
                    color: AuraSurface.ink,
                    height: 1.5,
                  ),
                ),
            ],
            // C4-followup — prefer canonical media[] when the backend
            // shipped one (institution posts after C4, user posts going
            // forward). Fall back to legacy mediaUrl for older payloads
            // and surfaces that haven't been re-projected yet. The
            // canonical branch routes RESTRICTED/PRIVATE rows through
            // AuraResolvableAttachmentImage so the C7 access gate fires
            // and signed URLs replace the permanent R2 URL.
            if (item.media.isNotEmpty) ...[
              const SizedBox(height: AuraSpace.s10),
              CanonicalMediaThumb(
                media: item.media.first,
                mode: mediaMode,
                downloadContext: _mediaDownloadContext(item.type),
              ),
            ] else if (item.mediaUrl != null && item.mediaUrl!.isNotEmpty) ...[
              const SizedBox(height: AuraSpace.s10),
              _LegacyMediaUrlThumb(
                url: item.mediaUrl!,
                attachmentId: item.id.isNotEmpty
                    ? 'feed:${item.id}:media'
                    : null,
                mode: mediaMode,
                downloadContext: _mediaDownloadContext(item.type),
              ),
            ],
            if (showVisibilityBadge) ...[
              const SizedBox(height: AuraSpace.s10),
              _MetaRow(
                visibility: item.visibility,
                distribution: item.distribution,
              ),
            ],
            // Primary topic — the authoritative, human-selected category.
            // Always visible when present (Content Topics doctrine).
            if (AuraTopic.fromWire(item.primaryTopic) case final topic?) ...[
              const SizedBox(height: AuraSpace.s8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AuraSpace.s8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AuraSurface.subtle,
                  borderRadius: BorderRadius.circular(AuraRadius.pill),
                  border: Border.all(color: AuraSurface.divider),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.label_outline_rounded,
                      size: 13,
                      color: AuraSurface.muted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      topic.label,
                      style: AuraText.micro.copyWith(
                        color: AuraSurface.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Public-record accountability status. Null and PENDING are
            // silent — a chip only appears when an institution has
            // formally responded. Language is calm and non-judgmental.
            if (_publicStatusLabel(item.publicStatus) case final label?) ...[
              const SizedBox(height: AuraSpace.s8),
              _PublicStatusChip(label: label),
            ],
            // Phase 4 — "Recent activity around this" line. Renders only
            // for official posts when the existing FeedItem.activity /
            // FeedItem.interaction signal carries a usable hint. No
            // backend fetch — purely derived from data already shipped.
            if (officialPost) ...[
              if (_recentActivityLabelFor(item) case final label?) ...[
                const SizedBox(height: AuraSpace.s8),
                _RecentActivityLine(label: label),
              ],
            ],
            if (showReplyPreview &&
                item.replyPreview != null &&
                item.replyPreview!.items.isNotEmpty) ...[
              const SizedBox(height: AuraSpace.s10),
              if (item.activity?.recentReply == true) ...[
                const _ActivityHintLine(label: 'New reply'),
                const SizedBox(height: 6),
              ],
              _ReplyPreviewBlock(
                preview: item.replyPreview!,
                openTarget: adaptedTarget,
              ),
            ],
            if (showInteractionBar) ...[
              const SizedBox(height: AuraSpace.s12),
              if (_reactionTargetFor(item) case final reactionTarget?)
                FeedInteractionBar(
                  target: reactionTarget,
                  visibility: item.interaction,
                  // Share reads as a peer reaction in line with Like /
                  // Reply / Repost — gated to publicly-shareable content
                  // (private / member-only / internal never shareable).
                  onShare: _canShare(item) ? () => _shareItem(context) : null,
                ),
            ],
          ],
        ),
      ),
    );
  }

  /// A feed card is shareable only when it is publicly visible and carries
  /// a canonical permalink we can build. User posts and institution posts
  /// qualify; announcements are shared from their own surfaces (the feed
  /// item does not carry the announcement slug).
  bool _canShare(FeedItem item) {
    if (item.visibility != FeedVisibility.public) return false;
    switch (item.type) {
      case FeedItemType.userPost:
        return item.id.trim().isNotEmpty;
      case FeedItemType.institutionPost:
        return item.id.trim().isNotEmpty && item.author.id.trim().isNotEmpty;
      case FeedItemType.announcement:
        return false;
    }
  }

  Future<void> _shareItem(BuildContext context) async {
    final String url;
    final String headline;
    switch (item.type) {
      case FeedItemType.institutionPost:
        url = canonicalInstitutionPostUrl(item.author.id, item.id);
        headline = 'Share this institution post';
        break;
      case FeedItemType.userPost:
        url = canonicalPostUrl(item.id);
        headline = 'Share this post';
        break;
      case FeedItemType.announcement:
        return;
    }
    await showAuraShareSheet(
      context,
      shareUrl: url,
      headline: headline,
      subtitle:
          'A public, crawler-friendly link that previews on LinkedIn, X, Discord, Slack, Facebook.',
      emailSubject: 'Aura',
    );
  }
}

/// Phase 6.4 — voice clarity line. Subordinate to both the primary author
/// and the secondary attribution; renders as a single uppercase micro-line
/// in the lightest UI color so it informs without competing.
class _VoiceLabelLine extends StatelessWidget {
  const _VoiceLabelLine({required this.voice});

  final FeedVoice voice;

  @override
  Widget build(BuildContext context) {
    final label = voice.label.trim();
    if (label.isEmpty) return const SizedBox.shrink();
    return Text(
      label.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AuraText.micro.copyWith(
        color: AuraSurface.faint,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        fontSize: 10,
      ),
    );
  }
}

/// True when the card represents a top-level institutional voice —
/// institution posts AND institutional announcements — distinct from a
/// personal user post or a reply *under* an institution post. The
/// OFFICIAL pill renders only for these so the card reads as
/// institutional voice.
bool _isOfficialInstitutionPost(FeedItem item) {
  if (!item.isInstitutionalVoice) return false;
  // Institution-post replies and reposts have a non-empty body but a blank
  // title and are conversational; only original posts with a title are
  // truly "official". Announcements always carry a title so they pass
  // through with the OFFICIAL pill rendered.
  final hasTitle = item.title != null && item.title!.trim().isNotEmpty;
  return hasTitle;
}

/// Eyebrow rendered above the author row of top-level institution posts.
///
/// Layout: `OFFICIAL` (primary) followed by an optional `• TYPE` token
/// (secondary, lighter) when the post carries a communication-type marker.
/// Calm, monochrome, never animated — its only job is to make institutional
/// speech visually distinct from a chat message in the same feed.
///
/// Phase 4 — accepts an `ageBucket` so older posts wear a less intense
/// eyebrow without losing the OFFICIAL signal entirely.
class _OfficialPill extends StatelessWidget {
  const _OfficialPill({this.type, this.ageBucket = _AgeBucket.fresh});

  /// When non-null, the type label renders as a secondary token after the
  /// OFFICIAL eyebrow. When null (legacy posts without the marker), only
  /// the OFFICIAL pill is shown.
  final InsCommunicationType? type;

  /// Time-decay bucket. Drives a single opacity modifier — the rest of
  /// the eyebrow stays identical so the legibility of OFFICIAL is
  /// preserved regardless of age.
  final _AgeBucket ageBucket;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: ageBucket.eyebrowOpacity,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AuraSurface.accentSoft,
              borderRadius: BorderRadius.circular(AuraRadius.pill),
              border: Border.all(
                color: AuraSurface.accent.withValues(alpha: 0.35),
              ),
            ),
            child: Text(
              'OFFICIAL',
              style: AuraText.micro.copyWith(
                color: AuraSurface.accentText,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                fontSize: 10,
              ),
            ),
          ),
          if (type != null) ...[
            const SizedBox(width: 6),
            Text(
              '• ${type!.label.toUpperCase()}',
              style: AuraText.micro.copyWith(
                color: AuraSurface.faint,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.7,
                fontSize: 10,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Phase 6.3 — secondary attribution gating.
///
/// Only renders when the backend supplied real data AND the actor is
/// distinct from the primary author (defensive: an institution post whose
/// human author somehow shares an id with the institution should not show
/// "Posted by itself").
bool _shouldRenderSecondary(FeedItem item) {
  final attr = item.secondaryAttribution;
  if (attr == null) return false;
  if (attr.type == FeedSecondaryAttributionType.unknown) return false;
  final actor = attr.actor;
  if (actor.id.isEmpty) return false;
  if (actor.displayName.trim().isEmpty && (actor.handle ?? '').trim().isEmpty) {
    return false;
  }
  // Skip when the secondary actor would duplicate the visible primary
  // identity. With current data this only happens in odd/legacy rows; the
  // safe default is to suppress.
  if (actor.id == item.author.id) return false;
  return true;
}

/// Phase 6.3 — small, muted, accountable line that sits below the author
/// row when an institution voice has a real human behind it.
///
/// Style rules: subordinate to the primary author row (smaller text,
/// muted color), tappable to the actor's profile, never rendered as a
/// metric. The optional context badge from Phase 6.1.1 is reused in
/// `replyPreview` mode so the line stays compact.
class _SecondaryAttributionLine extends StatelessWidget {
  const _SecondaryAttributionLine({
    required this.attribution,
    required this.currentPath,
  });

  final FeedSecondaryAttribution attribution;
  final String currentPath;

  @override
  Widget build(BuildContext context) {
    final actor = attribution.actor;
    final adaptedProfile = FeedRouting.adaptProfileRoute(
      actor.profileRoute,
      currentPath: currentPath,
    );
    final tap = (adaptedProfile == null || adaptedProfile.isEmpty)
        ? null
        : () => context.push(adaptedProfile);
    final ctxLabel = actor.context?.label;
    final hasMeaningfulCtx =
        actor.context != null && actor.context!.isMeaningful;

    final nameText = actor.displayName.isNotEmpty
        ? actor.displayName
        : ((actor.handle ?? '').isNotEmpty ? '@${actor.handle}' : 'A member');

    // Compose: "Posted by Founder · M S Bajwa"
    //   * verb              — neutral "Posted by"
    //   * role + dot        — when role context is meaningful (e.g. "Founder · ")
    //   * accountable name  — bolder than verb but still muted
    final composed = StringBuffer(attribution.type.verb)..write(' ');
    if (hasMeaningfulCtx && ctxLabel != null && ctxLabel.contains(' · ')) {
      // ctxLabel like "Founder · Aura Platform" — take the role half only.
      composed.write(ctxLabel.split(' · ').first);
      composed.write(' · ');
    } else if (hasMeaningfulCtx && ctxLabel != null && ctxLabel.isNotEmpty) {
      composed.write(ctxLabel);
      composed.write(' · ');
    }

    return InkWell(
      onTap: tap,
      borderRadius: BorderRadius.circular(AuraRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: RichText(
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          text: TextSpan(
            style: AuraText.micro.copyWith(
              color: AuraSurface.muted,
              height: 1.4,
            ),
            children: [
              TextSpan(text: composed.toString()),
              TextSpan(
                text: nameText,
                style: AuraText.micro.copyWith(
                  color: AuraSurface.ink,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Maps a FeedItem to the right ReactionTarget polymorph.
///
/// User posts → `PostReactionTarget(item.id)`.
/// Institution posts → `InstitutionPostReactionTarget` keyed by the
/// institution that owns the post (which is `author.id` for institution-
/// authored items, since the projection uses the institution as the author).
///
/// Returns `null` when the item is missing the data needed to build a
/// stable target — defensive against any backend regression that fails to
/// populate `author.id` on an institution post. With `null`, the card hides
/// the interaction bar instead of rendering a button that would hit
/// `/v1/institutions//posts/.../reactions/state` and 404.
ReactionTarget? _reactionTargetFor(FeedItem item) {
  if (item.type == FeedItemType.institutionPost) {
    final instId = item.author.id.trim();
    if (instId.isEmpty) return null;
    return InstitutionPostReactionTarget(
      institutionId: instId,
      postId: item.id,
    );
  }
  // Announcements don't yet expose a reaction endpoint; hiding the
  // interaction bar is correct rather than wiring one up to a 404.
  if (item.type == FeedItemType.announcement) return null;
  if (item.id.trim().isEmpty) return null;
  return PostReactionTarget(item.id);
}

class _AuthorRow extends StatelessWidget {
  const _AuthorRow({
    required this.author,
    required this.publishedAt,
    required this.profileRoute,
  });

  final FeedAuthor author;
  final DateTime? publishedAt;
  final String? profileRoute;

  @override
  Widget build(BuildContext context) {
    final initial = author.name.trim().isNotEmpty
        ? author.name.trim()[0].toUpperCase()
        : (author.handleOrSlug.isNotEmpty
              ? author.handleOrSlug[0].toUpperCase()
              : '?');
    final tap = profileRoute == null || profileRoute!.isEmpty
        ? null
        : () => context.push(profileRoute!);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        InkWell(
          onTap: tap,
          borderRadius: BorderRadius.circular(20),
          child: _AvatarWithPresence(
            avatar: _Avatar(
              imageUrl: author.avatarOrLogoUrl,
              fallback: initial,
              isInstitution: author.isInstitution,
            ),
            presence: author.presence,
            avatarSize: 36,
          ),
        ),
        const SizedBox(width: AuraSpace.s10),
        Expanded(
          child: InkWell(
            onTap: tap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        author.name.isNotEmpty
                            ? author.name
                            : (author.handleOrSlug.isNotEmpty
                                  ? '@${author.handleOrSlug}'
                                  : 'Unknown'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AuraText.small.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (author.context != null &&
                        author.context!.isMeaningful) ...[
                      const SizedBox(width: AuraSpace.s6),
                      Flexible(
                        child: AuraIdentityBadge(context: author.context!),
                      ),
                    ],
                  ],
                ),
                if (author.handleOrSlug.isNotEmpty && author.name.isNotEmpty)
                  Text(
                    author.isInstitution
                        ? '/${author.handleOrSlug}'
                        : '@${author.handleOrSlug}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AuraText.micro.copyWith(color: AuraSurface.faint),
                  ),
              ],
            ),
          ),
        ),
        if (publishedAt != null)
          Text(
            formatRelative(publishedAt!),
            style: AuraText.micro.copyWith(color: AuraSurface.faint),
          ),
      ],
    );
  }
}

/// Phase 6.2 — wraps any avatar with a small presence dot in the bottom-right
/// corner. No animation, no pulse, no tooltip. Rendered only for the three
/// "active" presence states; IDLE / unknown / null = no dot.
class _AvatarWithPresence extends StatelessWidget {
  const _AvatarWithPresence({
    required this.avatar,
    required this.avatarSize,
    this.presence,
  });

  final Widget avatar;
  final double avatarSize;
  final FeedPresence? presence;

  @override
  Widget build(BuildContext context) {
    final showDot = presence != null && presence!.state.hasDot;
    if (!showDot) return avatar;
    final dotSize = avatarSize <= 24 ? 6.0 : 8.0;
    return SizedBox(
      width: avatarSize,
      height: avatarSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: avatar),
          Positioned(
            right: -1,
            bottom: -1,
            child: _PresenceDot(state: presence!.state, size: dotSize),
          ),
        ],
      ),
    );
  }
}

class _PresenceDot extends StatelessWidget {
  const _PresenceDot({required this.state, required this.size});

  final FeedPresenceState state;
  final double size;

  Color get _color {
    switch (state) {
      case FeedPresenceState.activeNow:
        return const Color(0xFF22C55E); // soft green
      case FeedPresenceState.recentlyActive:
        return const Color(0xFF60A5FA); // muted blue
      case FeedPresenceState.activeToday:
        return const Color(0xFF94A3B8); // gray
      case FeedPresenceState.idle:
      case FeedPresenceState.unknown:
        return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _color,
        // Hairline ring so the dot reads against any avatar background.
        border: Border.all(color: AuraSurface.card, width: 1.5),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.imageUrl,
    required this.fallback,
    required this.isInstitution,
  });

  final String? imageUrl;
  final String fallback;
  final bool isInstitution;

  @override
  Widget build(BuildContext context) {
    final shape = isInstitution ? BoxShape.rectangle : BoxShape.circle;
    final radius = isInstitution ? BorderRadius.circular(AuraRadius.sm) : null;
    final url = imageUrl?.trim() ?? '';

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: shape,
        borderRadius: radius,
        color: AuraSurface.subtle,
        border: Border.all(color: AuraSurface.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: url.isEmpty
          ? Center(
              child: Text(
                fallback,
                style: AuraText.small.copyWith(
                  color: AuraSurface.muted,
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          : AuraAttachmentImage(
              url: url,
              fit: BoxFit.cover,
              errorWidget: (_) => Center(
                child: Text(
                  fallback,
                  style: AuraText.small.copyWith(
                    color: AuraSurface.muted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
    );
  }
}

/// Filename-context token for the fullscreen viewer's download action,
/// derived from the feed item's type.
String _mediaDownloadContext(FeedItemType type) {
  switch (type) {
    case FeedItemType.institutionPost:
      return 'institution-post-media';
    case FeedItemType.announcement:
      return 'announcement-media';
    case FeedItemType.userPost:
      return 'post-media';
  }
}

/// Legacy compatibility tile for items whose backend payload still
/// uses the flat `mediaUrl` field instead of the structured `media[]`.
/// Delegates to [AuraMediaFrame] so behavior matches the canonical
/// path exactly — same clipping, same maxWidth cap, same crop/contain
/// decision. Tapping opens the fullscreen [AuraMediaViewer].
class _LegacyMediaUrlThumb extends StatelessWidget {
  const _LegacyMediaUrlThumb({
    required this.url,
    this.attachmentId,
    this.mode = AuraMediaFrameMode.feed,
    this.downloadContext = 'post-media',
  });

  final String url;
  final String? attachmentId;
  final AuraMediaFrameMode mode;
  final String downloadContext;

  @override
  Widget build(BuildContext context) {
    final trimmed = url.trim();
    return AuraMediaFrame(
      url: url,
      attachmentId: attachmentId,
      mode: mode,
      // Legacy `mediaUrl` payloads are always flat public URLs, so the
      // save affordance can fetch them directly.
      saveUrl: trimmed.isEmpty ? null : url,
      onTap: trimmed.isEmpty
          ? null
          : () => showAuraMediaViewer(
              context,
              items: [
                AuraViewerItem(
                  originalUrl: trimmed,
                  caption: null,
                  downloadContext: downloadContext,
                ),
              ],
            ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.visibility, required this.distribution});

  final FeedVisibility visibility;
  final FeedDistribution distribution;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AuraSpace.s6,
      runSpacing: AuraSpace.s6,
      children: [
        _Badge(
          icon: _visibilityIcon(visibility),
          label: _visibilityLabel(visibility),
        ),
        if (distribution == FeedDistribution.globalEligible)
          const _Badge(
            icon: Icons.public,
            label: 'Global',
            tone: _BadgeTone.accent,
          ),
      ],
    );
  }

  IconData _visibilityIcon(FeedVisibility v) {
    switch (v) {
      case FeedVisibility.public:
        return Icons.public_rounded;
      case FeedVisibility.memberOnly:
        return Icons.group_rounded;
      case FeedVisibility.internal:
        return Icons.lock_outline_rounded;
      case FeedVisibility.unknown:
        return Icons.help_outline_rounded;
    }
  }

  String _visibilityLabel(FeedVisibility v) {
    switch (v) {
      case FeedVisibility.public:
        return 'Public';
      case FeedVisibility.memberOnly:
        return 'Members';
      case FeedVisibility.internal:
        return 'Internal';
      case FeedVisibility.unknown:
        return '';
    }
  }
}

enum _BadgeTone { neutral, accent }

/// Feed-card badge — wraps canonical SubstrateChip mapping the
/// local accent/neutral tone to canonical teal/mist states. The
/// previous hard-coded `0x1E0D9488` / `0xFF5EEAD4` hex values are
/// retired in favour of canonical co/teal substrate tokens.
class _Badge extends StatelessWidget {
  const _Badge({
    required this.icon,
    required this.label,
    this.tone = _BadgeTone.neutral,
  });

  final IconData icon;
  final String label;
  final _BadgeTone tone;

  @override
  Widget build(BuildContext context) {
    return SubstrateChip(
      label: label,
      icon: icon,
      state: tone == _BadgeTone.accent
          ? SubstrateChipState.teal
          : SubstrateChipState.mist,
    );
  }
}

/// Phase 6.2 — calm activity hint line above the reply-preview block.
/// "New reply" / "Recently replied" — single subtle line, no animation, no
/// counts, no color emphasis beyond the soft accent. Never reorders the
/// feed; just communicates that the conversation is fresh.
class _ActivityHintLine extends StatelessWidget {
  const _ActivityHintLine({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
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
          label,
          style: AuraText.micro.copyWith(
            color: AuraSurface.muted,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

/// Subordinate preview block sitting between the post body and the
/// interaction bar. Shows up to two reply summaries plus an optional
/// "View discussion" link.
///
/// Phase 5.1 product principle: this is conversation depth, not feed
/// noise. The block is visually quieter than the parent post — same card
/// surface, indented avatars, smaller type, no like counts on individual
/// replies. Tapping any reply or the "View discussion" link opens the
/// post-detail screen via the parent's already-shell-adapted
/// `targetRoute`.
class _ReplyPreviewBlock extends StatelessWidget {
  const _ReplyPreviewBlock({required this.preview, required this.openTarget});

  final FeedReplyPreview preview;
  final String openTarget;

  @override
  Widget build(BuildContext context) {
    final tap = openTarget.isEmpty ? null : () => context.push(openTarget);

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.s10,
        AuraSpace.s10,
        AuraSpace.s10,
        AuraSpace.s8,
      ),
      decoration: BoxDecoration(
        color: AuraSurface.subtle,
        borderRadius: BorderRadius.circular(AuraRadius.md),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < preview.items.length; i++) ...[
            _PreviewLine(item: preview.items[i], onTap: tap),
            if (i < preview.items.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Divider(height: 1, color: AuraSurface.divider),
              ),
          ],
          if (preview.hasMore && tap != null) ...[
            const SizedBox(height: AuraSpace.s8),
            InkWell(
              onTap: tap,
              borderRadius: BorderRadius.circular(AuraRadius.pill),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AuraSpace.s8,
                  vertical: 6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View discussion',
                      style: AuraText.micro.copyWith(
                        color: AuraSurface.accentText,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 12,
                      color: AuraSurface.accentText,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PreviewLine extends StatelessWidget {
  const _PreviewLine({required this.item, required this.onTap});

  final FeedReplyPreviewItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final initial = item.author.displayName.trim().isNotEmpty
        ? item.author.displayName.trim()[0].toUpperCase()
        : ((item.author.handle ?? '').isNotEmpty
              ? item.author.handle![0].toUpperCase()
              : '?');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AuraRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AvatarWithPresence(
              avatarSize: 22,
              presence: item.author.presence,
              avatar: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: AuraSurface.accentSoft,
                  shape: BoxShape.circle,
                  border: Border.all(color: AuraSurface.divider),
                ),
                clipBehavior: Clip.antiAlias,
                child: (item.author.avatarUrl ?? '').isNotEmpty
                    ? AuraAttachmentImage(
                        url: item.author.avatarUrl!,
                        attachmentId: item.author.id.isNotEmpty
                            ? 'user:${item.author.id}'
                            : null,
                        fit: BoxFit.cover,
                        errorWidget: (_) => Center(
                          child: Text(
                            initial,
                            style: AuraText.micro.copyWith(
                              color: AuraSurface.accentText,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          initial,
                          style: AuraText.micro.copyWith(
                            color: AuraSurface.accentText,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: AuraSpace.s8),
            Expanded(
              child: RichText(
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: AuraText.micro.copyWith(
                    color: AuraSurface.ink,
                    height: 1.4,
                  ),
                  children: [
                    TextSpan(
                      text: item.author.displayName.isNotEmpty
                          ? item.author.displayName
                          : ((item.author.handle ?? '').isNotEmpty
                                ? '@${item.author.handle}'
                                : 'Someone'),
                      style: AuraText.micro.copyWith(
                        color: AuraSurface.ink,
                        fontWeight: FontWeight.w800,
                        height: 1.4,
                      ),
                    ),
                    if (item.author.context != null &&
                        item.author.context!.isMeaningful) ...[
                      const WidgetSpan(child: SizedBox(width: 6)),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: AuraIdentityBadge(
                          context: item.author.context!,
                          mode: AuraIdentityBadgeMode.replyPreview,
                        ),
                      ),
                    ],
                    const TextSpan(text: '   '),
                    TextSpan(
                      text: item.body.replaceAll('\n', ' ').trim(),
                      style: AuraText.micro.copyWith(
                        color: AuraSurface.muted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Muhammad reposted" / "You reposted" / "2 people you follow reposted".
///
/// Phase 4 product principle: this is a **label**, not a metric. We never
/// render counts or icons that imply popularity. When the signal carries
/// multiple actors, we name the first (most recent) and aggregate the rest
/// as "and N others" if there are more.
class _SignalLabel extends StatelessWidget {
  const _SignalLabel({required this.signal});

  final FeedSignal signal;

  String _label() {
    if (signal.actors.isEmpty) return '';
    final first = signal.actors.first;
    final firstName = first.isViewer
        ? 'You'
        : (first.displayName.trim().isNotEmpty
              ? first.displayName.trim()
              : (first.handle ?? '').trim().isNotEmpty
              ? first.type == FeedAuthorType.institution
                    ? '/${first.handle}'
                    : '@${first.handle}'
              : 'Someone');
    final verb = first.isViewer ? 'reposted' : 'reposted';
    final more = signal.actors.length - 1;
    if (more <= 0) return '$firstName $verb';
    if (more == 1) {
      final second = signal.actors[1];
      final secondName = second.isViewer
          ? 'you'
          : (second.displayName.trim().isNotEmpty
                ? second.displayName.trim()
                : (second.handle ?? '').trim().isNotEmpty
                ? '@${second.handle}'
                : 'someone');
      return '$firstName and $secondName $verb';
    }
    return '$firstName and $more others $verb';
  }

  @override
  Widget build(BuildContext context) {
    final text = _label();
    if (text.isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        const Icon(Icons.repeat_rounded, size: 13, color: AuraSurface.faint),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AuraText.micro.copyWith(
              color: AuraSurface.faint,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// True when the existing `AuraIdentityBadge` will render in the author
/// row — the same gate `_AuthorRow` uses. We mirror that gate here so
/// the explicit "Verified institution" reinforcement line we add for
/// official posts doesn't duplicate the badge when both fire.
bool _authorBadgeShown(FeedItem item) {
  final ctx = item.author.context;
  return ctx != null && ctx.isMeaningful;
}

/// True only when the author identity context explicitly reports
/// `verified = true`. Used to gate the "Source: Verified institution"
/// sub-line — we never render that line on the absence of data so the
/// claim of authority is always backed by a real signal.
bool _isAuthorExplicitlyVerified(FeedItem item) {
  final ctx = item.author.context;
  if (ctx == null) return false;
  return ctx.verified;
}

/// Calm reinforcement line: small icon + "Verified institution" label.
/// Rendered for official institution posts when no `AuraIdentityBadge`
/// is present so trust authority is visible on every official card.
class _VerifiedInstitutionLine extends StatelessWidget {
  const _VerifiedInstitutionLine();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.verified_rounded,
          size: 12,
          color: AuraSurface.accentText,
        ),
        const SizedBox(width: 4),
        Text(
          'Verified institution',
          style: AuraText.micro.copyWith(
            color: AuraSurface.accentText,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

/// True when the item was published (or created) in the last 24 hours.
/// Drives the NEW chip on official posts so very-recent statements get
/// a calm attention marker. Returns false when no timestamp is present
/// — never assume freshness in the absence of data.
bool _isRecentlyPublished(FeedItem item) {
  final ts = item.publishedAt ?? item.createdAt;
  if (ts == null) return false;
  return DateTime.now().difference(ts) <= const Duration(hours: 24);
}

/// True when the post is ≤ 12 hours old. Drives the soft "Recent update"
/// reinforcement under announcement titles.
bool _isVeryRecent(FeedItem item) {
  final ts = item.publishedAt ?? item.createdAt;
  if (ts == null) return false;
  return DateTime.now().difference(ts) <= const Duration(hours: 12);
}

/// Phase 4 time-decay bucketing. Drives the eyebrow opacity + accent
/// border alpha for official posts so old statements feel less urgent
/// without disappearing.
///
/// Buckets:
///   * `fresh`    — ≤ 24 h: full intensity.
///   * `recent`   — 24–72 h: subtle dim on the eyebrow + lighter
///                  accent border on the card.
///   * `stale`    — > 72 h: card border drops to the regular divider
///                  color and the NEW chip is suppressed.
///   * `unknown`  — no timestamp: behaves like `fresh` (legacy
///                  content keeps reading the same way it did before
///                  Phase 4).
enum _AgeBucket { fresh, recent, stale, unknown }

extension on _AgeBucket {
  double get eyebrowOpacity {
    switch (this) {
      case _AgeBucket.fresh:
      case _AgeBucket.unknown:
        return 1.0;
      case _AgeBucket.recent:
        return 0.85;
      case _AgeBucket.stale:
        return 0.65;
    }
  }

  double get accentBorderAlpha {
    switch (this) {
      case _AgeBucket.fresh:
      case _AgeBucket.unknown:
        return 0.45;
      case _AgeBucket.recent:
        return 0.28;
      case _AgeBucket.stale:
        // Past 72 h, the border drops back to plain divider via the
        // caller's `accentBorder` selector — but for safety we still
        // expose a low alpha here so any direct user gets a calm
        // accent rather than a hard one.
        return 0.18;
    }
  }
}

_AgeBucket _ageBucketFor(FeedItem item) {
  final ts = item.publishedAt ?? item.createdAt;
  if (ts == null) return _AgeBucket.unknown;
  final age = DateTime.now().difference(ts);
  if (age <= const Duration(hours: 24)) return _AgeBucket.fresh;
  if (age <= const Duration(hours: 72)) return _AgeBucket.recent;
  return _AgeBucket.stale;
}

/// Phase 4 — derive a "Recent activity around this" label from existing
/// FeedItem signals. Prefers a precise reply count when the backend
/// flagged it as visible (`canViewReplyCount`); falls back to a generic
/// "Active discussion" hint when only the recent-reply boolean is set.
/// Returns null when there's nothing meaningful to say — the caller
/// should then render no line at all.
String? _recentActivityLabelFor(FeedItem item) {
  final replyCount = item.interaction.replyCount;
  if (item.interaction.canViewReplyCount && replyCount > 0) {
    return replyCount == 1
        ? '1 response from members'
        : '$replyCount responses from members';
  }
  if (item.activity?.recentReply == true) return 'Active discussion';
  return null;
}

/// Calm one-line activity hint rendered under the visibility row on
/// official posts that have generated reader response.
class _RecentActivityLine extends StatelessWidget {
  const _RecentActivityLine({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.forum_outlined, size: 12, color: AuraSurface.muted),
        const SizedBox(width: 5),
        Text(
          label,
          style: AuraText.small.copyWith(
            color: AuraSurface.muted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// Under-title intent label per communication type. Keep the mapping
/// minimal — Update returns null so routine posts don't carry extra
/// copy. Loose synonyms in the spec ("Public notice", "Action may be
/// required") are deliberately *not* used because they vary by context;
/// a single calibrated label per type reads more institutional.
String? _intentLabelFor(InsCommunicationType type) {
  switch (type) {
    case InsCommunicationType.announcement:
      return 'Official notice';
    case InsCommunicationType.advisory:
      return 'Guidance';
    case InsCommunicationType.notice:
      return 'Information';
    case InsCommunicationType.update:
      return null;
  }
}

/// Small "NEW" chip rendered next to the OFFICIAL eyebrow when the post
/// was published in the last 24 hours. Static, calm — no animation.
class _NewChip extends StatelessWidget {
  const _NewChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AuraSurface.coVerdant.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        border: Border.all(
          color: AuraSurface.coVerdant.withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        'NEW',
        style: AuraText.micro.copyWith(
          color: AuraSurface.coVerdant,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.7,
          fontSize: 9,
        ),
      ),
    );
  }
}

/// Maps a raw `publicStatus` wire value to the calm product label shown on
/// feed cards. Returns null when the status is absent, empty, or PENDING —
/// those states render nothing (silence is the default, not a failure).
String? _publicStatusLabel(String? raw) {
  switch ((raw ?? '').toUpperCase().trim()) {
    case 'RESPONDED':
      return 'Official Response';
    case 'COMMITTED':
      return 'Commitment';
    case 'RESOLVED':
      return 'Resolved';
    default:
      return null;
  }
}

/// Calm inline chip that surfaces the accountability status of a public post.
/// Shown only when an institution has formally responded (RESPONDED /
/// COMMITTED / RESOLVED). Never shows routing internals.
class _PublicStatusChip extends StatelessWidget {
  const _PublicStatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final isResolved = label == 'Resolved';
    final color = isResolved ? const Color(0xFF1B8A4C) : AuraSurface.accent;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isResolved
                ? Icons.check_circle_outline_rounded
                : Icons.verified_outlined,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: AuraText.micro.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small inline indicator rendered inside advisory cards. Calmer than a
/// full warning banner — a single icon + label that sits above the title
/// to communicate "pay attention" without alarm.
class _AdvisoryIndicator extends StatelessWidget {
  const _AdvisoryIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: AuraSurface.coSun.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        border: Border.all(color: AuraSurface.coSun.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.report_problem_rounded,
            size: 12,
            color: AuraSurface.coSun,
          ),
          const SizedBox(width: 6),
          Text(
            'Advisory',
            style: AuraText.micro.copyWith(
              color: AuraSurface.coSun,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

// `_formatRelative` was lifted into `lib/core/utils/relative_time.dart`
// (`formatRelative`) so the live room cards and post detail strips can
// reuse the same calibrated phrasing. This file imports it directly.
