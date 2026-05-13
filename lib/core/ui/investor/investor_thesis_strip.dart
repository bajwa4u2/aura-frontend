import 'package:flutter/material.dart';

import '../aura_radius.dart';
import '../aura_space.dart';
import '../aura_surface.dart';
import '../aura_text.dart';

/// Strategic-pillar strip used on the Investor surface.
///
/// Distinct visual register from the publication-system content blocks:
///
///   * Numbered chips (01 / 02 / 03) instead of plain uppercase labels.
///     Numbering implies a structured framework — executive cadence
///     rather than editorial enumeration.
///   * Three pillars compose side-by-side on desktop (≥760 px), stacking
///     to a single column on mobile. This gives the strategic thesis
///     dedicated horizontal real estate that the prior flat one-card-
///     per-pillar layout never claimed.
///   * Pillar tiles use a slightly lifted surface with a top accent rule
///     so they read as anchor blocks rather than body content.
class InvestorThesisStrip extends StatelessWidget {
  const InvestorThesisStrip({
    super.key,
    required this.pillars,
    this.accentColor = const Color(0xFFC9A55C),
  });

  /// Up to three or four pillar entries. The strip lays them out
  /// horizontally with equal weight on desktop; stacking on mobile.
  final List<InvestorThesisPillar> pillars;

  /// Top-of-tile accent rule color. Default Aura gold. Pass a different
  /// color if a band wants a softer treatment.
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        if (wide) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < pillars.length; i++) ...[
                  Expanded(
                    child: _PillarTile(
                      index: i + 1,
                      pillar: pillars[i],
                      accentColor: accentColor,
                    ),
                  ),
                  if (i < pillars.length - 1)
                    const SizedBox(width: AuraSpace.md),
                ],
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < pillars.length; i++) ...[
              _PillarTile(
                index: i + 1,
                pillar: pillars[i],
                accentColor: accentColor,
              ),
              if (i < pillars.length - 1)
                const SizedBox(height: AuraSpace.s12),
            ],
          ],
        );
      },
    );
  }
}

/// Single pillar tile on the strip.
class _PillarTile extends StatelessWidget {
  const _PillarTile({
    required this.index,
    required this.pillar,
    required this.accentColor,
  });

  final int index;
  final InvestorThesisPillar pillar;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final number = index.toString().padLeft(2, '0');
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.lg,
        AuraSpace.lg,
        AuraSpace.lg,
        AuraSpace.lg,
      ),
      decoration: BoxDecoration(
        color: AuraSurface.elevated,
        borderRadius: BorderRadius.circular(AuraRadius.md),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                number,
                style: AuraText.label.copyWith(
                  color: accentColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: AuraSpace.s10),
              Container(
                width: 24,
                height: 1.5,
                color: accentColor,
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.md),
          Text(
            pillar.label,
            style: AuraText.headline.copyWith(
              fontSize: 22,
              height: 1.25,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: AuraSpace.s10),
          Text(
            pillar.body,
            style: AuraText.body.copyWith(
              fontSize: 15,
              height: 1.65,
              color: AuraSurface.ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// One row on the strategic-pillar strip.
class InvestorThesisPillar {
  const InvestorThesisPillar({required this.label, required this.body});

  /// Short anchor word: "Trust", "Action", "Records", etc.
  final String label;

  /// 1–3 sentence body.
  final String body;
}
