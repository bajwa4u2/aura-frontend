import 'package:flutter/material.dart';

import 'aura_radius.dart';
import 'aura_space.dart';
import 'aura_surface.dart';

/// A calm, paper-like container used across Aura.
/// Keeps borders subtle and spacing consistent.
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
    final card = Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(AuraSpace.s16),
      decoration: ShapeDecoration(
        color: color ?? AuraSurface.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AuraRadius.card),
          side: BorderSide(
            color: borderColor ?? AuraSurface.divider,
            width: 1,
          ),
        ),
      ),
      child: child,
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AuraRadius.card),
        onTap: onTap,
        child: card,
      ),
    );
  }
}
