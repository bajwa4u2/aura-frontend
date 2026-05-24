import 'package:flutter/material.dart';

import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/ui/substrate_chip.dart';

/// Accountability tag legend — names the three canonical
/// accountability tags an institution voice can set on a reply,
/// per `lib/features/public/domain/accountability_tag.dart`:
///
///   COMMITMENT  →  the institution will act on the issue
///   UPDATE      →  in-flight progress on a prior commitment
///   RESOLVED    →  the issue is closed (positively or formally)
///
/// The legend is static — it is the canon. Pairing this legend
/// with the live `AccountabilityTimelineRail` and
/// `OpenCommitmentsBoard` gives a reader the full taxonomy + the
/// substrate together: vocabulary, lifecycle, current ledger.
///
/// Doctrine mirror — AU-01 §5 (Accountability lifecycle) +
/// `lib/features/public/domain/accountability_tag.dart` (the
/// wire enum). Verbatim definitions per the
/// substrate-citation doctrine.
class AccountabilityTagLegend extends StatelessWidget {
  const AccountabilityTagLegend({super.key});

  static const _tags = [
    _Tag(
      label: 'COMMITMENT',
      caption: 'The institution will act on the issue.',
      state: SubstrateChipState.teal,
    ),
    _Tag(
      label: 'UPDATE',
      caption: 'In-flight progress on a prior commitment.',
      state: SubstrateChipState.sun,
    ),
    _Tag(
      label: 'RESOLVED',
      caption: 'The issue is closed (positively or formally).',
      state: SubstrateChipState.verdant,
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
                  'Accountability tags',
                  style: AuraText.subtitle.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Three canonical states an institution can mark its reply with. The same tag drives feed chips, timelines, and the open-commitments ledger.',
            style: AuraText.micro.copyWith(
              color: AuraSurface.faint,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: AuraSpace.s10),
          for (var i = 0; i < _tags.length; i++) ...[
            _TagRow(tag: _tags[i]),
            if (i < _tags.length - 1) const SizedBox(height: AuraSpace.s8),
          ],
        ],
      ),
    );
  }
}

class _Tag {
  const _Tag({
    required this.label,
    required this.caption,
    required this.state,
  });

  final String label;
  final String caption;
  final SubstrateChipState state;
}

class _TagRow extends StatelessWidget {
  const _TagRow({required this.tag});
  final _Tag tag;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: SubstrateChip(label: tag.label, state: tag.state),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              tag.caption,
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
