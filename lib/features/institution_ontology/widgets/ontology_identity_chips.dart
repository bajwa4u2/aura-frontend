import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../providers.dart';

/// One reusable visual treatment for the institution-ontology identity.
///
/// Surfaces:
///   * `<CLASS>` chip (filled, accent-tinted)
///   * `<TYPE>` chip (outline, neutral-toned)
///   * up to N domain-tag chips (small, muted)
///
/// All labels are resolved against `institutionOntologyProvider`, so the
/// wire tokens stay stable while display labels can be retyped without
/// touching consumers. When the ontology has not yet loaded the chips
/// render the raw wire token rather than a placeholder spinner — this
/// is the calm visual treatment institutions deserve on a public page.
///
/// Visual tone is intentionally infrastructural: small caps + tabular
/// spacing on the class chip; outline on the type chip; muted text on
/// tags. NOT social-media tag spam.
class OntologyIdentityChips extends ConsumerWidget {
  const OntologyIdentityChips({
    super.key,
    required this.institutionClass,
    required this.institutionType,
    required this.domainTags,
    this.maxDomainTags = 4,
    this.dense = false,
    this.onTagTap,
  });

  /// Wire token (e.g., `GOVERNMENT`). Null hides the chip.
  final String? institutionClass;

  /// Wire token (e.g., `UNIVERSITY`). Null hides the chip.
  final String? institutionType;

  /// Wire tokens. Empty hides the row.
  final List<String> domainTags;

  /// Cap on visible domain-tag chips. Excess collapses into a count
  /// suffix on the last tag.
  final int maxDomainTags;

  /// Tighter spacing for in-card use; default spacing for profile heroes.
  final bool dense;

  /// Optional tap callback per tag (for filter drill-down on discovery
  /// surfaces). When null, tags render non-interactive.
  final void Function(String tagId)? onTagTap;

  bool get _isEmpty =>
      (institutionClass == null || institutionClass!.isEmpty) &&
      (institutionType == null || institutionType!.isEmpty) &&
      domainTags.isEmpty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (_isEmpty) return const SizedBox.shrink();
    final ontologyAsync = ref.watch(institutionOntologyProvider);
    final ontology = ontologyAsync.valueOrNull;

    final classLabel = institutionClass == null
        ? ''
        : (ontology?.classLabel(institutionClass) ?? institutionClass!);
    final typeLabel = institutionType == null
        ? ''
        : (ontology?.typeLabel(institutionType) ?? institutionType!);

    final shownTags = domainTags.take(maxDomainTags).toList(growable: false);
    final overflow = domainTags.length - shownTags.length;

    final spacing = dense ? AuraSpace.s4 : AuraSpace.s6;
    final runSpacing = dense ? AuraSpace.s4 : AuraSpace.s6;

    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (classLabel.isNotEmpty)
          _ClassChip(label: classLabel, dense: dense),
        if (typeLabel.isNotEmpty)
          _TypeChip(label: typeLabel, dense: dense),
        for (final tag in shownTags)
          _TagChip(
            label: ontology?.tagLabel(tag) ?? tag,
            dense: dense,
            onTap: onTagTap == null ? null : () => onTagTap!(tag),
          ),
        if (overflow > 0)
          _OverflowCounter(count: overflow, dense: dense),
      ],
    );
  }
}

class _ClassChip extends StatelessWidget {
  const _ClassChip({required this.label, required this.dense});

  final String label;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? AuraSpace.s8 : AuraSpace.s10,
        vertical: dense ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: AuraSurface.accentSoft,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        border: Border.all(
          color: AuraSurface.accent.withValues(alpha: 0.4),
        ),
      ),
      child: Text(
        label.toUpperCase(),
        style: AuraText.micro.copyWith(
          color: AuraSurface.accentText,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.7,
          fontSize: dense ? 9.5 : 10,
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.label, required this.dense});

  final String label;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? AuraSpace.s8 : AuraSpace.s10,
        vertical: dense ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Text(
        label,
        style: AuraText.micro.copyWith(
          color: AuraSurface.ink,
          fontWeight: FontWeight.w700,
          fontSize: dense ? 10 : 11,
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.label,
    required this.dense,
    required this.onTap,
  });

  final String label;
  final bool dense;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? AuraSpace.s6 : AuraSpace.s8,
        vertical: dense ? 1.5 : 2,
      ),
      decoration: BoxDecoration(
        color: AuraSurface.subtle,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
      ),
      child: Text(
        label,
        style: AuraText.micro.copyWith(
          color: AuraSurface.muted,
          fontWeight: FontWeight.w600,
          fontSize: dense ? 9.5 : 10,
          letterSpacing: 0.2,
        ),
      ),
    );
    if (onTap == null) return chip;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AuraRadius.pill),
      child: chip,
    );
  }
}

class _OverflowCounter extends StatelessWidget {
  const _OverflowCounter({required this.count, required this.dense});

  final int count;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Text(
        '+$count',
        style: AuraText.micro.copyWith(
          color: AuraSurface.faint,
          fontWeight: FontWeight.w700,
          fontSize: dense ? 9.5 : 10,
        ),
      ),
    );
  }
}
