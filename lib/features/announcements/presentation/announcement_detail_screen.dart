import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/ui/aura_text_block.dart';
import '../providers.dart';

class AnnouncementDetailScreen extends ConsumerWidget {
  const AnnouncementDetailScreen({super.key, required this.slug});
  final String slug;

  String _fmtDate(DateTime dt) {
    final d = dt.toLocal();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(announcementBySlugProvider(slug));

    return AuraScaffold(
      title: 'Announcement',
      showHomeAction: true,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (a) {
          if (a == null) {
            return const Center(child: Text('Not found'));
          }

          final title = a.title.isEmpty ? a.slug : a.title;
          final summary = a.summary.trim();
          final body = a.bodyMarkdown.trim();

          return ListView(
            padding: const EdgeInsets.all(AuraSpace.s16),
            children: [
              AuraCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AuraTextBlock(
                      title,
                      style: AuraText.h1,
                    ),
                    const SizedBox(height: AuraSpace.s8),
                    if (a.publishedAt != null)
                      Text(
                        'Published: ${_fmtDate(a.publishedAt!)}',
                        style: AuraText.small,
                      ),
                    if (summary.isNotEmpty) ...[
                      const SizedBox(height: AuraSpace.s12),
                      AuraTextBlock(
                        summary,
                        style: AuraText.body.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (body.isNotEmpty) ...[
                      const SizedBox(height: AuraSpace.s16),
                      AuraTextBlock(
                        body,
                        style: AuraText.body,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
