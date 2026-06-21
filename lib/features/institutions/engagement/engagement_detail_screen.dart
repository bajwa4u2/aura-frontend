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

class EngagementDetailScreen extends ConsumerWidget {
  const EngagementDetailScreen({
    super.key,
    required this.institutionId,
    required this.recordId,
  });

  final String institutionId;
  final String recordId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(
      engagementDetailProvider((institutionId, recordId)),
    );

    return async.when(
      loading: () => AuraScaffold(
        title: 'Public Record',
        showHomeAction: false,
        body: const Center(child: AuraLoadingState(message: 'Loading…')),
      ),
      error: (e, _) => AuraScaffold(
        title: 'Public Record',
        showHomeAction: false,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AuraSpace.s16),
            child: AuraErrorState(
              title: 'Could not load record',
              body: e.toString(),
            ),
          ),
        ),
      ),
      data: (record) => AuraScaffold(
        title: 'Public Record',
        showHomeAction: false,
        body: _DetailBody(record: record, institutionId: institutionId),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.record, required this.institutionId});

  final RoutedRecord record;
  final String institutionId;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (record.status) {
      RoutedRecordStatus.pending => const Color(0xFFE8853A),
      RoutedRecordStatus.responded => AuraSurface.accent,
      RoutedRecordStatus.committed => AuraSurface.accent,
      RoutedRecordStatus.resolved => const Color(0xFF1B8A4C),
    };

    return ListView(
      padding: const EdgeInsets.all(AuraSpace.s16),
      children: [
        // Status header
        Container(
          padding: const EdgeInsets.all(AuraSpace.s14),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(AuraRadius.card),
            border: Border.all(color: statusColor.withValues(alpha: 0.30)),
          ),
          child: Row(
            children: [
              Icon(
                switch (record.status) {
                  RoutedRecordStatus.resolved =>
                    Icons.check_circle_outline_rounded,
                  RoutedRecordStatus.pending => Icons.hourglass_empty_rounded,
                  _ => Icons.verified_outlined,
                },
                size: 20,
                color: statusColor,
              ),
              const SizedBox(width: AuraSpace.s10),
              Text(
                record.status.label,
                style: AuraText.body.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AuraSpace.s16),

        // Meta chips
        Wrap(
          spacing: AuraSpace.s8,
          runSpacing: AuraSpace.s8,
          children: [
            if (record.intent != RecordIntent.unknown)
              _MetaChip(
                icon: Icons.chat_bubble_outline_rounded,
                label: record.intent.label,
              ),
            if (record.topic != null)
              _MetaChip(
                icon: Icons.label_outline_rounded,
                label: record.topic!.label,
              ),
            if ((record.participationMode ?? '').isNotEmpty)
              _MetaChip(
                icon: Icons.domain_outlined,
                label: _modeLabel(record.participationMode),
              ),
          ],
        ),
        const SizedBox(height: AuraSpace.s20),

        // Post body
        if ((record.postBody ?? '').trim().isNotEmpty) ...[
          Text(
            'Public post',
            style: AuraText.small.copyWith(
              color: AuraSurface.muted,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: AuraSpace.s8),
          Container(
            padding: const EdgeInsets.all(AuraSpace.s14),
            decoration: BoxDecoration(
              color: AuraSurface.card,
              borderRadius: BorderRadius.circular(AuraRadius.card),
              border: Border.all(color: AuraSurface.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.postBody!.trim(),
                  style: AuraText.body.copyWith(
                    color: AuraSurface.ink,
                    height: 1.6,
                  ),
                ),
                if ((record.authorName ?? '').isNotEmpty ||
                    record.createdAt != null) ...[
                  const SizedBox(height: AuraSpace.s12),
                  Row(
                    children: [
                      if ((record.authorName ?? '').isNotEmpty) ...[
                        Text(
                          record.authorName!,
                          style: AuraText.small
                              .copyWith(color: AuraSurface.muted),
                        ),
                        const SizedBox(width: AuraSpace.s8),
                      ],
                      if (record.createdAt != null)
                        Text(
                          formatRelative(record.createdAt!),
                          style: AuraText.micro
                              .copyWith(color: AuraSurface.faint),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AuraSpace.s20),
        ],

        // Action — view original post in public thread
        if (record.postId.trim().isNotEmpty)
          OutlinedButton.icon(
            onPressed: () => context.push('/posts/${record.postId}'),
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: const Text('View original post'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AuraSurface.muted,
              side: const BorderSide(color: AuraSurface.divider),
            ),
          ),
      ],
    );
  }

  String _modeLabel(String? mode) {
    switch ((mode ?? '').toUpperCase()) {
      case 'ACCOUNTABLE':
        return 'Accountable';
      case 'RESPONDING':
        return 'Responding';
      default:
        return mode ?? '';
    }
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: AuraSurface.subtle,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AuraSurface.muted),
          const SizedBox(width: 5),
          Text(
            label,
            style: AuraText.small.copyWith(
              color: AuraSurface.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
