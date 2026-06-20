import 'package:flutter/material.dart';

import 'aura_space.dart';
import 'aura_surface.dart';
import 'aura_text.dart';

/// Shared underline tab bar used by every profile surface so navigation reads
/// identically on `/me`, `/u/:handle`, and elsewhere.
///
/// Pass a [TabController] (the caller owns its lifecycle) and a list of
/// `(label, icon)` records. The bar is scrollable and start-aligned, so any
/// number of tabs degrades gracefully on narrow viewports.
class AuraProfileTabBar extends StatelessWidget {
  const AuraProfileTabBar({
    super.key,
    required this.controller,
    required this.tabs,
  });

  final TabController controller;
  final List<(String, IconData)> tabs;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AuraSurface.divider)),
      ),
      child: TabBar(
        controller: controller,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: AuraSurface.ink,
        unselectedLabelColor: AuraSurface.muted,
        indicatorColor: AuraSurface.accent,
        indicatorWeight: 2.5,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        labelStyle: AuraText.small.copyWith(fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            AuraText.small.copyWith(fontWeight: FontWeight.w600),
        tabs: [
          for (final tab in tabs)
            Tab(
              height: 44,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(tab.$2, size: 16),
                  const SizedBox(width: AuraSpace.s8),
                  Text(tab.$1),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
