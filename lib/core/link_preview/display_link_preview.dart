import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/posts/presentation/widgets/post_card/post_card_utils.dart';
import '../ui/aura_space.dart';
import 'internal_reference_card.dart';
import 'link_preview.dart';
import 'link_preview_card.dart';
import 'link_preview_service.dart';

/// Item 14 — the one place every DISPLAY surface (already-published Posts,
/// Institution Posts, Announcements, Thread/Space messages, DMs) renders a
/// `linkUrl` carried on the object. Branches on host, not on any stored
/// "internal" flag (the flat-field response shape doesn't carry one; see
/// Item 13's `mapPost`-style projections):
///
///  - External link: renders immediately from the already-fetched OG
///    fields the object's own response carries (`linkTitle`/`linkImageUrl`/
///    ...). No network call here -- unchanged from Item 13.
///  - Internal Aura link: the object's response never carries OG fields for
///    these (the backend's internal branch has none to give), and more
///    importantly a stored/cached projection would be WRONG for this case:
///    authorization can change between when the link was posted and when
///    it's viewed. So this re-resolves live, via the same
///    `POST /link-previews/resolve` endpoint compose-time uses, revalidating
///    the CURRENT viewer's authorization on every render rather than
///    trusting historical/cached access.
///
/// Surfaces keep owning their own layout (spacing, dense-ness) around this;
/// only the fetch-or-not decision and the resulting card are shared.
class DisplayLinkPreview extends ConsumerStatefulWidget {
  const DisplayLinkPreview({
    super.key,
    required this.linkUrl,
    this.linkTitle,
    this.linkDescription,
    this.linkSiteName,
    this.linkImageUrl,
    this.dense = false,
  });

  final String linkUrl;
  final String? linkTitle;
  final String? linkDescription;
  final String? linkSiteName;
  final String? linkImageUrl;
  final bool dense;

  @override
  ConsumerState<DisplayLinkPreview> createState() => _DisplayLinkPreviewState();
}

class _DisplayLinkPreviewState extends ConsumerState<DisplayLinkPreview> {
  LinkPreview? _resolved;
  bool _loading = false;

  bool get _isInternal => isInternalAuraUrl(widget.linkUrl);

  @override
  void initState() {
    super.initState();
    if (_isInternal) _resolve();
  }

  @override
  void didUpdateWidget(covariant DisplayLinkPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.linkUrl != widget.linkUrl && _isInternal) {
      _resolved = null;
      _resolve();
    }
  }

  Future<void> _resolve() async {
    setState(() => _loading = true);
    final result = await ref.read(linkPreviewServiceProvider).resolve(widget.linkUrl);
    if (!mounted) return;
    setState(() {
      _resolved = result;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInternal) {
      return LinkPreviewCard(
        url: widget.linkUrl,
        title: widget.linkTitle,
        description: widget.linkDescription,
        siteName: widget.linkSiteName,
        imageUrl: widget.linkImageUrl,
        dense: widget.dense,
      );
    }

    if (_loading && _resolved == null) {
      return const SizedBox(
        height: 48,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return InternalReferenceCard(
      sourceUrl: widget.linkUrl,
      reference: _resolved?.internalReference,
      dense: widget.dense,
    );
  }
}

/// Shared spacer + null-guard used identically by every display surface
/// that currently inlines an `if (linkUrl != null) [SizedBox, LinkPreviewCard]`
/// block -- kept as a function rather than forcing every call site to
/// import `AuraSpace` just for this one constant.
Widget? buildDisplayLinkPreviewBlock({
  required String? linkUrl,
  String? linkTitle,
  String? linkDescription,
  String? linkSiteName,
  String? linkImageUrl,
  bool dense = false,
}) {
  final url = (linkUrl ?? '').trim();
  if (url.isEmpty) return null;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: AuraSpace.s10),
      DisplayLinkPreview(
        linkUrl: url,
        linkTitle: linkTitle,
        linkDescription: linkDescription,
        linkSiteName: linkSiteName,
        linkImageUrl: linkImageUrl,
        dense: dense,
      ),
    ],
  );
}
