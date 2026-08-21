import 'package:flutter/material.dart';

import '../aura_radius.dart';
import '../aura_surface.dart';
import '../aura_text.dart';

/// ARTICLE COVER — ONE presentation contract, used by the reader AND by the
/// composer's preview.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// WHY THIS EXISTS AS A SHARED WIDGET
///
/// The first version had the reader draw the cover inline and gave the composer
/// no preview at all. The author therefore could not see what they were about to
/// publish, and the reader's treatment was free to disagree with whatever the
/// author imagined. Two answers to one question, and the author only discovers
/// the real one after publishing.
///
/// So the reader and the composer render through this and nothing else. What the
/// author sees while composing is what readers get, because it is literally the
/// same widget.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// WHY IT DOES NOT CROP
///
/// The first version used `AspectRatio(16/9)` with `BoxFit.cover`, which is a
/// decision to DISCARD composition: a landscape artwork lost a substantial part
/// of its lower composition because the frame, not the artwork, decided the
/// shape. A cover is authored media — the author chose that image and that
/// framing — and a publication surface has no business silently re-cropping it.
///
/// The frame therefore follows the IMAGE: the cover fills the column's width and
/// takes whatever height its own aspect ratio requires, capped so that an
/// extremely tall image cannot push the headline off the screen. Nothing is
/// cropped; a very tall image is scaled down whole rather than trimmed.
///
/// Editorial cropping is a legitimate feature — but it is an intentional
/// authoring act, not something a renderer does on the author's behalf without
/// telling them.
/// ─────────────────────────────────────────────────────────────────────────────
class AuraArticleCover extends StatelessWidget {
  const AuraArticleCover(
    this.url, {
    super.key,
    this.onRetry,
    this.showFailure = false,
  });

  final String url;

  /// Composer-only affordance. A reader can do nothing about a failed image, so
  /// they are not offered a button; an author can re-pick, so they are.
  final VoidCallback? onRetry;

  /// Readers get silence on failure — a broken frame above a headline is worse
  /// than no frame. Authors get told, because an author who cannot see their
  /// cover needs to know whether it is missing or merely still loading.
  final bool showFailure;

  /// Tallest a cover may be before it is scaled down whole.
  ///
  /// Bounded against the VIEWPORT rather than a fixed number: on a laptop this
  /// keeps the headline visible with the cover, and on a phone it stops a
  /// portrait image from becoming the entire first screen. It never crops — it
  /// only decides when to stop growing.
  static double maxHeightFor(double viewportHeight) {
    final cap = viewportHeight * 0.6;
    if (cap < 220) return 220;
    if (cap > 620) return 620;
    return cap;
  }

  @override
  Widget build(BuildContext context) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return const SizedBox.shrink();
    final maxHeight = maxHeightFor(MediaQuery.of(context).size.height);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AuraRadius.md),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Image.network(
          trimmed,
          width: double.infinity,
          // CONTAIN, never cover: the whole authored composition survives.
          fit: BoxFit.contain,
          alignment: Alignment.center,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            // A determinate bar where the total is known, so a large cover on a
            // slow connection reads as loading rather than as broken.
            final total = progress.expectedTotalBytes;
            return Container(
              height: 220,
              color: AuraSurface.card,
              alignment: Alignment.center,
              child: SizedBox(
                width: 120,
                child: LinearProgressIndicator(
                  value: total == null
                      ? null
                      : progress.cumulativeBytesLoaded / total,
                  minHeight: 3,
                ),
              ),
            );
          },
          errorBuilder: (context, _, __) {
            if (!showFailure) return const SizedBox.shrink();
            return Container(
              height: 220,
              color: AuraSurface.card,
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('This cover could not be loaded.',
                      style: AuraText.small.copyWith(color: AuraSurface.muted)),
                  if (onRetry != null) ...[
                    const SizedBox(height: 8),
                    TextButton(onPressed: onRetry, child: const Text('Choose another')),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
