import 'package:flutter/material.dart';

import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';

/// THE TWO VIEWS OF ONE DESTINATION (founder ruling 2026-08-23).
///
/// Activity is the single personal continuity destination, and it answers two
/// questions that must not collapse into one another:
///
///   ATTENTION — what has been directed at me and not yet acknowledged. Carries
///   read semantics: an item can be marked read, and it feeds the drawer
///   signal.
///
///   HISTORY — what happened in the correspondence context I can reach. Carries
///   NO read semantics: nothing to acknowledge, nothing to clear, and it never
///   contributes to that signal.
///
/// VOCABULARY, and why. "Attention" is Aura's own word — the attention
/// authority, the attention matrix, attention items — so it is used rather than
/// invented. "History" is plain and unambiguous.
///
/// Two Aura-native alternatives were considered and rejected. "Continuity" is
/// the doctrine's own term and the more precise one, but it is internal jargon
/// a reader has never been taught. "Record" comes from Aura's own public copy
/// ("Not a feed. A record.") and fits the meaning exactly, but it collides with
/// call recording, which this product actually has.
///
/// A SEGMENTED CONTROL, not another filter pill. The filter row below selects
/// among kinds of attention; this selects between two different questions with
/// different semantics, and the control should not imply they are the same
/// kind of choice.
enum ActivityView { attention, history }

class ActivityViewSwitch extends StatelessWidget {
  const ActivityViewSwitch({
    super.key,
    required this.active,
    required this.onChange,
  });

  final ActivityView active;
  final ValueChanged<ActivityView> onChange;

  @override
  Widget build(BuildContext context) {
    Widget tab(ActivityView view, String label) {
      final selected = view == active;
      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          label: label,
          // Self-sufficient: InkWell needs a Material ancestor, and this
          // control must render wherever it is placed rather than depending on
          // a Scaffold happening to be above it.
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onChange(view),
              borderRadius: BorderRadius.circular(AuraRadius.r10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: AuraSpace.s10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? AuraSurface.accentSoft : Colors.transparent,
                  borderRadius: BorderRadius.circular(AuraRadius.r10),
                  border: Border.all(
                    color: selected
                        ? AuraSurface.accent.withValues(alpha: 0.25)
                        : Colors.transparent,
                  ),
                ),
                child: Text(
                  label,
                  style: AuraText.small.copyWith(
                    fontWeight: FontWeight.w700,
                    color: selected ? AuraSurface.ink : AuraSurface.muted,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AuraSpace.s4),
      decoration: BoxDecoration(
        color: AuraSurface.subtle,
        borderRadius: BorderRadius.circular(AuraRadius.r14),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Row(
        children: [
          tab(ActivityView.attention, 'Attention'),
          tab(ActivityView.history, 'History'),
        ],
      ),
    );
  }
}
