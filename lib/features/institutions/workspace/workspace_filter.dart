import 'package:flutter/material.dart';

import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import 'workspace_page.dart';

/// THE ONE FILTER CONTROL (DD-43): at the end of the tabs row, never a row
/// of dropdowns beside the tabs. It says how many filters are on; it opens a
/// sheet of groups, one choice per group.
class WorkspaceFilterButton extends StatelessWidget {
  const WorkspaceFilterButton({super.key, required this.active, required this.onPressed});

  /// How many filters are on now.
  final int active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final on = active > 0;
    return Semantics(
      button: true,
      label: on ? 'Filter, $active on' : 'Filter',
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AuraSpace.s14, vertical: AuraSpace.s8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AuraRadius.pill),
            color: on ? AuraSurface.accentSoft : Colors.transparent,
            border: Border.all(color: on ? AuraSurface.accent : AuraSurface.divider),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.tune_rounded, size: 16, color: on ? AuraSurface.accentText : AuraSurface.muted),
              const SizedBox(width: AuraSpace.s6),
              Text(
                on ? 'Filter · $active' : 'Filter',
                style: TextStyle(
                  fontFamily: 'AuraSans',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: on ? AuraSurface.ink : AuraSurface.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One group in the filter sheet: a title and its choices.
class WorkspaceFilterGroup<T> {
  const WorkspaceFilterGroup({
    required this.title,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final String title;
  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onSelected;
}

/// Opens the filter sheet. Each choice applies at once; Done closes it.
Future<void> showWorkspaceFilterSheet(BuildContext context, {required List<WorkspaceFilterGroup<dynamic>> groups}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AuraSurface.card,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AuraRadius.lg))),
    builder: (sheet) => _FilterSheet(groups: groups),
  );
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.groups});

  final List<WorkspaceFilterGroup<dynamic>> groups;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late final List<dynamic> _selected = [for (final g in widget.groups) g.selected];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(AuraSpace.s20, AuraSpace.s20, AuraSpace.s20, AuraSpace.s16),
          children: [
            Row(
              children: [
                const Expanded(child: Text('Filter', style: WorkspaceType.sectionTitle)),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(foregroundColor: AuraSurface.accentText),
                  child: const Text('Done'),
                ),
              ],
            ),
            for (var g = 0; g < widget.groups.length; g++) ...[
              const SizedBox(height: AuraSpace.s16),
              Text(widget.groups[g].title.toUpperCase(), style: WorkspaceType.eyebrow),
              const SizedBox(height: AuraSpace.s8),
              Wrap(
                spacing: AuraSpace.s8,
                runSpacing: AuraSpace.s8,
                children: [
                  for (final (value, label) in widget.groups[g].options)
                    _Choice(
                      label: label,
                      selected: value == _selected[g],
                      onTap: () {
                        setState(() => _selected[g] = value);
                        widget.groups[g].onSelected(value);
                      },
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A choice in the sheet, drawn like a tab so the two read as one idiom.
class _Choice extends StatelessWidget {
  const _Choice({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AuraSpace.s14, vertical: AuraSpace.s8),
          decoration: BoxDecoration(
            color: selected ? AuraSurface.accentSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(AuraRadius.pill),
            border: Border.all(color: selected ? AuraSurface.accent : AuraSurface.divider),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'AuraSans',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? AuraSurface.ink : AuraSurface.muted,
            ),
          ),
        ),
      ),
    );
  }
}
