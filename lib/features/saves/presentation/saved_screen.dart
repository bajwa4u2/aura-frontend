import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';
import '../../posts/presentation/widgets/post_card.dart';
import '../providers.dart';

class SavedScreen extends ConsumerWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedAsync = ref.watch(savedPostsProvider);

    return AuraScaffold(
      title: 'Saved',
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: () => ref.invalidate(savedPostsProvider),
          icon: const Icon(Icons.refresh),
        ),
      ],
      body: ListView(
        padding: EdgeInsets.fromLTRB(AuraSpace.s16, AuraSpace.s12, AuraSpace.s16, AuraSpace.s24),
        children: [
          AuraCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Return to what you chose to keep.', style: AuraText.body.copyWith(fontWeight: FontWeight.w700)),
                SizedBox(height: AuraSpace.s6),
                Text(
                  'Saved posts stay private. No totals. No performance.',
                  style: AuraText.muted,
                ),
              ],
            ),
          ),
          SizedBox(height: AuraSpace.s12),

          savedAsync.when(
            data: (posts) {
              if (posts.isEmpty) {
                return AuraCard(
                  child: Text(
                    'Nothing saved yet. When you save a post, it will appear here.',
                    style: AuraText.body,
                  ),
                );
              }

              return Column(
                children: posts
                    .map(
                      (p) => Padding(
                        padding: EdgeInsets.only(bottom: AuraSpace.s10),
                        child: PostCard(post: p, compact: false),
                      ),
                    )
                    .toList(),
              );
            },
            loading: () => const _LoadingCard(),
            error: (e, _) => AuraCard(
              child: Text(
                'Could not load saved posts: $e',
                style: AuraText.body,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      child: Row(
        children: [
          const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: AuraSpace.s10),
          Text('Loading…', style: AuraText.body),
        ],
      ),
    );
  }
}