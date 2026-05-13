import 'package:flutter/material.dart';

import '../aura_space.dart';
import '../aura_surface.dart';
import '../aura_text.dart';

/// Header used at the top of every Investor band.
///
/// Executive register: uppercase eyebrow (with optional numeral), a
/// large-but-restrained title, and a short subtitle. Renders as a
/// composed unit so band transitions feel deliberate rather than
/// "another stacked card".
class InvestorSectionHeader extends StatelessWidget {
  const InvestorSectionHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
    this.numeral,
    this.accentColor = const Color(0xFFC9A55C),
  });

  /// Short uppercase eyebrow ("Platform structure", "Why now",
  /// "Execution", "Deck"). Rendered with wide letter spacing.
  final String eyebrow;

  /// Section title.
  final String title;

  /// Optional one-paragraph subtitle.
  final String? subtitle;

  /// Optional numeral pinned ahead of the eyebrow (e.g. "II").
  final String? numeral;

  /// Accent color for the eyebrow rule + numeral.
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;
    final titleStyle = isMobile
        ? AuraText.headline.copyWith(fontSize: 26, height: 1.2)
        : AuraText.display.copyWith(
            fontSize: 32,
            height: 1.15,
            letterSpacing: -0.3,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if ((numeral ?? '').isNotEmpty) ...[
              Text(
                numeral!.toUpperCase(),
                style: AuraText.label.copyWith(
                  color: accentColor,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: AuraSpace.s10),
            ],
            Container(
              width: 24,
              height: 1.5,
              color: accentColor,
            ),
            const SizedBox(width: AuraSpace.s10),
            Flexible(
              child: Text(
                eyebrow.toUpperCase(),
                style: AuraText.label.copyWith(
                  color: AuraSurface.ink,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AuraSpace.md),
        Text(title, style: titleStyle),
        if ((subtitle ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: AuraSpace.s10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Text(
              subtitle!,
              style: AuraText.body.copyWith(
                fontSize: isMobile ? 15 : 16,
                height: 1.65,
                color: AuraSurface.muted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
