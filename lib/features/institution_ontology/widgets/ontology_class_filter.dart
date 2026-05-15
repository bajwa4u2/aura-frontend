import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../providers.dart';

/// Horizontal pill filter for institution discovery.
///
/// Renders an "All" pill plus one pill per curated class from
/// `institutionOntologyProvider`. The selected class is highlighted
/// accent; the rest are neutral outline. Tapping a pill calls
/// `onChanged` with the wire-token id (or `null` for "All").
///
/// Empty / loading state: no fallback skeleton. The pill row is the
/// discovery filter — when ontology hasn't loaded yet, we render a
/// single "All" pill and nothing else, which is honest and never
/// blocks the institutions list below.
class OntologyClassFilter extends ConsumerWidget {
  const OntologyClassFilter({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  /// Wire token of the currently-selected class, or null for "All".
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ontology =
        ref.watch(institutionOntologyProvider).valueOrNull;
    final classes = ontology?.classes ?? const [];

    // Avoid the lonely-pill state — when the ontology hasn't loaded
    // yet, the previous build rendered just an isolated "All" chip,
    // which read as orphaned UI. With no classes available the whole
    // row collapses; once the ontology arrives the row materialises
    // with All + every class together.
    if (classes.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        children: [
          _Pill(
            label: 'All',
            selected: selected == null,
            onTap: () => onChanged(null),
          ),
          for (final c in classes) ...[
            const SizedBox(width: AuraSpace.s6),
            _Pill(
              label: c.label,
              selected: selected == c.id,
              onTap: () => onChanged(c.id),
            ),
          ],
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? AuraSurface.accentSoft : Colors.transparent;
    final border = selected
        ? AuraSurface.accent.withValues(alpha: 0.4)
        : AuraSurface.divider;
    final fg = selected ? AuraSurface.accentText : AuraSurface.ink;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AuraRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.s12,
          vertical: AuraSpace.s6,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AuraRadius.pill),
          border: Border.all(color: border),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AuraText.small.copyWith(
            color: fg,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
