import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/ui/aura_text_block.dart';
import '../../feed/domain/post.dart';
import '../../feed/providers.dart';

Map<String, dynamic> _asMap(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return Map<String, dynamic>.from(v);
  return <String, dynamic>{};
}

class PublicHomeScreen extends ConsumerWidget {
  const PublicHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final worksAsync = ref.watch(feedProvider);

    return AuraScaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AuraSpace.s16,
              AuraSpace.s16,
              AuraSpace.s16,
              AuraSpace.s24,
            ),
            children: [
              const _PublicWorksHeader(),
              const SizedBox(height: AuraSpace.s20),
              const _SectionHeader(
                title: 'Public Work',
                subtitle: 'Recent writing and creations from the network.',
              ),
              const SizedBox(height: AuraSpace.s12),
              worksAsync.when(
                data: (posts) {
                  if (posts.isEmpty) {
                    return const AuraCard(
                      child: Text(
                        'No public work yet.',
                        style: AuraText.body,
                      ),
                    );
                  }

                  final show = posts.take(6).toList();

                  return Column(
                    children: [
                      for (final p in show) ...[
                        _PublicWorkPreview(post: p),
                        const SizedBox(height: AuraSpace.s10),
                      ],
                      const SizedBox(height: AuraSpace.s6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton(
                          onPressed: () => context.go('/search'),
                          child: const Text('Explore more'),
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const AuraCard(child: _LoadingBlock()),
                error: (e, _) => AuraCard(
                  child: Text(
                    'Could not load work right now. ($e)',
                    style: AuraText.body,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PublicWorksHeader extends StatelessWidget {
  const _PublicWorksHeader();

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      padding: const EdgeInsets.all(AuraSpace.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Build a public record of work that earns real consideration',
            style: AuraText.title,
          ),
          const SizedBox(height: AuraSpace.s10),
          Text(
            'Aura is where creators publish writing and creations that can be discovered, evaluated, and taken seriously by others and institutions.',
            style: AuraText.body,
          ),
          const SizedBox(height: AuraSpace.s14),
          Text(
            'No noise. Just structured, accountable work that holds weight over time.',
            style: AuraText.small.copyWith(
              color: AuraSurface.muted,
            ),
          ),
          const SizedBox(height: AuraSpace.s16),
          Wrap(
            spacing: AuraSpace.s10,
            runSpacing: AuraSpace.s10,
            children: [
              FilledButton(
                onPressed: () => context.go('/search'),
                child: const Text('Explore Public Work'),
              ),
              OutlinedButton(
                onPressed: () => context.go('/mission'),
                child: const Text('Read Mission'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AuraText.title),
        const SizedBox(height: AuraSpace.s6),
        Text(
          subtitle,
          style: AuraText.small.copyWith(
            color: AuraSurface.muted,
          ),
        ),
      ],
    );
  }
}

class _PublicWorkPreview extends StatelessWidget {
  const _PublicWorkPreview({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    final authorMeta = _asMap(post.authorMeta);
    final authorName = (authorMeta['name'] ?? '').toString().trim();
    final handle = (authorMeta['handle'] ?? '').toString().trim();

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (authorName.isNotEmpty || handle.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: AuraSpace.s8),
              child: Text(
                authorName.isNotEmpty && handle.isNotEmpty
                    ? '$authorName · @$handle'
                    : authorName.isNotEmpty
                        ? authorName
                        : '@$handle',
                style: AuraText.small.copyWith(
                  color: AuraSurface.muted,
                ),
              ),
            ),
          AuraTextBlock(
            text: post.text,
            maxLines: 8,
          ),
          const SizedBox(height: AuraSpace.s12),
          Wrap(
            spacing: AuraSpace.s10,
            runSpacing: AuraSpace.s10,
            children: [
              OutlinedButton(
                onPressed: () => context.go('/posts/${post.id}'),
                child: const Text('Open'),
              ),
              if (handle.isNotEmpty)
                OutlinedButton(
                  onPressed: () => context.go('/u/$handle'),
                  child: const Text('View profile'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoadingBlock extends StatelessWidget {
  const _LoadingBlock();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AuraSpace.s16),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.2),
        ),
      ),
    );
  }
}
