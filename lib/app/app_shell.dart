import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/ui/aura_scaffold.dart';
import '../core/ui/aura_space.dart';
import '../core/ui/aura_surface.dart';
import '../core/ui/aura_text.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  static const List<_MemberNavItem> _items = [
    _MemberNavItem(
      label: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      path: '/home',
    ),
    _MemberNavItem(
      label: 'Correspondence',
      icon: Icons.mail_outline,
      selectedIcon: Icons.mail,
      path: '/me/correspondence',
    ),
    _MemberNavItem(
      label: 'Create',
      icon: Icons.add_box_outlined,
      selectedIcon: Icons.add_box,
      path: '/compose',
      isPrimary: true,
    ),
    _MemberNavItem(
      label: 'Activity',
      icon: Icons.notifications_none,
      selectedIcon: Icons.notifications,
      path: '/updates',
    ),
    _MemberNavItem(
      label: 'Me',
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
      path: '/me',
    ),
  ];

  int _indexForPath(String path) {
    if (path == '/home') return 0;

    if (path == '/me/correspondence' ||
        path.startsWith('/me/correspondence/')) {
      return 1;
    }

    if (path == '/compose' || path == '/create') return 2;

    if (path == '/updates') return 3;

    if (path == '/me' || path.startsWith('/me/')) return 4;

    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final uri = GoRouterState.of(context).uri;
    final path = uri.path;
    final selectedIndex = _indexForPath(path);

    return Scaffold(
      backgroundColor: AuraSurface.page,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: child,
            ),
            Container(
              decoration: const BoxDecoration(
                color: AuraSurface.card,
                border: Border(
                  top: BorderSide(color: AuraSurface.divider),
                ),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AuraSpace.s4,
                vertical: AuraSpace.s6,
              ),
              child: Row(
                children: [
                  for (var i = 0; i < _items.length; i++)
                    Expanded(
                      child: _MemberNavButton(
                        item: _items[i],
                        selected: i == selectedIndex,
                        onTap: () {
                          final target = _items[i].path;
                          if (target != path) {
                            context.go(target);
                          }
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberNavItem {
  const _MemberNavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.path,
    this.isPrimary = false,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String path;
  final bool isPrimary;
}

class _MemberNavButton extends StatelessWidget {
  const _MemberNavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _MemberNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconColor = selected ? AuraSurface.ink : AuraSurface.muted;
    final textColor = selected ? AuraSurface.ink : AuraSurface.muted;
    final iconData = selected ? item.selectedIcon : item.icon;

    if (item.isPrimary) {
      return Center(
        child: Semantics(
          button: true,
          label: item.label,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AuraSpace.s4,
                horizontal: AuraSpace.s4,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: selected
                          ? AuraSurface.accentSoft
                          : AuraSurface.page,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AuraSurface.divider),
                    ),
                    child: Icon(iconData, size: 22, color: iconColor),
                  ),
                  const SizedBox(height: AuraSpace.s4),
                  Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AuraText.small.copyWith(
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Semantics(
      button: true,
      label: item.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AuraSpace.s6,
            horizontal: AuraSpace.s4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(iconData, size: 22, color: iconColor),
              const SizedBox(height: AuraSpace.s4),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AuraText.small.copyWith(
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
