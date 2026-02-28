import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';
import '../providers.dart';

class AnnouncementDetailScreen extends ConsumerWidget {
  const AnnouncementDetailScreen({super.key, required this.slug});
  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(announcementBySlugProvider(slug));

    return AuraScaffold(
      title: 'Announcement',
      showHomeAction: true,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: AuraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Failed to load', style: AuraText.title),
                  const SizedBox(height: AuraSpace.s10),
                  Text(e.toString(), style: AuraText.body),
                ],
              ),
            ),
          ),
        ),
        data: (a) {
          if (a == null) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: AuraCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Not found', style: AuraText.title),
                      const SizedBox(height: AuraSpace.s10),
                      Text('This announcement does not exist.', style: AuraText.body),
                    ],
                  ),
                ),
              ),
            );
          }

          final title = a.title.isEmpty ? a.slug : a.title;

          return ListView(
            padding: const EdgeInsets.fromLTRB(AuraSpace.s16, AuraSpace.s12, AuraSpace.s16, AuraSpace.s24),
            children: [
              AuraCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AuraText.h1),
                    const SizedBox(height: AuraSpace.s10),
                    if (a.publishedAt != null)
                      Text('Published: ${a.publishedAt!.toLocal()}', style: AuraText.small),
                    const SizedBox(height: AuraSpace.s14),
                    Text(a.body, style: AuraText.body),
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
