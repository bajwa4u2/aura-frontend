/// THE CANONICAL MEDIA GROUP — one composition, many ordered items.
///
/// A composition may carry one media item or several, and several items are
/// not unrelated attachments that happen to share a message: they are an
/// ORDERED GROUP, and the order is the author's intent.
///
/// ## WHAT THIS REPLACES
///
/// Nothing, structurally — which was the problem. The backend has carried
/// ordered multi-media for a long time: `PostMedia` and `MessageMedia` are both
/// join tables with an explicit `position`, `MessageMedia` even enforces
/// `@@unique([messageId, position])`, and every read path already sorts by it.
/// The client simply rendered `item.media.first` and dropped the rest on the
/// floor.
///
/// So this is not new capability. It is the client catching up to authority
/// that was already there.
///
/// ## WHY LAYOUT IS A POLICY, NOT A GRID
///
/// Shrinking every item to an equal cell regardless of count or shape produces
/// four unreadable stamps where two photographs and a video were meant. The
/// layouts below are chosen per count, and they preserve the single-item
/// treatment at one item rather than making a lone photograph pay for the
/// existence of the group case.
///
/// ## WHAT THIS DOES NOT OWN
///
/// It does not own media identity, authorization, posters, provenance or
/// export policy. Every item resolves those for ITSELF through the canonical
/// stored-media stack — which is what keeps provenance item-scoped, so one
/// AI-generated image in a group of three cannot label the other two.
library;

import 'package:flutter/material.dart';

import '../ui/aura_radius.dart';
import '../ui/aura_surface.dart';
import '../ui/aura_text.dart';
import '../../features/feed/domain/feed_media.dart';
import 'aura_media_frame.dart';
import 'canonical_media_thumb.dart';

/// How many items are shown before the rest collapse into a continuation.
///
/// Four is the largest count that still reads as a composition rather than a
/// contact sheet, and it is the last count with a layout that gives every item
/// a fair share. Beyond it the fifth cell carries the overflow.
const int kMediaGroupPreviewLimit = 4;

/// Renders an ordered group of media items.
///
/// Order comes from the caller and is never re-derived here: it is composition
/// intent, persisted server-side, and sorting by upload time or media type
/// would silently substitute an accident for a decision.
class AuraMediaGroup extends StatelessWidget {
  const AuraMediaGroup({
    super.key,
    required this.items,
    this.mode = AuraMediaFrameMode.feed,
    this.downloadContext = 'media',
    this.onOpenItem,
  });

  final List<FeedMedia> items;
  final AuraMediaFrameMode mode;
  final String downloadContext;

  /// Opens the immersive viewer at [index], with the WHOLE group in context so
  /// a person can move between items without leaving and re-entering.
  final void Function(int index)? onOpenItem;

  static const double _gap = 3;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    // ONE ITEM KEEPS THE SINGLE-MEDIA TREATMENT. A lone photograph should not
    // look different because the group case exists.
    if (items.length == 1) {
      return CanonicalMediaThumb(
        media: items.first,
        mode: mode,
        downloadContext: downloadContext,
        onTap: onOpenItem == null ? null : () => onOpenItem!(0),
      );
    }

    return Semantics(
      label: _groupSemanticLabel(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AuraRadius.lg),
        child: AspectRatio(
          aspectRatio: _aspectFor(items.length),
          child: _layoutFor(items.length),
        ),
      ),
    );
  }

  String _groupSemanticLabel() {
    final videos = items.where((m) => m.isVideo).length;
    final images = items.length - videos;
    final parts = <String>[
      if (images > 0) '$images image${images == 1 ? '' : 's'}',
      if (videos > 0) '$videos video${videos == 1 ? '' : 's'}',
    ];
    // Collage shape conveys count visually; this conveys it to everyone else.
    return '${items.length} media items: ${parts.join(', ')}';
  }

  /// The group's outer shape, chosen so each layout's cells stay legible.
  double _aspectFor(int count) {
    switch (count) {
      case 2:
        // Two side by side, each roughly portrait-ish — closer to how a pair
        // of phone photographs actually look.
        return 16 / 9;
      case 3:
        return 3 / 2;
      default:
        // A square grid reads evenly at four and gives the overflow cell room.
        return 1;
    }
  }

  Widget _layoutFor(int count) {
    switch (count) {
      case 2:
        return Row(children: [
          _cell(0),
          const SizedBox(width: _gap),
          _cell(1),
        ]);
      case 3:
        // A dominant item with two supporting it, rather than three equal
        // slivers. Three equal columns is the layout that makes every
        // three-item post look like a filmstrip.
        return Row(children: [
          _cell(0),
          const SizedBox(width: _gap),
          Expanded(
            child: Column(children: [
              _cell(1, expand: false),
              const SizedBox(height: _gap),
              _cell(2, expand: false),
            ]),
          ),
        ]);
      default:
        return Column(children: [
          Expanded(
            child: Row(children: [
              _cell(0),
              const SizedBox(width: _gap),
              _cell(1),
            ]),
          ),
          const SizedBox(height: _gap),
          Expanded(
            child: Row(children: [
              _cell(2),
              const SizedBox(width: _gap),
              // The fourth cell carries the overflow when there are more.
              _cell(3, overflow: items.length - kMediaGroupPreviewLimit),
            ]),
          ),
        ]);
    }
  }

  Widget _cell(int index, {bool expand = true, int overflow = 0}) {
    if (index >= items.length) return const Expanded(child: SizedBox.shrink());
    final child = _MediaGroupCell(
      media: items[index],
      downloadContext: downloadContext,
      overflow: overflow > 0 ? overflow : 0,
      onTap: onOpenItem == null ? null : () => onOpenItem!(index),
    );
    return expand ? Expanded(child: child) : Expanded(child: child);
  }
}

/// One cell. Delegates entirely to the canonical stack — a cell decides its
/// SHAPE, never what the media is or how it behaves.
class _MediaGroupCell extends StatelessWidget {
  const _MediaGroupCell({
    required this.media,
    required this.downloadContext,
    required this.overflow,
    this.onTap,
  });

  final FeedMedia media;
  final String downloadContext;

  /// How many further items this cell stands in for. Zero when it is just a cell.
  final int overflow;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // POSTER-FIRST INSIDE A GROUP. Each cell renders through the canonical
    // thumb, which for video shows the server poster and a play affordance and
    // does NOT instantiate a decoder. A four-video group would otherwise spin
    // up four decoders in a scrolling feed.
    final tile = CanonicalMediaThumb(
      media: media,
      mode: AuraMediaFrameMode.thumbnail,
      downloadContext: downloadContext,
      onTap: onTap,
      // The cell is already sized by the group's grid; the tile fills it.
      fillCell: true,
    );

    // TR IS NOT MOUNTED HERE. It lives on `CanonicalMediaThumb`, which this
    // cell renders — placing it in both would show the mark twice on a collage
    // and not at all on a single-media post, which is exactly the bug that
    // sent it there in the first place.
    //
    // It remains PER ITEM either way: each cell renders its own media, so each
    // carries its own Trace.
    if (overflow <= 0) return tile;

    return Stack(
      fit: StackFit.expand,
      children: [
        tile,
        // The continuation. Deliberately a count rather than a "+N more"
        // button: the whole cell is already the affordance.
        IgnorePointer(
          child: Container(
            color: AuraSurface.ink.withValues(alpha: 0.55),
            alignment: Alignment.center,
            child: Text(
              '+$overflow',
              style: AuraText.title.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
