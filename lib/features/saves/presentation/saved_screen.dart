import '../../../core/ui/aura_surface.dart';
import 'package:go_router/go_router.dart';
import '../../../core/engagement/engagement_model.dart';
import '../../../core/engagement/saved_publications.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/product/product_language.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
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
              const Expanded(
                child: Text('Saved', style: AuraText.headline),
              ),
              AuraActionPill(
                icon: Icons.refresh_rounded,
                label: 'Refresh',
                onTap: () {
                  ref.invalidate(savedPostsProvider);
                  ref.invalidate(savedPublicationsProvider);
                },
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s14),
          savedAsync.when(
            data: (raw) {
              final posts = _coercePosts(raw);

              final anyOther = (ref.watch(savedPublicationsProvider).value ??
                      const <SavedPublication>[])
                  .any((s) => s.targetType != PublicationTarget.post);
              if (posts.isEmpty && !anyOther) {
                return const AuraEmptyState(
                  title: 'Nothing saved yet',
                  body:
                      'Use the bookmark action on any work to save it for later.',
                  icon: Icons.bookmark_border_rounded,
                );
              }

              // Posts keep their full card. Everything else a person saved —
              // articles, institution posts, announcements — appears as a
              // titled entry. The alternative was to flatten posts into
              // entries too, which would have traded one incompleteness for a
              // worse reading experience.
              final others = ref
                      .watch(savedPublicationsProvider)
                      .value
                      ?.where((s) => s.targetType != PublicationTarget.post)
                      .toList() ??
                  const <SavedPublication>[];

              return Column(
                children: [
                  for (final s in others)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AuraSpace.s10),
                      child: _SavedEntry(entry: s),
                    ),
                  for (final p in posts)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AuraSpace.s10),
                      child: PostCard(post: p, compact: false),
                    ),
                ],
              );
            },
            loading: () => const AuraLoadingState(message: 'Loading saved…'),
            error: (e, _) => AuraErrorState(
              title: 'Could not load saved work',
              body: 'Your saved posts could not be retrieved right now.',
              action: AuraSecondaryButton(
                label: ProductLabels.of(ProductAction.retry),
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

/// A saved publication that is not a post.
///
/// Deliberately compact and uniform: the reader is scanning a list of things
/// they kept, and the kind matters as much as the title for telling them apart.
class _SavedEntry extends StatelessWidget {
  const _SavedEntry({required this.entry});

  final SavedPublication entry;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: entry.route != null,
      label: '${entry.kindLabel}: ${entry.title}',
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: entry.route == null ? null : () => context.push(entry.route!),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AuraSpace.s14),
          decoration: BoxDecoration(
            color: AuraSurface.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AuraSurface.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.kindLabel.toUpperCase(),
                style: AuraText.micro.copyWith(
                  color: AuraSurface.muted,
                  letterSpacing: 0.08,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                entry.title,
                style: AuraText.body.copyWith(
                  color: AuraSurface.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if ((entry.subtitle ?? '').isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  entry.subtitle!,
                  style: AuraText.small.copyWith(color: AuraSurface.muted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
