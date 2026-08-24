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
                        ref.watch(myUserIdProvider)) ...[
                      TextButton.icon(
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Edit'),
                        onPressed: () =>
                            context.push(
                                NavigationAuthority.articleEditorRoute(
                                    article.id)),
                      ),
                      // Retraction is visibility-changing and other people may
                      // already have the link, so it is confirmed rather than
                      // performed on a single tap — and the confirmation says
                      // plainly what survives, because "delete" is what an
                      // author will assume otherwise.
                      IconButton(
                        icon: const Icon(Icons.visibility_off_outlined, size: 18),
                        color: AuraSurface.muted,
                        tooltip: 'Retract from public view',
                        onPressed: () => _retract(context, ref, article),
                      ),
                    ],
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
                // ARTICLE ACTIONS — everything here acts on the ARTICLE.
                //
                // Translate used to sit BELOW the discussion, where it read as
                // translating the replies rather than the article. Placement
                // was the whole meaning of the control: it belongs with React
                // and Save, above the discussion boundary, and its result
                // appears attached to the article it translated.
                _ArticleActions(article: article, onReshare: () => _reshare(context, ref, article.id)),
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
                const SizedBox(height: AuraSpace.s32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Withdraws a published article from public view.
  ///
  /// Deliberately NOT called delete anywhere in this flow. The article keeps
  /// its reactions, saves and discussion, and its public address keeps
  /// resolving to a safe "unavailable" page rather than breaking — restoring
  /// returns all of it together. Saying "delete" would make an author expect
  /// destruction and then be surprised by a Restore button.
  Future<void> _retract(
    BuildContext context,
    WidgetRef ref,
    Article article,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AuraSurface.page,
        title: const Text('Retract this article?'),
        content: const Text(
          'It stops appearing publicly and its link stops resolving for '
          'readers. Its reactions and discussion are kept, and you can '
          'restore it at any time from the editor.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Retract'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(articlesRepositoryProvider).retract(article.id);
      ref.invalidate(publishedArticlesProvider);
      if (!context.mounted) return;
      // NOT a dead end. This screen reads the PUBLIC endpoint, which now
      // correctly reports the article as gone, so staying here would strand
      // the author on "Article unavailable" with no way back to their own
      // work. The editor still resolves it and carries the Restore action.
      context.go(NavigationAuthority.articleEditorRoute(article.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Retracted. You can restore it here.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      final err = AppErrorMapper.from(e, feature: 'retract this article');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err.message)));
    }
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

/// The article's own action region.
///
/// Stateful only because an INLINE translate control reports its result here,
/// so the translation can render full-width beneath the action row instead of
/// being wedged into it. A translated article is prose; it cannot live inside
/// a horizontal row, and the control cannot leave the row without ceasing to
/// look like an article action.
class _ArticleActions extends StatefulWidget {
  const _ArticleActions({required this.article, required this.onReshare});

  final Article article;
  final VoidCallback onReshare;

  @override
  State<_ArticleActions> createState() => _ArticleActionsState();
}

class _ArticleActionsState extends State<_ArticleActions> {
  String? _translated;
  String _language = '';

  @override
  Widget build(BuildContext context) {
    final article = widget.article;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // React · Translate · Save — one row of article-level actions.
        AuraEngagementBar(
          target: PublicationTarget.article,
          publicationId: article.id,
          // Articles reach translation through the SAME canonical action every
          // other publishable surface uses. There is deliberately no
          // article-specific translator: a readable content type arriving
          // without translation is the defect this closed, and closing it with
          // a private copy would have re-created it one type later.
          //
          // The title travels WITH the body as one Markdown document. A reader
          // who cannot read the language cannot read the headline either.
          inlineAction: CommunicationTranslateAction(
            objectType: CommunicationObjectType.article,
            objectId: article.id,
            sourceText: '# ${article.title}\n\n${article.bodyMarkdown}',
            inline: true,
            onResultChanged: (text, language) {
              if (!mounted) return;
              setState(() {
                _translated = text;
                _language = language;
              });
            },
          ),
        ),
        // The translation, attributed to the article and rendered as an
        // article — headings and paragraphs, not a flattened block.
        if ((_translated ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: AuraSpace.s12),
          AuraTranslationResult(
            translatedText: _translated!,
            targetLanguage: _language,
            bodyBuilder: (context, text) =>
                AuraPublicationMarkdown(data: text),
          ),
        ],
        const SizedBox(height: AuraSpace.s12),
        // NATIVE reshare — a different capability from external share. The
        // share control at the top hands someone a link; this brings the
        // article into Aura's own feed under the resharer's name, with the
        // Article still the canonical object rather than a copy of its text.
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.repeat_rounded, size: 16),
            label: const Text('Reshare on Aura'),
            onPressed: widget.onReshare,
          ),
        ),
      ],
    );
  }
}

/// DISCOVER → ARTICLES — the fourth domain, now REAL: published articles,
/// newest first, truthful empty state when none exist yet.

// ARTICLES DISCOVERY MOVED, 2026-08-24.
//
// The reverse-chronological list that lived here is replaced by the Articles
// domain destination in features/discover, which reads the relevance-ordered
// projection and presents articles editorially. Reading a single article is
// still this file's job; discovering one is not.
