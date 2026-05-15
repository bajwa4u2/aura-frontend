import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../providers.dart';
import 'civic_signal_card.dart';

/// Horizontal strip of recent institutional voices on the public
/// institutions directory. Self-collapses when no institution has
/// publicly posted lately. No fake "trending" header, no fabricated
/// engagement counts — purely a calm "institutions are speaking
/// here" surface for visitors.
class InstitutionActivityStrip extends ConsumerWidget {
  const InstitutionActivityStrip({super.key, this.limit = 6});

  /// Maximum number of cards rendered. The strip caps at this even if
  /// more institution-authored items are present in the public feed.
  final int limit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(recentInstitutionalVoicesProvider);
    final signals = async.maybeWhen(
      data: (list) => list,
      orElse: () => const [],
    );
    if (signals.isEmpty) return const SizedBox.shrink();
    final shown = signals.take(limit).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 6,
              height: 18,
              decoration: BoxDecoration(
                color: AuraSurface.accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: AuraSpace.s8),
            Text('Recent institutional voices', style: AuraText.title),
            const SizedBox(width: AuraSpace.s8),
            Flexible(
              child: Text(
                'What institutions are publicly saying right now.',
                style: AuraText.small.copyWith(color: AuraSurface.muted),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: AuraSpace.s10),
        SizedBox(
          height: 168,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            itemCount: shown.length,
            separatorBuilder: (_, __) => const SizedBox(width: AuraSpace.s12),
            itemBuilder: (_, i) => SizedBox(
              width: 320,
              child: CivicSignalCard(signal: shown[i], dense: true),
            ),
          ),
        ),
      ],
    );
  }
}
