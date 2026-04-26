import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import 'route_classification.dart';
import 'route_targets.dart';

import '../core/auth/auth_providers.dart';
import '../core/auth/session_providers.dart';
import '../core/net/dio_provider.dart';
import '../core/ui/aura_design_system.dart';
import '../features/realtime/presentation/incoming_live_overlay.dart';
import '../core/ui/aura_radius.dart';
import '../core/ui/aura_space.dart';
import '../core/ui/aura_surface.dart';
import '../core/ui/aura_text.dart';
import '../features/updates/providers.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = GoRouterState.of(context).uri.path;
    final isAuthed = ref.watch(isAuthedProvider);

    if (isInstitutionShellPath(path)) {
      return InstitutionShell(child: child);
    }
    if (isMemberShellPath(path) ||
        (isAuthed && shouldUseMemberShellForAuthed(path))) {
      return MemberShell(child: child);
    }
    return PublicShell(child: child);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PUBLIC SHELL
// ─────────────────────────────────────────────────────────────────────────────

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
                _PublicHeader(isDesktop: isDesktop, isTablet: isTablet),
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

// ─────────────────────────────────────────────────────────────────────────────
// MEMBER SHELL
// ─────────────────────────────────────────────────────────────────────────────

class MemberShell extends StatelessWidget {
  const MemberShell({super.key, required this.child});

  final Widget child;

  static const List<_NavItem> _items = [
    _NavItem(
      label: 'Works',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      path: '/home',
    ),
    _NavItem(
      label: 'Messages',
      icon: Icons.mail_outline_rounded,
      selectedIcon: Icons.mail_rounded,
      path: '/me/correspondence',
    ),
    _NavItem(
      label: 'Create',
      icon: Icons.add_rounded,
      selectedIcon: Icons.add_rounded,
      path: '/compose',
      isPrimary: true,
    ),
    _NavItem(
      label: 'Spaces',
      icon: Icons.forum_outlined,
      selectedIcon: Icons.forum_rounded,
      path: '/conversations',
    ),
    _NavItem(
      label: 'Me',
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
      path: '/me',
    ),
  ];

  static const double _maxContentWidth = 920;
  static const double _headerHeight = 64;
  static const double _logoHeight = 40;
  static const double _desktopBreakpoint = 1100;
  static const double _tabletBreakpoint = 760;
  static const String _logoAsset = 'assets/brand/AURA_logo_master.svg';

  int _indexForPath(String path) {
    if (path == '/home') return 0;
    if (path == '/me/correspondence' || path.startsWith('/me/correspondence/')) {
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
            child: AuraIncomingLiveLayer(
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
                              Expanded(child: child),
                              if (_showMemberFooter(path))
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
          ),
        );
      },
    );
  }
}

bool _showMemberFooter(String path) {
  if (path.startsWith('/realtime')) return false;
  if (path == '/conversations' || path.startsWith('/conversations/')) {
    return false;
  }
  if (path.startsWith('/me/correspondence/')) return false;
  if (path.startsWith('/spaces/') || path.startsWith('/space/')) return false;
  return true;
}

// ─────────────────────────────────────────────────────────────────────────────
// INSTITUTION SHELL
// ─────────────────────────────────────────────────────────────────────────────

class InstitutionShell extends StatelessWidget {
  const InstitutionShell({super.key, required this.child});

  final Widget child;

  static const List<_NavItem> _items = [
    _NavItem(
      label: 'Dashboard',
      icon: Icons.grid_view_outlined,
      selectedIcon: Icons.grid_view_rounded,
      path: '/institution/dashboard',
    ),
    _NavItem(
      label: 'Announcements',
      icon: Icons.campaign_outlined,
      selectedIcon: Icons.campaign_rounded,
      path: '/institution/announcements',
    ),
    _NavItem(
      label: 'Messages',
      icon: Icons.mail_outline_rounded,
      selectedIcon: Icons.mail_rounded,
      path: '/institution/correspondence',
    ),
    _NavItem(
      label: 'Profile',
      icon: Icons.apartment_outlined,
      selectedIcon: Icons.apartment_rounded,
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
            child: AuraIncomingLiveLayer(
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
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADERS
// ─────────────────────────────────────────────────────────────────────────────

class _PublicHeader extends StatelessWidget {
  const _PublicHeader({required this.isDesktop, required this.isTablet});

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
      decoration: const BoxDecoration(
        gradient: AuraGradients.header,
        border: Border(bottom: BorderSide(color: AuraSurface.divider)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
              maxWidth: PublicShell.maxContentWidth + 160),
          child: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: hPad, vertical: AuraSpace.s12),
            child: Row(
              children: [
                _AuraWordmark(onTap: () => context.go('/public')),
                const Spacer(),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isTablet) ...[
                      _NavTextLink(
                        label: 'Explore',
                        onTap: () => context.go('/search'),
                      ),
                      const SizedBox(width: AuraSpace.s4),
                      _NavTextLink(
                        label: 'Institutions',
                        onTap: () => context.go('/institutions'),
                      ),
                      const SizedBox(width: AuraSpace.s12),
                    ],
                    _SignInButton(onTap: () => context.go('/login')),
                    const SizedBox(width: AuraSpace.s8),
                    _JoinButton(onTap: () => context.go('/register')),
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

class _MemberHeader extends StatelessWidget {
  const _MemberHeader({required this.isDesktop, required this.isTablet});

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
      height: MemberShell._headerHeight,
      decoration: const BoxDecoration(
        gradient: AuraGradients.header,
        border: Border(bottom: BorderSide(color: AuraSurface.divider)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
              maxWidth: MemberShell._maxContentWidth + 160),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: hPad),
            child: Row(
              children: [
                _AuraWordmark(onTap: () => context.go('/home')),
                const Spacer(),
                _HeaderTools(
                  isTablet: isTablet,
                  isDesktop: isDesktop,
                  searchPath: '/search',
                  activityPath: '/activity',
                  invitePath: '/invite',
                  liveRoomsPath: '/realtime',
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
  const _InstitutionHeader({required this.isDesktop, required this.isTablet});

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
      decoration: const BoxDecoration(
        gradient: AuraGradients.header,
        border: Border(bottom: BorderSide(color: AuraSurface.divider)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
              maxWidth: PublicShell.maxContentWidth + 160),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
                hPad, AuraSpace.s12, hPad, AuraSpace.s12),
            child: Row(
              children: [
                _AuraWordmark(
                  onTap: () => context.go('/institution/dashboard'),
                ),
                const SizedBox(width: AuraSpace.s10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AuraSpace.s8, vertical: AuraSpace.s4),
                  decoration: BoxDecoration(
                    color: AuraSurface.accentSoft,
                    borderRadius: BorderRadius.circular(AuraRadius.pill),
                    border: Border.all(
                        color: AuraSurface.accent.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    'Institution',
                    style: AuraText.label.copyWith(
                        color: AuraSurface.accentText,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                const Spacer(),
                _HeaderTools(
                  isTablet: isTablet,
                  isDesktop: isDesktop,
                  searchPath: '/search',
                  activityPath: '/institution/correspondence',
                  invitePath: '/invite',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WORDMARK
// ─────────────────────────────────────────────────────────────────────────────

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
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AuraSpace.s4, vertical: AuraSpace.s4),
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

// ─────────────────────────────────────────────────────────────────────────────
// HEADER TOOLS (ICON STRIP)
// ─────────────────────────────────────────────────────────────────────────────

class _HeaderTools extends ConsumerStatefulWidget {
  const _HeaderTools({
    required this.isTablet,
    required this.isDesktop,
    required this.searchPath,
    required this.activityPath,
    required this.invitePath,
    this.liveRoomsPath,
  });

  final bool isTablet;
  final bool isDesktop;
  final String searchPath;
  final String activityPath;
  final String invitePath;
  final String? liveRoomsPath;

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
    } catch (_) {}

    try {
      await container.read(tokenStoreProvider).clear();
      container.invalidate(emailVerifiedProvider);
      container.invalidate(authStatusProvider);
      container.invalidate(isAuthedProvider);
    } finally {
      if (mounted) context.go('/public');
      if (mounted) setState(() => _busyLogout = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = ref.watch(notificationsUnreadCountProvider);
    const gap = SizedBox(width: AuraSpace.s6);

    final tools = <Widget>[
      _HeaderIconBtn(
        icon: Icons.search_rounded,
        tooltip: 'Search',
        onTap: () => context.push(widget.searchPath),
      ),
      gap,
      _HeaderActivityBtn(
        unreadCount: unreadCount,
        onTap: () => context.push(widget.activityPath),
      ),
      if ((widget.liveRoomsPath ?? '').isNotEmpty) ...[
        gap,
        _HeaderIconBtn(
          icon: Icons.videocam_outlined,
          tooltip: 'Live rooms',
          onTap: () => context.push(widget.liveRoomsPath!),
        ),
      ],
      gap,
      _HeaderIconBtn(
        icon: Icons.outbound_outlined,
        tooltip: 'Invite',
        onTap: () => context.push(widget.invitePath),
      ),
      gap,
      _HeaderAccountBtn(
        busy: _busyLogout,
        onSelected: (v) => unawaited(_handleAccountAction(v)),
      ),
    ];

    if (widget.isTablet) tools.add(const SizedBox(width: AuraSpace.s4));
    return Row(mainAxisSize: MainAxisSize.min, children: tools);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER BUTTON ATOMS
// ─────────────────────────────────────────────────────────────────────────────

class _HeaderIconBtn extends StatelessWidget {
  const _HeaderIconBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AuraSurface.subtle,
            borderRadius: BorderRadius.circular(AuraRadius.pill),
            border: Border.all(color: AuraSurface.divider),
          ),
          child: Icon(icon, size: 18, color: AuraSurface.muted),
        ),
      ),
    );
  }
}

class _HeaderActivityBtn extends StatelessWidget {
  const _HeaderActivityBtn({
    required this.unreadCount,
    required this.onTap,
  });

  final int unreadCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Activity',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AuraSurface.subtle,
                borderRadius: BorderRadius.circular(AuraRadius.pill),
                border: Border.all(color: AuraSurface.divider),
              ),
              child: const Icon(Icons.notifications_none_rounded,
                  size: 18, color: AuraSurface.muted),
            ),
            if (unreadCount > 0)
              Positioned(
                right: 0,
                top: 0,
                child: _UnreadDot(count: unreadCount),
              ),
          ],
        ),
      ),
    );
  }
}

class _UnreadDot extends StatelessWidget {
  const _UnreadDot({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: AuraSurface.accent,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        border: Border.all(color: AuraSurface.page, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: AuraText.micro.copyWith(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _HeaderAccountBtn extends StatelessWidget {
  const _HeaderAccountBtn({required this.busy, required this.onSelected});

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
          borderRadius: BorderRadius.circular(AuraRadius.r16),
          side: const BorderSide(color: AuraSurface.divider),
        ),
        color: AuraSurface.overlay,
        itemBuilder: (context) => [
          _menuItem('profile', Icons.person_outline_rounded, 'Profile'),
          _menuItem('edit_profile', Icons.edit_outlined, 'Edit profile'),
          _menuItem('security', Icons.shield_outlined, 'Security'),
          const PopupMenuDivider(),
          _menuItem('logout',
              busy ? Icons.hourglass_empty : Icons.logout_rounded,
              busy ? 'Signing out…' : 'Sign out',
              danger: true),
        ],
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AuraSurface.subtle,
            borderRadius: BorderRadius.circular(AuraRadius.pill),
            border: Border.all(color: AuraSurface.divider),
          ),
          child: busy
              ? const Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AuraSurface.muted,
                    ),
                  ),
                )
              : const Icon(Icons.person_outline_rounded,
                  size: 18, color: AuraSurface.muted),
        ),
      ),
    );
  }

  PopupMenuItem<String> _menuItem(
    String value,
    IconData icon,
    String label, {
    bool danger = false,
  }) {
    final color = danger ? AuraSurface.dangerInk : AuraSurface.ink;
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: AuraSpace.s10),
          Text(
            label,
            style: AuraText.small.copyWith(
                color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PUBLIC HEADER BUTTON ATOMS
// ─────────────────────────────────────────────────────────────────────────────

class _NavTextLink extends StatelessWidget {
  const _NavTextLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: AuraSurface.muted,
        padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s10, vertical: AuraSpace.s8),
      ),
      child: Text(
        label,
        style:
            AuraText.small.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _SignInButton extends StatelessWidget {
  const _SignInButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AuraRadius.pill),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s12, vertical: AuraSpace.s8),
        child: Text(
          'Sign in',
          style: AuraText.small.copyWith(
              fontWeight: FontWeight.w600, color: AuraSurface.muted),
        ),
      ),
    );
  }
}

class _JoinButton extends StatelessWidget {
  const _JoinButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        child: Ink(
          decoration: BoxDecoration(
            gradient: AuraGradients.accent,
            borderRadius: BorderRadius.circular(AuraRadius.pill),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AuraSpace.s14, vertical: AuraSpace.s8),
            child: Text(
              'Join',
              style: AuraText.small.copyWith(
                  fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SIDE NAV
// ─────────────────────────────────────────────────────────────────────────────

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
      width: 240,
      decoration: const BoxDecoration(
        gradient: AuraGradients.sideNav,
        border: Border(right: BorderSide(color: AuraSurface.divider)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AuraSpace.s12, AuraSpace.s16, AuraSpace.s12, AuraSpace.s20),
        child: Column(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              _SideNavTile(
                item: items[i],
                selected: i == selectedIndex,
                onTap: () {
                  final target = items[i].path;
                  if (target != currentPath) context.go(target);
                },
              ),
              if (i != items.length - 1) const SizedBox(height: AuraSpace.s4),
            ],
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class _SideNavTile extends StatelessWidget {
  const _SideNavTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconData = selected ? item.selectedIcon : item.icon;
    final fgColor = selected ? AuraSurface.ink : AuraSurface.muted;

    return Semantics(
      button: true,
      label: item.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AuraRadius.r14),
          child: AnimatedContainer(
            duration: AuraMotion.fast,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: AuraSpace.s12, vertical: AuraSpace.s10),
            decoration: BoxDecoration(
              color: selected ? AuraSurface.accentSoft : Colors.transparent,
              borderRadius: BorderRadius.circular(AuraRadius.r14),
              border: Border.all(
                color: selected
                    ? AuraSurface.accent.withValues(alpha: 0.25)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(iconData, size: AuraIconSize.md, color: fgColor),
                const SizedBox(width: AuraSpace.s10),
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AuraText.small.copyWith(
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                      color: fgColor,
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

// ─────────────────────────────────────────────────────────────────────────────
// BOTTOM NAV
// ─────────────────────────────────────────────────────────────────────────────

class _MemberBottomNav extends StatelessWidget {
  const _MemberBottomNav({
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
        gradient: AuraGradients.bottomNav,
        border: Border(top: BorderSide(color: AuraSurface.divider)),
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
                  child: _BottomNavButton(
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

class _BottomNavButton extends StatelessWidget {
  const _BottomNavButton({
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
    if (item.isPrimary) {
      return Center(
        child: Semantics(
          button: true,
          label: item.label,
          child: GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: AuraMotion.fast,
              width: compact ? 46 : 52,
              height: compact ? 46 : 52,
              decoration: BoxDecoration(
                gradient: selected ? null : AuraGradients.accent,
                color: selected ? AuraSurface.accentSoft : null,
                borderRadius: BorderRadius.circular(AuraRadius.pill),
                border: Border.all(
                  color: selected
                      ? AuraSurface.accent.withValues(alpha: 0.4)
                      : Colors.transparent,
                ),
                boxShadow: selected ? [] : AuraShadows.glow,
              ),
              child: Icon(
                item.icon,
                size: compact ? 20 : 22,
                color: Colors.white,
              ),
            ),
          ),
        ),
      );
    }

    final iconColor = selected ? AuraSurface.ink : AuraSurface.faint;
    final textColor = selected ? AuraSurface.accentText : AuraSurface.faint;

    return Semantics(
      button: true,
      label: item.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AuraRadius.r12),
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
// FOOTER
// ─────────────────────────────────────────────────────────────────────────────

class _ShellFooter extends StatelessWidget {
  const _ShellFooter();

  static const _links = [
    _Link('Mission', '/mission'),
    _Link('Institutions', '/institutions'),
    _Link('Investors', '/investors'),
    _Link('Patrons', '/patrons'),
    _Link('Supporters', '/supporters'),
    _Link('Contact', '/contact'),
    _Link('Privacy', '/privacy'),
    _Link('Terms', '/terms'),
    _Link('White Paper', '/white-paper'),
    _Link('Founder', '/founder'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: AuraGradients.footer,
        border: Border(top: BorderSide(color: AuraSurface.divider)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
              maxWidth: PublicShell.maxContentWidth + 160),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AuraSpace.s16, AuraSpace.s14, AuraSpace.s16, AuraSpace.s14),
            child: Wrap(
              spacing: AuraSpace.s2,
              runSpacing: AuraSpace.s4,
              children: _links.map((l) => _FooterBtn(link: l)).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _FooterBtn extends StatelessWidget {
  const _FooterBtn({required this.link});

  final _Link link;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => context.go(link.path),
      style: TextButton.styleFrom(
        foregroundColor: AuraSurface.faint,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s6, vertical: AuraSpace.s4),
      ),
      child: Text(
        link.label,
        style: AuraText.micro.copyWith(fontWeight: FontWeight.w500),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DATA CLASSES
// ─────────────────────────────────────────────────────────────────────────────

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

class _Link {
  const _Link(this.label, this.path);

  final String label;
  final String path;
}
