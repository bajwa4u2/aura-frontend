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
  required double availableWidth,
}) {
  // BASE FOLLOWS THE COLUMN THE TITLE ACTUALLY OCCUPIES.
  //
  // This used to read the VIEWPORT width, which is not the space a title has.
  // The article reader caps its column at 760px however wide the display is, so
  // on any desktop a headline was sized as though it owned the whole screen and
  // then wrapped inside a column half that width — the reported "dominates the
  // viewport" defect.
  //
  // The ceiling also drops out of the type scale rather than being invented:
  // AuraText.display (40) is documented "hero moments, landing page headlines
  // only", and a long-form reading column is not a hero. Against 15px body
  // text, 40px was a 2.7x jump; 32px keeps the title unmistakably dominant at
  // a ratio long-form reading can carry.
  final base = availableWidth < 380
      ? 24.0
      : availableWidth < 620
          ? 28.0
          : 32.0;

  if (characters <= 0) return base;

  // A short headline keeps full weight. Past that, the size steps down with
  // length and stops at a floor that is still unmistakably a title.
  const fullWeightUpTo = 48;
  const smallestAt = 170;
  var size = base;
  if (characters > fullWeightUpTo) {
    final t = ((characters - fullWeightUpTo) / (smallestAt - fullWeightUpTo))
        .clamp(0.0, 1.0);
    size = base - (base - base * 0.55) * t;
  }

  // FIT CAP. Length alone cannot know how wide the column is, so a title that
  // still would not fit steps down until it does. Three lines is the most a
  // headline may claim before it stops being a title and becomes the page.
  // 0.52em is a deliberately conservative average advance for this face —
  // underestimating it would let a title overflow, which is the failure mode
  // that matters.
  const advancePerChar = 0.52;
  const maxLines = 3;
  final fit = (availableWidth * maxLines) / (characters * advancePerChar);
  if (fit < size) size = fit;

  return size < 20.0 ? 20.0 : size;
}

/// The title text style, matched to what is actually being displayed.
TextStyle publicationTitleStyle({
  required String title,
  required double availableWidth,
}) {
  final size = publicationTitleFontSize(
    characters: title.trim().length,
    availableWidth: availableWidth,
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
    // LayoutBuilder, not MediaQuery: the title must be sized by the column it
    // is placed in, which on a wide display is far narrower than the window.
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        return Text(
          shown,
          style: publicationTitleStyle(title: shown, availableWidth: width),
        );
      },
    );
  }
}
