import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui/aura_design_system.dart';
import '../../core/ui/aura_radius.dart';
import '../../core/ui/aura_space.dart';
import '../../core/ui/aura_surface.dart';
import '../../core/ui/aura_text.dart';
import '../../features/realtime/application/realtime_providers.dart';
import '../../features/realtime/presentation/incoming_live_overlay.dart';
import 'public_shell.dart';
import 'shell_header_tools.dart';
import 'shell_shared.dart';

// ─────────────────────────────────────────────────────────────────────────────
// INSTITUTION COLOR PALETTE — teal authority, calm workspace
// ─────────────────────────────────────────────────────────────────────────────

const Color _institutionAccent = Color(0xFF0D9488);
const Color _institutionAccentSoft = Color(0x1E0D9488);
const Color _institutionAccentText = Color(0xFF5EEAD4);
const Color _institutionNavBg1 = Color(0xFF091820);
const Color _institutionNavBg2 = Color(0xFF071420);

const LinearGradient _institutionHeaderGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFF0B1C26),
    Color(0xFF0D2030),
    Color(0xFF0F2535),
  ],
);

const LinearGradient _institutionNavGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [_institutionNavBg1, _institutionNavBg2],
);

// ─────────────────────────────────────────────────────────────────────────────
// MEMBER SHELL
// ─────────────────────────────────────────────────────────────────────────────

class MemberShell extends ConsumerWidget {
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
      path: '/messages',
    ),
    _NavItem(
      label: 'Create',
      icon: Icons.add_rounded,
      selectedIcon: Icons.add_rounded,
      path: '/create',
      isPrimary: true,
    ),
    _NavItem(
      label: 'Institutions',
      icon: Icons.apartment_outlined,
      selectedIcon: Icons.apartment_rounded,
      path: '/institutions',
    ),
    _NavItem(
      label: 'Support',
      icon: Icons.support_agent_outlined,
      selectedIcon: Icons.support_agent_rounded,
      path: '/support/agent',
    ),
  ];

  static const double _maxContentWidth = 920;
  static const double _headerHeight = 64;
  static const double _desktopBreakpoint = 1100;
  static const double _tabletBreakpoint = 760;

  int _indexForPath(String path) {
    if (path == '/home') return 0;
    if (path == '/messages' ||
        path == '/me/correspondence' ||
        path.startsWith('/me/correspondence/') ||
        path == '/conversations') {
      return 1;
    }
    if (path == '/create' ||
        path == '/compose' ||
        path == '/announcements/create') {
      return 2;
    }
    if (path == '/institutions' || path.startsWith('/institutions/')) return 3;
    if (path.startsWith('/support')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uri = GoRouterState.of(context).uri;
    final path = uri.path;
    final selectedIndex = _indexForPath(path);
    final realtimeState = ref.watch(realtimeControllerProvider);

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
                  if (realtimeState.isJoined &&
                      realtimeState.sessionId != null &&
                      realtimeState.sessionId!.isNotEmpty &&
                      !path.startsWith('/realtime') &&
                      !path.contains('/thread/'))
                    _ActiveCallBar(
                      sessionId: realtimeState.sessionId!,
                      isVideo: realtimeState.isVideoMode,
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
                  if (!isDesktop && _showMemberBottomNav(path))
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
// ACTIVE CALL RETURN BANNER
// ─────────────────────────────────────────────────────────────────────────────

class _ActiveCallBar extends ConsumerWidget {
  const _ActiveCallBar({required this.sessionId, required this.isVideo});

  final String sessionId;
  final bool isVideo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF0E2235),
        border: Border(bottom: BorderSide(color: AuraSurface.divider)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s16,
        vertical: AuraSpace.s8,
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF4ADE80),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AuraSpace.s8),
          Icon(
            isVideo ? Icons.videocam_rounded : Icons.mic_rounded,
            size: 16,
            color: AuraSurface.accentText,
          ),
          const SizedBox(width: AuraSpace.s6),
          Expanded(
            child: Text(
              isVideo ? 'Video call in progress' : 'Audio call in progress',
              style: AuraText.small.copyWith(
                color: AuraSurface.ink,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AuraSpace.s8),
          InkWell(
            onTap: () => context.push('/realtime/$sessionId'),
            borderRadius: BorderRadius.circular(AuraRadius.pill),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AuraSpace.s12,
                vertical: AuraSpace.s4,
              ),
              decoration: BoxDecoration(
                gradient: AuraGradients.accent,
                borderRadius: BorderRadius.circular(AuraRadius.pill),
                boxShadow: AuraShadows.glow,
              ),
              child: Text(
                'Return',
                style: AuraText.small.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: AuraSpace.s8),
          InkWell(
            onTap: () => ref.read(realtimeControllerProvider.notifier).leave(),
            borderRadius: BorderRadius.circular(AuraRadius.r10),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AuraSpace.s10,
                vertical: AuraSpace.s4,
              ),
              decoration: BoxDecoration(
                color: const Color(0x22FF5555),
                borderRadius: BorderRadius.circular(AuraRadius.r10),
                border: Border.all(color: const Color(0x44FF5555)),
              ),
              child: Text(
                'End',
                style: AuraText.small.copyWith(
                  color: const Color(0xFFFF7070),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

bool _showMemberBottomNav(String path) {
  if (path.startsWith('/realtime')) return false;
  if (path.startsWith('/me/correspondence/') &&
      (path.contains('/thread/') || path.contains('/live/'))) {
    return false;
  }
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
      label: 'Overview',
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
      label: 'Settings',
      icon: Icons.tune_outlined,
      selectedIcon: Icons.tune_rounded,
      path: '/institution/profile',
    ),
  ];

  static const double _desktopBreakpoint = 1100;
  static const double _tabletBreakpoint = 760;

  int _indexForPath(String path) {
    if (path == '/institution/dashboard') return 0;
    if (path == '/institution/announcements') return 1;
    if (path == '/institution/correspondence') return 2;
    if (path == '/institution/profile' ||
        path == '/institution/domains' ||
        path == '/institution/request-verification') {
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
                          _InstitutionSideNav(
                            items: _items,
                            selectedIndex: selectedIndex,
                            currentPath: path,
                          ),
                        Expanded(child: child),
                      ],
                    ),
                  ),
                  if (!isDesktop)
                    _InstitutionBottomNav(
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
// MEMBER HEADER
// ─────────────────────────────────────────────────────────────────────────────

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
                AuraShellWordmark(onTap: () => context.go('/home')),
                const Spacer(),
                ShellHeaderTools(
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

// ─────────────────────────────────────────────────────────────────────────────
// INSTITUTION HEADER
// ─────────────────────────────────────────────────────────────────────────────

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
        gradient: _institutionHeaderGradient,
        border: Border(
          bottom: BorderSide(color: Color(0x220D9488)),
        ),
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
                AuraShellWordmark(
                  onTap: () => context.go('/institution/dashboard'),
                ),
                const SizedBox(width: AuraSpace.s10),
                _WorkspaceBadge(),
                const Spacer(),
                ShellHeaderTools(
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

class _WorkspaceBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: _institutionAccentSoft,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        border: Border.all(color: _institutionAccent.withValues(alpha: 0.4)),
      ),
      child: Text(
        'Workspace',
        style: AuraText.label.copyWith(
          color: _institutionAccentText,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MEMBER SIDE NAV
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
              _MemberSideNavTile(
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

class _MemberSideNavTile extends StatelessWidget {
  const _MemberSideNavTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (item.isPrimary) {
      return Semantics(
        button: true,
        label: item.label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AuraRadius.pill),
            child: AnimatedContainer(
              duration: AuraMotion.fast,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AuraSpace.s16,
                vertical: AuraSpace.s10,
              ),
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    item.icon,
                    size: AuraIconSize.md,
                    color: selected
                        ? AuraSurface.accentText
                        : Colors.white,
                  ),
                  const SizedBox(width: AuraSpace.s8),
                  Text(
                    item.label,
                    style: AuraText.small.copyWith(
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? AuraSurface.accentText
                          : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

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
// INSTITUTION SIDE NAV — left-border indicator, professional workspace style
// ─────────────────────────────────────────────────────────────────────────────

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
      width: 224,
      decoration: const BoxDecoration(
        gradient: _institutionNavGradient,
        border: Border(right: BorderSide(color: Color(0x14FFFFFF))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AuraSpace.s20,
              AuraSpace.s20,
              AuraSpace.s16,
              AuraSpace.s8,
            ),
            child: Text(
              'INSTITUTION',
              style: AuraText.micro.copyWith(
                color: _institutionAccent.withValues(alpha: 0.7),
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
                fontSize: 10,
              ),
            ),
          ),
          for (var i = 0; i < items.length; i++)
            _InstitutionSideNavTile(
              item: items[i],
              selected: i == selectedIndex,
              onTap: () {
                final target = items[i].path;
                if (target != currentPath) context.go(target);
              },
            ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _InstitutionSideNavTile extends StatelessWidget {
  const _InstitutionSideNavTile({
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
              color: selected ? _institutionAccentSoft : Colors.transparent,
              borderRadius: BorderRadius.circular(AuraRadius.r10),
              border: Border.all(
                color: selected
                    ? _institutionAccent.withValues(alpha: 0.25)
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
                    color: selected
                        ? _institutionAccent
                        : Colors.transparent,
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
                          color: selected
                              ? _institutionAccentText
                              : AuraSurface.faint,
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
                                  ? _institutionAccentText
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

// ─────────────────────────────────────────────────────────────────────────────
// INSTITUTION BOTTOM NAV — teal accented, professional
// ─────────────────────────────────────────────────────────────────────────────

class _InstitutionBottomNav extends StatelessWidget {
  const _InstitutionBottomNav({
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
        gradient: _institutionNavGradient,
        border: Border(top: BorderSide(color: Color(0x220D9488))),
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
                  child: _InstitutionBottomNavBtn(
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

class _InstitutionBottomNavBtn extends StatelessWidget {
  const _InstitutionBottomNavBtn({
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
    final iconColor =
        selected ? _institutionAccentText : AuraSurface.faint;
    final textColor =
        selected ? _institutionAccentText : AuraSurface.faint;

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
// MEMBER BOTTOM NAV
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
                  child: _MemberBottomNavButton(
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

class _MemberBottomNavButton extends StatelessWidget {
  const _MemberBottomNavButton({
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
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
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
// DATA CLASS
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
