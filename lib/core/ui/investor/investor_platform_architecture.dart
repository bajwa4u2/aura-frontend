import 'package:flutter/material.dart';

import '../aura_radius.dart';
import '../aura_space.dart';
import '../aura_surface.dart';
import '../aura_text.dart';

/// Visual platform architecture diagram for the Investor surface.
///
/// Communicates "two products on one shared fabric" through composition
/// rather than prose. Two product columns sit on top of a horizontal
/// infrastructure tier showing the shared capability cells (Identity,
/// Governance, Realtime, Records, AI execution).
///
/// This is the surface's primary strategic-coherence signal. Where the
/// publication system uses prose to assert relationships between
/// concepts, the investor register asserts them visually.
class InvestorPlatformArchitecture extends StatelessWidget {
  const InvestorPlatformArchitecture({
    super.key,
    required this.products,
    required this.fabricLabel,
    required this.fabricCells,
    this.accentColor = const Color(0xFFC9A55C),
  });

  /// The two-or-more product columns rendered at the top tier. Each
  /// product gets a labelled tile showing name + tagline.
  final List<InvestorArchitectureProduct> products;

  /// Header label rendered above the shared-infrastructure tier.
  /// Example: "Shared infrastructure".
  final String fabricLabel;

  /// Capability cells rendered horizontally as the shared fabric.
  /// Examples: "Identity", "Governance", "Realtime", "Records",
  /// "AI execution".
  final List<String> fabricCells;

  /// Connector accent color between product tiles and the fabric tier.
  /// Default Aura gold.
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top tier: product columns. Wrapped in IntrinsicHeight
            // so the equal-height stretch survives an unbounded-height
            // parent (e.g. inside a ListView).
            wide
                ? IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < products.length; i++) ...[
                          Expanded(
                            child: _ProductColumn(product: products[i]),
                          ),
                          if (i < products.length - 1)
                            const SizedBox(width: AuraSpace.md),
                        ],
                      ],
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < products.length; i++) ...[
                        _ProductColumn(product: products[i]),
                        if (i < products.length - 1)
                          const SizedBox(height: AuraSpace.s12),
                      ],
                    ],
                  ),

            // Connector — vertical hairlines plus a horizontal rule
            // that visually ties the products to the shared fabric.
            SizedBox(
              height: AuraSpace.xl,
              child: CustomPaint(
                painter: _ArchitectureConnectorPainter(
                  productCount: products.length,
                  accentColor: accentColor,
                  wide: wide,
                ),
              ),
            ),

            // Shared fabric tier — labelled horizontal capability row.
            Container(
              padding: const EdgeInsets.all(AuraSpace.lg),
              decoration: BoxDecoration(
                color: AuraSurface.elevated,
                borderRadius: BorderRadius.circular(AuraRadius.md),
                border: Border.all(color: AuraSurface.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 18,
                        height: 1.5,
                        color: accentColor,
                      ),
                      const SizedBox(width: AuraSpace.s8),
                      Flexible(
                        child: Text(
                          fabricLabel.toUpperCase(),
                          overflow: TextOverflow.ellipsis,
                          style: AuraText.label.copyWith(
                            color: accentColor,
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AuraSpace.md),
                  _FabricCellsRow(cells: fabricCells, wide: wide),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// One product column at the top of the architecture diagram.
class _ProductColumn extends StatelessWidget {
  const _ProductColumn({required this.product});
  final InvestorArchitectureProduct product;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AuraSpace.lg),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.md),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            product.name,
            style: AuraText.headline.copyWith(
              fontSize: 22,
              height: 1.2,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: AuraSpace.s6),
          Text(
            product.tagline,
            style: AuraText.body.copyWith(
              fontSize: 14,
              height: 1.55,
              color: AuraSurface.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FabricCellsRow extends StatelessWidget {
  const _FabricCellsRow({required this.cells, required this.wide});

  final List<String> cells;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    if (wide) {
      return Row(
        children: [
          for (var i = 0; i < cells.length; i++) ...[
            Expanded(child: _FabricCellTile(label: cells[i])),
            if (i < cells.length - 1) const SizedBox(width: AuraSpace.s8),
          ],
        ],
      );
    }
    return Wrap(
      spacing: AuraSpace.s8,
      runSpacing: AuraSpace.s8,
      children: cells.map((label) => _FabricCellTile(label: label)).toList(),
    );
  }
}

class _FabricCellTile extends StatelessWidget {
  const _FabricCellTile({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s12,
        vertical: AuraSpace.s10,
      ),
      decoration: BoxDecoration(
        color: AuraSurface.subtle,
        borderRadius: BorderRadius.circular(AuraRadius.sm),
        border: Border.all(color: AuraSurface.divider),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: AuraText.label.copyWith(
          color: AuraSurface.ink,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// Custom painter for the connector between product columns and the
/// shared-infrastructure tier. Draws short vertical drops from each
/// product column plus a horizontal hairline tying them together.
/// Subtle by design — visual implication, not architectural diagram
/// notation.
class _ArchitectureConnectorPainter extends CustomPainter {
  _ArchitectureConnectorPainter({
    required this.productCount,
    required this.accentColor,
    required this.wide,
  });

  final int productCount;
  final Color accentColor;
  final bool wide;

  @override
  void paint(Canvas canvas, Size size) {
    if (productCount <= 0) return;

    final dividerPaint = Paint()
      ..color = AuraSurface.divider.withValues(alpha: 0.9)
      ..strokeWidth = 1;
    final accentPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.6)
      ..strokeWidth = 1.5;

    if (!wide) {
      // Mobile: just a single vertical hairline down the middle so
      // products visually "fall" onto the fabric below.
      final x = size.width / 2;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        accentPaint,
      );
      return;
    }

    // Desktop: vertical drop from each product column, plus a
    // horizontal hairline at mid-height that ties them together.
    final columnCenterY = size.height / 2;
    canvas.drawLine(
      Offset(0, columnCenterY),
      Offset(size.width, columnCenterY),
      dividerPaint,
    );
    for (var i = 0; i < productCount; i++) {
      final cx = size.width *
          (productCount == 1
              ? 0.5
              : (i + 0.5) / productCount);
      canvas.drawLine(
        Offset(cx, 0),
        Offset(cx, size.height),
        accentPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_ArchitectureConnectorPainter old) =>
      old.productCount != productCount ||
      old.accentColor != accentColor ||
      old.wide != wide;
}

/// One product column in the architecture diagram.
class InvestorArchitectureProduct {
  const InvestorArchitectureProduct({
    required this.name,
    required this.tagline,
  });

  /// Product name (e.g., "Aura", "Orchestrate").
  final String name;

  /// One-line tagline rendered below the name.
  final String tagline;
}
