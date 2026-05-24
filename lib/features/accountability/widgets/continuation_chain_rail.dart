import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/ui/substrate_chip.dart';
import '../../discourse_intelligence/models.dart';
import '../../discourse_intelligence/providers.dart';
import '../../feed/domain/feed_item.dart' show FeedRouting;

/// Continuation chain rail — renders the most-active ongoing
/// discussion as a typed chain:
///
///   [ORIGIN]  →  [N replies]  →  [M institutions involved]  →
///                                [age]  →  [resolution state]
///
/// Surfaces the continuation arc of a single `DiscourseIssue` at
/// civic altitude: enough structure to convey "this discussion has
/// continuity across institutions over time," never engagement
/// metrics or rankings. The widget reads the scoped issues
/// provider that `DiscourseContinuityPanel` is already
/// subscribing to, so there is no second fetch.
///
/// Doctrine mirror — AU-01 §6 (Discourse-intelligence aggregates)
/// + civic-memory framing in `system/governance/governance-grammar.md`
/// §7. Quiet sectors self-collapse to `SizedBox.shrink`.
class ContinuationChainRail extends ConsumerWidget {
  const ContinuationChainRail({
    super.key,
    this.institutionClass,
    this.institutionId,
  });

  final String? institutionClass;
  final String? institutionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = DiscourseScopeArgs(
      institutionClass: institutionClass,
      institutionId: institutionId,
    );
    final async = ref.watch(scopedDiscourseIssuesProvider(scope));
    final issues = async.maybeWhen(
      data: (p) => p.items,
      orElse: () => const <DiscourseIssue>[],
    );
    if (issues.isEmpty) return const SizedBox.shrink();

    // Use the issue with the most institutional reply weight as the
    // chain to render — the one where the public/institutional arc
    // is most pronounced.
    final ranked = [...issues]..sort((a, b) {
        final inst = b.institutionReplyCount.compareTo(a.institutionReplyCount);
        if (inst != 0) return inst;
        return b.replyCount.compareTo(a.replyCount);
      });
    final lead = ranked.first;

    return Container(
      padding: const EdgeInsets.all(AuraSpace.s14),
      decoration: BoxDecoration(
        color: AuraSurface.subtle,
        borderRadius: BorderRadius.circular(AuraRadius.r14),
        border: Border.all(color: AuraSurface.divider.withValues(alpha: 0.6)),
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
                  color: AuraSurface.coTeal,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: AuraSpace.s8),
              Expanded(
                child: Text(
                  'Continuation chain',
                  style: AuraText.subtitle.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'A single ongoing arc rendered as its structural chain — institutions involved, observed over time.',
            style: AuraText.micro.copyWith(
              color: AuraSurface.faint,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: AuraSpace.s10),
          if (lead.preview.isNotEmpty) ...[
            InkWell(
              onTap: () => _open(context, lead.targetRoute),
              borderRadius: BorderRadius.circular(AuraRadius.r10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  lead.preview,
                  style: AuraText.small.copyWith(
                    color: AuraSurface.ink,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(height: AuraSpace.s8),
          ],
          _ChainStrip(lead: lead),
        ],
      ),
    );
  }

  static void _open(BuildContext context, String target) {
    if (target.isEmpty) return;
    final route = FeedRouting.adaptTargetRoute(
      target,
      currentPath: GoRouterState.of(context).uri.path,
    );
    context.push(route);
  }
}

class _ChainStrip extends StatelessWidget {
  const _ChainStrip({required this.lead});
  final DiscourseIssue lead;

  String _ageLabel() {
    final d = lead.ageInDays;
    if (d <= 0) return 'today';
    if (d == 1) return '1d';
    if (d < 30) return '${d}d';
    return '${(d / 30).floor()}mo';
  }

  @override
  Widget build(BuildContext context) {
    final institutionsInvolved = lead.participatingInstitutionIds.length;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      runSpacing: 8,
      children: [
        const SubstrateChip(label: 'ORIGIN', state: SubstrateChipState.teal),
        const _ChainArrow(),
        SubstrateChip(
          label: '${lead.replyCount} ${lead.replyCount == 1 ? "reply" : "replies"}',
          state: SubstrateChipState.mist,
          dimmed: lead.replyCount == 0,
        ),
        const _ChainArrow(),
        SubstrateChip(
          label: '$institutionsInvolved '
              '${institutionsInvolved == 1 ? "institution" : "institutions"}',
          state: SubstrateChipState.teal,
          dimmed: institutionsInvolved == 0,
        ),
        const _ChainArrow(),
        SubstrateChip(
          label: lead.institutionReplyCount > 0
              ? '${lead.institutionReplyCount} institutional'
              : 'AWAITING RESPONSE',
          state: lead.institutionReplyCount > 0
              ? SubstrateChipState.verdant
              : SubstrateChipState.sun,
        ),
        const SizedBox(width: 8),
        Text(
          'AGE ${_ageLabel()}',
          style: AuraText.micro.copyWith(
            color: AuraSurface.faint,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class _ChainArrow extends StatelessWidget {
  const _ChainArrow();

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.arrow_forward_rounded,
      size: 14,
      color: AuraSurface.coTeal.withValues(alpha: 0.55),
    );
  }
}
