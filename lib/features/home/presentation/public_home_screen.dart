import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';
import '../../feed/providers.dart';
import '../../feed/domain/post.dart';

class PublicHomeScreen extends ConsumerWidget {
  const PublicHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(feedProvider);

    return AuraScaffold(
      title: 'Aura',
      // No header actions here. Invitation should unfold from the content.
      actions: const [],
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AuraSpace.s16, AuraSpace.s16, AuraSpace.s16, AuraSpace.s24),
        children: [
          AuraCard(
            padding: const EdgeInsets.all(AuraSpace.s20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'A civic layer for accountability and alignment.',
                  style: AuraText.title,
                ),
                const SizedBox(height: AuraSpace.s10),
                Text(
                  'Aura is built to help people and institutions speak in a way that can be checked, carried, and returned to. '
                  'Not influence. Not spectacle. Just durable record and responsible exchange.',
                  style: AuraText.body,
                ),
              ],
            ),
          ),

          const SizedBox(height: AuraSpace.s16),

          // Public feed preview
          Text('Public record', style: AuraText.title),
          const SizedBox(height: AuraSpace.s10),
          Text(
            'Approved public posts, shown as individual entries. Tap any post to read it fully.',
            style: AuraText.muted,
          ),
          const SizedBox(height: AuraSpace.s12),

          feedAsync.when(
            data: (posts) {
              if (posts.isEmpty) {
                return AuraCard(
                  child: Text(
                    'No public posts yet. This space will open as moderation and publishing settle.',
                    style: AuraText.body,
                  ),
                );
              }

              final show = posts.take(8).toList();
              return Column(
                children: [
                  for (final p in show) ...[
                    _PublicPostPreview(post: p),
                    const SizedBox(height: AuraSpace.s10),
                  ],
                ],
              );
            },
            loading: () => const AuraCard(child: _LoadingBlock()),
            error: (e, _) => AuraCard(
              child: Text(
                'Could not load public feed yet. ($e)',
                style: AuraText.body,
              ),
            ),
          ),

          const SizedBox(height: AuraSpace.s16),

          // Invitation buttons after the feed.
          AuraCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Enter', style: AuraText.title),
                const SizedBox(height: AuraSpace.s10),
                Text(
                  'Create an account to publish, follow, and participate. Institutions will join as verified participants.',
                  style: AuraText.body,
                ),
                const SizedBox(height: AuraSpace.s16),
                Wrap(
                  spacing: AuraSpace.s10,
                  runSpacing: AuraSpace.s10,
                  children: [
                    OutlinedButton(
                      onPressed: () => context.go('/login'),
                      child: const Text('Sign in'),
                    ),
                    FilledButton(
                      onPressed: () => context.go('/register'),
                      child: const Text('Create account'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: AuraSpace.s16),

          // Compact hubs (public)
          AuraCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('About', style: AuraText.title),
                const SizedBox(height: AuraSpace.s10),
                _LinkRow(label: 'Mission', onTap: () => context.go('/mission')),
                _LinkRow(label: 'Founder message', onTap: () => context.go('/founder')),
                _LinkRow(label: 'Institutions', onTap: () => context.go('/institutions')),
                _LinkRow(label: 'Investors', onTap: () => context.go('/investors')),
                _LinkRow(label: 'Privacy', onTap: () => context.go('/privacy')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PublicPostPreview extends StatelessWidget {
  const _PublicPostPreview({required this.post});
  final Post post;

  @override
  Widget build(BuildContext context) {
    final a = post.author;
    final name = (a?.displayName ?? '').trim();
    final handle = (a?.handle ?? '').trim();
    final byline = handle.isEmpty ? name : '@$handle${name.isNotEmpty ? ' • $name' : ''}';

    final text = (post.text ?? '').trim();
    final preview = text.length <= 280 ? text : '${text.substring(0, 280)}…';

    return AuraCard(
      onTap: () => context.push('/posts/${post.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (byline.isNotEmpty) ...[
            Text(byline, style: AuraText.small.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: AuraSpace.s8),
          ],
          Text(preview.isEmpty ? '—' : preview, style: AuraText.body.copyWith(height: 1.4)),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AuraSpace.s12),
        child: Row(
          children: [
            Expanded(child: Text(label, style: AuraText.body)),
            const Icon(Icons.chevron_right, size: 20),
          ],
        ),
      ),
    );
  }
}

class _LoadingBlock extends StatelessWidget {
  const _LoadingBlock();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AuraSpace.s18),
      child: Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
