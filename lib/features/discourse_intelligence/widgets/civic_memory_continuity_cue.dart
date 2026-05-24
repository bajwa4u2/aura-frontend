import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/ui/substrate_chip.dart';
import '../providers.dart';

/// Civic memory continuity cue — a small inline accountability
/// rollup that surfaces civic continuity across institutions in a
/// single calm line:
///
///   CIVIC MEMORY · <N> open commitments · <M> updates · <K> resolved
///                  across <I> institutions
///
/// The cue composes data already loaded by the rail-side
/// `accountabilityTrailProvider`; this widget makes no new
/// requests. It self-collapses on quiet networks (no rows) so a
/// young deployment renders no chrome.
///
/// Doctrine mirror — AU-01 §6 (Discourse-intelligence aggregates)
/// and the civic-memory framing in
/// `system/governance/governance-grammar.md`. Calm, observational,
/// never a ranking. Reads as continuity, not a score.
class CivicMemoryContinuityCue extends ConsumerWidget {
  const CivicMemoryContinuityCue({super.key, this.padding});

  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(accountabilityTrailProvider);
    final page = async.maybeWhen(data: (p) => p, orElse: () => null);
    if (page == null || page.items.isEmpty) return const SizedBox.shrink();

    var commitments = 0;
    var updates = 0;
    var resolved = 0;
    for (final row in page.items) {
      commitments += row.commitments;
      updates += row.updates;
      resolved += row.resolved;
    }
    final open = commitments - resolved;
    final institutionCount = page.items.length;

    // If literally every counter is zero, render nothing — a quiet
    // network should be quiet.
    if (open <= 0 && updates <= 0 && resolved <= 0) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: AuraSpace.s16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AuraSpace.s14,
          AuraSpace.s10,
          AuraSpace.s14,
          AuraSpace.s10,
        ),
        decoration: BoxDecoration(
          color: AuraSurface.subtle,
          borderRadius: BorderRadius.circular(AuraRadius.r12),
          border: Border.all(
            color: AuraSurface.divider.withValues(alpha: 0.6),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CIVIC MEMORY',
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
              spacing: 6,
              runSpacing: 6,
              children: [
                if (open > 0)
                  SubstrateChip(
                    label: '$open open',
                    state: SubstrateChipState.teal,
                  ),
                if (updates > 0)
                  SubstrateChip(
                    label: '$updates update${updates == 1 ? '' : 's'}',
                    state: SubstrateChipState.sun,
                  ),
                if (resolved > 0)
                  SubstrateChip(
                    label: '$resolved resolved',
                    state: SubstrateChipState.verdant,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Across $institutionCount '
              '${institutionCount == 1 ? "institution" : "institutions"} '
              'with on-record accountability activity.',
              style: AuraText.micro.copyWith(
                color: AuraSurface.faint,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
