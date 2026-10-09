import 'package:flutter/material.dart';

import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import 'workspace_page.dart';

/// A row's own menu (DD-43): every act on one item, none of them gold. Sits
/// in [WorkspaceRow.trailing].
class WorkspaceRowMenu extends StatelessWidget {
  const WorkspaceRowMenu({super.key, required this.actions});

  final List<WorkspaceAction> actions;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: 'Actions',
      color: AuraSurface.overlay,
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AuraSurface.divider),
      ),
      icon: const Icon(Icons.more_vert_rounded, size: 20, color: AuraSurface.muted),
      onSelected: (i) => actions[i].onPressed?.call(),
      itemBuilder: (_) => [
        for (var i = 0; i < actions.length; i++)
          PopupMenuItem<int>(
            value: i,
            enabled: actions[i].onPressed != null,
            child: Row(
              children: [
                if (actions[i].icon != null) ...[
                  Icon(actions[i].icon, size: 18, color: actions[i].destructive ? AuraSurface.dangerInk : AuraSurface.muted),
                  const SizedBox(width: AuraSpace.s12),
                ],
                Text(
                  actions[i].label,
                  style: AuraText.body.copyWith(color: actions[i].destructive ? AuraSurface.dangerInk : AuraSurface.ink),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
