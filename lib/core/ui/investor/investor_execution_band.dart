import 'package:flutter/material.dart';

import '../aura_radius.dart';
import '../aura_space.dart';
import '../aura_surface.dart';
import '../aura_text.dart';

/// Execution-credibility content for the Investor surface.
///
/// Reinforces the operator-builder background and the infrastructure
/// discipline locked in Aura's positioning. Composed as a paragraph
/// lede plus a 2x2 grid of credibility tiles (background, principles,
/// product, direction).
class InvestorExecutionContent extends StatelessWidget {
  const InvestorExecutionContent({
    super.key,
    required this.summary,
    required this.tiles,
  });

  /// One-paragraph operator/builder framing.
  final String summary;

  /// Four credibility tiles. Renders 2-up on desktop, stacked on mobile.
  final List<InvestorExecutionTile> tiles;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 760;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: Text(
            summary,
            style: AuraText.body.copyWith(
              fontSize: isMobile ? 16 : 17,
              height: 1.7,
              color: AuraSurface.ink,
            ),
          ),
        ),
        const SizedBox(height: AuraSpace.xl),
        if (isMobile)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < tiles.length; i++) ...[
                _Tile(tile: tiles[i]),
                if (i < tiles.length - 1)
                  const SizedBox(height: AuraSpace.s12),
              ],
            ],
          )
        else
          // 2x2 grid on desktop.
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < tiles.length; i += 2) ...[
                if (i > 0) const SizedBox(height: AuraSpace.md),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _Tile(tile: tiles[i])),
                      const SizedBox(width: AuraSpace.md),
                      if (i + 1 < tiles.length)
                        Expanded(child: _Tile(tile: tiles[i + 1]))
                      else
                        const Spacer(),
                    ],
                  ),
                ),
              ],
            ],
          ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.tile});
  final InvestorExecutionTile tile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AuraSpace.lg),
      decoration: BoxDecoration(
        color: AuraSurface.elevated,
        borderRadius: BorderRadius.circular(AuraRadius.md),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(tile.icon, size: 18, color: const Color(0xFFC9A55C)),
          const SizedBox(height: AuraSpace.s10),
          Text(
            tile.label,
            style: AuraText.subtitle.copyWith(
              fontSize: 17,
              height: 1.3,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AuraSpace.s8),
          Text(
            tile.body,
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

class InvestorExecutionTile {
  const InvestorExecutionTile({
    required this.icon,
    required this.label,
    required this.body,
  });

  final IconData icon;
  final String label;
  final String body;
}
