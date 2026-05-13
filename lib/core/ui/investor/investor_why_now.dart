import 'package:flutter/material.dart';

import '../aura_radius.dart';
import '../aura_space.dart';
import '../aura_surface.dart';
import '../aura_text.dart';

/// "Why now" market-context content for the Investor surface.
///
/// Renders a two-column market-context layout on desktop (forces vs.
/// shifts) and stacks to a single column on mobile. Distinct from the
/// strategic pillars: pillars are *what* the company stands on, why-
/// now is *why this is the moment*.
class InvestorWhyNowContent extends StatelessWidget {
  const InvestorWhyNowContent({
    super.key,
    required this.forces,
    required this.shifts,
    this.accentColor = const Color(0xFFC9A55C),
  });

  /// Left column items — the market forces creating demand.
  final List<InvestorMarketPoint> forces;

  /// Right column items — the operational shifts those forces enable.
  final List<InvestorMarketPoint> shifts;

  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        final forcesCol = _Column(
          header: 'Market forces',
          headerAccent: accentColor,
          points: forces,
        );
        final shiftsCol = _Column(
          header: 'Operational shift',
          headerAccent: accentColor,
          points: shifts,
        );
        if (!wide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              forcesCol,
              const SizedBox(height: AuraSpace.lg),
              shiftsCol,
            ],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: forcesCol),
              const SizedBox(width: AuraSpace.xl),
              Container(width: 1, color: AuraSurface.divider),
              const SizedBox(width: AuraSpace.xl),
              Expanded(child: shiftsCol),
            ],
          ),
        );
      },
    );
  }
}

class _Column extends StatelessWidget {
  const _Column({
    required this.header,
    required this.headerAccent,
    required this.points,
  });

  final String header;
  final Color headerAccent;
  final List<InvestorMarketPoint> points;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 18, height: 1.5, color: headerAccent),
            const SizedBox(width: AuraSpace.s8),
            Flexible(
              child: Text(
                header.toUpperCase(),
                overflow: TextOverflow.ellipsis,
                style: AuraText.label.copyWith(
                  color: headerAccent,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AuraSpace.md),
        for (var i = 0; i < points.length; i++) ...[
          _PointRow(point: points[i]),
          if (i < points.length - 1) const SizedBox(height: AuraSpace.md),
        ],
      ],
    );
  }
}

class _PointRow extends StatelessWidget {
  const _PointRow({required this.point});
  final InvestorMarketPoint point;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AuraSpace.md),
      decoration: BoxDecoration(
        color: AuraSurface.elevated,
        borderRadius: BorderRadius.circular(AuraRadius.md),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            point.headline,
            style: AuraText.subtitle.copyWith(
              fontSize: 16,
              height: 1.3,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AuraSpace.s6),
          Text(
            point.body,
            style: AuraText.body.copyWith(
              fontSize: 14,
              height: 1.6,
              color: AuraSurface.muted,
            ),
          ),
        ],
      ),
    );
  }
}

/// One bullet on the Why-Now content.
class InvestorMarketPoint {
  const InvestorMarketPoint({required this.headline, required this.body});

  /// One-line headline, sentence case.
  final String headline;

  /// 1–2 sentence body.
  final String body;
}
