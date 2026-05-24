import 'package:flutter/material.dart';

import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/ui/substrate_chip.dart';
import '../../feed/domain/feed_item.dart';

/// Thread lineage rail — renders the typed-pointer lineage of a
/// public post as a horizontal lane:
///
///   [RESOLVES ↩]  →  [THIS THREAD]  →  [CONTINUES ↪]
///                                       (N replies)
///                                       (M institutional)
///
/// Each lane node is a `SubstrateChip` — teal for the current
/// thread, mist for unset edges, verdant when the thread is the
/// resolution of a prior commitment. The widget reads only fields
/// already present on `FeedItem` plus the in-memory reply page;
/// it makes no network calls and invents no linkage.
///
/// Doctrine mirror — AU-01 §4 (Typed pointers across public
/// spaces). `resolves` and `continues` are first-class, set only by
/// the institution; the frontend renders the structure, never
/// guesses it.
class ThreadLineageRail extends StatelessWidget {
  const ThreadLineageRail({
    super.key,
    required this.item,
    required this.replyCount,
    required this.institutionReplyCount,
  });

  final FeedItem item;
  final int replyCount;
  final int institutionReplyCount;

  @override
  Widget build(BuildContext context) {
    final hasUpstream =
        (item.resolvesPostId ?? '').isNotEmpty ||
            (item.continuesPostId ?? '').isNotEmpty;
    // No lineage to render and the thread has no downstream
    // institutional voice yet — quietly self-collapse.
    if (!hasUpstream && replyCount == 0 && institutionReplyCount == 0) {
      return const SizedBox.shrink();
    }

    final resolves = (item.resolvesPostId ?? '').trim();
    final continues = (item.continuesPostId ?? '').trim();

    return Container(
      padding: const EdgeInsets.all(AuraSpace.s12),
      decoration: BoxDecoration(
        color: AuraSurface.subtle,
        borderRadius: BorderRadius.circular(AuraRadius.r12),
        border: Border.all(color: AuraSurface.divider.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'THREAD LINEAGE',
            style: AuraText.micro.copyWith(
              color: AuraSurface.muted,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: AuraSpace.s8),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            runSpacing: 8,
            children: [
              SubstrateChip(
                label: resolves.isEmpty ? 'NO PRIOR RESOLUTION' : 'RESOLVES',
                state: resolves.isEmpty
                    ? SubstrateChipState.mist
                    : SubstrateChipState.verdant,
                dimmed: resolves.isEmpty,
              ),
              const _LineageArrow(),
              const SubstrateChip(
                label: 'THIS THREAD',
                state: SubstrateChipState.teal,
              ),
              const _LineageArrow(),
              SubstrateChip(
                label: continues.isEmpty ? 'NO CONTINUATION' : 'CONTINUES',
                state: continues.isEmpty
                    ? SubstrateChipState.mist
                    : SubstrateChipState.sun,
                dimmed: continues.isEmpty,
              ),
            ],
          ),
          if (replyCount > 0 || institutionReplyCount > 0) ...[
            const SizedBox(height: AuraSpace.s8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Downstream:',
                  style: AuraText.micro.copyWith(
                    color: AuraSurface.faint,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
                SubstrateChip(
                  label: '$replyCount ${replyCount == 1 ? "reply" : "replies"}',
                  state: SubstrateChipState.mist,
                  dimmed: replyCount == 0,
                ),
                if (institutionReplyCount > 0)
                  SubstrateChip(
                    label: '$institutionReplyCount institutional',
                    state: SubstrateChipState.teal,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _LineageArrow extends StatelessWidget {
  const _LineageArrow();

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.arrow_forward_rounded,
      size: 14,
      color: AuraSurface.coTeal.withValues(alpha: 0.55),
    );
  }
}
