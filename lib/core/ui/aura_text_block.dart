import 'package:flutter/material.dart';

/// AuraTextBlock
///
/// A durable text primitive for Aura surfaces.
///
/// What it does:
/// - Detects RTL/LTR automatically from language or content
/// - Applies Directionality and alignment consistently
/// - Handles multi-paragraph text by resolving direction paragraph-by-paragraph
/// - Preserves manual override when a surface already knows the language/direction
/// - Supports both plain Text and selectable text
class AuraTextBlock extends StatelessWidget {
  const AuraTextBlock(
    this.text, {
    super.key,
    this.languageCode,
    this.textDirection,
    this.style,
    this.textAlign,
    this.overflow,
    this.maxLines,
    this.softWrap,
    this.semanticsLabel,
    this.locale,
    this.strutStyle,
    this.textScaler,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.paragraphSpacing = 8,
    this.selectable = false,
    this.trim = true,
    this.empty,
  });

  final String? text;

  /// Optional BCP-47-ish language hint such as: en, ur, ar, fa, he.
  final String? languageCode;

  /// Explicit override when direction is already known.
  final TextDirection? textDirection;

  final TextStyle? style;
  final TextAlign? textAlign;
  final TextOverflow? overflow;
  final int? maxLines;
  final bool? softWrap;
  final String? semanticsLabel;
  final Locale? locale;
  final StrutStyle? strutStyle;
  final TextScaler? textScaler;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;

  /// Vertical space inserted between detected paragraphs.
  final double paragraphSpacing;

  /// Wraps output in SelectionArea and uses SelectableText when true.
  final bool selectable;

  /// Trims surrounding whitespace while preserving paragraph breaks.
  final bool trim;

  /// Optional widget shown when text is null/empty.
  final Widget? empty;

  @override
  Widget build(BuildContext context) {
    final raw = text ?? '';
    final resolved = trim ? _normalize(raw) : raw;

    if (resolved.isEmpty) {
      return empty ?? const SizedBox.shrink();
    }

    final paragraphs = _splitParagraphs(resolved);

    Widget child;
    if (paragraphs.length == 1) {
      child = _buildParagraph(
        context,
        paragraphs.first,
        isLast: true,
      );
    } else {
      child = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < paragraphs.length; i++)
            Padding(
              padding: EdgeInsets.only(
                bottom: i == paragraphs.length - 1 ? 0 : paragraphSpacing,
              ),
              child: _buildParagraph(
                context,
                paragraphs[i],
                isLast: i == paragraphs.length - 1,
              ),
            ),
        ],
      );
    }

    return selectable ? SelectionArea(child: child) : child;
  }

  Widget _buildParagraph(
    BuildContext context,
    String paragraph, {
    required bool isLast,
  }) {
    final direction = textDirection ??
        AuraTextBlockDirection.resolve(
          paragraph,
          languageCode: languageCode,
          locale: locale ?? Localizations.maybeLocaleOf(context),
        );

    final effectiveAlign = _resolveTextAlign(direction);
    final effectiveLocale = locale ?? _localeFromLanguage(languageCode);

    final wrapped = Directionality(
      textDirection: direction,
      child: selectable
          ? SelectableText(
              paragraph,
              style: style,
              textAlign: effectiveAlign,
              strutStyle: strutStyle,
              semanticsLabel: semanticsLabel,
              maxLines: maxLines,
              textScaler: textScaler,
              textWidthBasis: textWidthBasis,
            )
          : Text(
              paragraph,
              style: style,
              textAlign: effectiveAlign,
              overflow: overflow,
              maxLines: maxLines,
              softWrap: softWrap,
              semanticsLabel: semanticsLabel,
              locale: effectiveLocale,
              strutStyle: strutStyle,
              textScaler: textScaler,
              textWidthBasis: textWidthBasis,
              textHeightBehavior: textHeightBehavior,
            ),
    );

    if (effectiveLocale == null || selectable) {
      return wrapped;
    }

    return Localizations.override(
      context: context,
      locale: effectiveLocale,
      child: wrapped,
    );
  }

  TextAlign _resolveTextAlign(TextDirection direction) {
    if (textAlign != null) return textAlign!;
    return direction == TextDirection.rtl ? TextAlign.right : TextAlign.left;
  }

  static String _normalize(String input) {
    final unix = input.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lines = unix.split('\n');
    return lines.map((line) => line.trim()).join('\n').trim();
  }

  static List<String> _splitParagraphs(String value) {
    return value
        .split(RegExp(r'\n{2,}|\u2029'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList(growable: false);
  }

  static Locale? _localeFromLanguage(String? languageCode) {
    final code = AuraTextBlockDirection.normalizeLanguageCode(languageCode);
    if (code == null || code.isEmpty) return null;
    return Locale(code);
  }
}

/// Direction resolver used by AuraTextBlock.
///
/// Priority:
/// 1. Explicit language hint
/// 2. Locale language
/// 3. First strong directional character in the text
/// 4. LTR fallback
final class AuraTextBlockDirection {
  AuraTextBlockDirection._();

  static const Set<String> _rtlLanguages = {
    'ar', // Arabic
    'fa', // Persian / Farsi
    'he', // Hebrew
    'iw', // legacy Hebrew code
    'ku', // Kurdish (often Arabic script)
    'ps', // Pashto
    'sd', // Sindhi
    'ug', // Uyghur
    'ur', // Urdu
    'yi', // Yiddish
  };

  static TextDirection resolve(
    String? text, {
    String? languageCode,
    Locale? locale,
  }) {
    final explicit = normalizeLanguageCode(languageCode);
    if (explicit != null) {
      return isRtlLanguage(explicit) ? TextDirection.rtl : TextDirection.ltr;
    }

    final localeCode = normalizeLanguageCode(locale?.languageCode);
    if (localeCode != null && isRtlLanguage(localeCode)) {
      return TextDirection.rtl;
    }

    final fromText = _detectFromText(text ?? '');
    return fromText ?? TextDirection.ltr;
  }

  static bool isRtlLanguage(String? languageCode) {
    final code = normalizeLanguageCode(languageCode);
    return code != null && _rtlLanguages.contains(code);
  }

  static String? normalizeLanguageCode(String? languageCode) {
    if (languageCode == null) return null;
    final cleaned = languageCode.trim();
    if (cleaned.isEmpty) return null;
    return cleaned.toLowerCase().replaceAll('_', '-').split('-').first;
  }

  static TextDirection? _detectFromText(String text) {
    for (final rune in text.runes) {
      if (_isRtlRune(rune)) return TextDirection.rtl;
      if (_isLtrRune(rune)) return TextDirection.ltr;
    }
    return null;
  }

  static bool _isRtlRune(int rune) {
    return (rune >= 0x0590 && rune <= 0x05FF) || // Hebrew
        (rune >= 0x0600 && rune <= 0x06FF) || // Arabic
        (rune >= 0x0750 && rune <= 0x077F) || // Arabic Supplement
        (rune >= 0x08A0 && rune <= 0x08FF) || // Arabic Extended-A
        (rune >= 0xFB50 && rune <= 0xFDFF) || // Arabic Presentation Forms-A
        (rune >= 0xFE70 && rune <= 0xFEFF) || // Arabic Presentation Forms-B
        (rune >= 0x10E60 && rune <= 0x10E7F) ||
        (rune >= 0x1EE00 && rune <= 0x1EEFF);
  }

  static bool _isLtrRune(int rune) {
    return (rune >= 0x0041 && rune <= 0x005A) || // A-Z
        (rune >= 0x0061 && rune <= 0x007A) || // a-z
        (rune >= 0x00C0 && rune <= 0x02AF) || // Latin extended
        (rune >= 0x0370 && rune <= 0x052F) || // Greek + Cyrillic
        (rune >= 0x0900 && rune <= 0x097F) || // Devanagari
        (rune >= 0x0980 && rune <= 0x09FF) || // Bengali
        (rune >= 0x0A00 && rune <= 0x0A7F) || // Gurmukhi
        (rune >= 0x3040 && rune <= 0x30FF) || // Japanese kana
        (rune >= 0x4E00 && rune <= 0x9FFF) || // CJK unified ideographs
        (rune >= 0xAC00 && rune <= 0xD7AF); // Hangul syllables
  }
}
