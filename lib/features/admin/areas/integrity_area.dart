/// INTEGRITY — moderation, appeals, media custody and communication
/// governance, as one operator responsibility.
///
/// These were four separate front doors, two of them unreachable from
/// navigation. They are still four authorities and stay that way; what changes
/// is that an operator meets them as one job.
///
/// COMMUNICATION IS GOVERNED HERE, NOT PERFORMED HERE. Composition, drafting
/// and audience belong to the communication authority. Admin approves, sends
/// where authorised, and surfaces the resulting work. The console will not
/// become a newsletter tool again.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../data/operator_work.dart';
import '../domain/operator_authority_provider.dart';
import '../domain/operator_capability.dart';
import '../ui/operator_kit.dart';

/// The queue sources that belong to INTEGRITY, in the order an operator would
/// work them: conduct first, then appeals against it, then what people told us.
const _integritySources = <String, ({String label, IconData icon, String needs})>{
  'MODERATION': (
    label: 'Moderation',
    icon: Icons.flag_rounded,
    needs: 'moderation',
  ),
  'MEDIA_APPEAL': (
    label: 'Media appeals',
    icon: Icons.gavel_rounded,
    needs: 'moderation',
  ),
  'PRODUCT_FEEDBACK': (
    label: 'Product feedback',
    icon: Icons.rate_review_rounded,
    needs: 'product feedback',
  ),
  'SUPPORT': (
    label: 'Support',
    icon: Icons.support_agent_rounded,
    needs: 'support',
  ),
};

class IntegrityArea extends ConsumerWidget {
  const IntegrityArea({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authority = ref.watch(operatorAuthorityProvider).valueOrNull ??
        const OperatorAuthority.none();
    final summary = ref.watch(operatorWorkSummaryProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        return ListView(
          padding: EdgeInsets.all(wide ? AuraSpace.s20 : AuraSpace.s12),
          children: [
            OperatorSection(
              title: 'Conduct and custody',
              subtitle: 'Reports, appeals and what people have told us',
              child: summary.when(
                loading: () => const OperatorLoading(lines: 3),
                error: (e, _) => OperatorFailure(
                  title: 'Integrity queues could not be read',
                  onRetry: () =>
                      ref.invalidate(operatorWorkSummaryProvider),
                ),
                data: (s) {
                  final rows = <Widget>[];
                  for (final entry in _integritySources.entries) {
                    final source = s.sources
                        .where((x) => x.source == entry.key)
                        .toList();
                    if (source.isEmpty) continue; // not readable by this operator
                    rows.add(Padding(
                      padding: const EdgeInsets.only(bottom: AuraSpace.s8),
                      child: _QueueTile(
                        label: entry.value.label,
                        icon: entry.value.icon,
                        summary: source.first,
                      ),
                    ));
                  }
                  if (rows.isEmpty) {
                    return const OperatorInsufficientCapability(
                      needs: 'moderation, feedback or support',
                    );
                  }
                  return Column(children: rows);
                },
              ),
            ),
            const SizedBox(height: AuraSpace.s24),
            _CommunicationGovernance(authority: authority),
          ],
        );
      },
    );
  }
}

class _QueueTile extends StatelessWidget {
  const _QueueTile({
    required this.label,
    required this.icon,
    required this.summary,
  });

  final String label;
  final IconData icon;
  final OperatorWorkSourceSummary summary;

  @override
  Widget build(BuildContext context) {
    if (!summary.readable) {
      return OperatorFailure(
        title: '$label is unavailable',
        detail: 'Reported as unavailable rather than as an empty queue.',
      );
    }

    final oldest = summary.oldestAgeDays ?? 0;
    return Material(
      color: AuraSurface.card,
      borderRadius: BorderRadius.circular(AuraRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AuraRadius.card),
        onTap: () => context.go(summary.destination),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AuraRadius.card),
            border: Border.all(color: AuraSurface.divider),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s16,
            vertical: AuraSpace.s14,
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AuraSurface.muted),
              const SizedBox(width: AuraSpace.s14),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AuraSurface.ink,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (summary.open == 0)
                const Text(
                  'clear',
                  style: TextStyle(color: AuraSurface.goodInk, fontSize: 12.5),
                )
              else ...[
                Text(
                  '${summary.open}',
                  style: TextStyle(
                    fontSize: 18,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    color: oldest >= 14
                        ? AuraSurface.dangerInk
                        : oldest >= 7
                            ? AuraSurface.warnInk
                            : AuraSurface.ink,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: AuraSpace.s12),
                SizedBox(
                  width: 76,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: OperatorAge(days: oldest),
                  ),
                ),
              ],
              const SizedBox(width: AuraSpace.s8),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: AuraSurface.faint),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommunicationGovernance extends StatelessWidget {
  const _CommunicationGovernance({required this.authority});

  final OperatorAuthority authority;

  @override
  Widget build(BuildContext context) {
    final canRead = authority.can(OperatorCapability.communicationsRead);
    if (!canRead) {
      return const OperatorSection(
        title: 'Communication governance',
        child: OperatorInsufficientCapability(needs: 'communications'),
      );
    }

    final canApprove = authority.can(OperatorCapability.communicationsApprove);
    final canSend = authority.can(OperatorCapability.communicationsSend);

    return OperatorSection(
      title: 'Communication governance',
      subtitle: 'Admin governs outbound communication. It does not compose it.',
      child: OperatorPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Drafting, audience and delivery belong to the communication '
              'authority. What lives here is the decision to approve and the '
              'decision to send — and the record of who made them.',
              style: TextStyle(
                color: AuraSurface.muted,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: AuraSpace.s14),
            Wrap(
              spacing: AuraSpace.s8,
              runSpacing: AuraSpace.s8,
              children: [
                _AuthorityChip(
                  label: 'Read',
                  held: canRead,
                ),
                _AuthorityChip(
                  label: 'Approve',
                  held: canApprove,
                ),
                _AuthorityChip(
                  label: 'Send',
                  held: canSend,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows which of the four communication scopes this operator holds.
///
/// The separation between READ, WRITE, APPROVE and SEND is deliberate — one
/// person drafting and another sending is the point — so the console states
/// which of them you are rather than hiding the distinction behind an
/// enabled or disabled button.
class _AuthorityChip extends StatelessWidget {
  const _AuthorityChip({required this.label, required this.held});

  final String label;
  final bool held;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s10,
        vertical: AuraSpace.s6,
      ),
      decoration: BoxDecoration(
        color: held ? AuraSurface.goodBg : AuraSurface.elevated,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            held ? Icons.check_rounded : Icons.remove_rounded,
            size: 13,
            color: held ? AuraSurface.goodInk : AuraSurface.faint,
          ),
          const SizedBox(width: AuraSpace.s6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: held ? AuraSurface.goodInk : AuraSurface.faint,
            ),
          ),
        ],
      ),
    );
  }
}
