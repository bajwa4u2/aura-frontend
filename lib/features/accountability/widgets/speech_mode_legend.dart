import 'package:flutter/material.dart';

import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/ui/substrate_chip.dart';

/// Speech mode legend — names the four canonical institutional
/// communication types (per `lib/features/institutions/domain/
/// communication_type.dart`) as a typed legend with verbatim
/// definitions:
///
///   ANNOUNCEMENT   →  the institution is making a formal statement
///   ADVISORY       →  guidance / recommendation the institution wants
///                     the public to act on
///   NOTICE         →  factual information being put on record
///   UPDATE         →  in-flight progress on prior commitments
///
/// Renders the canonical taxonomy visibly so readers can map a
/// chip they saw on a feed card back to its definition. The
/// legend is static — it is the canon. When a new communication
/// type ships, this widget gains one row without disturbing
/// existing ones.
///
/// Doctrine mirror — `governance-grammar.md` §2 (institutional
/// speech modes) + `lib/features/institutions/domain/
/// communication_type.dart` (the wire enum).
class SpeechModeLegend extends StatelessWidget {
  const SpeechModeLegend({super.key});

  static const _modes = [
    _Mode(
      label: 'ANNOUNCEMENT',
      caption:
          'A formal statement from the institution. Highest priority in feeds; carries the OFFICIAL ANNOUNCEMENT eyebrow on detail.',
      state: SubstrateChipState.teal,
    ),
    _Mode(
      label: 'ADVISORY',
      caption:
          'Guidance or recommendation the institution wants the public to act on.',
      state: SubstrateChipState.sun,
    ),
    _Mode(
      label: 'NOTICE',
      caption:
          'Factual information being put on record. Reference, not action.',
      state: SubstrateChipState.mist,
    ),
    _Mode(
      label: 'UPDATE',
      caption:
          'In-flight progress on a prior commitment. Pairs with the accountability UPDATE tag.',
      state: SubstrateChipState.sun,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AuraSpace.s14),
      decoration: BoxDecoration(
        color: AuraSurface.subtle,
        borderRadius: BorderRadius.circular(AuraRadius.r14),
        border: Border.all(color: AuraSurface.divider.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 4,
                height: 14,
                decoration: BoxDecoration(
                  color: AuraSurface.coTeal,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: AuraSpace.s8),
              Expanded(
                child: Text(
                  'Institutional speech modes',
                  style: AuraText.subtitle.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Four typed registers an institution may speak under. The same vocabulary appears wherever institutions post.',
            style: AuraText.micro.copyWith(
              color: AuraSurface.faint,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: AuraSpace.s10),
          for (var i = 0; i < _modes.length; i++) ...[
            _ModeRow(mode: _modes[i]),
            if (i < _modes.length - 1) const SizedBox(height: AuraSpace.s8),
          ],
        ],
      ),
    );
  }
}

class _Mode {
  const _Mode({
    required this.label,
    required this.caption,
    required this.state,
  });

  final String label;
  final String caption;
  final SubstrateChipState state;
}

class _ModeRow extends StatelessWidget {
  const _ModeRow({required this.mode});
  final _Mode mode;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 150,
          child: SubstrateChip(label: mode.label, state: mode.state),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              mode.caption,
              style: AuraText.small.copyWith(
                color: AuraSurface.ink,
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
