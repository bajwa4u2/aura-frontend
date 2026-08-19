import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/attachments/aura_media_upload.dart';
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
  Timer? _autosave;
  bool _loading = true;
  bool _publishing = false;
  bool _preview = false;
  bool _wasPublished = false;
  String _saveState = '';

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
      _wasPublished = article.isPublished;
      _title.text = article.title;
      _body.text = article.bodyMarkdown;

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
    setState(() => _saveState = 'Saving…');
    _autosave = Timer(const Duration(seconds: 2), _saveNow);
  }

  Future<void> _saveNow() async {
    final id = _articleId;
    if (id == null) return;
    try {
      await ref.read(articlesRepositoryProvider).saveDraft(
            id,
            title: _title.text,
            bodyMarkdown: _body.text,
          );
      if (mounted) setState(() => _saveState = 'Saved');
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

  Future<void> _insertImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    try {
      final Uint8List bytes = await picked.readAsBytes();
      final result = await uploadAuraMedia(
        dio: ref.read(dioProvider),
        bytes: bytes,
        fileName: picked.name,
        mimeType: picked.mimeType ?? 'image/jpeg',
        kind: 'IMAGE',
        source: 'GALLERY',
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
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Image upload failed — try again.')));
      }
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
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AuraSpace.s20, AuraSpace.s16, AuraSpace.s20, 0),
          child: TextField(
            controller: _title,
            // F026 — the field itself sizes to the title. A pasted headline
            // steps down to fit instead of clipping inside a fixed 40px box,
            // and the formatter strips the newlines a paste brings with it
            // without removing a single word.
            style: publicationTitleStyle(
              title: _title.text,
              viewportWidth: MediaQuery.of(context).size.width,
            ),
            inputFormatters: const [PublicationTitleInputFormatter()],
            maxLines: 3,
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
                IconButton(
                  tooltip: 'Back',
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => context.canPop()
                      ? context.pop()
                      : context.go(NavigationAuthority.createRoute),
                ),
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
