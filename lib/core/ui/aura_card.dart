import 'package:flutter/material.dart';

import 'aura_design_system.dart';
import 'aura_radius.dart';
import 'aura_space.dart';
import 'aura_surface.dart';

/// Premium navy panel container for Aura.
/// Depth via gradient + shadow. No performance-heavy blur.
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
    const radius = AuraRadius.card;

    Widget card = Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(AuraSpace.md),
      decoration: BoxDecoration(
        gradient: color != null ? null : AuraGradients.card,
        color: color?.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: borderColor ?? AuraSurface.divider,
          width: 1,
        ),
        boxShadow: AuraShadows.card,
      ),
      child: child,
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        splashColor: AuraSurface.accentSoft,
        highlightColor: AuraSurface.divider,
        onTap: onTap,
        child: card,
      ),
    );
  }
}
