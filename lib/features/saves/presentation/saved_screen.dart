import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../feed/domain/post.dart';
import '../../posts/presentation/widgets/post_card.dart';
import '../providers.dart';

List<Post> _coercePosts(dynamic raw) {
  if (raw is List<Post>) return raw;

  if (raw is List) {
    final out = <Post>[];
    for (final item in raw) {
      if (item is Post) {
        out.add(item);
        continue;
      }
      if (item is Map) {
        out.add(Post.fromJson(Map<String, dynamic>.from(item)));
        continue;
      }
    }
    return out;
  }

  return const <Post>[];
}

class SavedScreen extends ConsumerWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedAsync = ref.watch(savedPostsProvider);

    return AuraScaffold(
      showHeader: false,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AuraSpace.s16,
          AuraSpace.s20,
          AuraSpace.s16,
          AuraSpace.s32,
        ),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Saved', style: AuraText.headline),
                    const SizedBox(height: AuraSpace.s4),
                    Text(
                      'Work you chose to keep. Stays private.',
                      style: AuraText.small.copyWith(color: AuraSurface.muted),
                    ),
                  ],
                ),
              ),
              AuraActionPill(
                icon: Icons.refresh_rounded,
                label: 'Refresh',
                onTap: () => ref.invalidate(savedPostsProvider),
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s24),
          savedAsync.when(
            data: (raw) {
              final posts = _coercePosts(raw);

              if (posts.isEmpty) {
                return const AuraEmptyState(
                  title: 'Nothing saved yet',
                  body:
                      'Use the bookmark action on any work to save it for later.',
                  icon: Icons.bookmark_border_rounded,
                );
              }

              return Column(
                children: posts
                    .map(
                      (p) => Padding(
                        padding: const EdgeInsets.only(bottom: AuraSpace.s10),
                        child: PostCard(post: p, compact: false),
                      ),
                    )
                    .toList(),
              );
            },
            loading: () => const AuraLoadingState(message: 'Loading saved…'),
            error: (e, _) => AuraErrorState(
              title: 'Could not load saved work',
              body: 'Your saved posts could not be retrieved right now.',
              action: AuraSecondaryButton(
                label: 'Try again',
                onPressed: () => ref.invalidate(savedPostsProvider),
                icon: Icons.refresh_rounded,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
