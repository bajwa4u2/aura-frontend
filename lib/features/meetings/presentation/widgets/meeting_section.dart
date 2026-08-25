import 'package:flutter/material.dart';

import '../../../../core/ui/aura_card.dart';
import '../../../../core/ui/aura_space.dart';
import '../../../../core/ui/aura_surface.dart';

/// The ONE section grammar for every meeting surface (Desk, Meeting Record,
/// workroom panels). Built on [AuraCard] so meetings share the exact material
/// language of the institution workspace screens — gradient depth, canonical
/// radius, canonical divider — instead of hand-rolled flat boxes.
///
/// Rules this widget enforces by construction:
///  * one heading scale (titleMedium w700),
///  * full-width sections (no floating half-width cards),
///  * empty states are a QUIET LINE inside the section, never their own card.
class MeetingSection extends StatelessWidget {
  final String title;

  /// Small trailing widget on the heading row (count chip, action button).
  final Widget? trailing;

  /// Section body. Use [MeetingSection.emptyLine] for empty content.
  final Widget child;

  final EdgeInsetsGeometry? padding;

  /// How many things are in this section, when that is worth knowing at a
  /// glance. Null hides the chip entirely - a count of nothing is noise.
  final int? count;

  /// Marks a section that genuinely wants attention. Used sparingly: if two
  /// sections on a surface are emphasised, neither is.
  final bool emphasis;

  /// Renders the heading without the card around it. The Meetings landing
  /// composes its own cards inside each section, and a card inside a card is
  /// a border nobody asked for.
  final bool bare;

  const MeetingSection({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.padding,
    this.count,
    this.emphasis = false,
    this.bare = false,
  });

  /// The canonical quiet empty state: one muted line, no vessel of its own.
  static Widget emptyLine(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AuraSpace.s6),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AuraSurface.muted,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final heading = Row(
      children: [
        if (emphasis) ...[
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AuraSurface.accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AuraSpace.s8),
        ],
        Semantics(
          header: true,
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (count != null && count! > 0) ...[
          const SizedBox(width: AuraSpace.s8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(
              color: AuraSurface.elevated,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: AuraSurface.muted),
            ),
          ),
        ],
        const Spacer(),
        if (trailing != null) trailing!,
      ],
    );

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        heading,
        const SizedBox(height: AuraSpace.s12),
        child,
      ],
    );

    if (bare) return body;

    return AuraCard(
      padding: padding ?? const EdgeInsets.all(AuraSpace.s18),
      child: body,
    );
  }
}
