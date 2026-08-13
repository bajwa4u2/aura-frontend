import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/posts/presentation/widgets/post_card/post_card_utils.dart';
import 'inline_markdown.dart';

/// Item 15 — turns a plain-text segment into `InlineSpan`s carrying the
/// lightweight inline markdown subset (bold/italic/code/links), reusing
/// the pure tokenizer in `inline_markdown.dart`. Returns the produced
/// `TapGestureRecognizer`s so the caller (whichever State already manages
/// mention-tap recognizers, e.g. `ResolvedTagText`) can own their disposal
/// -- this function creates no State of its own, matching the existing
/// "wrap the controller" convention rather than adding a new widget layer.
///
/// A link's target is resolved the same way `InternalReferenceCard`/
/// `DisplayLinkPreview` do: an Aura-internal URL navigates in-app (the
/// destination screen's own existing authorization guard is authoritative
/// -- this is a navigation shortcut, not a new hydration/preview surface);
/// anything else opens externally. This does not duplicate Items 13/14's
/// resolution authority -- an inline link is just a navigational target,
/// the same as any other link tap elsewhere in the app.
({List<InlineSpan> spans, List<TapGestureRecognizer> recognizers})
    buildInlineRichSpans(
  BuildContext context,
  String text,
  TextStyle baseStyle,
) {
  final tokens = tokenizeInlineMarkdown(text);
  final spans = <InlineSpan>[];
  final recognizers = <TapGestureRecognizer>[];

  for (final token in tokens) {
    switch (token.type) {
      case InlineMarkdownTokenType.text:
        spans.add(TextSpan(text: token.text));
      case InlineMarkdownTokenType.bold:
        spans.add(TextSpan(
          text: token.text,
          style: baseStyle.copyWith(fontWeight: FontWeight.w700),
        ));
      case InlineMarkdownTokenType.italic:
        spans.add(TextSpan(
          text: token.text,
          style: baseStyle.copyWith(fontStyle: FontStyle.italic),
        ));
      case InlineMarkdownTokenType.code:
        spans.add(TextSpan(
          text: token.text,
          style: baseStyle.copyWith(
            fontFamily: 'monospace',
            fontSize: (baseStyle.fontSize ?? 14) - 1,
          ),
        ));
      case InlineMarkdownTokenType.link:
        final url = token.url ?? '';
        final recognizer = TapGestureRecognizer()
          ..onTap = () {
            if (url.isEmpty) return;
            if (isInternalAuraUrl(url)) {
              final path = Uri.tryParse(url)?.path;
              if (path != null && path.isNotEmpty) {
                GoRouter.of(context).push(path);
              }
              return;
            }
            openExternalUrl(context, url);
          };
        recognizers.add(recognizer);
        spans.add(TextSpan(
          text: token.text,
          style: baseStyle.copyWith(
            color: const Color(0xFFC9A55C),
            decoration: TextDecoration.underline,
          ),
          recognizer: recognizer,
        ));
    }
  }

  return (spans: spans, recognizers: recognizers);
}
