/// TR SITS ON THE MEDIA'S OWN CORNER (founder, 2026-10-26).
///
/// Callers used to stack TR over the widget they held, at its bottom-start.
/// That box is the media's whole slot, not the picture: since 2026-09-30 feeds
/// and detail pages CENTRE their media, so the picture is a narrower shape in
/// the middle of a full-width box and TR floated in the empty space beside it.
/// A video wrapped with its caption put TR under the caption.
///
/// Only the renderer knows where the media is actually painted, so the caller
/// hands the mark DOWN and the renderer places it on its own sized box:
///
///   * [AuraMediaFrame] (every image): always bottom-start;
///   * [AuraVideoSurface] (every video): always bottom-end, because the
///     bottom-start corner belongs to the feed's mute control. Fixed per
///     kind, never moved by playback state (founder: "TR should be
///     deterministic").
///
/// The first renderer to place the mark clears it for anything nested inside,
/// so a poster frame inside a video surface cannot draw it twice.
library;

import 'package:flutter/widgets.dart';

class MediaCornerMark extends InheritedWidget {
  const MediaCornerMark({super.key, required this.mark, required super.child});

  /// Hide any mark handed down from above (used once a renderer placed it).
  const MediaCornerMark.clear({super.key, required super.child}) : mark = null;

  final Widget? mark;

  static Widget? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MediaCornerMark>()?.mark;

  /// Inset from the media's bottom-start corner.
  static const double inset = 6;

  @override
  bool updateShouldNotify(MediaCornerMark oldWidget) => mark != oldWidget.mark;
}
