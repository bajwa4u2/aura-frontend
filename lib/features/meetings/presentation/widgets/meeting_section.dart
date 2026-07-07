import 'package:flutter/material.dart';

import '../../../../core/ui/aura_card.dart';
import '../../../../core/ui/aura_space.dart';

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

  const MeetingSection({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.padding,
  });

  /// The canonical quiet empty state: one muted line, no vessel of its own.
  static Widget emptyLine(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AuraSpace.s6),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF8A94A6),
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AuraCard(
      padding: padding ?? const EdgeInsets.all(AuraSpace.s18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: AuraSpace.s12),
          child,
        ],
      ),
    );
  }
}
