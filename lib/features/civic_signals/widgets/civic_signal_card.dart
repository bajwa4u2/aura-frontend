import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../feed/domain/feed_item.dart' show FeedRouting;
import '../models.dart';

/// Compact civic-signal card.
///
/// Renders one [CivicSignal] as a tap-through tile. Visual tone is
/// intentionally institutional — outline border, accent type chip,
/// muted body excerpt. No engagement counts, no fake metrics.
///
/// `dense` shrinks the card vertically for use inside a horizontal
/// strip on the directory; the default density is sized for the
/// sector-page activity panel.
class CivicSignalCard extends StatelessWidget {
  const CivicSignalCard({
    super.key,
    required this.signal,
    this.dense = false,
  });

  final CivicSignal signal;
  final bool dense;

  String _relativeTime() {
    final at = signal.publishedAt;
    if (at == null) return '';
    final diff = DateTime.now().difference(at);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${(diff.inDays / 7).floor()}w';
  }

  @override
  Widget build(BuildContext context) {
    final adapted = FeedRouting.adaptTargetRoute(
      signal.targetRoute,
      currentPath: GoRouterState.of(context).uri.path,
    );
    return Material(
      color: AuraSurface.card,
      borderRadius: BorderRadius.circular(AuraRadius.r12),
      child: InkWell(
        borderRadius: BorderRadius.circular(AuraRadius.r12),
        onTap: () => context.push(adapted),
        child: Container(
          padding: EdgeInsets.all(dense ? AuraSpace.s10 : AuraSpace.s12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AuraRadius.r12),
            border: Border.all(
              color: AuraSurface.divider.withValues(alpha: 0.6),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AuraSpace.s6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AuraSurface.accentSoft,
                      borderRadius: BorderRadius.circular(AuraRadius.pill),
                      border: Border.all(
                        color: AuraSurface.accent.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      'INSTITUTION VOICE',
                      style: AuraText.micro.copyWith(
                        color: AuraSurface.accentText,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        fontSize: 9.5,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _relativeTime(),
                    style: AuraText.micro.copyWith(
                      color: AuraSurface.faint,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              SizedBox(height: dense ? 6 : AuraSpace.s8),
              Text(
                signal.actorName.isEmpty ? 'Institution' : signal.actorName,
                style: AuraText.small.copyWith(
                  color: AuraSurface.ink,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (signal.bodyExcerpt.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  signal.bodyExcerpt,
                  style: AuraText.small.copyWith(
                    color: AuraSurface.muted,
                    height: 1.4,
                  ),
                  maxLines: dense ? 2 : 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
