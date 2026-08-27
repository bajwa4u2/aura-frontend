/// THE ORIGIN DISCLOSURE CONTROL — one interaction, every composer.
///
/// `UPLOADER_DECLARATION` existed in the evidence model with no way for any
/// person to exercise it. This is that way, and it is deliberately ONE widget:
/// a checkbox bolted onto each composer separately would drift into several
/// vocabularies for the same claim, and the evidence model has exactly one.
///
/// ## WHY IT IS QUIET, AND WHY IT IS OPTIONAL
///
/// Most media has no AI involvement and most people have nothing to declare, so
/// this must not read as an interrogation before every upload. It is a single
/// unobtrusive line, defaulting to saying nothing, and saying nothing records
/// NOTHING — no evidence row, no state, no badge.
///
/// ## WHY THERE IS NO "MADE BY A HUMAN" OPTION
///
/// `NOT_AI` exists in the model and is offered here as "No AI involved",
/// because a creator genuinely can state that about their own work. But it is
/// recorded as a DECLARATION, never as verification, and it can never mint a
/// human-authenticity badge — the resolver has no such state to reach. The
/// wording avoids implying it proves anything.
///
/// ## WHERE IT BELONGS
///
/// Beside a composition that carries visual media. It is NOT shown when
/// provenance is already established by stronger evidence: asking someone to
/// declare what Aura already knows deterministically would invite a
/// contradiction whose only possible resolution is to ignore their answer.
library;

import 'package:flutter/material.dart';

import '../ui/aura_space.dart';
import '../ui/aura_surface.dart';
import '../ui/aura_text.dart';

/// What a creator may say. Null means they said nothing.
enum OriginDeclaration { aiGenerated, aiEdited, notAi }

/// The wire value the upload contract expects.
String originDeclarationWire(OriginDeclaration d) {
  switch (d) {
    case OriginDeclaration.aiGenerated:
      return 'AI_GENERATED';
    case OriginDeclaration.aiEdited:
      return 'AI_EDITED';
    case OriginDeclaration.notAi:
      return 'NOT_AI';
  }
}

String originDeclarationLabel(OriginDeclaration d) {
  switch (d) {
    case OriginDeclaration.aiGenerated:
      return 'Generated with AI';
    case OriginDeclaration.aiEdited:
      return 'Edited with AI';
    case OriginDeclaration.notAi:
      return 'No AI involved';
  }
}

/// A single quiet line offering the declaration.
class MediaOriginDisclosureControl extends StatelessWidget {
  const MediaOriginDisclosureControl({
    super.key,
    required this.value,
    required this.onChanged,
    this.visible = true,
  });

  final OriginDeclaration? value;
  final ValueChanged<OriginDeclaration?> onChanged;

  /// False when provenance is already established by stronger evidence, or
  /// when the composition carries no visual media.
  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s12,
        vertical: AuraSpace.s6,
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 15, color: AuraSurface.faint),
          const SizedBox(width: AuraSpace.s6),
          Flexible(
            child: Text(
              'Origin',
              style: AuraText.small.copyWith(color: AuraSurface.faint),
            ),
          ),
          const SizedBox(width: AuraSpace.s8),
          Flexible(
            flex: 3,
            child: Semantics(
              label: 'Declare how this media was made',
              child: DropdownButtonHideUnderline(
                child: DropdownButton<OriginDeclaration?>(
                  value: value,
                  isDense: true,
                  isExpanded: true,
                  // The default. Saying nothing is a legitimate answer and the
                  // most common one, so it costs no interaction at all.
                  hint: Text(
                    'Not specified',
                    style: AuraText.small.copyWith(color: AuraSurface.faint),
                  ),
                  items: [
                    const DropdownMenuItem<OriginDeclaration?>(
                      value: null,
                      child: Text('Not specified', style: AuraText.small),
                    ),
                    for (final d in OriginDeclaration.values)
                      DropdownMenuItem<OriginDeclaration?>(
                        value: d,
                        child: Text(originDeclarationLabel(d),
                            style: AuraText.small),
                      ),
                  ],
                  onChanged: onChanged,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
