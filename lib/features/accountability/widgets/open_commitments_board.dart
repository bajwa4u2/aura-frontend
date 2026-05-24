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

/// Open commitments board — renders the explicit AU-01 formula
///
///   openCommitments = commitments − resolvedDistinct
///
/// per institution, sorted by open-commitment count descending so
/// the institutions with the longest outstanding accountability
/// chain surface first. The board composes data already loaded by
/// `accountabilityTrailProvider`; it makes no new requests.
///
/// Each row carries a SubstrateChip for the open count, plus
/// secondary chips for updates and resolutions so the reader can
/// see "open / in-flight / closed" together. Self-collapses when
/// every institution has zero open commitments.
///
/// Doctrine mirror — AU-01 §5 (Accountability lifecycle). Calm,
/// civic register — observational, never a ranking. Rows with
/// resolved == commitments dim because the chain is closed.
class OpenCommitmentsBoard extends ConsumerWidget {
  const OpenCommitmentsBoard({super.key, this.limit = 10});

  final int limit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(accountabilityTrailProvider);
    final page = async.maybeWhen(data: (p) => p, orElse: () => null);
    if (page == null || page.items.isEmpty) return const SizedBox.shrink();

    final ranked = [...page.items]..sort((a, b) {
        final ao = a.commitments - a.resolved;
        final bo = b.commitments - b.resolved;
        if (bo != ao) return bo.compareTo(ao);
        return b.updates.compareTo(a.updates);
      });
    final visible = ranked.where((r) => r.commitments > 0).take(limit).toList(
          growable: false,
        );
    if (visible.isEmpty) return const SizedBox.shrink();

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
            crossAxisAlignment: CrossAxisAlignment.center,
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
                  'Open commitments',
                  style: AuraText.subtitle.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Per-institution open = commitments − resolved. Observational, never a ranking.',
            style: AuraText.micro.copyWith(
              color: AuraSurface.faint,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: AuraSpace.s10),
          for (var i = 0; i < visible.length; i++) ...[
            _Row(row: visible[i]),
            if (i < visible.length - 1) const SizedBox(height: AuraSpace.s8),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.row});
  final AccountabilityRow row;

  String _oldestLabel() {
    final at = row.oldestCommitmentAt;
    if (at == null) return '';
    final diff = DateTime.now().difference(at);
    if (diff.inDays < 1) return 'today';
    if (diff.inDays == 1) return '1 day';
    if (diff.inDays < 7) return '${diff.inDays} days';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w';
    return '${(diff.inDays / 30).floor()}mo';
  }

  @override
  Widget build(BuildContext context) {
    final open = row.commitments - row.resolved;
    final closed = open <= 0;
    final oldest = _oldestLabel();
    return InkWell(
      borderRadius: BorderRadius.circular(AuraRadius.r10),
      onTap: row.institutionSlug.isEmpty
          ? null
          : () => context.push('/institutions/${row.institutionSlug}'),
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AuraSpace.s10,
          AuraSpace.s8,
          AuraSpace.s10,
          AuraSpace.s8,
        ),
        decoration: BoxDecoration(
          color: AuraSurface.card,
          borderRadius: BorderRadius.circular(AuraRadius.r10),
          border: Border.all(color: AuraSurface.divider.withValues(alpha: 0.6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    row.institutionName.isEmpty
                        ? 'Institution'
                        : row.institutionName,
                    style: AuraText.small.copyWith(
                      color: AuraSurface.ink,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (oldest.isNotEmpty && !closed) ...[
                  Text(
                    'oldest $oldest',
                    style: AuraText.micro.copyWith(
                      color: AuraSurface.faint,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                SubstrateChip(
                  label: closed
                      ? '${row.commitments} closed'
                      : '$open open',
                  state: closed
                      ? SubstrateChipState.verdant
                      : SubstrateChipState.teal,
                  dimmed: closed,
                ),
                if (row.updates > 0)
                  SubstrateChip(
                    label: '${row.updates} update${row.updates == 1 ? '' : 's'}',
                    state: SubstrateChipState.sun,
                  ),
                if (row.resolved > 0)
                  SubstrateChip(
                    label: '${row.resolved} resolved',
                    state: SubstrateChipState.verdant,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
