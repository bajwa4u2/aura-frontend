import 'package:flutter/gestures.dart';
import '../../../core/ui/aura_text_block.dart' show AuraTextBlockDirection;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/tagging/tag_entities.dart';
import '../../../core/rich_content/inline_rich_span_builder.dart';

/// Public-UX Phase 6.1 / AXR-1 — renders body text with governed tags
/// styled as accent links: `@handle` substrings tap to `/u/:handle`,
/// and `#Topic` substrings tap to topic search.
///
/// Detection mirrors the backend `extractHandles` regex:
/// `(^|[^a-zA-Z0-9_])@([a-zA-Z0-9_]{2,32})`. Email-style addresses
/// (`x@y.z`) are skipped because the char before `@` must not be a
/// word char. `#Topic` uses the same word-boundary rule.
class MentionText extends StatefulWidget {
  const MentionText(
    this.text, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
  });

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  State<MentionText> createState() => _MentionTextState();
}

/// AXR-1 — non-interactive tag styling for preview surfaces (feed cards)
/// where the whole card is the tap target: `@handle` / `#Topic` render in
/// the accent style but carry no recognizers, so card navigation never
/// competes with span taps. Detail surfaces use [MentionText] instead.
class TagStyledText extends StatelessWidget {
  const TagStyledText(
    this.text, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
  });

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final base = style ?? AuraText.body;
    final t = text;
    if (t.isEmpty) return Text(t, style: base);
    // A post reads in the direction of its own first letter, as the web's
    // dir="auto" does: Urdu and Arabic right to left, aligned to their start
    // (founder, 2026-09-29: published Urdu was laid out left to right).
    final dir = AuraTextBlockDirection.resolve(t);

    final re = RegExp(r'(^|[^a-zA-Z0-9_])([@#])([a-zA-Z0-9_\-]{2,32})');
    final matches = re.allMatches(t).toList();
    if (matches.isEmpty) {
      return _placed(dir, Text(t, style: base, maxLines: maxLines, overflow: overflow,
          textDirection: dir, textAlign: TextAlign.start));
    }

    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final m in matches) {
      final lead = m.group(1) ?? '';
      final tagStart = m.start + lead.length;
      if (tagStart > cursor) {
        spans.add(TextSpan(text: t.substring(cursor, tagStart), style: base));
      }
      spans.add(
        TextSpan(
          text: '${m.group(2)}${m.group(3)}',
          style: base.copyWith(
            color: AuraSurface.accentText,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
      cursor = m.end;
    }
    if (cursor < t.length) {
      spans.add(TextSpan(text: t.substring(cursor), style: base));
    }

    return _placed(dir, RichText(
      text: TextSpan(style: base, children: spans),
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
      textDirection: dir,
      textAlign: TextAlign.start,
    ));
  }
}

class ResolvedTagText extends StatefulWidget {
  const ResolvedTagText(
    this.text, {
    super.key,
    this.tagReferences = const <TagReference>[],
    this.style,
    this.maxLines,
    this.overflow,
    this.selectable = false,
  });

  final String text;
  final List<TagReference> tagReferences;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool selectable;

  @override
  State<ResolvedTagText> createState() => _ResolvedTagTextState();
}

class _ResolvedTagTextState extends State<ResolvedTagText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final refs = widget.tagReferences.where((r) => r.isMention).toList();
    if (refs.isEmpty) {
      return TagStyledText(
        widget.text,
        style: widget.style,
        maxLines: widget.maxLines,
        overflow: widget.overflow,
      );
    }

    final base = widget.style ?? AuraText.body;
    final spans = <InlineSpan>[];
    final ranges = _ranges(widget.text, refs);
    var cursor = 0;

    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();

    for (final item in ranges) {
      if (item.start < cursor) continue;
      if (item.start > cursor) {
        final plain = buildInlineRichSpans(
          context,
          widget.text.substring(cursor, item.start),
          base,
        );
        spans.addAll(plain.spans);
        _recognizers.addAll(plain.recognizers);
      }
      final recognizer = TapGestureRecognizer()
        ..onTap = () => _openReference(context, item.reference);
      _recognizers.add(recognizer);
      spans.add(
        TextSpan(
          text: item.reference.displayToken,
          style: base.copyWith(
            color: AuraSurface.accentText,
            fontWeight: FontWeight.w800,
          ),
          recognizer: recognizer,
        ),
      );
      cursor = item.end;
    }

    if (cursor < widget.text.length) {
      final plain = buildInlineRichSpans(
        context,
        widget.text.substring(cursor),
        base,
      );
      spans.addAll(plain.spans);
      _recognizers.addAll(plain.recognizers);
    }

    final span = TextSpan(style: base, children: spans);
    final dir = AuraTextBlockDirection.resolve(widget.text);
    if (widget.selectable) {
      return _placed(dir, SelectableText.rich(span,
          maxLines: widget.maxLines,
          textDirection: dir,
          textAlign: TextAlign.start));
    }
    return _placed(dir, RichText(
      text: span,
      maxLines: widget.maxLines,
      overflow: widget.overflow ?? TextOverflow.clip,
      textDirection: dir,
      textAlign: TextAlign.start,
    ));
  }

  List<_ResolvedRange> _ranges(String text, List<TagReference> refs) {
    final ranges = <_ResolvedRange>[];
    var searchFrom = 0;
    for (final ref in refs) {
      final source = ref.durableSourceText;
      if (source.isEmpty) continue;
      var start = ref.startOffset;
      var end = ref.endOffset;
      final hasValidRange =
          start != null &&
          end != null &&
          start >= 0 &&
          end <= text.length &&
          start < end &&
          text.substring(start, end) == source;
      if (!hasValidRange) {
        start = text.indexOf(source, searchFrom);
        end = start < 0 ? -1 : start + source.length;
      }
      if (start < 0 || end > text.length) {
        continue;
      }
      ranges.add(_ResolvedRange(start, end, ref));
      searchFrom = end;
    }
    ranges.sort((a, b) => a.start.compareTo(b.start));
    return ranges;
  }

  void _openReference(BuildContext context, TagReference reference) {
    final route = (reference.identity?.route ?? '').trim();
    if (route.isNotEmpty) {
      GoRouter.of(context).push(route);
      return;
    }
    final slug = (reference.identity?.handleOrSlug ?? '').trim();
    if (slug.isEmpty) return;
    if (reference.kind == TagKind.institution) {
      GoRouter.of(context).push('/institutions/$slug');
    } else {
      GoRouter.of(context).push('/u/$slug');
    }
  }
}

class _ResolvedRange {
  const _ResolvedRange(this.start, this.end, this.reference);

  final int start;
  final int end;
  final TagReference reference;
}

class _MentionTextState extends State<MentionText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.style ?? AuraText.body;
    final t = widget.text;
    if (t.isEmpty) return Text(t, style: base);
    // A post reads in the direction of its own first letter, as the web's
    // dir="auto" does: Urdu and Arabic right to left, aligned to their start
    // (founder, 2026-09-29: published Urdu was laid out left to right).
    final dir = AuraTextBlockDirection.resolve(t);

    final re = RegExp(r'(^|[^a-zA-Z0-9_])([@#])([a-zA-Z0-9_\-]{2,32})');
    final matches = re.allMatches(t).toList();
    if (matches.isEmpty) {
      return _placed(dir, Text(
        t,
        style: base,
        maxLines: widget.maxLines,
        overflow: widget.overflow,
        textDirection: dir,
        textAlign: TextAlign.start,
      ));
    }

    // Reset recognizers each build — match count can change.
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();

    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final m in matches) {
      // The handle starts at m.start + length of the leading group.
      final lead = m.group(1) ?? '';
      final handleStart = m.start + lead.length;
      // Emit any unmatched leading text + the lead char (it's part of
      // the surrounding prose, not the handle).
      if (handleStart > cursor) {
        spans.add(
          TextSpan(text: t.substring(cursor, handleStart), style: base),
        );
      }
      final sigil = m.group(2) ?? '@';
      final body = m.group(3) ?? '';
      final recognizer = TapGestureRecognizer()
        ..onTap = () {
          final b = body.trim();
          if (b.isEmpty) return;
          if (sigil == '#') {
            // Governed topic tag — open search scoped to the tag.
            GoRouter.of(
              context,
            ).push('/search?q=${Uri.encodeComponent('#$b')}');
            return;
          }
          // Routing layer owns handle resolution. We just navigate.
          GoRouter.of(context).push('/u/$b');
        };
      _recognizers.add(recognizer);
      spans.add(
        TextSpan(
          text: '$sigil$body',
          style: base.copyWith(
            color: AuraSurface.accentText,
            fontWeight: FontWeight.w700,
          ),
          recognizer: recognizer,
        ),
      );
      cursor = m.end;
    }
    if (cursor < t.length) {
      spans.add(TextSpan(text: t.substring(cursor), style: base));
    }

    return _placed(dir, RichText(
      text: TextSpan(style: base, children: spans),
      maxLines: widget.maxLines,
      overflow: widget.overflow ?? TextOverflow.clip,
      textDirection: dir,
      textAlign: TextAlign.start,
    ));
  }
}

/// Right-to-left text starts at the right edge of its space; left-to-right
/// layouts are left exactly as they were. In unbounded width Align shrinks to
/// the text, so this is safe inside a Row.
Widget _placed(TextDirection dir, Widget child) => dir == TextDirection.rtl
    ? Align(alignment: Alignment.topRight, child: child)
    : child;
