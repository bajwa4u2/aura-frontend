import 'package:flutter/material.dart';

import 'aura_radius.dart';
import 'aura_space.dart';
import 'aura_surface.dart';

/// A cinematic panel container used across Aura.
/// Structured. Subtle. Layered.
class AuraCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Color? borderColor;
  final VoidCallback? onTap;

  const AuraCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.color,
    this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final double radius = AuraRadius.card;

    final card = Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(AuraSpace.md),
      decoration: BoxDecoration(
        color: color ?? AuraSurface.card,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: borderColor ?? AuraSurface.divider,
          width: 1,
        ),
        boxShadow: const [
          // Soft cinematic lift (not harsh Material shadow)
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        splashColor: AuraSurface.accentSoft,
        highlightColor: Colors.transparent,
        onTap: onTap,
        child: card,
      ),
    );
  }
}