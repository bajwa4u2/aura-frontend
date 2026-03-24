import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_providers.dart';
import '../core/auth/session_providers.dart';
import '../core/net/dio_provider.dart';
import '../core/ui/aura_space.dart';
import '../core/ui/aura_surface.dart';
import '../core/ui/aura_text.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  static bool _isInstitutionPath(String path) {
    return path == '/enter-institution' || path.startsWith('/institution');
  }

  static bool _isMemberPath(String path) {
    return path == '/home' ||
        path == '/saved' ||
        path == '/updates' ||
        path == '/conversations' ||
        path == '/activity' ||
        path == '/create' ||
        path == '/compose' ||
        path == '/announcements/create' ||
        path == '/ai/claim-audit' ||
        path == '/me' ||
        path == '/me/edit' ||
        path == '/security' ||
        path == '/me/follow-requests' ||
        path == '/me/correspondence' ||
        path == '/me/correspondence/create/conversation' ||
        path == '/me/correspondence/create/space' ||
        path.startsWith('/me/correspondence/') ||
        path == '/admin';
  }

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;

    if (_isInstitutionPath(path)) {
      return InstitutionShell(child: child);
    }
    if (_isMemberPath(path)) {
      return MemberShell(child: child);
    }
    return PublicShell(child: child);
  }
}

class PublicShell extends StatelessWidget {
  const PublicShell({super.key, required this.child});

  final Widget child;

  static const double maxContentWidth = 920;
  static const double desktopBreakpoint = 1100;
  static const double tabletBreakpoint = 760;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isDesktop = width >= desktopBreakpoint;
        final isTablet = width >= tabletBreakpoint;

        return Scaffold(
          backgroundColor: AuraSurface.page,
          body: SafeArea(
            top: true,
            bottom: false,
            child: Column(
              children: [
                _PublicHeader(
                  isDesktop: isDesktop,
                  isTablet: isTablet,
                ),
                Expanded(child: child),
                const _ShellFooter(),
              ],
            ),
          ),
        );
      },
    );
  }
}

class MemberShell extends StatelessWidget {
  const MemberShell({super.key, required this.child});

  final Widget child;

  static const List<_MemberNavItem> _items = [
    _MemberNavItem(
      label: 'Works',
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
      label: 'Conversations',
      icon: Icons.forum_outlined,
      selectedIcon: Icons.forum,
      path: '/conversations',
    ),
    _MemberNavItem(
      label: 'Presence',
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
      path: '/me',
    ),
  ];

  static const double _maxContentWidth = 920;
  static const double _headerHeight = 72;
  static const double _logoHeight = 44;
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

    if (path == '/conversations') return 3;

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
                        child: Column(
                          children: [
                            Expanded(
                              child: child,
                            ),
                            const _ShellFooter(),
                          ],
                        ),
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

class InstitutionShell extends StatelessWidget {
  const InstitutionShell({super.key, required this.child});

  final Widget child;

  static const List<_MemberNavItem> _items = [
    _MemberNavItem(
      label: 'Dashboard',
      icon: Icons.grid_view_outlined,
      selectedIcon: Icons.grid_view,
      path: '/institution/dashboard',
    ),
    _MemberNavItem(
      label: 'Announcements',
      icon: Icons.campaign_outlined,
      selectedIcon: Icons.campaign,
      path: '/institution/announcements',
    ),
    _MemberNavItem(
      label: 'Correspondence',
      icon: Icons.mail_outline,
      selectedIcon: Icons.mail,
      path: '/institution/correspondence',
    ),
    _MemberNavItem(
      label: 'Profile',
      icon: Icons.apartment_outlined,
      selectedIcon: Icons.apartment,
      path: '/institution/profile',
    ),
  ];

  static const double _desktopBreakpoint = 1100;
  static const double _tabletBreakpoint = 760;

  int _indexForPath(String path) {
    if (path == '/institution/dashboard') return 0;
    if (path == '/institution/announcements') return 1;
    if (path == '/institution/correspondence') return 2;
    if (path == '/institution/profile' || path == '/institution/domains') {
      return 3;
    }
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
                _InstitutionHeader(
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
                      Expanded(child: child),
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

class _PublicHeader extends StatelessWidget {
  const _PublicHeader({
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
      decoration: const BoxDecoration(
        color: AuraSurface.page,
        border: Border(
          bottom: BorderSide(color: AuraSurface.divider),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: PublicShell.maxContentWidth + 160,
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              AuraSpace.s12,
              horizontalPadding,
              AuraSpace.s12,
            ),
            child: Row(
              children: [
                _AuraWordmark(onTap: () => context.go('/public')),
                const SizedBox(width: AuraSpace.s12),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _HeaderTextLink(
                          label: 'Explore',
                          onTap: () => context.go('/search'),
                        ),
                        const SizedBox(width: AuraSpace.s8),
                        _HeaderTextLink(
                          label: 'Institutions',
                          onTap: () => context.go('/institutions'),
                        ),
                        const SizedBox(width: AuraSpace.s12),
                        _PublicActionButton(
                          label: 'Sign in',
                          filled: false,
                          onTap: () => context.go('/login'),
                        ),
                        const SizedBox(width: AuraSpace.s8),
                        _PublicActionButton(
                          label: 'Join',
                          filled: true,
                          onTap: () => context.go('/register'),
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
      height: MemberShell._headerHeight,
      decoration: const BoxDecoration(
        color: AuraSurface.page,
        border: Border(
          bottom: BorderSide(color: AuraSurface.divider),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: MemberShell._maxContentWidth + 160),
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
                  searchPath: '/search',
                  activityPath: '/activity',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InstitutionHeader extends StatelessWidget {
  const _InstitutionHeader({
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
      decoration: const BoxDecoration(
        color: AuraSurface.page,
        border: Border(
          bottom: BorderSide(color: AuraSurface.divider),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: PublicShell.maxContentWidth + 160,
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              AuraSpace.s12,
              horizontalPadding,
              AuraSpace.s12,
            ),
            child: Row(
              children: [
                _AuraWordmark(
                  onTap: () => context.go('/institution/dashboard'),
                ),
                const SizedBox(width: AuraSpace.s12),
                Expanded(
                  child: Text(
                    'Institution workspace',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AuraText.small.copyWith(
                      color: AuraSurface.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: AuraSpace.s12),
                _HeaderTools(
                  isTablet: isTablet,
                  isDesktop: isDesktop,
                  searchPath: '/search',
                  activityPath: '/institution/correspondence',
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
            MemberShell._logoAsset,
            height: MemberShell._logoHeight,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

class _HeaderTools extends ConsumerStatefulWidget {
  const _HeaderTools({
    required this.isTablet,
    required this.isDesktop,
    required this.searchPath,
    required this.activityPath,
  });

  final bool isTablet;
  final bool isDesktop;
  final String searchPath;
  final String activityPath;

  @override
  ConsumerState<_HeaderTools> createState() => _HeaderToolsState();
}

class _HeaderToolsState extends ConsumerState<_HeaderTools> {
  bool _busyLogout = false;

  Future<void> _handleAccountAction(String value) async {
    switch (value) {
      case 'profile':
        context.go('/me');
        return;
      case 'edit_profile':
        context.go('/me/edit');
        return;
      case 'security':
        context.go('/security');
        return;
      case 'logout':
        await _logout();
        return;
    }
  }

  Future<void> _logout() async {
    if (_busyLogout) return;

    setState(() => _busyLogout = true);

    final container = ProviderScope.containerOf(context, listen: false);
    final dio = container.read(dioProvider);

    try {
      await dio.post('/auth/logout');
    } catch (_) {
      // Local logout should still complete even if server logout fails.
    }

    if (mounted) {
      context.go('/public');
    }

    await Future<void>.delayed(Duration.zero);

    try {
      await container.read(tokenStoreProvider).clear();
      container.invalidate(emailVerifiedProvider);
      container.invalidate(authStatusProvider);
      container.invalidate(isAuthedProvider);
    } finally {
      if (mounted) {
        setState(() => _busyLogout = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isDesktop) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _HeaderPillButton(
            tooltip: 'Search',
            icon: Icons.search,
            label: 'Search',
            onTap: () => context.push(widget.searchPath),
          ),
          const SizedBox(width: AuraSpace.s8),
          _HeaderPillButton(
            tooltip: 'Activity',
            icon: Icons.notifications_none,
            label: 'Activity',
            onTap: () => context.push(widget.activityPath),
          ),
          const SizedBox(width: AuraSpace.s8),
          _HeaderAccountButton(
            compact: false,
            busy: _busyLogout,
            onSelected: (value) => unawaited(_handleAccountAction(value)),
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
          onTap: () => context.push(widget.searchPath),
        ),
        const SizedBox(width: AuraSpace.s8),
        _HeaderIconButton(
          tooltip: 'Activity',
          icon: Icons.notifications_none,
          onTap: () => context.push(widget.activityPath),
        ),
        const SizedBox(width: AuraSpace.s8),
        _HeaderAccountButton(
          compact: true,
          busy: _busyLogout,
          onSelected: (value) => unawaited(_handleAccountAction(value)),
        ),
        if (widget.isTablet) const SizedBox(width: AuraSpace.s4),
      ],
    );
  }
}

class _HeaderAccountButton extends StatelessWidget {
  const _HeaderAccountButton({
    required this.compact,
    required this.busy,
    required this.onSelected,
  });

  final bool compact;
  final bool busy;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      absorbing: busy,
      child: PopupMenuButton<String>(
        tooltip: 'Account',
        onSelected: onSelected,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AuraSurface.divider),
        ),
        color: AuraSurface.card,
        itemBuilder: (context) => [
          const PopupMenuItem<String>(
            value: 'profile',
            child: _AccountMenuItemRow(
              icon: Icons.person_outline,
              label: 'Profile',
            ),
          ),
          const PopupMenuItem<String>(
            value: 'edit_profile',
            child: _AccountMenuItemRow(
              icon: Icons.edit_outlined,
              label: 'Edit profile',
            ),
          ),
          const PopupMenuItem<String>(
            value: 'security',
            child: _AccountMenuItemRow(
              icon: Icons.shield_outlined,
              label: 'Security',
            ),
          ),
          const PopupMenuDivider(),
          PopupMenuItem<String>(
            value: 'logout',
            child: _AccountMenuItemRow(
              icon: busy ? Icons.hourglass_empty : Icons.logout,
              label: busy ? 'Signing out…' : 'Sign out',
              danger: true,
            ),
          ),
        ],
        child: compact
            ? _HeaderIconButtonVisual(
                tooltip: 'Account',
                icon: busy ? null : Icons.person_outline,
                progress: busy,
              )
            : _HeaderPillButtonVisual(
                tooltip: 'Account',
                icon: busy ? null : Icons.person_outline,
                label: busy ? 'Signing out…' : 'Account',
                progress: busy,
              ),
      ),
    );
  }
}

class _AccountMenuItemRow extends StatelessWidget {
  const _AccountMenuItemRow({
    required this.icon,
    required this.label,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? Colors.redAccent : AuraSurface.ink;

    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: AuraSpace.s12),
        Text(
          label,
          style: AuraText.small.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
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
        child: _HeaderIconButtonVisual(
          tooltip: tooltip,
          icon: icon,
          progress: false,
        ),
      ),
    );
  }
}

class _HeaderIconButtonVisual extends StatelessWidget {
  const _HeaderIconButtonVisual({
    required this.tooltip,
    required this.icon,
    required this.progress,
  });

  final String tooltip;
  final IconData? icon;
  final bool progress;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AuraSurface.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AuraSurface.divider),
        ),
        child: Center(
          child: progress
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
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
        child: _HeaderPillButtonVisual(
          tooltip: tooltip,
          icon: icon,
          label: label,
          progress: false,
        ),
      ),
    );
  }
}

class _HeaderPillButtonVisual extends StatelessWidget {
  const _HeaderPillButtonVisual({
    required this.tooltip,
    required this.icon,
    required this.label,
    required this.progress,
  });

  final String tooltip;
  final IconData? icon;
  final String label;
  final bool progress;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
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
            if (progress)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
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
            const SizedBox(width: AuraSpace.s6),
            const Icon(
              Icons.keyboard_arrow_down,
              size: 18,
              color: AuraSurface.muted,
            ),
          ],
        ),
      ),
    );
  }
}

class _PublicActionButton extends StatelessWidget {
  const _PublicActionButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final background = filled ? AuraSurface.ink : Colors.transparent;
    final foreground = filled ? AuraSurface.page : AuraSurface.ink;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.s12,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AuraSurface.divider),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AuraText.small.copyWith(
            color: foreground,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _HeaderTextLink extends StatelessWidget {
  const _HeaderTextLink({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: AuraSurface.ink,
        padding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.s8,
          vertical: AuraSpace.s8,
        ),
      ),
      child: Text(
        label,
        style: AuraText.small.copyWith(
          color: AuraSurface.ink,
          fontWeight: FontWeight.w600,
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
    final background = selected ? AuraSurface.accentSoft : Colors.transparent;

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
              color: selected ? AuraSurface.divider : Colors.transparent,
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
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
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
                      color: selected ? AuraSurface.accentSoft : AuraSurface.page,
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

class _ShellFooter extends StatelessWidget {
  const _ShellFooter();

  static const List<_FooterLink> _links = [
    _FooterLink(label: 'Mission', path: '/mission'),
    _FooterLink(label: 'Institutions', path: '/institutions'),
    _FooterLink(label: 'Investors', path: '/investors'),
    _FooterLink(label: 'Patrons', path: '/patrons'),
    _FooterLink(label: 'Supporters', path: '/supporters'),
    _FooterLink(label: 'Contact', path: '/contact'),
    _FooterLink(label: 'Privacy', path: '/privacy'),
    _FooterLink(label: 'Terms', path: '/terms'),
    _FooterLink(label: 'White Paper', path: '/white-paper'),
    _FooterLink(label: 'Founder', path: '/founder'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AuraSurface.page,
        border: Border(
          top: BorderSide(color: AuraSurface.divider),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: PublicShell.maxContentWidth + 160,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AuraSpace.s16,
              AuraSpace.s16,
              AuraSpace.s16,
              AuraSpace.s16,
            ),
            child: Wrap(
              spacing: AuraSpace.s8,
              runSpacing: AuraSpace.s8,
              children: [
                for (final link in _links)
                  _FooterButton(link: link),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FooterButton extends StatelessWidget {
  const _FooterButton({required this.link});

  final _FooterLink link;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => context.go(link.path),
      style: TextButton.styleFrom(
        foregroundColor: AuraSurface.muted,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.s4,
          vertical: AuraSpace.s4,
        ),
      ),
      child: Text(
        link.label,
        style: AuraText.small.copyWith(
          color: AuraSurface.muted,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _FooterLink {
  const _FooterLink({
    required this.label,
    required this.path,
  });

  final String label;
  final String path;
}
