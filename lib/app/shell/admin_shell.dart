import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui/aura_design_system.dart';
import '../../core/ui/aura_radius.dart';
import '../../core/ui/aura_space.dart';
import '../../core/ui/aura_surface.dart';
import '../../core/ui/aura_text.dart';
import 'shell_header_tools.dart';
import 'shell_shared.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ADMIN COLOR PALETTE — amber authority, command-center dark
// ─────────────────────────────────────────────────────────────────────────────

const Color _adminAccent = Color(0xFFF59E0B);
const Color _adminAccentSoft = Color(0x20F59E0B);
const Color _adminAccentText = Color(0xFFFBBF24);
const Color _adminNavBg = Color(0xFF070B14);
const Color _adminHeaderBg1 = Color(0xFF07090F);
const Color _adminHeaderBg2 = Color(0xFF090D18);
const Color _adminHeaderBg3 = Color(0xFF0B1020);

const LinearGradient _adminHeaderGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [_adminHeaderBg1, _adminHeaderBg2, _adminHeaderBg3],
);

const LinearGradient _adminNavGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [_adminNavBg, Color(0xFF050810)],
);

// ─────────────────────────────────────────────────────────────────────────────
// ADMIN SHELL
// ─────────────────────────────────────────────────────────────────────────────

class AdminShell extends StatelessWidget {
  const AdminShell({super.key, required this.child});

  final Widget child;

  static const List<_NavItem> _items = [
    _NavItem(
      label: 'Dashboard',
      icon: Icons.space_dashboard_outlined,
      selectedIcon: Icons.space_dashboard_rounded,
      path: '/admin',
    ),
    _NavItem(
      label: 'Users',
      icon: Icons.group_outlined,
      selectedIcon: Icons.group_rounded,
      path: '/admin/users',
    ),
    _NavItem(
      label: 'Grants',
      icon: Icons.verified_user_outlined,
      selectedIcon: Icons.verified_user_rounded,
      path: '/admin/grants',
    ),
    _NavItem(
      label: 'Audit',
      icon: Icons.history_rounded,
      selectedIcon: Icons.history_rounded,
      path: '/admin/audit-logs',
    ),
    _NavItem(
      label: 'Domains',
      icon: Icons.apartment_outlined,
      selectedIcon: Icons.apartment_rounded,
      path: '/admin/institution-domains',
    ),
    _NavItem(
      label: 'Settings',
      icon: Icons.tune_outlined,
      selectedIcon: Icons.tune_rounded,
      path: '/admin/settings',
    ),
    _NavItem(
      label: 'Flags',
      icon: Icons.flag_outlined,
      selectedIcon: Icons.flag_rounded,
      path: '/admin/feature-flags',
    ),
    _NavItem(
      label: 'Comms',
      icon: Icons.mark_email_unread_outlined,
      selectedIcon: Icons.mark_email_unread_rounded,
      path: '/admin/communications',
    ),
  ];

  static const double _desktopBreakpoint = 1100;
  static const double _tabletBreakpoint = 760;

  int _indexForPath(String path) {
    if (path == '/admin') return 0;
    if (path == '/admin/users') return 1;
    if (path == '/admin/grants') return 2;
    if (path == '/admin/audit-logs') return 3;
    if (path == '/admin/institution-domains') return 4;
    if (path == '/admin/settings') return 5;
    if (path == '/admin/feature-flags') return 6;
    if (path == '/admin/communications') return 7;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
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
                _AdminHeader(isDesktop: isDesktop, isTablet: isTablet),
                Expanded(
                  child: Row(
                    children: [
                      if (isDesktop)
                        _AdminSideNav(
                          items: _items,
                          selectedIndex: selectedIndex,
                          currentPath: path,
                        ),
                      Expanded(child: child),
                    ],
                  ),
                ),
                if (!isDesktop)
                  _AdminBottomNav(
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

// ─────────────────────────────────────────────────────────────────────────────
// ADMIN HEADER
// ─────────────────────────────────────────────────────────────────────────────

class _AdminHeader extends StatelessWidget {
  const _AdminHeader({required this.isDesktop, required this.isTablet});

  final bool isDesktop;
  final bool isTablet;

  @override
  Widget build(BuildContext context) {
    final hPad = isDesktop
        ? AuraSpace.s24
        : isTablet
            ? AuraSpace.s20
            : AuraSpace.s16;

    return Container(
      height: 56,
      decoration: const BoxDecoration(
        gradient: _adminHeaderGradient,
        border: Border(bottom: BorderSide(color: Color(0x28F59E0B))),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: hPad),
        child: Row(
          children: [
            AuraShellWordmark(onTap: () => context.go('/admin')),
            const SizedBox(width: AuraSpace.s10),
            _AdminBadge(),
            const Spacer(),
            ShellHeaderTools(
              isTablet: isTablet,
              isDesktop: isDesktop,
              searchPath: '/search',
              activityPath: '/activity',
              invitePath: '/invite',
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: _adminAccentSoft,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        border: Border.all(color: _adminAccent.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: _adminAccent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _adminAccent.withValues(alpha: 0.6),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 5),
          Text(
            'ADMIN',
            style: AuraText.micro.copyWith(
              color: _adminAccentText,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ADMIN SIDE NAV
// ─────────────────────────────────────────────────────────────────────────────

class _AdminSideNav extends StatelessWidget {
  const _AdminSideNav({
    required this.items,
    required this.selectedIndex,
    required this.currentPath,
  });

  final List<_NavItem> items;
  final int selectedIndex;
  final String currentPath;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      decoration: const BoxDecoration(
        gradient: _adminNavGradient,
        border: Border(right: BorderSide(color: Color(0x14FFFFFF))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AuraSpace.s16,
              AuraSpace.s20,
              AuraSpace.s16,
              AuraSpace.s8,
            ),
            child: Text(
              'PLATFORM CONTROL',
              style: AuraText.micro.copyWith(
                color: _adminAccent.withValues(alpha: 0.7),
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
                fontSize: 10,
              ),
            ),
          ),
          for (var i = 0; i < items.length; i++) ...[
            _AdminSideNavTile(
              item: items[i],
              selected: i == selectedIndex,
              onTap: () {
                final target = items[i].path;
                if (target != currentPath) context.go(target);
              },
            ),
          ],
          const Spacer(),
          _AdminNavFooter(),
        ],
      ),
    );
  }
}

class _AdminSideNavTile extends StatelessWidget {
  const _AdminSideNavTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: item.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: AuraMotion.fast,
            margin: const EdgeInsets.symmetric(
              horizontal: AuraSpace.s8,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: selected ? _adminAccentSoft : Colors.transparent,
              borderRadius: BorderRadius.circular(AuraRadius.r10),
              border: Border.all(
                color: selected
                    ? _adminAccent.withValues(alpha: 0.3)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: AuraMotion.fast,
                  width: 3,
                  height: 42,
                  decoration: BoxDecoration(
                    color: selected ? _adminAccent : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AuraSpace.s12,
                      vertical: AuraSpace.s10,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selected ? item.selectedIcon : item.icon,
                          size: AuraIconSize.md,
                          color: selected ? _adminAccentText : AuraSurface.faint,
                        ),
                        const SizedBox(width: AuraSpace.s10),
                        Expanded(
                          child: Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AuraText.small.copyWith(
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: selected
                                  ? _adminAccentText
                                  : AuraSurface.faint,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminNavFooter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AuraSpace.s16),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.s12,
          vertical: AuraSpace.s10,
        ),
        decoration: BoxDecoration(
          color: _adminAccentSoft,
          borderRadius: BorderRadius.circular(AuraRadius.r10),
          border: Border.all(color: _adminAccent.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.verified_user_outlined,
              size: AuraIconSize.sm,
              color: _adminAccent.withValues(alpha: 0.8),
            ),
            const SizedBox(width: AuraSpace.s8),
            Expanded(
              child: Text(
                'Elevated access',
                style: AuraText.micro.copyWith(
                  color: _adminAccentText.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ADMIN BOTTOM NAV
// ─────────────────────────────────────────────────────────────────────────────

class _AdminBottomNav extends StatelessWidget {
  const _AdminBottomNav({
    required this.items,
    required this.selectedIndex,
    required this.currentPath,
    required this.compact,
  });

  final List<_NavItem> items;
  final int selectedIndex;
  final String currentPath;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: _adminNavGradient,
        border: Border(top: BorderSide(color: Color(0x22F59E0B))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? AuraSpace.s4 : AuraSpace.s8,
            vertical: compact ? AuraSpace.s6 : AuraSpace.s8,
          ),
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _AdminBottomNavBtn(
                    item: items[i],
                    selected: i == selectedIndex,
                    compact: compact,
                    onTap: () {
                      final target = items[i].path;
                      if (target != currentPath) context.go(target);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminBottomNavBtn extends StatelessWidget {
  const _AdminBottomNavBtn({
    required this.item,
    required this.selected,
    required this.onTap,
    required this.compact,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final iconColor = selected ? _adminAccentText : AuraSurface.faint;
    final textColor = selected ? _adminAccentText : AuraSurface.faint;

    return Semantics(
      button: true,
      label: item.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AuraRadius.r10),
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: compact ? AuraSpace.s4 : AuraSpace.s6,
            horizontal: AuraSpace.s4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? item.selectedIcon : item.icon,
                size: compact ? 20 : 22,
                color: iconColor,
              ),
              const SizedBox(height: AuraSpace.s4),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AuraText.micro.copyWith(
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w500,
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

// ─────────────────────────────────────────────────────────────────────────────
// DATA CLASS
// ─────────────────────────────────────────────────────────────────────────────

class _NavItem {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.path,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String path;
}
