import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/product/product_state.dart';
import '../../../core/product/temporal.dart';
import '../../../core/product/product_state_view.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/ui/publication/aura_publication_markdown.dart';
import '../../conversation/presentation/conversation_identity.dart';
import '../data/articles_repository.dart';
import '../../../core/navigation/navigation_authority.dart';

/// PUBLISHED ARTICLE — the durable long-form reading experience: author
/// attribution, published time, canonical link identity (/articles/:slug),
/// body through the shared publication markdown primitive. Public by
/// doctrine (an Article is durable public thought).
class ArticleScreen extends ConsumerWidget {
  const ArticleScreen({super.key, required this.slug});
  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final articleAsync = ref.watch(articleBySlugProvider(slug));
    return AuraScaffold(
      showHeader: false,
      body: articleAsync.when(
        loading: () =>
            const AuraProductState(state: ProductState.loading),
        error: (e, _) => const AuraProductState(
          state: ProductState.unavailable,
          headline: 'Article unavailable',
          detail: 'It may have been removed, or the link may be wrong.',
        ),
        data: (article) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(AuraSpace.s20),
              children: [
                Text(article.title, style: AuraText.display),
                const SizedBox(height: AuraSpace.s12),
                Row(
                  children: [
                    AuraAvatar(
                        name: article.author?.displayName ?? '', size: 32),
                    const SizedBox(width: AuraSpace.s10),
                    Expanded(
                      child: InkWell(
                        onTap: article.author?.handle == null
                            ? null
                            : () => context
                                .push('/u/${article.author!.handle}'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(article.author?.displayName ?? 'Aura member',
                                style: AuraText.small.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AuraSurface.ink)),
                            if (article.publishedAt != null)
                              Text(
                                AuraTemporal.calendar(ProductTime(
                                        article.publishedAt!,
                                        TimeEvent.published)) +
                                    (article.revised ? ' · Edited' : ''),
                                style: AuraText.micro
                                    .copyWith(color: AuraSurface.muted),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (article.author?.userId ==
                        ref.watch(myUserIdProvider))
                      TextButton.icon(
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Edit'),
                        onPressed: () =>
                            context.push(
                                NavigationAuthority.articleEditorRoute(
                                    article.id)),
                      ),
                  ],
                ),
                const SizedBox(height: AuraSpace.s20),
                const Divider(height: 1),
                const SizedBox(height: AuraSpace.s20),
                AuraPublicationMarkdown(data: article.bodyMarkdown),
                const SizedBox(height: AuraSpace.s32),
              ],
            ),
          ),
        ),
      ),
    );
  }

}

/// DISCOVER → ARTICLES — the fourth domain, now REAL: published articles,
/// newest first, truthful empty state when none exist yet.
class ArticlesDiscoveryScreen extends ConsumerWidget {
  const ArticlesDiscoveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final articlesAsync = ref.watch(publishedArticlesProvider);
    return AuraScaffold(
      showHeader: false,
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(publishedArticlesProvider),
        child: ListView(
          padding: const EdgeInsets.all(AuraSpace.s16),
          children: [
            const Text('Articles', style: AuraText.display),
            const SizedBox(height: AuraSpace.s6),
            Text('Substantial authored thought — durable long-form writing.',
                style: AuraText.body.copyWith(color: AuraSurface.muted)),
            const SizedBox(height: AuraSpace.s16),
            articlesAsync.when(
              loading: () =>
                  const AuraProductState(state: ProductState.loading),
              error: (e, _) => AuraProductState(
                state: ProductState.retryableError,
                onRecover: () => ref.invalidate(publishedArticlesProvider),
              ),
              data: (articles) {
                if (articles.isEmpty) {
                  return const AuraProductState(
                    state: ProductState.empty,
                    headline: 'No articles yet',
                    detail:
                        'When people publish long-form writing on Aura, it '
                        'arrives here. Yours could be the first — '
                        'Create → Article.',
                    icon: Icons.article_outlined,
                  );
                }
                return Column(
                  children: [
                    for (final a in articles)
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: AuraSpace.s8, vertical: AuraSpace.s4),
                        title: Text(a.title,
                            style: AuraText.headline
                                .copyWith(fontWeight: FontWeight.w700)),
                        subtitle: Text(
                          a.author?.displayName ?? 'Aura member',
                          style: AuraText.small
                              .copyWith(color: AuraSurface.muted),
                        ),
                        onTap: a.slug == null
                            ? null
                            : () => context.push(NavigationAuthority.articleRoute(a.slug!)),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
