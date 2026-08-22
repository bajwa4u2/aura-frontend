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
import '../../../core/engagement/aura_engagement_bar.dart';
import '../../../core/errors/app_error_mapper.dart';
import '../../../core/engagement/engagement_model.dart';
import '../../../core/engagement/aura_publication_discussion.dart';
import '../../../core/engagement/publication_discussion_repository.dart';
import '../../../core/media/aura_media_viewer.dart';
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
                  // PUBLICATION CONTENT, not identity imagery. The identity
                  // interaction ruling governs avatars, logos and profile
                  // covers; an article cover is the author's own published
                  // work, so it opens in the CANONICAL media viewer — the same
                  // one post attachments and conversation media use — rather
                  // than staying inert or gaining an article-private viewer.
                  //
                  // The viewer receives the governed door URL and the media id,
                  // so it resolves full resolution through the same custody
                  // path as everything else. The page itself keeps rendering
                  // the display derivative; only the viewer asks for more.
                  Semantics(
                    label: 'Article cover image. Activate to view full size.',
                    button: true,
                    child: InkWell(
                      onTap: () => showAuraMediaViewer(
                        context,
                        items: [
                          AuraViewerItem(
                            originalUrl: article.coverUrl!,
                            mediaId: article.coverMediaId,
                            caption: article.title,
                            downloadContext: 'article-cover',
                          ),
                        ],
                      ),
                      child: AuraArticleCover(article.coverUrl!),
                    ),
                  ),
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
                AuraPublicationMarkdown(
                  data: article.bodyMarkdown,
                  // Inline imagery is publication content too, and opens in the
                  // same canonical viewer as the cover. The image is already a
                  // governed URL the server emitted; the viewer resolves full
                  // resolution through the ordinary custody path.
                  onTapImage: (url, alt) => showAuraMediaViewer(
                    context,
                    items: [
                      AuraViewerItem(
                        originalUrl: url,
                        caption: (alt ?? '').trim().isEmpty ? null : alt!.trim(),
                        downloadContext: 'article-image',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AuraSpace.s20),
                const Divider(height: 1),
                const SizedBox(height: AuraSpace.s12),
                // Articles become engageable through the SHARED authority. No
                // ArticleReaction storage, no article-specific block check, no
                // article reaction bar — those are how engagement ended up
                // cloned for institution posts and missing for articles in the
                // first place.
                AuraEngagementBar(
                  target: PublicationTarget.article,
                  publicationId: article.id,
                ),
                const SizedBox(height: AuraSpace.s12),
                // NATIVE reshare — a different capability from external share.
                // The share sheet above hands someone a link; this brings the
                // article into Aura's own feed under the resharer's name, with
                // the Article still the canonical object rather than a copy of
                // its text.
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: const Icon(Icons.repeat_rounded, size: 16),
                    label: const Text('Reshare on Aura'),
                    onPressed: () => _reshare(context, ref, article.id),
                  ),
                ),
                const SizedBox(height: AuraSpace.s20),
                const Divider(height: 1),
                const SizedBox(height: AuraSpace.s20),
                // Discussion through the SHARED authority. A reply is a Post,
                // so it carries Aura's moderation gate, Discourse Quality,
                // mention fan-out, acting authority and blocking without an
                // article-specific comment system.
                AuraPublicationDiscussion(
                  target: PublicationTarget.article,
                  publicationId: article.id,
                ),
                const SizedBox(height: AuraSpace.s16),
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

  /// Native reshare with commentary.
  ///
  /// Commentary is required, not optional: Discourse Quality refuses an empty
  /// reshare server-side, and asking for it here is honest about that rather
  /// than letting the reader discover the rule through a rejection.
  Future<void> _reshare(
    BuildContext context,
    WidgetRef ref,
    String articleId,
  ) async {
    final controller = TextEditingController();
    final commentary = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AuraSurface.page,
        title: const Text('Reshare on Aura'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'Say why this is worth reading',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Reshare'),
          ),
        ],
      ),
    );
    if (commentary == null || commentary.isEmpty) return;
    if (!context.mounted) return;
    try {
      await ref
          .read(publicationDiscussionRepositoryProvider)
          .reshare(PublicationTarget.article, articleId, commentary);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reshared to your feed.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      final err = AppErrorMapper.from(e, feature: 'reshare this');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err.message)));
    }
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
