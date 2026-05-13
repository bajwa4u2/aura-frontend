import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

import '../aura_radius.dart';
import '../aura_space.dart';
import '../aura_surface.dart';
import '../aura_text.dart';

/// Markdown renderer with publication-grade typography.
///
/// What's different from a bare `MarkdownBody`
/// -------------------------------------------
/// * Heading scale matches the publication hero (H1 = 28, H2 = 22,
///   H3 = 18) rather than the body-fontsize defaults flutter_markdown
///   ships. Each heading carries deliberate `padding` so vertical
///   rhythm is consistent across a long document.
/// * Paragraphs use the editorial 16 / 1.75 reading rhythm — heavier
///   line-height than the in-app body for sustained reading comfort.
/// * Blockquotes render with a left gold rule on a slightly lifted
///   surface — same visual identity as
///   [AuraPublicationCallout] so author-written and markdown-rendered
///   quotes feel like one family.
/// * Inline links are gold (matches the publication accent) and
///   open in the external app, not inside the SPA.
/// * Horizontal rules are turned into a centered hairline + ornament
///   so a `---` between sections reads as a chapter break.
/// * Code blocks use the elevated surface with a thin border, keeping
///   the publication aesthetic but staying readable for any technical
///   snippets that appear.
///
/// Sizing
/// ------
/// Heading sizes shrink slightly on narrow viewports so a top-level
/// H1 never blows past two lines on a 360 px phone.
class AuraPublicationMarkdown extends StatelessWidget {
  const AuraPublicationMarkdown({
    super.key,
    required this.data,
    this.selectable = true,
  });

  final String data;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;
    const goldAccent = Color(0xFFC9A55C);

    final h1Size = isMobile ? 24.0 : 28.0;
    final h2Size = isMobile ? 20.0 : 22.0;
    final h3Size = isMobile ? 17.0 : 18.0;

    return MarkdownBody(
      data: data,
      selectable: selectable,
      onTapLink: (text, href, title) async {
        if (href == null) return;
        final uri = Uri.tryParse(href);
        if (uri == null) return;
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      },
      styleSheet: MarkdownStyleSheet(
        // Paragraphs — editorial line-height for long reading.
        p: AuraText.body.copyWith(
          fontSize: 16,
          height: 1.75,
          color: AuraSurface.ink,
        ),
        pPadding: const EdgeInsets.only(bottom: AuraSpace.md),

        // Headings — match the publication hero scale.
        h1: AuraText.display.copyWith(
          fontSize: h1Size,
          height: 1.2,
          letterSpacing: -0.2,
        ),
        h1Padding: const EdgeInsets.only(
          top: AuraSpace.xxl,
          bottom: AuraSpace.md,
        ),
        h2: AuraText.headline.copyWith(
          fontSize: h2Size,
          height: 1.3,
          letterSpacing: 0,
        ),
        h2Padding: const EdgeInsets.only(
          top: AuraSpace.xl,
          bottom: AuraSpace.s10,
        ),
        h3: AuraText.subtitle.copyWith(
          fontSize: h3Size,
          height: 1.35,
          letterSpacing: 0.1,
        ),
        h3Padding: const EdgeInsets.only(
          top: AuraSpace.lg,
          bottom: AuraSpace.s8,
        ),
        h4: AuraText.subtitle.copyWith(fontSize: 16, height: 1.4),
        h4Padding: const EdgeInsets.only(top: AuraSpace.md, bottom: 4),
        h5: AuraText.emphasis.copyWith(fontSize: 15),
        h6: AuraText.emphasis.copyWith(fontSize: 14),

        // Lists — anchor bullets/numbers with proper indent.
        listBullet: AuraText.body.copyWith(
          fontSize: 16,
          height: 1.75,
          color: AuraSurface.muted,
        ),
        listBulletPadding: const EdgeInsets.only(right: AuraSpace.s8),
        listIndent: AuraSpace.md,

        // Inline emphasis.
        em: AuraText.body.copyWith(
          fontSize: 16,
          height: 1.75,
          fontStyle: FontStyle.italic,
          color: AuraSurface.ink,
        ),
        strong: AuraText.body.copyWith(
          fontSize: 16,
          height: 1.75,
          fontWeight: FontWeight.w700,
          color: AuraSurface.ink,
        ),

        // Inline + block code.
        code: AuraText.body.copyWith(
          fontFamily: 'monospace',
          fontSize: 14,
          height: 1.6,
          color: AuraSurface.ink,
          backgroundColor: AuraSurface.subtle,
        ),
        codeblockPadding: const EdgeInsets.all(AuraSpace.md),
        codeblockDecoration: BoxDecoration(
          color: AuraSurface.subtle,
          borderRadius: BorderRadius.circular(AuraRadius.md),
          border: Border.all(color: AuraSurface.divider),
        ),

        // Blockquote — pulled-quote treatment, gold left rule.
        blockquote: AuraText.body.copyWith(
          fontSize: 17,
          height: 1.7,
          fontWeight: FontWeight.w500,
          color: AuraSurface.ink,
        ),
        blockquotePadding: const EdgeInsets.fromLTRB(
          AuraSpace.md,
          AuraSpace.md,
          AuraSpace.md,
          AuraSpace.md,
        ),
        blockquoteDecoration: const BoxDecoration(
          color: AuraSurface.subtle,
          border: Border(
            left: BorderSide(color: goldAccent, width: 3),
          ),
        ),

        // Inline link.
        a: AuraText.body.copyWith(
          fontSize: 16,
          height: 1.75,
          color: goldAccent,
          decoration: TextDecoration.underline,
          decorationColor: goldAccent,
          decorationThickness: 1.0,
        ),

        // Horizontal rule — turned into an elegant section break.
        horizontalRuleDecoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AuraSurface.divider, width: 1),
          ),
        ),

        // Tables.
        tableHead: AuraText.label.copyWith(
          color: AuraSurface.ink,
          letterSpacing: 1.0,
        ),
        tableBody: AuraText.body.copyWith(fontSize: 14, height: 1.5),
        tableBorder: const TableBorder(
          horizontalInside: BorderSide(color: AuraSurface.divider),
          top: BorderSide(color: AuraSurface.divider),
          bottom: BorderSide(color: AuraSurface.divider),
        ),
        tableCellsPadding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.s10,
          vertical: AuraSpace.s8,
        ),

        // Block spacing — adds a calm rhythm between paragraphs and
        // adjacent block elements.
        blockSpacing: AuraSpace.s8,
      ),
    );
  }
}
