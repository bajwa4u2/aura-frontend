import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/utils/relative_time.dart';
import 'engagement_models.dart';
import 'engagement_providers.dart';

class EngagementListScreen extends ConsumerWidget {
  const EngagementListScreen({super.key, required this.institutionId});

  final String institutionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(engagementListProvider(institutionId));
    final summaryAsync = ref.watch(engagementSummaryProvider(institutionId));

    return AuraScaffold(
      title: 'Public Engagement',
      showHomeAction: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: 'Participation settings',
          onPressed: () => context.push(
            '/institution/$institutionId/public-engagement/participation',
          ),
        ),
      ],
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: summaryAsync.whenOrNull(
              data: (s) => s.total > 0 ? _SummaryBar(summary: s) : null,
            ) ?? const SizedBox.shrink(),
          ),
          listAsync.when(
            loading: () => const SliverFillRemaining(
              child: Center(child: AuraLoadingState(message: 'Loading…')),
            ),
            error: (e, _) => SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AuraSpace.s16),
                  child: AuraErrorState(
                    title: 'Could not load public engagement',
                    body: e.toString(),
                  ),
                ),
              ),
            ),
            data: (list) {
              if (list.isEmpty) {
                return const SliverFillRemaining(
                  child: _EmptyState(),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.all(AuraSpace.s16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) {
                      if (i.isOdd) {
                        return const SizedBox(height: AuraSpace.s12);
                      }
                      final record = list[i ~/ 2];
                      return _RecordCard(
                        record: record,
                        onTap: () => context.push(
                          '/institution/$institutionId/public-engagement/${record.id}',
                        ),
                      );
                    },
                    childCount: list.length * 2 - 1,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUMMARY BAR
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.summary});

  final EngagementSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AuraSpace.s16,
        AuraSpace.s16,
        AuraSpace.s16,
        0,
      ),
      padding: const EdgeInsets.all(AuraSpace.s14),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Row(
        children: [
          _Counter(label: 'Total', count: summary.total),
          const _Divider(),
          _Counter(
            label: 'Needs Response',
            count: summary.pending,
            urgent: summary.pending > 0,
          ),
          const _Divider(),
          _Counter(label: 'Committed', count: summary.committed),
          const _Divider(),
          _Counter(
            label: 'Resolved',
            count: summary.resolved,
            highlight: true,
          ),
        ],
      ),
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({
    required this.label,
    required this.count,
    this.urgent = false,
    this.highlight = false,
  });

  final String label;
  final int count;
  final bool urgent;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final color = urgent
        ? const Color(0xFFE8853A)
        : highlight
            ? const Color(0xFF1B8A4C)
            : AuraSurface.ink;

    return Expanded(
      child: Column(
        children: [
          Text(
            count.toString(),
            style: AuraText.title.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AuraText.micro.copyWith(
              color: AuraSurface.muted,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      color: AuraSurface.divider,
      margin: const EdgeInsets.symmetric(horizontal: AuraSpace.s8),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RECORD CARD
// ─────────────────────────────────────────────────────────────────────────────

class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.record, required this.onTap});

  final RoutedRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (record.status) {
      RoutedRecordStatus.pending => const Color(0xFFE8853A),
      RoutedRecordStatus.responded => AuraSurface.accent,
      RoutedRecordStatus.committed => AuraSurface.accent,
      RoutedRecordStatus.resolved => const Color(0xFF1B8A4C),
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AuraRadius.card),
      child: Container(
        padding: const EdgeInsets.all(AuraSpace.s14),
        decoration: BoxDecoration(
          color: AuraSurface.card,
          borderRadius: BorderRadius.circular(AuraRadius.card),
          border: Border.all(color: AuraSurface.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (record.intent != RecordIntent.unknown) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AuraSpace.s8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AuraSurface.subtle,
                      borderRadius: BorderRadius.circular(AuraRadius.pill),
                      border: Border.all(color: AuraSurface.divider),
                    ),
                    child: Text(
                      record.intent.label,
                      style: AuraText.micro.copyWith(
                        color: AuraSurface.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: AuraSpace.s8),
                ],
                if (record.topic != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AuraSpace.s8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AuraSurface.subtle,
                      borderRadius: BorderRadius.circular(AuraRadius.pill),
                      border: Border.all(color: AuraSurface.divider),
                    ),
                    child: Text(
                      record.topic!.label,
                      style: AuraText.micro.copyWith(
                        color: AuraSurface.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: AuraSpace.s8),
                ],
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AuraSpace.s8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AuraRadius.pill),
                  ),
                  child: Text(
                    record.status.label,
                    style: AuraText.micro.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if ((record.postBody ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: AuraSpace.s10),
              Text(
                record.postBody!.trim(),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: AuraText.body.copyWith(
                  color: AuraSurface.ink,
                  height: 1.5,
                ),
              ),
            ],
            const SizedBox(height: AuraSpace.s10),
            Row(
              children: [
                if ((record.authorName ?? '').trim().isNotEmpty) ...[
                  Text(
                    record.authorName!,
                    style: AuraText.small.copyWith(color: AuraSurface.muted),
                  ),
                  const SizedBox(width: AuraSpace.s8),
                ],
                if (record.createdAt != null)
                  Text(
                    formatRelative(record.createdAt!),
                    style: AuraText.micro.copyWith(color: AuraSurface.faint),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AuraSpace.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: AuraSurface.subtle,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.inbox_outlined,
                size: 24,
                color: AuraSurface.muted,
              ),
            ),
            const SizedBox(height: AuraSpace.s16),
            const Text('No public records yet', style: AuraText.title),
            const SizedBox(height: AuraSpace.s8),
            Text(
              'When members of the public raise issues or ask questions '
              'on your topics, they will appear here.',
              style: AuraText.body.copyWith(color: AuraSurface.muted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
