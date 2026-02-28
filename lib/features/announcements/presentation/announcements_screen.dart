import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';
import '../providers.dart';

class AnnouncementsScreen extends ConsumerWidget {
  const AnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pinnedAsync = ref.watch(pinnedAnnouncementsProvider);
    final listAsync = ref.watch(announcementsProvider);

    return AuraScaffold(
      title: 'Announcements',
      showHomeAction: true,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AuraSpace.s16, AuraSpace.s12, AuraSpace.s16, AuraSpace.s24),
        children: [
          Text(
            'Official notes from Aura.',
            style: AuraText.body,
          ),
          const SizedBox(height: AuraSpace.s12),
          pinnedAsync.when(
            loading: () => const _LoadingCard(label: 'Loading pinned…'),
            error: (e, _) => _ErrorCard(error: e),
            data: (items) {
              if (items.isEmpty) return const SizedBox.shrink();
              return AuraCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pinned', style: AuraText.title),
                    const SizedBox(height: AuraSpace.s10),
                    for (final a in items) ...[
                      _AnnouncementRow(
                        title: a.title.isEmpty ? a.slug : a.title,
                        subtitle: a.publishedAt == null ? null : a.publishedAt!.toLocal().toString(),
                        onTap: () => context.go('/announcements/${a.slug}'),
                      ),
                      const SizedBox(height: AuraSpace.s8),
                    ],
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: AuraSpace.s12),
          listAsync.when(
            loading: () => const _LoadingCard(label: 'Loading announcements…'),
            error: (e, _) => _ErrorCard(error: e),
            data: (items) {
              if (items.isEmpty) {
                return AuraCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Nothing yet', style: AuraText.title),
                      const SizedBox(height: AuraSpace.s10),
                      Text('When Aura publishes official notices, they will appear here.', style: AuraText.body),
                    ],
                  ),
                );
              }

              return AuraCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('All', style: AuraText.title),
                    const SizedBox(height: AuraSpace.s10),
                    for (final a in items) ...[
                      _AnnouncementRow(
                        title: a.title.isEmpty ? a.slug : a.title,
                        subtitle: a.publishedAt == null ? null : a.publishedAt!.toLocal().toString(),
                        onTap: () => context.go('/announcements/${a.slug}'),
                      ),
                      const SizedBox(height: AuraSpace.s8),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AnnouncementRow extends StatelessWidget {
  const _AnnouncementRow({
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Row(
          children: [
            const Icon(Icons.campaign_outlined, size: 18),
            const SizedBox(width: AuraSpace.s10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AuraText.body.copyWith(fontWeight: FontWeight.w600)),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: AuraText.small),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18),
          ],
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    return AuraCard(
      child: Row(
        children: [
          const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: AuraSpace.s10),
          Text(label, style: AuraText.body),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.error});
  final Object error;
  @override
  Widget build(BuildContext context) {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Failed to load', style: AuraText.title),
          const SizedBox(height: AuraSpace.s10),
          Text(error.toString(), style: AuraText.body),
        ],
      ),
    );
  }
}
