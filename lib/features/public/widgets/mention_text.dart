import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';

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

    final re = RegExp(r'(^|[^a-zA-Z0-9_])([@#])([a-zA-Z0-9_\-]{2,32})');
    final matches = re.allMatches(t).toList();
    if (matches.isEmpty) {
      return Text(t, style: base, maxLines: maxLines, overflow: overflow);
    }

    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final m in matches) {
      final lead = m.group(1) ?? '';
      final tagStart = m.start + lead.length;
      if (tagStart > cursor) {
        spans.add(TextSpan(text: t.substring(cursor, tagStart), style: base));
      }
      spans.add(TextSpan(
        text: '${m.group(2)}${m.group(3)}',
        style: base.copyWith(
          color: AuraSurface.accentText,
          fontWeight: FontWeight.w700,
        ),
      ));
      cursor = m.end;
    }
    if (cursor < t.length) {
      spans.add(TextSpan(text: t.substring(cursor), style: base));
    }

    return RichText(
      text: TextSpan(style: base, children: spans),
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
    );
  }
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

    final re = RegExp(r'(^|[^a-zA-Z0-9_])([@#])([a-zA-Z0-9_\-]{2,32})');
    final matches = re.allMatches(t).toList();
    if (matches.isEmpty) {
      return Text(
        t,
        style: base,
        maxLines: widget.maxLines,
        overflow: widget.overflow,
      );
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
        spans.add(TextSpan(
          text: t.substring(cursor, handleStart),
          style: base,
        ));
      }
      final sigil = m.group(2) ?? '@';
      final body = m.group(3) ?? '';
      final recognizer = TapGestureRecognizer()
        ..onTap = () {
          final b = body.trim();
          if (b.isEmpty) return;
          if (sigil == '#') {
            // Governed topic tag — open search scoped to the tag.
            GoRouter.of(context)
                .push('/search?q=${Uri.encodeComponent('#$b')}');
            return;
          }
          // Routing layer owns handle resolution. We just navigate.
          GoRouter.of(context).push('/u/$b');
        };
      _recognizers.add(recognizer);
      spans.add(TextSpan(
        text: '$sigil$body',
        style: base.copyWith(
          color: AuraSurface.accentText,
          fontWeight: FontWeight.w700,
        ),
        recognizer: recognizer,
      ));
      cursor = m.end;
    }
    if (cursor < t.length) {
      spans.add(TextSpan(text: t.substring(cursor), style: base));
    }

    return RichText(
      text: TextSpan(style: base, children: spans),
      maxLines: widget.maxLines,
      overflow: widget.overflow ?? TextOverflow.clip,
    );
  }
}
