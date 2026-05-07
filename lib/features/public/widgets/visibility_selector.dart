import 'package:flutter/material.dart';

import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../domain/public_visibility.dart';

/// Two-state segmented selector — Social / Public — with a one-line
/// consequence sentence underneath. Personal is intentionally absent;
/// the public composer never offers it.
class PubVisibilitySelector extends StatelessWidget {
  const PubVisibilitySelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.dense = false,
  });

  final PubVisibility value;
  final ValueChanged<PubVisibility> onChanged;

  /// When true, hides the consequence line — useful for the in-line
  /// hint above a sticky reply composer where space is at a premium.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!dense) ...[
          Text(
            'AUDIENCE',
            style: AuraText.micro.copyWith(
              color: AuraSurface.faint,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: AuraSpace.s8),
        ],
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: AuraSurface.subtle,
            borderRadius: BorderRadius.circular(AuraRadius.pill),
            border: Border.all(color: AuraSurface.divider),
          ),
          child: Row(
            children: [
              for (final v in PubVisibility.values)
                _SegBtn(
                  label: v.label,
                  selected: value == v,
                  onTap: () => onChanged(v),
                ),
            ],
          ),
        ),
        if (!dense) ...[
          const SizedBox(height: AuraSpace.s8),
          Text(
            value.consequence,
            style: AuraText.small.copyWith(
              color: AuraSurface.muted,
              height: 1.45,
            ),
          ),
        ],
      ],
    );
  }
}

class _SegBtn extends StatelessWidget {
  const _SegBtn({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AuraRadius.pill),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.s14,
          vertical: AuraSpace.s8,
        ),
        decoration: BoxDecoration(
          color: selected ? AuraSurface.accentSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(AuraRadius.pill),
          border: Border.all(
            color: selected
                ? AuraSurface.accent.withValues(alpha: 0.4)
                : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: AuraText.small.copyWith(
            color: selected ? AuraSurface.accentText : AuraSurface.muted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// Compact "Public" / "Social" chip rendered next to a published item's
/// timestamp so readers always know who can see it.
class PubVisibilityChip extends StatelessWidget {
  const PubVisibilityChip({super.key, required this.value});

  final PubVisibility value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AuraSurface.subtle,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            value == PubVisibility.public
                ? Icons.public_rounded
                : Icons.people_outline_rounded,
            size: 10,
            color: AuraSurface.faint,
          ),
          const SizedBox(width: 4),
          Text(
            value.label,
            style: AuraText.micro.copyWith(
              color: AuraSurface.faint,
              fontWeight: FontWeight.w800,
              fontSize: 9,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
