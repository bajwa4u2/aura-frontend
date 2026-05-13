import 'package:flutter/material.dart';

import '../aura_space.dart';
import '../aura_surface.dart';
import '../aura_text.dart';

/// Editorial primitives for hand-authored publication content
/// (mission, founder, supporters, patrons). These are the
/// publication-system counterpart to the older `Doc.*` helpers in
/// `document_scaffold.dart` — same intent, tightened typography,
/// stronger rhythm.
///
/// Why a separate family
/// ---------------------
/// `Doc.*` powers legal/policy pages where the visual register is
/// "form, not document". Publication pages need editorial weight:
/// larger headings, generous lede line-height, callouts that read as
/// pulled quotes. Keeping the families separate lets us evolve the
/// publication aesthetic without disturbing privacy/terms/etc.
class PubText {
  PubText._();

  /// Lede — first paragraph after a hero. Larger, looser, used once
  /// per page to anchor the reading.
  static Widget lede(String text) => Padding(
        padding: const EdgeInsets.only(top: AuraSpace.md),
        child: Text(
          text,
          style: AuraText.body.copyWith(
            fontSize: 17,
            height: 1.8,
            color: AuraSurface.ink,
          ),
        ),
      );

  /// Section heading. Larger and more breathing room than `Doc.h`.
  static Widget h(String text) => Padding(
        padding: const EdgeInsets.only(
          top: AuraSpace.xxl,
          bottom: AuraSpace.s10,
        ),
        child: Text(
          text,
          style: AuraText.headline.copyWith(
            fontSize: 22,
            height: 1.3,
            letterSpacing: 0,
          ),
        ),
      );

  /// Body paragraph.
  static Widget p(String text) => Padding(
        padding: const EdgeInsets.only(bottom: AuraSpace.md),
        child: Text(
          text,
          style: AuraText.body.copyWith(fontSize: 16, height: 1.75),
        ),
      );

  /// Bullet list — used sparingly.
  static Widget bullets(List<String> items) => Padding(
        padding: const EdgeInsets.only(bottom: AuraSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: items
              .map(
                (x) => Padding(
                  padding: const EdgeInsets.only(bottom: AuraSpace.s10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: Icon(
                          Icons.circle,
                          size: 5,
                          color: AuraSurface.muted,
                        ),
                      ),
                      const SizedBox(width: AuraSpace.s10),
                      Expanded(
                        child: Text(
                          x,
                          style: AuraText.body.copyWith(
                            fontSize: 16,
                            height: 1.7,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      );
}

/// Pulled-quote callout used to anchor key statements in a
/// publication. Reads with a left rule and a slightly lifted surface
/// so it's distinct from the body text.
class AuraPublicationCallout extends StatelessWidget {
  const AuraPublicationCallout({
    super.key,
    required this.text,
    this.attribution,
  });

  final String text;
  final String? attribution;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: AuraSpace.lg),
      padding: const EdgeInsets.all(AuraSpace.lg),
      decoration: const BoxDecoration(
        color: AuraSurface.subtle,
        border: Border(
          left: BorderSide(color: Color(0xFFC9A55C), width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: AuraText.body.copyWith(
              fontSize: 17,
              height: 1.65,
              fontWeight: FontWeight.w500,
              color: AuraSurface.ink,
            ),
          ),
          if ((attribution ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s10),
            Text(
              attribution!.toUpperCase(),
              style: AuraText.micro.copyWith(
                letterSpacing: 1.2,
                color: AuraSurface.muted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Elegant section divider — a hairline rule with optional centered
/// ornament. Reads as a chapter break, not a default `<hr>`.
class AuraPublicationDivider extends StatelessWidget {
  const AuraPublicationDivider({super.key, this.ornament = '§'});

  final String ornament;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AuraSpace.xl),
      child: Row(
        children: [
          const Expanded(child: Divider(color: AuraSurface.divider)),
          if (ornament.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AuraSpace.md),
              child: Text(
                ornament,
                style: AuraText.label.copyWith(
                  color: AuraSurface.muted,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          const Expanded(child: Divider(color: AuraSurface.divider)),
        ],
      ),
    );
  }
}

/// Footer line at the end of a publication: publisher + (optional)
/// version. Establishes a coherent "this is a published artifact"
/// closing rather than ending mid-scroll.
class AuraPublicationColophon extends StatelessWidget {
  const AuraPublicationColophon({
    super.key,
    this.publisher = 'Aura Platform LLC',
    this.version,
    this.updatedLabel,
  });

  final String publisher;
  final String? version;
  final String? updatedLabel;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      publisher,
      if ((version ?? '').trim().isNotEmpty) version!,
      if ((updatedLabel ?? '').trim().isNotEmpty) updatedLabel!,
    ];
    return Padding(
      padding: const EdgeInsets.only(top: AuraSpace.xxl),
      child: Text(
        parts.join(' · '),
        style: AuraText.label.copyWith(
          letterSpacing: 1.0,
          color: AuraSurface.muted,
        ),
      ),
    );
  }
}
