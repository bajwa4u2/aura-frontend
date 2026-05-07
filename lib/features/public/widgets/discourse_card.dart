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
  });

  final FeedItem item;

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

  /// The label we'll render in the stripe band. Free-OFFICIAL is
  /// derived; everything else needs an explicit override.
  MonetizationKind? get _stripeLabel {
    if (paidLabel != null) return paidLabel;
    if (_isOfficial) return MonetizationKind.officialResponse;
    return null;
  }

  void _openSpace(BuildContext context) {
    final route = spaceRoute?.trim() ?? '';
    if (route.isEmpty) return;
    context.push(route);
  }

  @override
  Widget build(BuildContext context) {
    final hasContextEyebrow = (spaceName?.trim().isNotEmpty ?? false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasContextEyebrow) ...[
          _ContextEyebrow(
            label: spaceName!.trim(),
            onTap: spaceRoute == null ? null : () => _openSpace(context),
          ),
          const SizedBox(height: AuraSpace.s6),
        ],
        // Engine: UnifiedFeedCard owns author row, OFFICIAL pill, title,
        // body, media, visibility row, reply preview, interaction bar.
        UnifiedFeedCard(item: item),
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
      ],
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
