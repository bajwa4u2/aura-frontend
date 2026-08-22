import '../../../core/ui/publication/aura_article_cover.dart';
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
import '../../../core/translation/communication_translate_action.dart';
import '../../../core/translation/communication_translation.dart';
import '../../posts/presentation/widgets/post_card/post_card_utils.dart'
    show canonicalArticleUrl;
import '../../share/aura_share_sheet.dart';
import '../../../core/ui/publication/aura_publication_markdown.dart';
import '../../../core/ui/publication/aura_publication_title.dart';
import '../../conversation/presentation/conversation_identity.dart';
import '../data/articles_repository.dart';
import '../../../core/navigation/navigation_authority.dart';
import '../../../core/identity/person_identity_model.dart';

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
                // F026 — one title authority. A long headline steps down to
                // fit its column instead of running past it, and it is the
                // same size here as it was in the editor's preview.
                // The cover is the article's representative image. Optional by
                // design — most articles have none, and an empty frame would
                // be worse than no frame. Rendered from the SERVER's governed
                // URL; the client never composes a media address itself.
                // Rendered through the SHARED cover contract, so the author's
                // composer preview and this are the same widget and cannot
                // disagree about framing.
                if ((article.coverUrl ?? '').trim().isNotEmpty) ...[
                  AuraArticleCover(article.coverUrl!),
                  const SizedBox(height: AuraSpace.s16),
                ],
                AuraPublicationTitle(article.title),
                const SizedBox(height: AuraSpace.s12),
                Row(
                  children: [
                    // The byline carries the author's REAL likeness. It was
                    // constructed from the name alone, so every article
                    // rendered a generated initial while the API had been
                    // sending a governed avatarUrl the whole time — the author
                    // appeared anonymous on their own published work.
                    AuraAvatar(
                      name: article.author?.proseName ?? '',
                      imageUrl: article.author?.avatarUrl,
                      size: 32,
                    ),
                    const SizedBox(width: AuraSpace.s10),
                    Expanded(
                      child: InkWell(
                        onTap: article.author?.profileRoute == null
                            ? null
                            : () => context
                                .push(article.author!.profileRoute!),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                (article.author ?? AuraPersonIdentity.unknown)
                                    .proseName,
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
                    // Articles were the one publishable type with no way to
                    // share them. The address deliberately points at the
                    // marketing host, not at this screen's own URL: only that
                    // host is crawled, so it is the only link that previews
                    // as the author's title and cover rather than as the
                    // generic Aura card.
                    //
                    // Offered only for a published article — a draft has no
                    // slug, and there would be nothing on the other end.
                    if ((article.slug ?? '').trim().isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.ios_share, size: 18),
                        color: AuraSurface.muted,
                        tooltip: 'Share this article',
                        onPressed: () => showAuraShareSheet(
                          context,
                          shareUrl: canonicalArticleUrl(article.slug!),
                          headline: 'Share this article',
                          subtitle:
                              'A public, crawler-friendly link that previews on LinkedIn, X, Discord, Slack, Facebook.',
                          emailSubject: article.title,
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
                const SizedBox(height: AuraSpace.s20),
                // Articles reach translation through the SAME canonical action
                // every other publishable surface uses. There is deliberately
                // no article-specific translator: a new readable content type
                // arriving without translation is the defect this closes, and
                // closing it with a private copy would have re-created it one
                // type later.
                //
                // The title travels WITH the body as a single Markdown
                // document. A reader who cannot read the language cannot read
                // the headline either, and one document keeps the translation
                // a coherent whole rather than two independently-cached
                // fragments — while the Markdown renderer below keeps the
                // translated article looking like an article.
                CommunicationTranslateAction(
                  objectType: CommunicationObjectType.article,
                  objectId: article.id,
                  sourceText: '# ${article.title}\n\n${article.bodyMarkdown}',
                  translatedBodyBuilder: (context, text) =>
                      AuraPublicationMarkdown(data: text),
                ),
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
                          (a.author ?? AuraPersonIdentity.unknown).proseName,
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
