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

class PublicShell extends StatelessWidget {
  const PublicShell({super.key, required this.child});

  final Widget child;

  static const double _maxContentWidth = 920;
  static const double _desktopBreakpoint = 1100;
  static const double _tabletBreakpoint = 760;

  @override
  Widget build(BuildContext context) {
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
                _PublicHeader(
                  isDesktop: isDesktop,
                  isTablet: isTablet,
                ),
                _PublicNavigation(
                  isDesktop: isDesktop,
                  isTablet: isTablet,
                ),
                Expanded(child: child),
                const _ShellFooter(compact: false),
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

  static const List<_NavItem> _items = [
    _NavItem(
      label: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      path: '/home',
    ),
    _NavItem(
      label: 'Correspondence',
      icon: Icons.mail_outline,
      selectedIcon: Icons.mail,
      path: '/me/correspondence',
    ),
    _NavItem(
      label: 'Compose',
      icon: Icons.add_box_outlined,
      selectedIcon: Icons.add_box,
      path: '/compose',
      isPrimary: true,
    ),
    _NavItem(
      label: 'Explore',
      icon: Icons.search,
      selectedIcon: Icons.search,
      path: '/explore',
    ),
    _NavItem(
      label: 'Me',
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
      path: '/me',
    ),
  ];

  static const double _maxContentWidth = 920;
  static const double _desktopBreakpoint = 1100;
  static const double _tabletBreakpoint = 760;

  int _indexForPath(String path) {
    if (path == '/home') return 0;
    if (path == '/me/correspondence' || path.startsWith('/me/correspondence/')) {
      return 1;
    }
    if (path == '/compose') return 2;
    if (path == '/explore') return 3;
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
                        child: Padding(
                          padding: EdgeInsets.only(
                            bottom: isDesktop ? 0 : (_MemberBottomNav.height + _ShellFooter.memberBarHeight),
                          ),
                          child: child,
                        ),
                      ),
                    ],
                  ),
                ),
                const _ShellFooter(compact: true),
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

  static const List<_NavItem> _items = [
    _NavItem(
      label: 'Dashboard',
      icon: Icons.grid_view_outlined,
      selectedIcon: Icons.grid_view,
      path: '/institution/dashboard',
    ),
    _NavItem(
      label: 'Announcements',
      icon: Icons.campaign_outlined,
      selectedIcon: Icons.campaign,
      path: '/institution/announcements',
    ),
    _NavItem(
      label: 'Correspondence',
      icon: Icons.mail_outline,
      selectedIcon: Icons.mail,
      path: '/institution/correspondence',
    ),
    _NavItem(
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
    if (path == '/institution/profile' || path == '/institution/domains') return 3;
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
                _InstitutionHeader(
                  isDesktop: isDesktop,
                  isTablet: isTablet,
                ),
                Expanded(
                  child: Row(
                    children: [
                      if (isDesktop)
                        _InstitutionSideNav(
                          items: _items,
                          selectedIndex: selectedIndex,
                          currentPath: path,
                        ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            bottom: isDesktop ? 0 : (_MemberBottomNav.height + _ShellFooter.memberBarHeight),
                          ),
                          child: child,
                        ),
                      ),
                    ],
                  ),
                ),
                const _ShellFooter(compact: true),
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
      height: 72,
      decoration: const BoxDecoration(
        color: AuraSurface.page,
        border: Border(
          bottom: BorderSide(color: AuraSurface.divider),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: PublicShell._maxContentWidth + 160),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: AuraSpace.s12,
            ),
            child: Row(
              children: [
                _AuraWordmark(onTap: () => context.go('/public')),
                const Spacer(),
                Wrap(
                  spacing: AuraSpace.s10,
                  runSpacing: AuraSpace.s10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _HeaderTextLink(
                      label: 'Explore',
                      onTap: () => context.go('/search'),
                    ),
                    _HeaderTextLink(
                      label: 'Institutions',
                      onTap: () => context.go('/institutions'),
                    ),
                    _HeaderOutlinedAction(
                      label: 'Sign in',
                      onTap: () => context.go('/login'),
                    ),
                    _HeaderFilledAction(
                      label: 'Join',
                      onTap: () => context.go('/register'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PublicNavigation extends StatelessWidget {
  const _PublicNavigation({
    required this.isDesktop,
    required this.isTablet,
  });

  final bool isDesktop;
  final bool isTablet;

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
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
          constraints: const BoxConstraints(maxWidth: PublicShell._maxContentWidth + 160),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              AuraSpace.s12,
              horizontalPadding,
              AuraSpace.s12,
            ),
            child: Wrap(
              spacing: AuraSpace.s10,
              runSpacing: AuraSpace.s10,
              children: [
                _PublicNavPill(
                  label: 'Home',
                  selected: path == '/' || path == '/public',
                  onTap: () => context.go('/public'),
                ),
                _PublicNavPill(
                  label: 'Explore',
                  selected: path == '/search' || path.startsWith('/posts/') || path.startsWith('/u/'),
                  onTap: () => context.go('/search'),
                ),
                _PublicNavPill(
                  label: 'Institutions',
                  selected: path == '/institutions' || path.startsWith('/institutions/'),
                  onTap: () => context.go('/institutions'),
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
      height: 72,
      decoration: const BoxDecoration(
        color: AuraSurface.page,
        border: Border(
          bottom: BorderSide(color: AuraSurface.divider),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: MemberShell._maxContentWidth + 160),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: AuraSpace.s12,
            ),
            child: Row(
              children: [
                _AuraWordmark(onTap: () => context.go('/home')),
                const Spacer(),
                _HeaderTools(
                  isTablet: isTablet,
                  isDesktop: isDesktop,
                  searchPath: '/explore',
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
      height: 72,
      decoration: const BoxDecoration(
        color: AuraSurface.page,
        border: Border(
          bottom: BorderSide(color: AuraSurface.divider),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: PublicShell._maxContentWidth + 160),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: AuraSpace.s12,
            ),
            child: Row(
              children: [
                _AuraWordmark(onTap: () => context.go('/institution/dashboard')),
                const SizedBox(width: AuraSpace.s14),
                Expanded(
                  child: Text(
                    'Institution workspace',
                    style: AuraText.small.copyWith(
                      color: AuraSurface.muted,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AuraSpace.s10),
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

  static const String _logoAsset = 'assets/brand/AURA_logo_master.svg';

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
            _logoAsset,
            height: 44,
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
            onTap: () => context.go(widget.searchPath),
          ),
          const SizedBox(width: AuraSpace.s8),
          _HeaderPillButton(
            tooltip: 'Activity',
            icon: Icons.notifications_none,
            label: 'Activity',
            onTap: () => context.go(widget.activityPath),
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
          onTap: () => context.go(widget.searchPath),
        ),
        const SizedBox(width: AuraSpace.s8),
        _HeaderIconButton(
          tooltip: 'Activity',
          icon: Icons.notifications_none,
          onTap: () => context.go(widget.activityPath),
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
          const PopupMenuDivider(height: 1),
          PopupMenuItem<String>(
            value: 'logout',
            child: _AccountMenuItemRow(
              icon: busy ? Icons.hourglass_empty : Icons.logout,
              label: busy ? 'Signing out…' : 'Sign out',
            ),
          ),
        ],
        child: compact
            ? Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AuraSurface.card,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AuraSurface.divider),
                ),
                child: const Icon(
                  Icons.person_outline,
                  color: AuraSurface.foreground,
                ),
              )
            : Container(
                height: 44,
                padding: const EdgeInsets.symmetric(
                  horizontal: AuraSpace.s14,
                ),
                decoration: BoxDecoration(
                  color: AuraSurface.card,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AuraSurface.divider),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(
                      Icons.person_outline,
                      size: 18,
                      color: AuraSurface.foreground,
                    ),
                    SizedBox(width: AuraSpace.s8),
                    Text(
                      'Account',
                      style: AuraText.small,
                    ),
                  ],
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: AuraSpace.s14),
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
                  color: AuraSurface.foreground,
                ),
                const SizedBox(width: AuraSpace.s8),
                Text(
                  label,
                  style: AuraText.small,
                ),
              ],
            ),
          ),
        ),
      ),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AuraSurface.card,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AuraSurface.divider),
            ),
            child: Icon(
              icon,
              size: 20,
              color: AuraSurface.foreground,
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountMenuItemRow extends StatelessWidget {
  const _AccountMenuItemRow({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AuraSurface.foreground),
        const SizedBox(width: AuraSpace.s10),
        Text(label, style: AuraText.small),
      ],
    );
  }
}

class _MemberSideNav extends StatelessWidget {
  const _MemberSideNav({
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
      width: 224,
      decoration: const BoxDecoration(
        border: Border(
          right: BorderSide(color: AuraSurface.divider),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.s14,
        AuraSpace.s18,
        AuraSpace.s14,
        AuraSpace.s18,
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            _SideNavTile(
              item: items[i],
              selected: selectedIndex == i,
              currentPath: currentPath,
            ),
            if (i != items.length - 1) const SizedBox(height: AuraSpace.s8),
          ],
          const Spacer(),
        ],
      ),
    );
  }
}

class _InstitutionSideNav extends StatelessWidget {
  const _InstitutionSideNav({
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
        border: Border(
          right: BorderSide(color: AuraSurface.divider),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.s14,
        AuraSpace.s18,
        AuraSpace.s14,
        AuraSpace.s18,
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            _SideNavTile(
              item: items[i],
              selected: selectedIndex == i,
              currentPath: currentPath,
            ),
            if (i != items.length - 1) const SizedBox(height: AuraSpace.s8),
          ],
          if (currentPath == '/institution/domains') ...[
            const SizedBox(height: AuraSpace.s8),
            _SideNavTile(
              item: const _NavItem(
                label: 'Domains',
                icon: Icons.language_outlined,
                selectedIcon: Icons.language,
                path: '/institution/domains',
              ),
              selected: true,
              currentPath: currentPath,
            ),
          ],
          const Spacer(),
        ],
      ),
    );
  }
}

class _SideNavTile extends StatelessWidget {
  const _SideNavTile({
    required this.item,
    required this.selected,
    required this.currentPath,
  });

  final _NavItem item;
  final bool selected;
  final String currentPath;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (currentPath == item.path) return;
          context.go(item.path);
        },
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s14,
            vertical: AuraSpace.s12,
          ),
          decoration: BoxDecoration(
            color: selected ? AuraSurface.card : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AuraSurface.divider : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected ? item.selectedIcon : item.icon,
                size: 20,
                color: selected
                    ? AuraSurface.foreground
                    : AuraSurface.muted,
              ),
              const SizedBox(width: AuraSpace.s12),
              Expanded(
                child: Text(
                  item.label,
                  style: AuraText.small.copyWith(
                    color: selected
                        ? AuraSurface.foreground
                        : AuraSurface.muted,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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

  static const double height = 88;

  final List<_NavItem> items;
  final int selectedIndex;
  final String currentPath;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: AuraSurface.page,
        border: Border(
          top: BorderSide(color: AuraSurface.divider),
        ),
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: _BottomNavButton(
                item: items[i],
                selected: selectedIndex == i,
                currentPath: currentPath,
                compact: compact,
              ),
            ),
        ],
      ),
    );
  }
}

class _BottomNavButton extends StatelessWidget {
  const _BottomNavButton({
    required this.item,
    required this.selected,
    required this.currentPath,
    required this.compact,
  });

  final _NavItem item;
  final bool selected;
  final String currentPath;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final icon = selected ? item.selectedIcon : item.icon;
    final labelStyle = AuraText.small.copyWith(
      fontSize: compact ? 11.5 : 12,
      color: selected ? AuraSurface.foreground : AuraSurface.muted,
      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
    );

    final iconWidget = Icon(
      icon,
      size: item.isPrimary ? 23 : 21,
      color: selected ? AuraSurface.foreground : AuraSurface.muted,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (currentPath == item.path) return;
          context.go(item.path);
        },
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AuraSpace.s8,
            compact ? AuraSpace.s10 : AuraSpace.s12,
            AuraSpace.s8,
            compact ? AuraSpace.s12 : AuraSpace.s14,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (item.isPrimary)
                Container(
                  width: compact ? 42 : 46,
                  height: compact ? 42 : 46,
                  decoration: BoxDecoration(
                    color: AuraSurface.card,
                    shape: BoxShape.circle,
                    border: Border.all(color: AuraSurface.divider),
                  ),
                  child: Center(child: iconWidget),
                )
              else
                iconWidget,
              const SizedBox(height: AuraSpace.s8),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: labelStyle,
              ),
            ],
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
        foregroundColor: AuraSurface.foreground,
        padding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.s8,
          vertical: AuraSpace.s10,
        ),
      ),
      child: Text(label, style: AuraText.small.copyWith(fontWeight: FontWeight.w600)),
    );
  }
}

class _HeaderOutlinedAction extends StatelessWidget {
  const _HeaderOutlinedAction({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.s14,
          vertical: AuraSpace.s12,
        ),
      ),
      child: Text(label),
    );
  }
}

class _HeaderFilledAction extends StatelessWidget {
  const _HeaderFilledAction({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.s14,
          vertical: AuraSpace.s12,
        ),
      ),
      child: Text(label),
    );
  }
}

class _PublicNavPill extends StatelessWidget {
  const _PublicNavPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s14,
            vertical: AuraSpace.s12,
          ),
          decoration: BoxDecoration(
            color: selected ? AuraSurface.card : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AuraSurface.divider : Colors.transparent,
            ),
          ),
          child: Text(
            label,
            style: AuraText.small.copyWith(
              color: selected ? AuraSurface.foreground : AuraSurface.muted,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _ShellFooter extends StatelessWidget {
  const _ShellFooter({required this.compact});

  static const double memberBarHeight = 54;

  final bool compact;

  static const List<_FooterLink> _links = [
    _FooterLink(label: 'Mission', path: '/mission'),
    _FooterLink(label: 'Institutions', path: '/institutions'),
    _FooterLink(label: 'Investors', path: '/investors'),
    _FooterLink(label: 'Patrons', path: '/patrons'),
    _FooterLink(label: 'Supporters', path: '/supporters'),
    _FooterLink(label: 'Contact', path: '/contact'),
    _FooterLink(label: 'Privacy', path: '/privacy'),
    _FooterLink(label: 'Terms', path: '/terms'),
    _FooterLink(label: 'White paper', path: '/white-paper'),
    _FooterLink(label: 'Founder', path: '/founder'),
  ];

  @override
  Widget build(BuildContext context) {
    final padding = compact
        ? const EdgeInsets.fromLTRB(AuraSpace.s16, AuraSpace.s10, AuraSpace.s16, AuraSpace.s10)
        : const EdgeInsets.fromLTRB(AuraSpace.s20, AuraSpace.s16, AuraSpace.s20, AuraSpace.s18);

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
          constraints: const BoxConstraints(maxWidth: PublicShell._maxContentWidth + 160),
          child: Padding(
            padding: padding,
            child: compact
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: AuraSpace.s12,
                        runSpacing: AuraSpace.s8,
                        children: [
                          for (final link in _links.take(8))
                            _FooterButton(link: link, compact: true),
                        ],
                      ),
                      const SizedBox(height: AuraSpace.s8),
                      Text(
                        'Aura Platform LLC',
                        style: AuraText.small.copyWith(
                          color: AuraSurface.muted,
                          fontSize: 11.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Aura',
                        style: AuraText.body.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: AuraSpace.s6),
                      Text(
                        'Reference only. Quiet routes for mission, policy, and institutional entry.',
                        style: AuraText.small.copyWith(color: AuraSurface.muted),
                      ),
                      const SizedBox(height: AuraSpace.s14),
                      Wrap(
                        spacing: AuraSpace.s12,
                        runSpacing: AuraSpace.s10,
                        children: [
                          for (final link in _links)
                            _FooterButton(link: link, compact: false),
                        ],
                      ),
                      const SizedBox(height: AuraSpace.s14),
                      Text(
                        '© 2026 Aura Platform LLC',
                        style: AuraText.small.copyWith(color: AuraSurface.muted),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _FooterButton extends StatelessWidget {
  const _FooterButton({
    required this.link,
    required this.compact,
  });

  final _FooterLink link;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => context.go(link.path),
      style: TextButton.styleFrom(
        foregroundColor: AuraSurface.muted,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? AuraSpace.s4 : AuraSpace.s2,
          vertical: compact ? AuraSpace.s2 : AuraSpace.s4,
        ),
      ),
      child: Text(
        link.label,
        style: AuraText.small.copyWith(
          fontSize: compact ? 11.5 : 12,
          color: AuraSurface.muted,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
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

class _FooterLink {
  const _FooterLink({
    required this.label,
    required this.path,
  });

  final String label;
  final String path;
}
