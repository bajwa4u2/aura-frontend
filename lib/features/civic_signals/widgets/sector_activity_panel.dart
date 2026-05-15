import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../providers.dart';
import 'civic_signal_card.dart';

/// Sector-scoped civic activity panel.
///
/// Lives on the sector landing (`/institutions/sector/:classId`) and
/// surfaces public-feed items authored by institutions in this
/// sector. Pure cross-provider derivation — `sectorActivityProvider`
/// joins the sector's institution set with the public feed; no new
/// endpoints, no fake metrics.
///
/// Collapses entirely (`SizedBox.shrink`) when:
///   * the public feed is empty
///   * none of the visible institutions in this sector have posted
///   * the provider is still loading (calm — no skeleton)
///
/// Loading / error are intentionally silent here so the rest of the
/// sector page (institution result grids) never depends on this
/// secondary signal resolving.
class SectorActivityPanel extends ConsumerWidget {
  const SectorActivityPanel({
    super.key,
    required this.classId,
    required this.classLabel,
    this.limit = 4,
  });

  /// Wire token of the sector's class (e.g., `GOVERNMENT`).
  final String classId;

  /// Display label for the section heading.
  final String classLabel;

  /// Cap on the visible signal count.
  final int limit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(sectorActivityProvider(classId));
    final signals = async.maybeWhen(
      data: (list) => list,
      orElse: () => const [],
    );
    if (signals.isEmpty) return const SizedBox.shrink();
    final shown = signals.take(limit).toList(growable: false);

    return Container(
      padding: const EdgeInsets.all(AuraSpace.s14),
      decoration: BoxDecoration(
        color: AuraSurface.subtle,
        borderRadius: BorderRadius.circular(AuraRadius.r14),
        border: Border.all(
          color: AuraSurface.divider.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                  'Recent voices in $classLabel',
                  style: AuraText.subtitle.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s4),
          Text(
            'Public posts authored by institutions in this sector.',
            style: AuraText.small.copyWith(
              color: AuraSurface.muted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AuraSpace.s12),
          for (var i = 0; i < shown.length; i++) ...[
            CivicSignalCard(signal: shown[i]),
            if (i < shown.length - 1) const SizedBox(height: AuraSpace.s8),
          ],
        ],
      ),
    );
  }
}
