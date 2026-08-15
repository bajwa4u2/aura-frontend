/// ATTRIBUTION AT THE CONSEQUENTIAL ACT — C1, founder-approved Option A.
///
/// > **ACTING AUTHORITY BECOMES EXPLICIT WHEN A CONSEQUENTIAL ACTION REQUIRES
/// > ATTRIBUTION — NOT BECAUSE OF THE ROUTE THE PERSON NAVIGATED THROUGH.**
///
/// The frozen rules this widget implements:
///
///  * No global acting-context mode for convenience.
///  * No route-derived sender identity.
///  * **One** legitimate acting context → no chooser is introduced. The person
///    is simply told who the act will represent.
///  * **Several** legitimate acting contexts → explicit choice is required
///    before the act.
///  * Institutional attribution always retains the natural person behind it —
///    choosing an institution never means the institution acts by itself.
///
/// This is deliberately small. It is the attribution surface, not a redesign
/// of any composer or thread; the surfaces that own those belong to C5 and C7.
library;

import 'package:flutter/material.dart';

import '../ui/aura_radius.dart';
import '../ui/aura_space.dart';
import '../ui/aura_surface.dart';
import '../ui/aura_text.dart';
import '../product/product_language.dart';
import 'acting_context.dart';

/// Shows who a consequential act will represent, and — only when the choice is
/// real — lets the person change it before committing.
class ActingAttribution extends StatelessWidget {
  const ActingAttribution({
    super.key,
    required this.resolution,
    required this.selected,
    required this.onChanged,
    this.verb,
    this.switchLabel,
  });

  /// The resolved acting options for this act.
  final ActingResolution resolution;

  /// The option currently chosen. Callers seed this from
  /// [ActingResolution.recommended] and hold it in their own state, so the
  /// choice belongs to the act rather than to global state.
  final ActingOption selected;

  final ValueChanged<ActingOption> onChanged;

  /// Optional verb for the sentence, e.g. "Publishing". Defaults to a neutral
  /// statement so the widget never mislabels an act it does not know.
  final String? verb;

  /// Contextual copy for the switch-identity action ("Publish as…", "Send
  /// as…"). The **semantic action is always** [ProductAction.switchIdentity];
  /// this only changes how it reads on this surface.
  final String? switchLabel;

  @override
  Widget build(BuildContext context) {
    if (!resolution.isAvailable) return const SizedBox.shrink();

    final line = verb == null
        ? 'This will be attributed to'
        : '${verb!} as';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s12,
        vertical: AuraSpace.s10,
      ),
      decoration: BoxDecoration(
        color: AuraSurface.subtle,
        borderRadius: BorderRadius.circular(AuraRadius.r12),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Row(
        children: [
          _Avatar(option: selected),
          const SizedBox(width: AuraSpace.s10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(line, style: AuraText.small),
                const SizedBox(height: 2),
                Text(
                  selected.displayName,
                  style: AuraText.body.copyWith(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                // An institutional act keeps the person visible. The
                // institution never appears to act by itself.
                if (selected.isInstitution)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      selected.availability.explanation,
                      style: AuraText.small.copyWith(color: AuraSurface.faint),
                    ),
                  ),
              ],
            ),
          ),
          // The chooser exists ONLY when more than one identity is legitimate.
          // A single option is stated, never offered as a decision.
          if (resolution.requiresExplicitChoice) ...[
            const SizedBox(width: AuraSpace.s8),
            _Chooser(
              options: resolution.options,
              selected: selected,
              onChanged: onChanged,
              label: switchLabel,
            ),
          ],
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.option});
  final ActingOption option;

  @override
  Widget build(BuildContext context) {
    final url = option.avatarUrl;
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: AuraSurface.card,
        border: Border.all(color: AuraSurface.divider),
        // Institutions read as squared, people as round — the same visual
        // grammar the rest of the product uses for the two identities.
        borderRadius: BorderRadius.circular(option.isInstitution ? 8 : 16),
        image: (url != null && url.isNotEmpty)
            ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover)
            : null,
      ),
      child: (url == null || url.isEmpty)
          ? Icon(
              option.isInstitution
                  ? Icons.account_balance_outlined
                  : Icons.person_outline,
              size: 18,
              color: AuraSurface.faint,
            )
          : null,
    );
  }
}

class _Chooser extends StatelessWidget {
  const _Chooser({
    required this.options,
    required this.selected,
    required this.onChanged,
    this.label,
  });

  final List<ActingOption> options;
  final ActingOption selected;
  final ValueChanged<ActingOption> onChanged;

  /// Contextual copy for the one semantic action, e.g. "Publish as…".
  final String? label;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ActingOption>(
      tooltip: ProductLabels.of(ProductAction.switchIdentity),
      initialValue: selected,
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final o in options)
          PopupMenuItem<ActingOption>(
            value: o,
            child: Row(
              children: [
                _Avatar(option: o),
                const SizedBox(width: AuraSpace.s10),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(o.displayName, style: AuraText.body),
                      Text(
                        o.availability.explanation,
                        style:
                            AuraText.small.copyWith(color: AuraSurface.faint),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ONE semantic action (ProductAction.switchIdentity). A surface
            // may render contextual copy instead — "Publish as…", "Send
            // as…" — but never a second semantic action.
            Text(label ?? ProductLabels.of(ProductAction.switchIdentity),
                style: AuraText.small),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more_rounded,
                size: 16, color: AuraSurface.muted),
          ],
        ),
      ),
    );
  }
}
