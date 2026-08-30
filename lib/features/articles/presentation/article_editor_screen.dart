import '../../../core/errors/app_error_mapper.dart';
import '../../../core/ui/publication/aura_article_cover.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/attachments/aura_media_upload.dart';
import '../../../core/composition/composition_authority.dart';
import '../../../core/media/media_acquisition.dart';
import '../../../core/media/attachment.dart';
import '../../../core/net/dio_provider.dart';
import '../../../core/product/product_state.dart';
import '../../../core/product/product_state_view.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/ui/publication/aura_publication_markdown.dart';
import '../../../core/ui/publication/aura_publication_title.dart';
import '../data/articles_repository.dart';
import '../../../core/navigation/navigation_authority.dart';

/// ARTICLE AUTHORING — purpose-built long-form writing (founder addendum
/// 2026-08-16). NOT the Post composer enlarged, NOT a CMS: title + a
/// markdown body sharing the platform's publication primitives (the same
/// renderer Announcements/whitepaper use), light formatting actions,
/// inline image insertion through the canonical Media authority, draft
/// autosave, preview, publish → the published Article.
class ArticleEditorScreen extends ConsumerStatefulWidget {
  const ArticleEditorScreen({super.key, this.articleId});
  final String? articleId;

  @override
  ConsumerState<ArticleEditorScreen> createState() =>
      _ArticleEditorScreenState();
}

class _ArticleEditorScreenState extends ConsumerState<ArticleEditorScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  String? _articleId;
  String? _coverUrl;
  String? _coverMediaId;
  bool _coverBusy = false;
  Timer? _autosave;
  bool _loading = true;
  bool _publishing = false;
  bool _preview = false;
  bool _wasPublished = false;
  /// Set when the author has withdrawn this published article from public
  /// view. Retraction is reversible, so the editor is where it is reversed.
  bool _retracted = false;
  bool _restoring = false;
  String _saveState = '';

  /// The snapshot as last persisted. Null until the first save.
  String? _savedSnapshot;

  /// Title and body are ONE draft as far as recovery is concerned, so
  /// dirtiness is measured over both.
  ///
  /// Length-prefixed rather than delimiter-joined: title "a" + body "bc" and
  /// title "ab" + body "c" are different drafts, and any separator a person
  /// could also type would collapse them into one snapshot and lose a save.
  String get _snapshot =>
      '${_title.text.length}:${_title.text}${_body.text}';

  /// The canonical composition, for the part CompositionAuthority owns here:
  /// dirtiness, and whether an autosave may run at all.
  ///
  /// Length is deliberately NOT policed — articles are long-form and the
  /// backend applies no `@MaxLength` to an article body, so imposing a cap
  /// here would invent a refusal the product does not have.
  CompositionState get _composition => CompositionState(
        body: _snapshot,
        maxLength: 1 << 30,
        requiresBody: false,
        isSubmitting: _publishing,
        savedBody: _savedSnapshot,
      );

  static const _autosavePolicy = AutosavePolicy();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final repo = ref.read(articlesRepositoryProvider);
    try {
      final article = widget.articleId != null
          ? await repo.getOwn(widget.articleId!)
          : await repo.createDraft();
      _articleId = article.id;
      _coverMediaId = article.coverMediaId;
      // Reopening a draft must show its saved cover, not an empty slot.
      unawaited(_refreshCoverPreview());
      _wasPublished = article.isPublished;
      _retracted = article.isRetracted;
      _title.text = article.title;
      _body.text = article.bodyMarkdown;
      // What was loaded IS what is saved. Without this baseline a freshly
      // opened draft reads as dirty and autosaves an unchanged article.
      _savedSnapshot = _snapshot;

      // RC7 / F063 — WRITE THE DRAFT'S IDENTITY INTO THE URL.
      //
      // `/articles/write` carries no id, so every mount of it minted a NEW
      // draft. Reloading the page therefore did not reopen the article being
      // written — it created another empty one and left the real work
      // unreachable, one orphan row per refresh. The address bar is the only
      // thing a reload preserves, so the draft's identity has to live there.
      //
      // `replace`, not `push`: the id-less address was never a place worth
      // going back to, and Back should leave the editor rather than return
      // to a route that would mint yet another draft.
      if (widget.articleId == null && mounted) {
        context.replace(NavigationAuthority.articleEditorRoute(article.id));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not open the draft — try again.')));
        context.pop();
        return;
      }
    }
    if (mounted) setState(() => _loading = false);
    _title.addListener(_scheduleSave);
    _body.addListener(_scheduleSave);
  }

  @override
  void dispose() {
    _autosave?.cancel();
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  void _scheduleSave() {
    _autosave?.cancel();
    // The authority decides WHETHER to save; this surface only decides when.
    // It used to schedule unconditionally, so it wrote an unchanged draft on
    // every keystroke-batch and could write underneath a publish in flight.
    if (!_autosavePolicy.shouldSave(_composition)) return;
    setState(() => _saveState = 'Saving…');
    _autosave = Timer(_autosavePolicy.debounce, _saveNow);
  }

  Future<void> _saveNow() async {
    final id = _articleId;
    if (id == null) return;
    // Captured BEFORE the await: anything typed while the request is in flight
    // must still count as dirty afterwards, or the next edit would be dropped.
    final inFlight = _snapshot;
    try {
      await ref.read(articlesRepositoryProvider).saveDraft(
            id,
            title: _title.text,
            bodyMarkdown: _body.text,
          );
      if (mounted) {
        setState(() {
          _savedSnapshot = inFlight;
          _saveState = 'Saved';
        });
      }
    } catch (_) {
      if (mounted) setState(() => _saveState = 'Not saved — check connection');
    }
  }

  /// Light markdown formatting: wraps the selection (or inserts a stub).
  void _wrapSelection(String before, String after, String stub) {
    final sel = _body.selection;
    final text = _body.text;
    if (!sel.isValid || sel.isCollapsed) {
      final at = sel.isValid ? sel.start : text.length;
      final inserted = '$before$stub$after';
      _body.value = TextEditingValue(
        text: text.replaceRange(at, at, inserted),
        selection: TextSelection(
            baseOffset: at + before.length,
            extentOffset: at + before.length + stub.length),
      );
      return;
    }
    final selected = text.substring(sel.start, sel.end);
    _body.value = TextEditingValue(
      text: text.replaceRange(sel.start, sel.end, '$before$selected$after'),
      selection: TextSelection.collapsed(
          offset: sel.end + before.length + after.length),
    );
  }

  /// Width the title field actually occupies — the column minus its own
  /// horizontal padding. Using the raw viewport here is what let the published
  /// title and the field disagree about size on a wide screen.
  double _titleFieldWidth(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final column = w > 1000 ? w / 2 : w; // split-pane preview above 1000
    return (column - AuraSpace.s20 * 2).clamp(240.0, 900.0);
  }

  /// Resolve a URL the COMPOSER can actually display.
  ///
  /// The reader renders the governed door, which anonymous visitors may use
  /// because a PUBLISHED article authorises it. A DRAFT authorises nobody — so
  /// `Image.network` on the door, which sends no credentials, is denied 403 for
  /// exactly the article the author is still writing. The preview would have
  /// failed precisely where it is needed.
  ///
  /// So the composer asks the AUTHENTICATED endpoint, which checks that this
  /// caller owns the media and issues a short-lived signed URL. Authority is
  /// unchanged — it is enforced at issuance rather than skipped — and the
  /// PRESENTATION is still the shared AuraArticleCover, so what the author sees
  /// is what readers will get.
  Future<void> _refreshCoverPreview() async {
    final mediaId = _coverMediaId;
    if (mediaId == null || mediaId.isEmpty) {
      if (mounted) setState(() => _coverUrl = null);
      return;
    }
    try {
      final res = await ref
          .read(dioProvider)
          .get<dynamic>('/media/$mediaId/url');
      final raw = res.data;
      final data = raw is Map && raw['data'] is Map
          ? raw['data'] as Map
          : (raw as Map? ?? const {});
      final url = (data['url'] ?? '').toString();
      if (mounted) setState(() => _coverUrl = url.isEmpty ? null : url);
    } catch (_) {
      // A signed URL also EXPIRES, so a failure here is often staleness rather
      // than absence. Leaving the old value lets the cover keep rendering until
      // a retry succeeds instead of blanking the author's work.
    }
  }

  /// Choose the article's cover.
  ///
  /// Deliberately SEPARATE from inserting an inline image. A cover is the
  /// article's representative identity — it appears on the reader, and on the
  /// surfaces that show an article without its body. Inline media is part of
  /// the reading flow. Conflating them (for example by silently promoting the
  /// first inline image) would take the choice away from the author, so the
  /// cover is only ever what the author picked.
  Future<void> _pickCover() async {
    final id = _articleId;
    if (id == null || _coverBusy) return;
    // THE CANONICAL ACQUISITION, not a private picker.
    //
    // This constructed its own `ImagePicker` and then repeated intake by hand.
    // Both halves already exist in `media_acquisition`, and going around it
    // cost this surface the Android Photo Picker: `image_picker_android`
    // defaults `useAndroidPhotoPicker` to false, so a private picker opens the
    // legacy file browser. A person choosing a cover was shown a file manager.
    final resolution = await acquireSingleImage();
    if (resolution == null) return;
    setState(() => _coverBusy = true);
    try {
      final cover = resolution.attachment;
      if (cover == null || cover.kind != AttachmentKind.image) {
        throw _CoverRefused(
          cover == null
              ? resolution.rejectionMessage!
              : 'A cover must be an image.',
        );
      }
      final result = await uploadAuraMedia(
        dio: ref.read(dioProvider),
        bytes: cover.bytes!,
        fileName: cover.fileName ?? 'cover',
        mimeType: cover.mimeType!,
        originalMimeType: cover.originalMimeType,
        kind: wireKind(cover.kind),
        source: wireSource(cover.source),
      );
      // canonical Media identity, never a durable URL
      await ref.read(articlesRepositoryProvider).setCover(id, result.mediaId);
      if (!mounted) return;
      setState(() => _coverMediaId = result.mediaId);
      await _refreshCoverPreview();
    } catch (e) {
      if (mounted) {
        // A governed refusal says what is wrong and is not retryable. Showing
        // "try again" for a file type Aura will never accept invites the person
        // to repeat something that cannot succeed.
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e is _CoverRefused
                ? e.message
                : 'Cover upload failed — try again.')));
      }
    } finally {
      if (mounted) setState(() => _coverBusy = false);
    }
  }

  /// Remove the cover. Sends an explicit null, which `saveDraft` cannot express.
  Future<void> _removeCover() async {
    final id = _articleId;
    if (id == null || _coverBusy) return;
    setState(() => _coverBusy = true);
    try {
      await ref.read(articlesRepositoryProvider).setCover(id, null);
      if (mounted) {
        setState(() {
          _coverMediaId = null;
          _coverUrl = null;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not remove the cover — try again.')));
      }
    } finally {
      if (mounted) setState(() => _coverBusy = false);
    }
  }

  Future<void> _insertImage() async {
    final resolution = await acquireSingleImage();
    if (resolution == null) return;
    try {
      final inline = resolution.attachment;
      if (inline == null || inline.kind != AttachmentKind.image) {
        throw _CoverRefused(
          inline == null
              ? resolution.rejectionMessage!
              : 'Only an image can be inserted here.',
        );
      }
      final result = await uploadAuraMedia(
        dio: ref.read(dioProvider),
        bytes: inline.bytes!,
        fileName: inline.fileName ?? 'image',
        mimeType: inline.mimeType!,
        originalMimeType: inline.originalMimeType,
        kind: wireKind(inline.kind),
        source: wireSource(inline.source),
      );
      final urlRes =
          await ref.read(dioProvider).get<dynamic>('/media/${result.mediaId}/url');
      final data = urlRes.data is Map<String, dynamic> &&
              (urlRes.data as Map<String, dynamic>)['data'] is Map
          ? (urlRes.data as Map<String, dynamic>)['data'] as Map
          : urlRes.data as Map? ?? {};
      final url = (data['url'] ?? data['deliveryUrl'] ?? '').toString();
      if (url.isEmpty) throw Exception('no url');
      // The markdown that is written is NOT changed here — the durability and
      // correctness of the written URL is F121's subject, not F025's.
      _wrapSelection('\n![', ']($url)\n', 'image');
      // F025 — on a wide viewport the image has already appeared in the
      // preview pane. On a narrow one it has not, so the author is told the
      // image exists and given one tap to see it rendered, instead of being
      // left looking at a line of raw markdown.
      if (mounted && MediaQuery.of(context).size.width < 1000 && !_preview) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Image added'),
          action: SnackBarAction(
            label: 'Preview',
            onPressed: () {
              if (mounted) setState(() => _preview = true);
            },
          ),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e is _CoverRefused
                ? e.message
                : 'Image upload failed — try again.')));
      }
    }
  }

  /// Returns a retracted article to public view, with its discussion intact.
  Future<void> _restore() async {
    final id = _articleId;
    if (id == null || _restoring) return;
    setState(() => _restoring = true);
    try {
      final article = await ref.read(articlesRepositoryProvider).restore(id);
      ref.invalidate(publishedArticlesProvider);
      if (!mounted) return;
      setState(() {
        _retracted = article.isRetracted;
        _wasPublished = article.isPublished;
      });
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Restored. It is publicly visible again.')),
      );
    } catch (e) {
      if (!mounted) return;
      final err = AppErrorMapper.from(e, feature: 'restore this article');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err.message)));
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  Future<void> _publish() async {
    final id = _articleId;
    if (id == null || _publishing) return;
    setState(() => _publishing = true);
    _autosave?.cancel();
    try {
      await _saveNow();
      // Publishing a draft mints the slug; saving changes to an already
      // published article revises IN PLACE (founder ruling: same identity,
      // same canonical URL, durable revision history server-side).
      final article = await ref.read(articlesRepositoryProvider).publish(id);
      ref.invalidate(publishedArticlesProvider);
      if (article.slug != null) {
        ref.invalidate(articleBySlugProvider(article.slug!));
      }
      if (mounted && article.slug != null) {
        context.pushReplacement(
            NavigationAuthority.articleRoute(article.slug!));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString().contains('substantial')
                ? 'An article is substantial authored thought — write a '
                    'little more before publishing.'
                : 'Could not publish — a title and a substantial body are '
                    'required.')));
      }
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }


  /// The rendered half. `live` is the always-on pane beside the source on a
  /// wide viewport; without it this is the Preview the toggle switches to.
  ///
  /// Both draw the title through [AuraPublicationTitle] and the body through
  /// the shared publication renderer, so what the author sees while writing
  /// is what the published article will be — the same two primitives, not a
  /// second approximation of them.
  Widget _previewPane({required bool live}) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.all(AuraSpace.s20),
          children: [
            if (live) ...[
              Text('PREVIEW',
                  style: AuraText.micro.copyWith(
                      color: AuraSurface.faint, letterSpacing: 1.2)),
              const SizedBox(height: AuraSpace.s10),
            ],
            AuraPublicationTitle(_title.text, placeholder: 'Untitled'),
            const SizedBox(height: AuraSpace.s16),
            AuraPublicationMarkdown(data: _body.text),
            const SizedBox(height: AuraSpace.s32),
          ],
        ),
      ),
    );
  }

  /// The source half: title, formatting actions, markdown body.
  Widget _writePane() {
    return Column(
      children: [
        // COVER PREVIEW — the author must see what they are about to publish.
        // A filename or a success toast is not a cover-authoring experience:
        // the first version gave no preview at all, so the framing was only
        // discoverable AFTER publishing. This renders through the same
        // AuraArticleCover the reader uses, so it predicts the real result
        // rather than approximating it.
        if ((_coverUrl ?? '').trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AuraSpace.s20, AuraSpace.s16, AuraSpace.s20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AuraArticleCover(
                  _coverUrl!,
                  showFailure: true,
                  onRetry: _coverBusy ? null : _refreshCoverPreview,
                ),
                const SizedBox(height: AuraSpace.s8),
                Row(children: [
                  Text('Cover',
                      style: AuraText.micro.copyWith(color: AuraSurface.muted)),
                  const Spacer(),
                  TextButton(
                      onPressed: _coverBusy ? null : _pickCover,
                      child: const Text('Replace')),
                  TextButton(
                      onPressed: _coverBusy ? null : _removeCover,
                      child: const Text('Remove')),
                ]),
              ],
            ),
          ),
        if (_coverBusy)
          const Padding(
            padding: EdgeInsets.fromLTRB(
                AuraSpace.s20, AuraSpace.s16, AuraSpace.s20, 0),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AuraSpace.s20, AuraSpace.s16, AuraSpace.s20, 0),
          child: TextField(
            controller: _title,
            // F026 — the field itself sizes to the title. A pasted headline
            // steps down to fit instead of clipping inside a fixed 40px box,
            // and the formatter strips the newlines a paste brings with it
            // without removing a single word.
            // Sized by the editor's own field width, so the title looks the
            // same size while it is being written as it will once published.
            style: publicationTitleStyle(
              title: _title.text,
              availableWidth: _titleFieldWidth(context),
            ),
            inputFormatters: const [PublicationTitleInputFormatter()],
            maxLines: null,
            minLines: 1,
            decoration: const InputDecoration(
              hintText: 'Title',
              border: InputBorder.none,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AuraSpace.s16),
          child: Row(
            children: [
              IconButton(
                  tooltip: 'Heading',
                  icon: const Icon(Icons.title_rounded, size: 20),
                  onPressed: () => _wrapSelection('\n## ', '\n', 'Heading')),
              IconButton(
                  tooltip: 'Bold',
                  icon: const Icon(Icons.format_bold_rounded, size: 20),
                  onPressed: () => _wrapSelection('**', '**', 'bold')),
              IconButton(
                  tooltip: 'Italic',
                  icon: const Icon(Icons.format_italic_rounded, size: 20),
                  onPressed: () => _wrapSelection('_', '_', 'italic')),
              IconButton(
                  tooltip: 'Link',
                  icon: const Icon(Icons.link_rounded, size: 20),
                  onPressed: () =>
                      _wrapSelection('[', '](https://)', 'link text')),
              IconButton(
                  tooltip: 'Image',
                  icon: const Icon(Icons.image_outlined, size: 20),
                  onPressed: _insertImage),
              IconButton(
                tooltip: (_coverUrl ?? '').isEmpty
                    ? 'Set cover image'
                    : 'Change cover image',
                icon: Icon(
                    (_coverUrl ?? '').isEmpty
                        ? Icons.wallpaper_outlined
                        : Icons.wallpaper_rounded,
                    size: 20),
                onPressed: _coverBusy ? null : _pickCover,
              ),
              if ((_coverUrl ?? '').isNotEmpty)
                IconButton(
                  tooltip: 'Remove cover image',
                  icon: const Icon(Icons.hide_image_outlined, size: 20),
                  onPressed: _coverBusy ? null : _removeCover,
                ),
              const Spacer(),
              Text(_saveState,
                  style: AuraText.micro.copyWith(color: AuraSurface.faint)),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(AuraSpace.s20),
            child: TextField(
              controller: _body,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: AuraText.body.copyWith(height: 1.7),
              decoration: const InputDecoration(
                hintText: 'Write your article — substantial authored '
                    'thought, in your own words.',
                border: InputBorder.none,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return AuraScaffold(
          body: const AuraProductState(state: ProductState.loading));
    }
    // F025 — the split writing view needs real width; below it the author
    // keeps the Write/Preview toggle rather than two cramped columns.
    final wide = MediaQuery.of(context).size.width >= 1000;

    return AuraScaffold(
      showHeader: false,
      body: Column(
        children: [
          // TRUTHFUL STATE. A retracted article looks identical to a published
          // one in an editor, so without this the author would edit something
          // nobody can read and have no way to know. It is also the only place
          // Restore is offered, because the public reader deliberately reports
          // a retracted article as gone.
          if (_retracted)
            Container(
              width: double.infinity,
              color: AuraSurface.elevated,
              padding: const EdgeInsets.symmetric(
                  horizontal: AuraSpace.s16, vertical: AuraSpace.s12),
              child: Row(
                children: [
                  const Icon(Icons.visibility_off_outlined,
                      size: 18, color: AuraSurface.muted),
                  const SizedBox(width: AuraSpace.s8),
                  Expanded(
                    child: Text(
                      'Retracted — not publicly visible. Its reactions and '
                      'discussion are kept.',
                      style: AuraText.small.copyWith(color: AuraSurface.ink),
                    ),
                  ),
                  const SizedBox(width: AuraSpace.s8),
                  FilledButton(
                    onPressed: _restoring ? null : _restore,
                    child: Text(_restoring ? 'Restoring…' : 'Restore'),
                  ),
                ],
              ),
            ),
          // VISIBLE editor bar — AuraScaffold renders no chrome of its
          // own, so the editor owns Publish/Preview explicitly.
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AuraSpace.s8, vertical: AuraSpace.s6),
            decoration: const BoxDecoration(
              color: AuraSurface.card,
              border: Border(bottom: BorderSide(color: AuraSurface.divider)),
            ),
            child: Row(
              children: [
                // RETIRED 2026-08-25 — duplicated the governed return
                // control: canPop ? pop : Create is exactly what
                // ReturnPathAuthority resolves for a flow surface, and two
                // arrows on one screen is what the shared control ends.
                Text('Article',
                    style: AuraText.body.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AuraSurface.ink)),
                const Spacer(),
                Text(_saveState,
                    style:
                        AuraText.micro.copyWith(color: AuraSurface.faint)),
                const SizedBox(width: AuraSpace.s10),
                if (!wide) ...[
                  TextButton(
                    onPressed: () => setState(() => _preview = !_preview),
                    child: Text(_preview ? 'Write' : 'Preview'),
                  ),
                  const SizedBox(width: AuraSpace.s6),
                ],
                AuraPrimaryButton(
                  label: _publishing
                      ? 'Publishing…'
                      : (_wasPublished ? 'Save changes' : 'Publish'),
                  onPressed: _publishing ? null : _publish,
                ),
                const SizedBox(width: AuraSpace.s6),
              ],
            ),
          ),
          Expanded(
            child: wide
                // F025 — on a viewport with room for it, the author writes
                // and SEES at the same time. An inserted image renders in
                // the pane beside the source the instant it is added, which
                // is the whole of what F025 reported missing.
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _writePane()),
                      const VerticalDivider(width: 1),
                      Expanded(child: _previewPane(live: true)),
                    ],
                  )
                : Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child:
                          _preview ? _previewPane(live: false) : _writePane(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// A refusal the editor can show verbatim, so a governed "that file type
/// cannot be attached" is not flattened into "upload failed — try again".
class _CoverRefused implements Exception {
  const _CoverRefused(this.message);
  final String message;
  @override
  String toString() => message;
}
