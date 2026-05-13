import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../aura_radius.dart';
import '../aura_space.dart';
import '../aura_surface.dart';
import '../aura_text.dart';

/// Flagship investor-deck presentation.
///
/// Replaces the prior small "download tile" with an intentional
/// centerpiece: a stylized deck-face preview at the left, a labelled
/// metadata column at the right, and a clear primary CTA. The deck
/// reads as the surface's terminal artifact rather than as a utility
/// download.
///
/// The "face" is rendered in Flutter — no PDF thumbnail dependency.
/// It carries the publisher line, document title, version, and an
/// Aura ring-mark callout, so when the page is screenshotted or
/// captured, the deck card visually represents the artifact.
class InvestorDeckCenterpiece extends StatelessWidget {
  const InvestorDeckCenterpiece({
    super.key,
    required this.title,
    required this.subtitle,
    required this.version,
    required this.updatedLabel,
    required this.onOpen,
    this.accentColor = const Color(0xFFC9A55C),
  });

  /// Deck title.
  final String title;

  /// Deck subtitle / publisher framing.
  final String subtitle;

  /// Version label (e.g. "Version 1.0 · Seed").
  final String version;

  /// Updated/date label (e.g. "May 2026").
  final String updatedLabel;

  /// Callback invoked by the primary CTA.
  final VoidCallback onOpen;

  /// Accent color used for the gold rule + cover ring.
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 760;

    final cover = _DeckCover(
      title: title,
      version: version,
      accentColor: accentColor,
    );
    final meta = _DeckMeta(
      title: title,
      subtitle: subtitle,
      version: version,
      updatedLabel: updatedLabel,
      onOpen: onOpen,
      accentColor: accentColor,
    );

    return Container(
      padding: const EdgeInsets.all(AuraSpace.xl),
      decoration: BoxDecoration(
        color: AuraSurface.elevated,
        borderRadius: BorderRadius.circular(AuraRadius.lg),
        border: Border.all(color: AuraSurface.divider),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 28,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // On mobile the cover sizes to its content rather than
                // a fixed paper aspect — keeps the title/ring/version
                // legible at narrow widths without crowding the column.
                cover,
                const SizedBox(height: AuraSpace.lg),
                meta,
              ],
            )
          : IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Deck cover at 1.414:1 (matches A4/Letter aspect
                  // so the artifact reads as a document, not a poster).
                  Expanded(
                    flex: 5,
                    child: AspectRatio(aspectRatio: 1.414, child: cover),
                  ),
                  const SizedBox(width: AuraSpace.xl),
                  Expanded(flex: 6, child: meta),
                ],
              ),
            ),
    );
  }
}

/// In-Flutter rendition of the deck face.
class _DeckCover extends StatelessWidget {
  const _DeckCover({
    required this.title,
    required this.version,
    required this.accentColor,
  });

  final String title;
  final String version;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AuraSpace.lg),
      decoration: BoxDecoration(
        color: AuraSurface.page,
        borderRadius: BorderRadius.circular(AuraRadius.md),
        border: Border.all(color: AuraSurface.divider),
        // A subtle inner highlight implies a real paper artifact.
        gradient: const RadialGradient(
          center: Alignment.topLeft,
          radius: 1.4,
          colors: [
            Color(0xFF13202F),
            AuraSurface.page,
          ],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Spacers only work inside a bounded-height parent. When this
          // cover is rendered inside a Column with no AspectRatio (mobile
          // path), constraints.maxHeight is infinite — fall back to
          // fixed gaps so the cover sizes to its content.
          final bounded = constraints.maxHeight.isFinite;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(width: 18, height: 1.5, color: accentColor),
                  const SizedBox(width: AuraSpace.s8),
                  Text(
                    'AURA PLATFORM LLC',
                    style: AuraText.label.copyWith(
                      color: accentColor,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.6,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              bounded
                  ? const Spacer()
                  : const SizedBox(height: AuraSpace.xl),
              _AuraRing(color: accentColor, size: 56),
              const SizedBox(height: AuraSpace.md),
              Text(
                'Investor Deck',
                style: AuraText.label.copyWith(
                  color: AuraSurface.muted,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: AuraSpace.s8),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AuraText.headline.copyWith(
                  fontSize: 22,
                  height: 1.2,
                  letterSpacing: -0.1,
                ),
              ),
              bounded
                  ? const Spacer()
                  : const SizedBox(height: AuraSpace.xl),
              Row(
                children: [
                  Text(
                    version.toUpperCase(),
                    style: AuraText.micro.copyWith(
                      color: AuraSurface.muted,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AuraRing extends StatelessWidget {
  const _AuraRing({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _AuraRingPainter(color: color)),
    );
  }
}

class _AuraRingPainter extends CustomPainter {
  _AuraRingPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 4;

    final ring = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, ring);

    // Tick marks at cardinal points.
    final tick = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    const tickLen = 4.0;
    for (final angleDeg in [0.0, 90.0, 180.0, 270.0]) {
      final rad = angleDeg * math.pi / 180.0;
      final outerX = center.dx + (radius + 7) * math.cos(rad);
      final outerY = center.dy + (radius + 7) * math.sin(rad);
      final innerX = center.dx + (radius + 7 - tickLen) * math.cos(rad);
      final innerY = center.dy + (radius + 7 - tickLen) * math.sin(rad);
      canvas.drawLine(Offset(innerX, innerY), Offset(outerX, outerY), tick);
    }
  }

  @override
  bool shouldRepaint(_AuraRingPainter old) => old.color != color;
}

class _DeckMeta extends StatelessWidget {
  const _DeckMeta({
    required this.title,
    required this.subtitle,
    required this.version,
    required this.updatedLabel,
    required this.onOpen,
    required this.accentColor,
  });

  final String title;
  final String subtitle;
  final String version;
  final String updatedLabel;
  final VoidCallback onOpen;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(width: 24, height: 1.5, color: accentColor),
            const SizedBox(width: AuraSpace.s8),
            Text(
              'INVESTOR DECK',
              style: AuraText.label.copyWith(
                color: accentColor,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: AuraSpace.md),
        Text(
          title,
          style: AuraText.headline.copyWith(
            fontSize: 26,
            height: 1.2,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: AuraSpace.s10),
        Text(
          subtitle,
          style: AuraText.body.copyWith(
            fontSize: 15,
            height: 1.65,
            color: AuraSurface.muted,
          ),
        ),
        const SizedBox(height: AuraSpace.lg),
        _MetaRow(label: 'Version', value: version),
        const SizedBox(height: AuraSpace.s8),
        _MetaRow(label: 'Updated', value: updatedLabel),
        const SizedBox(height: AuraSpace.s8),
        const _MetaRow(label: 'Audience', value: 'Investors and partners'),
        const SizedBox(height: AuraSpace.lg),
        Material(
          color: accentColor,
          borderRadius: BorderRadius.circular(AuraRadius.md),
          child: InkWell(
            borderRadius: BorderRadius.circular(AuraRadius.md),
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AuraSpace.lg,
                vertical: AuraSpace.s12,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Open the deck',
                    style: AuraText.subtitle.copyWith(
                      color: AuraSurface.page,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(width: AuraSpace.s8),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: AuraSurface.page,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 96,
          child: Text(
            label.toUpperCase(),
            style: AuraText.label.copyWith(
              color: AuraSurface.faint,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AuraText.body.copyWith(
              fontSize: 14,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
