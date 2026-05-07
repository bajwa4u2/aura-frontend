import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/utils/relative_time.dart';
import '../../../shared/identity/aura_identity_badge.dart';
import '../../feed/domain/feed_item.dart';
import '../../institutions/domain/communication_type.dart';
import '../domain/monetization_kind.dart';
import '../domain/public_visibility.dart';
import 'mention_text.dart';
import 'monetization_label.dart';
import 'visibility_selector.dart';

/// Header block at the top of a thread screen — the original signal.
///
/// Renders:
///   * OFFICIAL eyebrow (with TYPE) for institution posts.
///   * Author row with verified badge when applicable.
///   * Title (decoded clean) and full body (no clamp).
///   * Context line ("In space …" if attached).
///   * Visibility chip + relative timestamp.
///
/// Extends rather than reuses `UnifiedFeedCard` so the title can render
/// at full headline weight and the body never clamps. The interaction
/// bar belongs to the thread screen itself, not the header.
class ThreadHeader extends StatelessWidget {
  const ThreadHeader({
    super.key,
    required this.item,
    this.spaceName,
    this.spaceRoute,
  });

  final FeedItem item;
  final String? spaceName;
  final String? spaceRoute;

  bool get _isOfficial =>
      item.type == FeedItemType.institutionPost &&
      (item.title?.trim().isNotEmpty ?? false);

  @override
  Widget build(BuildContext context) {
    final decoded = _isOfficial
        ? InsCommunicationDecoded.parse(item.title)
        : null;
    final cleanTitle = decoded?.cleanTitle ??
        (item.title ?? '').trim();

    final ts = item.publishedAt ?? item.createdAt;
    final author = item.author;
    final ctx = author.context;
    final hasBadge = ctx != null && ctx.isMeaningful;
    final visibility = _resolveVisibility(item);

    return Container(
      padding: const EdgeInsets.all(AuraSpace.s16),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.lg),
        border: Border.all(
          color: _isOfficial
              ? AuraSurface.accent.withValues(alpha: 0.45)
              : AuraSurface.divider,
          width: _isOfficial ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isOfficial) ...[
            Row(
              children: [
                _OfficialEyebrow(decoded: decoded!),
                const SizedBox(width: 6),
                const MonetizationLabel(
                  kind: MonetizationKind.officialResponse,
                  compact: true,
                ),
              ],
            ),
            const SizedBox(height: AuraSpace.s8),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AuraAvatar(
                name: author.name.isNotEmpty
                    ? author.name
                    : author.handleOrSlug,
                size: 36,
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
                            author.name.isNotEmpty
                                ? author.name
                                : '@${author.handleOrSlug}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AuraText.body.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (hasBadge) ...[
                          const SizedBox(width: AuraSpace.s6),
                          Flexible(
                            child: AuraIdentityBadge(context: ctx),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          author.handleOrSlug.isNotEmpty
                              ? '@${author.handleOrSlug}'
                              : '',
                          style: AuraText.micro.copyWith(
                            color: AuraSurface.faint,
                          ),
                        ),
                        if (ts != null) ...[
                          const SizedBox(width: AuraSpace.s6),
                          Text(
                            '· ${formatRelative(ts)}',
                            style: AuraText.micro.copyWith(
                              color: AuraSurface.faint,
                            ),
                          ),
                        ],
                        const SizedBox(width: AuraSpace.s8),
                        PubVisibilityChip(value: visibility),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (cleanTitle.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s14),
            Text(
              cleanTitle,
              style: AuraText.headline.copyWith(
                fontWeight: FontWeight.w900,
                height: 1.25,
              ),
            ),
          ],
          if (item.body.trim().isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s10),
            // Phase 6.1 — accent-style + tappable @mentions in the
            // post body, mirroring reply rendering.
            MentionText(
              item.body,
              style: AuraText.body.copyWith(
                color: AuraSurface.ink,
                height: 1.55,
              ),
            ),
          ],
          if ((spaceName ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s12),
            InkWell(
              onTap: spaceRoute == null
                  ? null
                  : () => context.push(spaceRoute!),
              borderRadius: BorderRadius.circular(AuraRadius.pill),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AuraSpace.s10,
                  vertical: AuraSpace.s4,
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
                      size: 12,
                      color: AuraSurface.muted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'In $spaceName',
                      style: AuraText.small.copyWith(
                        color: AuraSurface.muted,
                        fontWeight: FontWeight.w700,
                      ),
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

  PubVisibility _resolveVisibility(FeedItem i) {
    switch (i.visibility) {
      case FeedVisibility.public:
        return PubVisibility.public;
      case FeedVisibility.memberOnly:
      case FeedVisibility.internal:
      case FeedVisibility.unknown:
        return PubVisibility.social;
    }
  }
}

class _OfficialEyebrow extends StatelessWidget {
  const _OfficialEyebrow({required this.decoded});

  final InsCommunicationDecoded decoded;

  @override
  Widget build(BuildContext context) {
    final hasType = decoded.hadMarker;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AuraSurface.accentSoft,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        border: Border.all(
          color: AuraSurface.accent.withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        hasType ? 'OFFICIAL · ${decoded.type.label.toUpperCase()}' : 'OFFICIAL',
        style: AuraText.micro.copyWith(
          color: AuraSurface.accentText,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
          fontSize: 10,
        ),
      ),
    );
  }
}
