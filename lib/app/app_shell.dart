import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

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

  static const double _maxContentWidth = 920;
  static const double _headerHeight = 72;
  static const double _logoHeight = 40;
  static const double _desktopBreakpoint = 1100;
  static const double _tabletBreakpoint = 760;
  static const String _logoAsset = 'assets/brand/AURA_logo_master.svg';

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

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isDesktop = width >= _desktopBreakpoint;
        final isTablet = width >= _tabletBreakpoint;

        return Scaffold(
          backgroundColor: AuraSurface.page,
          body: SafeArea(
            top: true,
            bottom: false,
            child: Column(
              children: [
                _MemberHeader(
                  isDesktop: isDesktop,
                  isTablet: isTablet,
                ),
                Expanded(
                  child: Row(
                    children: [
                      if (isDesktop)
                        _MemberSideNav(
                          items: _items,
                          selectedIndex: selectedIndex,
                          currentPath: path,
                        ),
                      Expanded(
                        child: child,
                      ),
                    ],
                  ),
                ),
                if (!isDesktop)
                  _MemberBottomNav(
                    items: _items,
                    selectedIndex: selectedIndex,
                    currentPath: path,
                    compact: !isTablet,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MemberHeader extends StatelessWidget {
  const _MemberHeader({
    required this.isDesktop,
    required this.isTablet,
  });

  final bool isDesktop;
  final bool isTablet;

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = isDesktop
        ? AuraSpace.s24
        : isTablet
            ? AuraSpace.s20
            : AuraSpace.s16;

    return Container(
      height: AppShell._headerHeight,
      decoration: const BoxDecoration(
        color: AuraSurface.page,
        border: Border(
          bottom: BorderSide(color: AuraSurface.divider),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: AppShell._maxContentWidth + 160),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: AuraSpace.s12,
            ),
            child: Row(
              children: [
                _AuraWordmark(
                  onTap: () => context.go('/home'),
                ),
                const Spacer(),
                _HeaderTools(
                  isTablet: isTablet,
                  isDesktop: isDesktop,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AuraWordmark extends StatelessWidget {
  const _AuraWordmark({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Aura',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s4,
            vertical: AuraSpace.s4,
          ),
          child: SvgPicture.asset(
            AppShell._logoAsset,
            height: AppShell._logoHeight,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

class _HeaderTools extends StatelessWidget {
  const _HeaderTools({
    required this.isTablet,
    required this.isDesktop,
  });

  final bool isTablet;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    if (isDesktop) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _HeaderPillButton(
            tooltip: 'Search',
            icon: Icons.search,
            label: 'Search',
            onTap: () => context.push('/search'),
          ),
          const SizedBox(width: AuraSpace.s8),
          _HeaderPillButton(
            tooltip: 'Activity',
            icon: Icons.notifications_none,
            label: 'Activity',
            onTap: () => context.push('/updates'),
          ),
          const SizedBox(width: AuraSpace.s8),
          _HeaderPillButton(
            tooltip: 'Me',
            icon: Icons.person_outline,
            label: 'Me',
            onTap: () => context.push('/me'),
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _HeaderIconButton(
          tooltip: 'Search',
          icon: Icons.search,
          onTap: () => context.push('/search'),
        ),
        const SizedBox(width: AuraSpace.s8),
        _HeaderIconButton(
          tooltip: 'Activity',
          icon: Icons.notifications_none,
          onTap: () => context.push('/updates'),
        ),
        const SizedBox(width: AuraSpace.s8),
        _HeaderIconButton(
          tooltip: 'Me',
          icon: Icons.person_outline,
          onTap: () => context.push('/me'),
        ),
        if (isTablet) const SizedBox(width: AuraSpace.s4),
      ],
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AuraSurface.card,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AuraSurface.divider),
          ),
          child: Icon(
            icon,
            size: 20,
            color: AuraSurface.muted,
          ),
        ),
      ),
    );
  }
}

class _HeaderPillButton extends StatelessWidget {
  const _HeaderPillButton({
    required this.tooltip,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s12,
          ),
          decoration: BoxDecoration(
            color: AuraSurface.card,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AuraSurface.divider),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: AuraSurface.muted,
              ),
              const SizedBox(width: AuraSpace.s8),
              Text(
                label,
                style: AuraText.small.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AuraSurface.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberSideNav extends StatelessWidget {
  const _MemberSideNav({
    required this.items,
    required this.selectedIndex,
    required this.currentPath,
  });

  final List<_MemberNavItem> items;
  final int selectedIndex;
  final String currentPath;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 248,
      decoration: const BoxDecoration(
        color: AuraSurface.page,
        border: Border(
          right: BorderSide(color: AuraSurface.divider),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AuraSpace.s16),
        child: Column(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              _MemberRailButton(
                item: items[i],
                selected: i == selectedIndex,
                onTap: () {
                  final target = items[i].path;
                  if (target != currentPath) {
                    context.go(target);
                  }
                },
              ),
              if (i != items.length - 1) const SizedBox(height: AuraSpace.s8),
            ],
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class _MemberRailButton extends StatelessWidget {
  const _MemberRailButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _MemberNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconData = selected ? item.selectedIcon : item.icon;
    final foreground = selected ? AuraSurface.ink : AuraSurface.muted;
    final background =
        selected ? AuraSurface.accentSoft : Colors.transparent;

    return Semantics(
      button: true,
      label: item.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s12,
            vertical: AuraSpace.s12,
          ),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? AuraSurface.divider
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: selected ? AuraSurface.page : AuraSurface.card,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AuraSurface.divider),
                ),
                child: Icon(
                  iconData,
                  size: 20,
                  color: foreground,
                ),
              ),
              const SizedBox(width: AuraSpace.s12),
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AuraText.small.copyWith(
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w600,
                    color: foreground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberBottomNav extends StatelessWidget {
  const _MemberBottomNav({
    required this.items,
    required this.selectedIndex,
    required this.currentPath,
    required this.compact,
  });

  final List<_MemberNavItem> items;
  final int selectedIndex;
  final String currentPath;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AuraSurface.card,
        border: Border(
          top: BorderSide(color: AuraSurface.divider),
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AuraSpace.s4 : AuraSpace.s8,
        vertical: compact ? AuraSpace.s6 : AuraSpace.s8,
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: _MemberNavButton(
                  item: items[i],
                  selected: i == selectedIndex,
                  compact: compact,
                  onTap: () {
                    final target = items[i].path;
                    if (target != currentPath) {
                      context.go(target);
                    }
                  },
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
    required this.compact,
  });

  final _MemberNavItem item;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

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
              padding: EdgeInsets.symmetric(
                vertical: compact ? AuraSpace.s4 / 2 : AuraSpace.s4,
                horizontal: AuraSpace.s4,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: compact ? 42 : 46,
                    height: compact ? 42 : 46,
                    decoration: BoxDecoration(
                      color: selected
                          ? AuraSurface.accentSoft
                          : AuraSurface.page,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AuraSurface.divider),
                    ),
                    child: Icon(
                      iconData,
                      size: compact ? 20 : 22,
                      color: iconColor,
                    ),
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
          padding: EdgeInsets.symmetric(
            vertical: compact ? AuraSpace.s4 : AuraSpace.s6,
            horizontal: AuraSpace.s4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                iconData,
                size: compact ? 20 : 22,
                color: iconColor,
              ),
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