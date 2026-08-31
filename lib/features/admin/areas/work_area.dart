/// WORK — one list, every queue.
///
/// Aura had seven queue authorities behind seven front doors, two of which had
/// no navigation entry at all. An operator's work was whatever screen they
/// happened to open. This is the single list, oldest first, filtered by what
/// the operator can actually act on.
///
/// It is OPERATIONAL, not decorative: dense rows, aligned age, a scannable
/// left edge. Nothing here decides anything — every row hands the item back to
/// the authority that owns it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../data/operator_work.dart';
import '../shell/operator_shell.dart';
import '../ui/operator_kit.dart';

class WorkArea extends ConsumerWidget {
  const WorkArea({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(operatorWorkSummaryProvider);
    final items = ref.watch(operatorWorkListProvider);
    final filter = ref.watch(operatorWorkFilterProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= kOperatorDesktopWidth - 216;

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(operatorWorkSummaryProvider);
            ref.invalidate(operatorWorkListProvider);
            await ref.read(operatorWorkListProvider.future);
          },
          child: ListView(
            padding: EdgeInsets.all(wide ? AuraSpace.s20 : AuraSpace.s12),
            children: [
              summary.when(
                loading: () => const SizedBox(height: 40),
                error: (_, __) => const SizedBox.shrink(),
                data: (s) => _SourceFilter(summary: s, selected: filter),
              ),
              const SizedBox(height: AuraSpace.s16),
              items.when(
                loading: () => const OperatorLoading(lines: 5),
                error: (e, _) => OperatorFailure(
                  title: 'The worklist could not be loaded',
                  detail: 'Your work is not lost — this is a read failure.',
                  onRetry: () => ref.invalidate(operatorWorkListProvider),
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return OperatorClear(
                      title: filter == null
                          ? 'Nothing needs your attention'
                          : 'Nothing open in this queue',
                      detail: filter == null
                          ? 'Every queue you hold authority over is clear.'
                          : null,
                    );
                  }
                  return Column(
                    children: [
                      for (final item in list)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AuraSpace.s8),
                          child: _WorkRow(item: item, wide: wide),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _SourceFilter extends ConsumerWidget {
  const _SourceFilter({required this.summary, required this.selected});

  final OperatorWorkSummary summary;
  final String? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readable = summary.sources.where((s) => s.readable).toList();
    final degraded = summary.sources.where((s) => !s.readable).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Horizontally scrollable so a phone shows real chips rather than a
        // squeezed row — the failure the old fourteen-item bottom nav made.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _Chip(
                label: 'All',
                count: summary.totalOpen,
                selected: selected == null,
                onTap: () =>
                    ref.read(operatorWorkFilterProvider.notifier).state = null,
              ),
              for (final source in readable)
                _Chip(
                  label: source.label,
                  count: source.open,
                  selected: selected == source.source,
                  onTap: () => ref
                      .read(operatorWorkFilterProvider.notifier)
                      .state = source.source,
                ),
            ],
          ),
        ),
        if (degraded.isNotEmpty) ...[
          const SizedBox(height: AuraSpace.s10),
          OperatorFailure(
            title: '${degraded.length} '
                'queue${degraded.length == 1 ? '' : 's'} unavailable',
            detail: '${degraded.map((d) => d.label).join(', ')} could not be '
                'read. Counts exclude them rather than showing zero.',
            onRetry: () => ref.invalidate(operatorWorkSummaryProvider),
          ),
        ],
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AuraSpace.s8),
      child: Semantics(
        selected: selected,
        button: true,
        label: '$label, $count open',
        child: Material(
          color: selected ? AuraSurface.accentSoft : AuraSurface.card,
          borderRadius: BorderRadius.circular(AuraRadius.pill),
          child: InkWell(
            borderRadius: BorderRadius.circular(AuraRadius.pill),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AuraSpace.s12,
                vertical: AuraSpace.s8,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected ? AuraSurface.ink : AuraSurface.muted,
                    ),
                  ),
                  const SizedBox(width: AuraSpace.s6),
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color:
                          selected ? AuraSurface.accentText : AuraSurface.faint,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _WorkRow extends StatelessWidget {
  const _WorkRow({required this.item, required this.wide});

  final OperatorWorkItem item;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    // Age drives the left edge. Scanning a worklist is scanning for what has
    // waited too long, so that signal belongs where the eye lands first.
    final edge = item.ageDays >= 14
        ? AuraSurface.dangerInk
        : item.ageDays >= 7
            ? AuraSurface.warnInk
            : AuraSurface.divider;

    return Material(
      color: AuraSurface.card,
      borderRadius: BorderRadius.circular(AuraRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AuraRadius.card),
        onTap: () => context.go(item.destination),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AuraRadius.card),
            border: Border.all(color: AuraSurface.divider),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [edge.withValues(alpha: 0.18), Colors.transparent],
              stops: const [0, 0.012],
            ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s14,
            vertical: AuraSpace.s12,
          ),
          child: wide ? _wideLayout() : _narrowLayout(),
        ),
      ),
    );
  }

  Widget _wideLayout() {
    return Row(
      children: [
        SizedBox(width: 132, child: _sourceLabel()),
        Expanded(child: _titleAndSubject()),
        const SizedBox(width: AuraSpace.s12),
        OperatorStatePill(state: item.state, tone: OperatorTone.pending),
        const SizedBox(width: AuraSpace.s16),
        SizedBox(
          width: 84,
          child: Align(
            alignment: Alignment.centerRight,
            child: OperatorAge(days: item.ageDays),
          ),
        ),
        const SizedBox(width: AuraSpace.s8),
        const Icon(Icons.chevron_right_rounded,
            size: 18, color: AuraSurface.faint),
      ],
    );
  }

  Widget _narrowLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _sourceLabel()),
            OperatorAge(days: item.ageDays, dense: true),
          ],
        ),
        const SizedBox(height: AuraSpace.s6),
        _titleAndSubject(),
        const SizedBox(height: AuraSpace.s8),
        OperatorStatePill(
          state: item.state,
          tone: OperatorTone.pending,
          dense: true,
        ),
      ],
    );
  }

  Widget _sourceLabel() {
    return Text(
      item.sourceLabel,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 11.5,
        letterSpacing: 0.4,
        fontWeight: FontWeight.w600,
        color: AuraSurface.faint,
      ),
    );
  }

  Widget _titleAndSubject() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: AuraSurface.ink,
          ),
        ),
        if (item.subjectLabel != null && item.subjectLabel!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            item.subjectLabel!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: AuraSurface.muted),
          ),
        ],
      ],
    );
  }
}
