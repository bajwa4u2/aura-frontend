import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../models.dart';
import '../providers.dart';
import 'continuity_cards.dart';

/// Horizontal strip of currently-ongoing public discussions.
/// Surfaces top items from `scopedDiscourseIssuesProvider` with no
/// scope (global). Self-collapses when the public feed has no
/// recent reply momentum. Used on `/institutions` directly under
/// the institution-voices strip; this provides discovery into the
/// civic-discourse layer without dominating the directory.
class OngoingDiscussionsStrip extends ConsumerWidget {
  const OngoingDiscussionsStrip({super.key, this.limit = 6});

  final int limit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(
      scopedDiscourseIssuesProvider(const DiscourseScopeArgs()),
    );
    final issues = async.maybeWhen(
      data: (p) => p.items,
      orElse: () => const <DiscourseIssue>[],
    );
    if (issues.isEmpty) return const SizedBox.shrink();
    final shown = issues.take(limit).toList(growable: false);

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
            Text('Ongoing public discussions', style: AuraText.title),
            const SizedBox(width: AuraSpace.s8),
            Flexible(
              child: Text(
                'Recent public posts that have drawn sustained replies.',
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
              child: OngoingIssueCard(issue: shown[i]),
            ),
          ),
        ),
      ],
    );
  }
}
