import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../feed/domain/feed_item.dart';
import '../../feed/presentation/unified_feed_card.dart';
import '../domain/monetization_kind.dart';
import 'activity_tail.dart';
import 'monetization_label.dart';

/// Phase 2 — promoted activity pulse rendered as a small attention-
/// grabbing chip ABOVE the card body when there's meaningful activity.
/// Signals "people are responding now" / "institution involved" /
/// "active discussion" without redrawing the card or stacking visual
/// weight on every quiet item.
///
/// Phase 4 — adds `outcomeResolved` (highest precedence) so threads
/// that have produced an outcome read distinctly from those that
/// haven't.
enum _PulseKind {
  outcomeResolved,
  institutionInvolved,
  awaitingInstitutionResponse,
  peopleResponding,
  activeDiscussion,
}

extension on _PulseKind {
  String get label {
    switch (this) {
      case _PulseKind.outcomeResolved:
        return 'Outcome reached';
      case _PulseKind.activeDiscussion:
        return 'Active discussion';
      case _PulseKind.peopleResponding:
        return 'People are responding now';
      case _PulseKind.institutionInvolved:
        return 'Institution involved';
      case _PulseKind.awaitingInstitutionResponse:
        return 'Awaiting institution response';
    }
  }

  IconData get icon {
    switch (this) {
      case _PulseKind.outcomeResolved:
        return Icons.check_circle_outline_rounded;
      case _PulseKind.activeDiscussion:
        return Icons.bolt_rounded;
      case _PulseKind.peopleResponding:
        return Icons.forum_rounded;
      case _PulseKind.institutionInvolved:
        return Icons.verified_rounded;
      case _PulseKind.awaitingInstitutionResponse:
        return Icons.hourglass_top_rounded;
    }
  }
}

/// Discourse-flavored feed item.
///
/// Wraps the existing `UnifiedFeedCard` so all of its rendering logic
/// (author row, OFFICIAL pill, type-aware title weight, time decay,
/// verified line, advisory indicator, reply preview, interaction bar)
/// is preserved. On top, this widget adds the public-discourse signals
/// the design spec calls for:
///
///   * **Eyebrow context strip** — `In space [name]` chip when the
///     item is anchored to a space/topic, plus an OFFICIAL response
///     monetization pill when the post is institution-authored.
///   * **Activity tail** — `12 replies · 3 institutions responded ·
///     Active discussion`, derived from existing FeedItem fields.
///   * **Paid distribution stripe** — full-width `MonetizationLabel`
///     band rendered below the card body when a paid action is in
///     play. Phase 1: derived for `OFFICIAL_RESPONSE` (free verified)
///     from the existing institution-post heuristic; backend-driven
///     for paid kinds in a later phase.
///
/// The card itself has no Riverpod dependency — everything it needs is
/// already on the supplied `FeedItem`.
class DiscourseCard extends StatelessWidget {
  const DiscourseCard({
    super.key,
    required this.item,
    this.spaceName,
    this.spaceRoute,
    this.paidLabel,
    this.showInteractionBar = true,
    this.showEntryHookCta = true,
  });

  final FeedItem item;

  /// When false, the underlying like/reply/repost row is hidden. Used
  /// on the signed-out public homepage where interactions require an
  /// account — surfacing them with no behavior is misleading.
  final bool showInteractionBar;

  /// When false, the bottom single-line entry-hook CTA is hidden.
  /// Used on surfaces (e.g. Public homepage) that wrap the card with
  /// their own footer strip — keeping both would double up the CTA.
  final bool showEntryHookCta;

  /// Optional context label (space / topic). When non-null, an "In
  /// space [name]" chip is rendered as the leading eyebrow segment.
  /// Tap routes to [spaceRoute].
  final String? spaceName;
  final String? spaceRoute;

  /// Backend-driven paid label override. When null, the card derives a
  /// label only for the free `OFFICIAL_RESPONSE` case via the
  /// institution-post heuristic; paid kinds are rendered only when the
  /// caller passes them in.
  final MonetizationKind? paidLabel;

  bool get _isOfficial =>
      item.type == FeedItemType.institutionPost &&
      (item.title?.trim().isNotEmpty ?? false);

  /// The label we'll render in the stripe band. Order of precedence:
  ///   1. Explicit caller override (still supported for hand-rendered
  ///      surfaces that want to force a specific label).
  ///   2. Backend `paidAction` field on the FeedItem (Phase 3 wiring).
  ///   3. Free-OFFICIAL — derived from the institution-post heuristic.
  MonetizationKind? get _stripeLabel {
    if (paidLabel != null) return paidLabel;
    final fromWire =
        MonetizationKindX.fromPaidActionWire(item.paidActionWire);
    if (fromWire != null) return fromWire;
    if (_isOfficial) return MonetizationKind.officialResponse;
    return null;
  }

  /// Phase 2/4/6 — derive the strongest single discourse pulse this
  /// card can express. We pick at most one to avoid stacking. Order
  /// of precedence:
  ///   1. **Outcome reached** — at least one RESOLVED institutional
  ///      reply (currently inferred via timeline metadata).
  ///   2. Institution involved — institutional response in the
  ///      preview. Signals authority/accountability.
  ///   3. **Awaiting institution response** (Phase 6) — user post
  ///      with replies but NO institutional voice has weighed in.
  ///      Surfaces the gap so institutions feel pressure to engage.
  ///   4. People responding now — recent reply landed within the
  ///      activity hint window.
  ///   5. Active discussion — parent has reply count >= 2.
  _PulseKind? get _pulse {
    final preview = item.replyPreview;
    final hasInstitutionalReply = (preview?.items ?? const [])
        .any((r) => r.author.context?.type ==
            FeedIdentityContextType.officialInstitution);
    if (hasInstitutionalReply) return _PulseKind.institutionInvolved;

    // Phase 6 — surface "awaiting institution response" when the
    // discussion has substance but no institutional voice has
    // engaged yet. We only flag this on user posts (institution
    // posts authored by an institution don't need this — they ARE
    // an institutional voice).
    final replyCount = item.interaction.canViewReplyCount
        ? item.interaction.replyCount
        : 0;
    if (item.type == FeedItemType.userPost && replyCount >= 2) {
      return _PulseKind.awaitingInstitutionResponse;
    }

    if (item.activity?.recentReply == true) {
      return _PulseKind.peopleResponding;
    }
    if (replyCount >= 2) {
      return _PulseKind.activeDiscussion;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // Public-UX Phase 3 — when the caller didn't pass a space context
    // explicitly, fall back to whatever the backend ships on the item
    // itself so a card on the global feed surfaces the space anchor.
    final resolvedSpaceName =
        (spaceName?.trim().isNotEmpty ?? false)
            ? spaceName!.trim()
            : (item.publicSpaceName?.trim() ?? '');
    final resolvedSpaceRoute = spaceRoute ??
        ((item.publicSpaceSlug?.trim().isNotEmpty ?? false)
            ? '/spaces/${item.publicSpaceSlug!.trim()}'
            : null);
    final hasContextEyebrow = resolvedSpaceName.isNotEmpty;
    final pulse = _pulse;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasContextEyebrow || pulse != null) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (hasContextEyebrow)
                _ContextEyebrow(
                  label: resolvedSpaceName,
                  onTap: resolvedSpaceRoute == null
                      ? null
                      : () => context.push(resolvedSpaceRoute),
                ),
              if (pulse != null) _PulsePill(kind: pulse),
            ],
          ),
          const SizedBox(height: AuraSpace.s6),
        ],
        // Engine: UnifiedFeedCard owns author row, OFFICIAL pill, title,
        // body, media, visibility row, reply preview, interaction bar.
        UnifiedFeedCard(item: item, showInteractionBar: showInteractionBar),
        // Activity tail: replies + institutions responded + recent.
        Builder(
          builder: (_) {
            final tail = ActivityTail(item: item);
            // Empty-state of ActivityTail collapses to SizedBox.shrink,
            // so the spacer below would still render — pad only when
            // we actually have something to show.
            if (tail._institutionResponseCount == 0 &&
                !item.interaction.canViewReplyCount &&
                item.activity?.recentReply != true) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.fromLTRB(
                AuraSpace.s14,
                0,
                AuraSpace.s14,
                AuraSpace.s10,
              ),
              child: tail,
            );
          },
        ),
        if (_stripeLabel != null) ...[
          const SizedBox(height: AuraSpace.s6),
          _MonetizationStripe(kind: _stripeLabel!),
        ],
        // Public-UX Phase 5 — entry-hook CTA at the bottom of the
        // card. Single tappable line that takes the user directly
        // into the thread instead of leaving them scrolling. The
        // label is chosen by the dominant pulse so the CTA matches
        // the framing of the card. Suppressed on surfaces that wrap
        // the card with their own footer strip.
        if (showEntryHookCta)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AuraSpace.s14,
              AuraSpace.s4,
              AuraSpace.s14,
              AuraSpace.s10,
            ),
            child: _EntryHookCTA(item: item, pulse: _pulse),
          ),
      ],
    );
  }
}

/// Public-UX Phase 5 — single-line entry-hook CTA. Lives at the
/// bottom of every `DiscourseCard`. The label adapts to the dominant
/// pulse: "View resolution" for outcome-resolved, "View official
/// response" when an institution has responded, "Join discussion"
/// for active threads, "Be the first to respond" for unanswered.
class _EntryHookCTA extends StatelessWidget {
  const _EntryHookCTA({required this.item, required this.pulse});

  final FeedItem item;
  final _PulseKind? pulse;

  String get _label {
    switch (pulse) {
      case _PulseKind.outcomeResolved:
        return 'View resolution';
      case _PulseKind.institutionInvolved:
        return 'View official response';
      case _PulseKind.awaitingInstitutionResponse:
        return 'Add weight to this';
      case _PulseKind.peopleResponding:
      case _PulseKind.activeDiscussion:
        return 'Join discussion';
      case null:
        final hasReplies =
            item.interaction.canViewReplyCount &&
                item.interaction.replyCount > 0;
        return hasReplies ? 'Open thread' : 'Be the first to respond';
    }
  }

  IconData get _icon {
    switch (pulse) {
      case _PulseKind.outcomeResolved:
        return Icons.check_circle_outline_rounded;
      case _PulseKind.institutionInvolved:
        return Icons.verified_rounded;
      case _PulseKind.awaitingInstitutionResponse:
        return Icons.hourglass_top_rounded;
      case _PulseKind.peopleResponding:
      case _PulseKind.activeDiscussion:
        return Icons.forum_rounded;
      case null:
        final hasReplies =
            item.interaction.canViewReplyCount &&
                item.interaction.replyCount > 0;
        return hasReplies
            ? Icons.subdirectory_arrow_right_rounded
            : Icons.reply_rounded;
    }
  }

  /// Phase 5 — drop the reader at a meaningful position in the
  /// thread. For outcome-resolved or institution-responded items, we
  /// hint the thread screen to scroll to the latest official reply
  /// via a query param. For active threads the same query param
  /// scrolls to the latest reply. For unanswered, the screen lands
  /// at the top with the composer ready.
  String get _route {
    final id = item.id;
    if (id.isEmpty) return '/';
    final type = item.type == FeedItemType.institutionPost
        ? 'INSTITUTION_POST'
        : 'USER_POST';
    String? focus;
    switch (pulse) {
      case _PulseKind.outcomeResolved:
        focus = 'resolution';
      case _PulseKind.institutionInvolved:
        focus = 'official';
      case _PulseKind.awaitingInstitutionResponse:
      case _PulseKind.peopleResponding:
      case _PulseKind.activeDiscussion:
        focus = 'latest';
      case null:
        focus = null;
    }
    final qp = <String, String>{
      'type': type,
      if (focus != null) 'focus': focus,
    };
    final qs = qp.entries
        .map((e) =>
            '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return '/thread/$id?$qs';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push(_route),
      borderRadius: BorderRadius.circular(AuraRadius.pill),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.s4,
          vertical: AuraSpace.s4,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icon, size: 13, color: AuraSurface.accentText),
            const SizedBox(width: 5),
            Text(
              _label,
              style: AuraText.small.copyWith(
                color: AuraSurface.accentText,
                fontWeight: FontWeight.w800,
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
    );
  }
}

class _ContextEyebrow extends StatelessWidget {
  const _ContextEyebrow({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AuraRadius.pill),
      child: Container(
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
              Icons.tag_rounded,
              size: 11,
              color: AuraSurface.muted,
            ),
            const SizedBox(width: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Text(
                'In $label',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AuraText.micro.copyWith(
                  color: AuraSurface.muted,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonetizationStripe extends StatelessWidget {
  const _MonetizationStripe({required this.kind});

  final MonetizationKind kind;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.s14,
        0,
        AuraSpace.s14,
        AuraSpace.s10,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: MonetizationLabel(kind: kind),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper extension — exposes the private institution-response counter on
// ActivityTail so DiscourseCard can decide whether to pad the tail row.
// We keep this colocated rather than promoting it to the ActivityTail
// public API because the gate is rendering-only.
// ─────────────────────────────────────────────────────────────────────────────

extension on ActivityTail {
  int get _institutionResponseCount {
    final preview = item.replyPreview;
    if (preview == null || preview.items.isEmpty) return 0;
    final seen = <String>{};
    var n = 0;
    for (final r in preview.items) {
      final ctx = r.author.context;
      if (ctx == null) continue;
      if (ctx.type != FeedIdentityContextType.officialInstitution) continue;
      if (r.author.id.isEmpty || seen.contains(r.author.id)) continue;
      seen.add(r.author.id);
      n++;
    }
    return n;
  }
}

/// Promoted activity-pulse pill rendered above the card body. Calm —
/// no animation, no color escalation. Its job is to make the card
/// read as "something is happening" without crossing into noise.
class _PulsePill extends StatelessWidget {
  const _PulsePill({required this.kind});

  final _PulseKind kind;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color ink, Color border) = switch (kind) {
      _PulseKind.outcomeResolved => (
        AuraSurface.coVerdant.withValues(alpha: 0.16),
        AuraSurface.coVerdant,
        AuraSurface.coVerdant.withValues(alpha: 0.4),
      ),
      _PulseKind.institutionInvolved => (
        AuraSurface.accentSoft,
        AuraSurface.accentText,
        AuraSurface.accent.withValues(alpha: 0.4),
      ),
      _PulseKind.awaitingInstitutionResponse => (
        AuraSurface.coSun.withValues(alpha: 0.16),
        AuraSurface.coSun,
        AuraSurface.coSun.withValues(alpha: 0.35),
      ),
      _PulseKind.peopleResponding ||
      _PulseKind.activeDiscussion =>
        (AuraSurface.subtle, AuraSurface.muted, AuraSurface.divider),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(kind.icon, size: 11, color: ink),
          const SizedBox(width: 4),
          Text(
            kind.label,
            style: AuraText.micro.copyWith(
              color: ink,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
