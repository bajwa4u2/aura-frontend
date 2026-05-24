import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/ui/substrate_chip.dart';
import '../models.dart';
import '../providers.dart';

/// Institutional response history strip — a horizontal civic-tone
/// strip of institutions that have observably responded in the
/// scope (sector / institution). Each chip carries the observed
/// reply count and last-responded recency, anchored by a
/// `SubstrateChip` in canonical teal.
///
/// Composes data already loaded by `responsivenessProvider`; this
/// widget makes no new requests. Self-collapses when the provider
/// returns zero rows so a quiet scope renders no chrome.
///
/// Doctrine mirror — AU-01 §6 (Discourse-intelligence aggregates).
/// Observational, not a ranking — copy is deliberately calm and
/// avoids "top", "best", "leading" framing.
class InstitutionalResponseHistoryStrip extends ConsumerWidget {
  const InstitutionalResponseHistoryStrip({
    super.key,
    this.institutionClass,
    this.institutionId,
    this.limit = 12,
  });

  final String? institutionClass;
  final String? institutionId;
  final int limit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = DiscourseScopeArgs(
      institutionClass: institutionClass,
      institutionId: institutionId,
    );
    final async = ref.watch(responsivenessProvider(scope));
    final rows = async.maybeWhen(
      data: (p) => p.items,
      orElse: () => const <ResponsivenessRow>[],
    );
    final visible = rows.where((r) => r.recentResponseCount > 0).toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    final shown = visible.take(limit).toList(growable: false);

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.s14,
        AuraSpace.s12,
        AuraSpace.s14,
        AuraSpace.s12,
      ),
      decoration: BoxDecoration(
        color: AuraSurface.subtle,
        borderRadius: BorderRadius.circular(AuraRadius.r14),
        border: Border.all(color: AuraSurface.divider.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'INSTITUTIONAL RESPONSE HISTORY',
            style: AuraText.micro.copyWith(
              color: AuraSurface.muted,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Recent observed replies by institution. Observational, not a ranking.',
            style: AuraText.micro.copyWith(
              color: AuraSurface.faint,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: AuraSpace.s10),
          SizedBox(
            height: 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              itemCount: shown.length,
              separatorBuilder: (_, __) => const SizedBox(width: AuraSpace.s8),
              itemBuilder: (_, i) => _HistoryTile(row: shown[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.row});
  final ResponsivenessRow row;

  String _lastLabel() {
    final at = row.lastRespondedAt;
    if (at == null) return '';
    final diff = DateTime.now().difference(at);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${(diff.inDays / 7).floor()}w';
  }

  @override
  Widget build(BuildContext context) {
    final last = _lastLabel();
    return Material(
      color: AuraSurface.card,
      borderRadius: BorderRadius.circular(AuraRadius.r10),
      child: InkWell(
        borderRadius: BorderRadius.circular(AuraRadius.r10),
        onTap: row.institutionSlug.isEmpty
            ? null
            : () => context.push('/institutions/${row.institutionSlug}'),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s10,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AuraRadius.r10),
            border: Border.all(
              color: AuraSurface.divider.withValues(alpha: 0.6),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
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
                  if (row.verified) ...[
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.verified_rounded,
                      size: 11,
                      color: AuraSurface.accentText,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SubstrateChip(
                    label: '${row.recentResponseCount} '
                        '${row.recentResponseCount == 1 ? "reply" : "replies"}',
                    state: SubstrateChipState.teal,
                  ),
                  if (last.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Text(
                      'last $last',
                      style: AuraText.micro.copyWith(
                        color: AuraSurface.faint,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
