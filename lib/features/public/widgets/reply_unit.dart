import 'package:flutter/material.dart';

import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/utils/relative_time.dart';
import '../../../shared/identity/aura_identity_badge.dart';
import '../../feed/domain/feed_item.dart';
import '../domain/monetization_kind.dart';
import 'monetization_label.dart';

/// One reply in the discourse thread.
///
/// Visual rules:
///   * **Default reply** — calm subtle card.
///   * **Official institution response** — same skeleton, plus a left
///     accent border and a small "Official response" eyebrow. Reads
///     inline with member replies (the discussion stays one stream).
///   * **Non-official replies under an official parent** — slightly
///     dimmed (opacity 0.85) so institutional voice is dominant. We
///     keep readability intact.
class ReplyUnit extends StatelessWidget {
  const ReplyUnit({
    super.key,
    required this.reply,
    this.parentIsOfficial = false,
  });

  final FeedReply reply;

  /// True when this reply belongs to an official institution post — the
  /// thread screen passes this so non-official replies dim correctly.
  final bool parentIsOfficial;

  bool get _isOfficial {
    final ctx = reply.author.context;
    if (ctx == null) return false;
    return ctx.type == FeedIdentityContextType.officialInstitution;
  }

  @override
  Widget build(BuildContext context) {
    final ctx = reply.author.context;
    final hasBadge = ctx != null && ctx.isMeaningful;
    final initial = reply.author.displayName.trim().isNotEmpty
        ? reply.author.displayName.trim()[0].toUpperCase()
        : (reply.author.handle.isNotEmpty
            ? reply.author.handle[0].toUpperCase()
            : '?');

    final card = Container(
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.s12,
        AuraSpace.s12,
        AuraSpace.s12,
        AuraSpace.s12,
      ),
      decoration: BoxDecoration(
        color: AuraSurface.subtle,
        borderRadius: BorderRadius.circular(AuraRadius.md),
        border: Border(
          top: const BorderSide(color: AuraSurface.divider),
          right: const BorderSide(color: AuraSurface.divider),
          bottom: const BorderSide(color: AuraSurface.divider),
          left: BorderSide(
            color: _isOfficial
                ? AuraSurface.accent.withValues(alpha: 0.6)
                : AuraSurface.divider,
            width: _isOfficial ? 2.5 : 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isOfficial) ...[
            const Row(
              children: [
                MonetizationLabel(
                  kind: MonetizationKind.officialResponse,
                  compact: true,
                ),
              ],
            ),
            const SizedBox(height: AuraSpace.s8),
          ],
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
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: AuraText.small.copyWith(
                    color: AuraSurface.accentText,
                    fontWeight: FontWeight.w800,
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AuraText.small.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (hasBadge) ...[
                          const SizedBox(width: AuraSpace.s6),
                          Flexible(
                            child: AuraIdentityBadge(
                              context: ctx,
                              mode: AuraIdentityBadgeMode.replyPreview,
                            ),
                          ),
                        ],
                        if (reply.createdAt != null) ...[
                          const SizedBox(width: AuraSpace.s6),
                          Text(
                            '· ${formatRelative(reply.createdAt!)}',
                            style: AuraText.micro.copyWith(
                              color: AuraSurface.faint,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (reply.body.trim().isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s8),
            Text(
              reply.body,
              style: AuraText.body.copyWith(
                color: AuraSurface.ink,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );

    // Phase 4 (Value Layer) carryover: non-official replies under an
    // official parent dim slightly so institutional voice dominates.
    if (parentIsOfficial && !_isOfficial) {
      return Opacity(opacity: 0.85, child: card);
    }
    return card;
  }
}
