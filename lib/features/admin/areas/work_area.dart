/// WORK — the operator's workbench.
///
/// Aura has seven authorities that produce human decisions. Before this they
/// had seven front doors, two of which no navigation entry pointed at, and an
/// operator's work was whatever screen they happened to open.
///
/// This is not a wrapper around those seven queues. It is one bench: every
/// item, normalized enough to answer the questions an operator asks before
/// opening anything —
///
///   WHAT IS THIS?          the title, in the authority's own words
///   WHY IS IT HERE?        the queue it came from
///   WHO DOES IT CONCERN?   the subject, named
///   HOW OLD IS IT?         days waited, never a deadline
///   WHAT STATE IS IT IN?   the record's own state word
///   WHAT HAPPENS IF I OPEN IT?  the destination, before the tap
///
/// PARTIAL IS A FIRST-CLASS RESULT. One authority failing used to blank this
/// whole screen. Now the items that arrived are shown, the queues that did not
/// answer are named, and the operator is told the list is incomplete — because
/// six queues presented as seven is how real work gets missed.
///
/// NOTHING HERE DECIDES ANYTHING. Every row hands the item back to the
/// authority that owns it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../data/operator_work.dart';
import '../domain/operator_signal.dart';
import '../ui/operator_kit.dart';
import '../ui/operator_states.dart';

class WorkArea extends ConsumerWidget {
  const WorkArea({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(operatorWorkSummaryProvider);
    final list = ref.watch(operatorWorkListProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final pad = wide ? AuraSpace.s20 : AuraSpace.s12;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // THE BENCH'S OWN CHROME. The filter is not scrolled away with the
            // items: an operator working a long queue needs to change source
            // without scrolling back to the top.
            Padding(
              padding: EdgeInsets.fromLTRB(pad, pad, pad, AuraSpace.s8),
              child: summary.maybeWhen(
                orElse: () => const SizedBox(height: 36),
                data: (signal) => signal.hasValue
                    ? _SourceBar(summary: signal.value as OperatorWorkSummary)
                    : const SizedBox(height: 36),
              ),
            ),
            Expanded(
              child: list.when(
                loading: () => Padding(
                  padding: EdgeInsets.all(pad),
                  child: const OperatorLoading(lines: 5),
                ),
                error: (_, __) => Padding(
                  padding: EdgeInsets.all(pad),
                  child: OperatorFailure(
                    title: 'The worklist could not be loaded',
                    detail: 'Your work is not lost — this is a read failure.',
                    onRetry: () => ref.invalidate(operatorWorkListProvider),
                  ),
                ),
                data: (signal) => _Bench(
                  signal: signal,
                  padding: pad,
                  onRetry: () => ref.invalidate(operatorWorkListProvider),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Which queues exist, how much is in each, and which are not answering.
///
/// A source that failed is shown DISABLED with its reason, not hidden. Hiding
/// it would leave an operator believing they had seen everything.
class _SourceBar extends ConsumerWidget {
  const _SourceBar({required this.summary});

  final OperatorWorkSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(operatorWorkFilterProvider);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _SourceChip(
            label: 'All',
            count: summary.totalOpen,
            selected: selected == null,
            onTap: () =>
                ref.read(operatorWorkFilterProvider.notifier).state = null,
          ),
          for (final source in summary.sources)
            Padding(
              padding: const EdgeInsets.only(left: AuraSpace.s8),
              child: _SourceChip(
                label: source.label,
                count: source.readable ? source.open : null,
                selected: selected == source.source,
                unavailableReason:
                    source.readable ? null : source.unavailableReason,
                onTap: source.readable
                    ? () => ref
                        .read(operatorWorkFilterProvider.notifier)
                        .state = source.source
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}

class _SourceChip extends StatelessWidget {
  const _SourceChip({
    required this.label,
    required this.selected,
    this.count,
    this.onTap,
    this.unavailableReason,
  });

  final String label;
  final bool selected;

  /// Null when this source did not answer — the count is then unknown, and an
  /// unknown count must never be drawn as zero.
  final int? count;

  final VoidCallback? onTap;
  final String? unavailableReason;

  @override
  Widget build(BuildContext context) {
    final unavailable = unavailableReason != null;

    return Tooltip(
      message: unavailable
          ? '$label ${describeUnavailable(unavailableReason)}'
          : '',
      child: Material(
        color: selected ? AuraSurface.elevated : AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        child: InkWell(
          borderRadius: BorderRadius.circular(AuraRadius.pill),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AuraSpace.s14,
              vertical: AuraSpace.s8,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AuraRadius.pill),
              border: Border.all(
                color: selected ? AuraSurface.accent : AuraSurface.divider,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (unavailable) ...[
                  const Icon(Icons.cloud_off_rounded,
                      size: 13, color: AuraSurface.dangerInk),
                  const SizedBox(width: AuraSpace.s6),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: unavailable
                        ? AuraSurface.faint
                        : (selected ? AuraSurface.ink : AuraSurface.muted),
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                const SizedBox(width: AuraSpace.s8),
                Text(
                  // An em dash, not 0. The count is not known.
                  count == null ? '—' : '$count',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: unavailable ? AuraSurface.faint : AuraSurface.faint,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _Bench extends StatelessWidget {
  const _Bench({
    required this.signal,
    required this.padding,
    required this.onRetry,
  });

  final OperatorSignal<OperatorWorklist> signal;
  final double padding;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (!signal.hasValue) {
      return Padding(
        padding: EdgeInsets.all(padding),
        child: OperatorSignalView<OperatorWorklist>(
          signal: signal,
          subject: 'the worklist',
          // A CLAUSE CANNOT FILL A NOUN SLOT. This produced, live:
          // "You do not hold a queue you can work authority."
          unauthorizedSentence: 'You do not hold any queue you can work. '
              'An operator who does can act on this.',
          onRetry: onRetry,
          builder: (_, __) => const SizedBox.shrink(),
        ),
      );
    }

    final worklist = signal.value as OperatorWorklist;
    final disclosure = OperatorDisclosure.forSignal(
      signal,
      subject: 'the worklist',
      onRetry: onRetry,
    );

    if (worklist.items.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (disclosure != null) ...[
              disclosure,
              const SizedBox(height: AuraSpace.s12),
            ],
            OperatorPanel(
              child: OperatorClear(
                title: worklist.complete
                    ? 'Nothing is waiting'
                    : 'Nothing is waiting in the queues that answered',
                detail: worklist.complete
                    ? 'Every queue you can work is clear.'
                    : null,
                icon: Icons.check_circle_outline_rounded,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(padding, 0, padding, AuraSpace.s32),
      // One extra row for the disclosure, when there is one.
      itemCount: worklist.items.length + (disclosure == null ? 0 : 1),
      itemBuilder: (context, index) {
        if (disclosure != null && index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AuraSpace.s12),
            child: disclosure,
          );
        }
        final item =
            worklist.items[disclosure == null ? index : index - 1];
        return Padding(
          padding: const EdgeInsets.only(bottom: AuraSpace.s8),
          child: _WorkRow(item: item),
        );
      },
    );
  }
}

/// One piece of work, answering every question before it is opened.
class _WorkRow extends StatelessWidget {
  const _WorkRow({required this.item});

  final OperatorWorkItem item;

  @override
  Widget build(BuildContext context) {
    final tone = item.ageDays >= 14
        ? OperatorTone.danger
        : item.ageDays >= 7
            ? OperatorTone.warn
            : OperatorTone.neutral;

    return Material(
      color: AuraSurface.card,
      borderRadius: BorderRadius.circular(AuraRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AuraRadius.card),
        onTap: () => context.go(item.destination),
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AuraSpace.s16,
                AuraSpace.s12,
                AuraSpace.s14,
                AuraSpace.s12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // WHY IT IS HERE, first and quietest: the operator is
                      // scanning for the kind of judgement being asked of them.
                      Expanded(
                        child: Text(
                          item.sourceLabel,
                          style: const TextStyle(
                            color: AuraSurface.faint,
                            fontSize: 11,
                            letterSpacing: 0.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      OperatorAge(days: item.ageDays, dense: true),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // WHAT IT IS.
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AuraSurface.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      // WHO IT CONCERNS.
                      if (item.subjectLabel != null &&
                          item.subjectLabel!.isNotEmpty) ...[
                        Icon(
                          switch (item.subjectKind) {
                            WorkSubjectKind.person => Icons.person_outline,
                            WorkSubjectKind.institution =>
                              Icons.apartment_rounded,
                            WorkSubjectKind.media => Icons.perm_media_outlined,
                            WorkSubjectKind.content => Icons.article_outlined,
                            WorkSubjectKind.unknown => Icons.circle_outlined,
                          },
                          size: 13,
                          color: AuraSurface.faint,
                        ),
                        const SizedBox(width: AuraSpace.s6),
                        Flexible(
                          child: Text(
                            item.subjectLabel!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AuraSurface.muted,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: AuraSpace.s10),
                      ],
                      // WHAT STATE IT IS IN — the authority's own word.
                      if (item.state.isNotEmpty)
                        OperatorStatePill(state: item.state, dense: true),
                    ],
                  ),
                ],
              ),
            ),
            if (tone != OperatorTone.neutral)
              Positioned(
                left: 0,
                top: AuraSpace.s10,
                bottom: AuraSpace.s10,
                child: Container(
                  width: 3,
                  decoration: BoxDecoration(
                    color: tone.ink,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
