/// PUBLICATION TITLE — F026.
///
/// THE DEFECT THIS REPLACES. The article editor rendered its title field at
/// `AuraText.display` (40px) with `maxLines: 2`, and the published article
/// rendered it at the same fixed 40px. A pasted title therefore OVERSIZED: a
/// long headline either clipped inside the field while writing or ran past its
/// column once published, and a title pasted from a document brought its
/// newlines with it — each one consuming a whole 40px line of a two-line box.
///
/// TWO CAUSES, TWO FIXES, ONE AUTHORITY.
///
///   1. SHAPE. A title is one line of text by definition. Pasted newlines,
///      tabs and non-breaking spaces are shape, not content, and are
///      normalised to single spaces. NO WORD IS EVER REMOVED and the title is
///      NEVER TRUNCATED — the author's words are theirs.
///
///   2. SIZE. The size now follows the title's LENGTH as well as the
///      viewport. A four-word headline still lands at full display weight; a
///      long one steps down to a size that fits its column instead of
///      overflowing it.
///
/// The editor field, the editor's preview and the published article all draw
/// their title from here, so a title cannot look one size while being written
/// and another size once published.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../aura_text.dart';

/// Whitespace a pasted title carries in but a title never means. `\s`
/// covers the ordinary controls plus the Unicode spaces a word processor
/// leaves behind, including the non-breaking space.
final RegExp _shapeWhitespace = RegExp(r'\s+');
final RegExp _leadingSpaces = RegExp(r'^ +');

/// Normalises the SHAPE of a title without touching its words.
///
/// A trailing single space is deliberately preserved: this runs on every
/// keystroke, and trimming the end would make it impossible to type a space
/// between two words.
String normalizePublicationTitle(String raw) {
  return raw
      .replaceAll(_shapeWhitespace, ' ')
      .replaceFirst(_leadingSpaces, '');
}

/// Applies [normalizePublicationTitle] to typing AND to paste, which is the
/// path F026 was actually reported from.
class PublicationTitleInputFormatter extends TextInputFormatter {
  const PublicationTitleInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final normalized = normalizePublicationTitle(newValue.text);
    if (normalized == newValue.text) return newValue;

    // Anchor the caret by normalising the text BEFORE it. Clamping a raw
    // offset against a shortened string would drop the caret to the wrong
    // word after a multi-line paste.
    final rawCaret = newValue.selection.baseOffset;
    final caret = rawCaret < 0
        ? normalized.length
        : normalizePublicationTitle(
            newValue.text.substring(0, rawCaret.clamp(0, newValue.text.length)),
          ).length;

    return TextEditingValue(
      text: normalized,
      selection: TextSelection.collapsed(
        offset: caret.clamp(0, normalized.length),
      ),
      composing: TextRange.empty,
    );
  }
}

/// Font size for a publication title, from its length and the viewport.
///
/// Deterministic and pure so the scale is unit-testable rather than something
/// only a screenshot can confirm.
double publicationTitleFontSize({
  required int characters,
  required double viewportWidth,
}) {
  // Mobile starts lower for the same reason the publication hero does: 40px
  // never fits a headline on a 360px screen.
  final base = viewportWidth < 600 ? 28.0 : 40.0;

  // A short headline keeps full display weight. Past that, the size steps
  // down with length and stops at a floor that is still unmistakably a title.
  const fullWeightUpTo = 48;
  const smallestAt = 170;
  if (characters <= fullWeightUpTo) return base;

  final t = ((characters - fullWeightUpTo) / (smallestAt - fullWeightUpTo))
      .clamp(0.0, 1.0);
  final scaled = base - (base - base * 0.55) * t;
  return scaled < 20.0 ? 20.0 : scaled;
}

/// The title text style, matched to what is actually being displayed.
TextStyle publicationTitleStyle({
  required String title,
  required double viewportWidth,
}) {
  final size = publicationTitleFontSize(
    characters: title.trim().length,
    viewportWidth: viewportWidth,
  );
  // Long titles need a little more leading, or the descenders of a
  // three-line headline collide.
  return AuraText.display.copyWith(
    fontSize: size,
    height: size >= 34 ? 1.08 : 1.18,
  );
}

/// A published or previewed publication title.
class AuraPublicationTitle extends StatelessWidget {
  const AuraPublicationTitle(this.title, {super.key, this.placeholder});

  final String title;

  /// Shown when the title is still empty — the editor's preview needs
  /// something to render, and an empty headline reads as a broken page.
  final String? placeholder;

  @override
  Widget build(BuildContext context) {
    final shown = title.trim().isEmpty ? (placeholder ?? '') : title.trim();
    return Text(
      shown,
      style: publicationTitleStyle(
        title: shown,
        viewportWidth: MediaQuery.of(context).size.width,
      ),
    );
  }
}
