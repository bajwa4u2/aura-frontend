import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/institutions/institution_access_provider.dart';
import '../../core/ui/aura_design_system.dart';
import '../../core/ui/aura_radius.dart';
import '../../core/ui/aura_space.dart';
import '../../core/ui/aura_surface.dart';
import '../../core/ui/aura_text.dart';
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

class InstitutionShell extends ConsumerWidget {
  const InstitutionShell({super.key, required this.child});

  final Widget child;

  static const double _desktopBreakpoint = 1100;
  static const double _tabletBreakpoint = 760;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(institutionIdentityProvider);
    final path = GoRouterState.of(context).uri.path;

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
                    identity: identity,
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        if (isDesktop)
                          _InstitutionSideNav(
                            currentPath: path,
                            identity: identity,
                          ),
                        Expanded(child: child),
                      ],
                    ),
                  ),
                  if (!isDesktop)
                    _InstitutionBottomNav(
                      currentPath: path,
                      compact: !isTablet,
                      identity: identity,
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
  const _InstitutionHeader({
    required this.isDesktop,
    required this.isTablet,
    required this.identity,
  });

  final bool isDesktop;
  final bool isTablet;
  final InstitutionIdentity? identity;

  @override
  Widget build(BuildContext context) {
    final hPad = isDesktop
        ? AuraSpace.s24
        : isTablet
            ? AuraSpace.s20
            : AuraSpace.s16;

    final name = identity?.name ?? '';
    final logoUrl = identity?.logoUrl;
    final isVerified = identity?.isVerified ?? false;

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
                hPad, AuraSpace.s10, hPad, AuraSpace.s10),
            child: Row(
              children: [
                // Institution identity stays primary in the header.
                _InstitutionAvatarSmall(name: name, logoUrl: logoUrl),
                const SizedBox(width: AuraSpace.s10),
                if (isTablet && name.isNotEmpty) ...[
                  Flexible(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AuraText.small.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AuraSurface.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: AuraSpace.s8),
                ],
                if (isVerified) ...[
                  const _InstitutionVerifiedBadge(),
                  const SizedBox(width: AuraSpace.s6),
                ],
                _WorkspaceBadge(),
                const Spacer(),
                // Operator profile (avatar) is demoted to the top-right corner
                // on desktop. The primary nav lives in the side nav now.
                if (isDesktop)
                  ShellHeaderTools(
                    isTablet: isTablet,
                    isDesktop: isDesktop,
                    searchPath: '/search',
                    activityPath: _institutionActivityPath(identity),
                    invitePath: '/invite',
                  )
                else
                  // Compact: only search + account on tablet/mobile so the
                  // institution identity has visual room.
                  _CompactHeaderTools(identity: identity),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _institutionActivityPath(InstitutionIdentity? identity) {
  final id = identity?.id ?? '';
  if (id.isEmpty) return '/activity';
  return '/institution/$id/activity';
}

class _InstitutionVerifiedBadge extends StatelessWidget {
  const _InstitutionVerifiedBadge();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Verified institution',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.s8,
          vertical: 3,
        ),
        decoration: BoxDecoration(
          color: AuraSurface.goodBg,
          borderRadius: BorderRadius.circular(AuraRadius.pill),
          border: Border.all(color: AuraSurface.goodInk.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.verified_rounded,
                size: 12, color: AuraSurface.goodInk),
            const SizedBox(width: 4),
            Text(
              'Verified',
              style: AuraText.label.copyWith(
                color: AuraSurface.goodInk,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact header tools for tablet/mobile inside the institution shell.
/// Shows only search + account; primary nav (Explore/Activity/Live/Invite)
/// is rendered in the bottom nav at small widths.
class _CompactHeaderTools extends StatelessWidget {
  const _CompactHeaderTools({required this.identity});

  final InstitutionIdentity? identity;

  @override
  Widget build(BuildContext context) {
    return ShellHeaderTools(
      isTablet: false,
      isDesktop: false,
      searchPath: '/search',
      activityPath: _institutionActivityPath(identity),
      invitePath: '/invite',
    );
  }
}

class _InstitutionAvatarSmall extends StatelessWidget {
  const _InstitutionAvatarSmall({required this.name, this.logoUrl});

  final String name;
  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    final initials =
        name.isNotEmpty ? name.trim()[0].toUpperCase() : '';

    return GestureDetector(
      onTap: () => context.go('/institution/dashboard'),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: _institutionAccentSoft,
          shape: BoxShape.circle,
          border:
              Border.all(color: _institutionAccent.withValues(alpha: 0.4)),
        ),
        clipBehavior: Clip.antiAlias,
        child: logoUrl != null && logoUrl!.isNotEmpty
            ? Image.network(
                logoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _avatarFallback(initials),
              )
            : _avatarFallback(initials),
      ),
    );
  }

  Widget _avatarFallback(String initials) {
    if (initials.isNotEmpty) {
      return Center(
        child: Text(
          initials,
          style: AuraText.micro.copyWith(
            color: _institutionAccentText,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      );
    }
    return const Icon(
      Icons.apartment_outlined,
      size: 16,
      color: _institutionAccentText,
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
// INSTITUTION SIDE NAV — left-border indicator, full workspace sections
// ─────────────────────────────────────────────────────────────────────────────

/// Describes a single entry in the institution side nav.
class _InstEntry {
  const _InstEntry({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.sectionLabel,
    this.pathBuilder,
    this.pathMatcher,
    this.adminOnly = false,
    // ignore: unused_element_parameter
    this.disabled = false,
    // ignore: unused_element_parameter
    this.disabledReason,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String? sectionLabel;

  /// Builds the navigation path from the current identity. Return null to disable.
  final String? Function(InstitutionIdentity?)? pathBuilder;

  /// Custom path matcher: returns true if this item is "selected" for path.
  final bool Function(String)? pathMatcher;

  final bool adminOnly;
  final bool disabled;
  final String? disabledReason;

  String? resolvedPath(InstitutionIdentity? identity) =>
      pathBuilder?.call(identity);

  bool isSelected(String currentPath, InstitutionIdentity? identity) {
    if (pathMatcher != null) return pathMatcher!(currentPath);
    final p = resolvedPath(identity);
    if (p == null) return false;
    final base = p.split('?')[0];
    return currentPath == base || currentPath.startsWith('$base/');
  }
}

List<_InstEntry> _buildInstEntries(InstitutionIdentity? identity) {
  final id = identity?.id ?? '';
  final slug = identity?.slug ?? '';
  final isAdmin = identity?.isAdmin ?? false;

  return [
    // ── PRIMARY: Explore / Activity / Live / Invite ─────────────────────
    _InstEntry(
      sectionLabel: 'WORKSPACE',
      label: 'Explore',
      icon: Icons.explore_outlined,
      selectedIcon: Icons.explore_rounded,
      pathBuilder: (_) =>
          id.isNotEmpty ? '/institution/$id/explore' : '/institution/dashboard',
      pathMatcher: (p) =>
          p == '/institution/dashboard' ||
          (p.startsWith('/institution/') && p.contains('/explore')),
    ),
    _InstEntry(
      label: 'Activity',
      icon: Icons.timeline_outlined,
      selectedIcon: Icons.timeline_rounded,
      pathBuilder: (_) =>
          id.isNotEmpty ? '/institution/$id/activity' : null,
      pathMatcher: (p) =>
          p.startsWith('/institution/') && p.contains('/activity'),
    ),
    _InstEntry(
      label: 'Live',
      icon: Icons.radio_outlined,
      selectedIcon: Icons.radio_rounded,
      pathBuilder: (_) => '/institution/live-rooms',
      pathMatcher: (p) =>
          p == '/institution/live-rooms' ||
          (p.startsWith('/institution/') && p.contains('/live')),
    ),
    _InstEntry(
      label: 'Invite',
      icon: Icons.outbound_outlined,
      selectedIcon: Icons.outbound_rounded,
      pathBuilder: (_) => id.isNotEmpty
          ? '/institution/$id/invites'
          : '/invite',
      pathMatcher: (p) =>
          p == '/invite' ||
          (p.startsWith('/institution/') && p.contains('/invite')),
    ),

    // ── SECONDARY: Workspace tools (formerly the bulk of the side nav) ─
    _InstEntry(
      sectionLabel: 'WORKSPACE TOOLS',
      label: 'Messages',
      icon: Icons.mail_outline_rounded,
      selectedIcon: Icons.mail_rounded,
      pathBuilder: (_) =>
          id.isNotEmpty ? '/institution/$id/messages' : null,
      pathMatcher: (p) =>
          (p.startsWith('/institution/') && p.contains('/messages')) ||
          p == '/institution/correspondence',
    ),
    _InstEntry(
      label: 'Spaces',
      icon: Icons.forum_outlined,
      selectedIcon: Icons.forum_rounded,
      pathBuilder: (_) => id.isNotEmpty ? '/institution/$id/spaces' : null,
      pathMatcher: (p) =>
          p.contains('/spaces') && p.startsWith('/institution/'),
    ),
    _InstEntry(
      label: 'Announcements',
      icon: Icons.campaign_outlined,
      selectedIcon: Icons.campaign_rounded,
      pathBuilder: (_) =>
          id.isNotEmpty ? '/institution/$id/announcements' : null,
      pathMatcher: (p) =>
          p.contains('/announcements') && p.startsWith('/institution/'),
    ),
    _InstEntry(
      label: 'Members',
      icon: Icons.people_outline_rounded,
      selectedIcon: Icons.people_rounded,
      pathBuilder: (_) => id.isNotEmpty ? '/institution/$id/members' : null,
      pathMatcher: (p) =>
          p.contains('/members') && p.startsWith('/institution/'),
    ),
    _InstEntry(
      label: 'Join Requests',
      icon: Icons.person_add_outlined,
      selectedIcon: Icons.person_add_rounded,
      adminOnly: true,
      pathBuilder: (_) => id.isNotEmpty && isAdmin
          ? '/institution/$id/join-requests?admin=true'
          : null,
      pathMatcher: (p) =>
          p.contains('/join-requests') && p.startsWith('/institution/'),
    ),
    _InstEntry(
      label: 'Domains',
      icon: Icons.language_rounded,
      selectedIcon: Icons.language_rounded,
      pathBuilder: (_) => '/institution/domains',
    ),

    // ── PROFILE section (institution profile only — not operator profile) ─
    _InstEntry(
      sectionLabel: 'PROFILE',
      label: 'Overview',
      icon: Icons.grid_view_outlined,
      selectedIcon: Icons.grid_view_rounded,
      pathBuilder: (_) => '/institution/dashboard',
      pathMatcher: (p) => p == '/institution/dashboard',
    ),
    _InstEntry(
      label: 'Profile',
      icon: Icons.badge_outlined,
      selectedIcon: Icons.badge_rounded,
      pathBuilder: (_) => '/institution/profile',
    ),
    _InstEntry(
      label: 'Edit Profile',
      icon: Icons.edit_outlined,
      selectedIcon: Icons.edit_rounded,
      adminOnly: true,
      pathBuilder: (_) => isAdmin ? '/institution/edit-profile' : null,
    ),
    _InstEntry(
      label: 'Public Preview',
      icon: Icons.open_in_new_rounded,
      selectedIcon: Icons.open_in_new_rounded,
      pathBuilder: (_) => slug.isNotEmpty ? '/institutions/$slug' : null,
      pathMatcher: (p) => p.startsWith('/institutions/'),
    ),
  ];
}

class _InstitutionSideNav extends StatelessWidget {
  const _InstitutionSideNav({
    required this.currentPath,
    required this.identity,
  });

  final String currentPath;
  final InstitutionIdentity? identity;

  @override
  Widget build(BuildContext context) {
    final entries = _buildInstEntries(identity);

    return Container(
      width: 232,
      decoration: const BoxDecoration(
        gradient: _institutionNavGradient,
        border: Border(right: BorderSide(color: Color(0x14FFFFFF))),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(0, AuraSpace.s12, 0, AuraSpace.s20),
        children: [
          for (final entry in entries) ...[
            if (entry.sectionLabel != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AuraSpace.s20,
                  AuraSpace.s14,
                  AuraSpace.s12,
                  AuraSpace.s4,
                ),
                child: Text(
                  entry.sectionLabel!,
                  style: AuraText.micro.copyWith(
                    color: _institutionAccent.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    fontSize: 9.5,
                  ),
                ),
              ),
            _InstitutionSideNavTile(
              entry: entry,
              selected: entry.isSelected(currentPath, identity),
              identity: identity,
              currentPath: currentPath,
            ),
          ],
        ],
      ),
    );
  }
}

class _InstitutionSideNavTile extends StatelessWidget {
  const _InstitutionSideNavTile({
    required this.entry,
    required this.selected,
    required this.identity,
    required this.currentPath,
  });

  final _InstEntry entry;
  final bool selected;
  final InstitutionIdentity? identity;
  final String currentPath;

  @override
  Widget build(BuildContext context) {
    final target = entry.resolvedPath(identity);
    final isDisabled = entry.disabled || target == null;
    final iconColor = selected
        ? _institutionAccentText
        : isDisabled
            ? AuraSurface.faint.withValues(alpha: 0.45)
            : AuraSurface.faint;
    final textColor = selected
        ? _institutionAccentText
        : isDisabled
            ? AuraSurface.faint.withValues(alpha: 0.45)
            : AuraSurface.faint;

    void onTap() {
      if (isDisabled) return;
      if (target != currentPath.split('?')[0]) context.go(target);
    }

    return Semantics(
      button: !isDisabled,
      label: entry.label,
      child: MouseRegion(
        cursor:
            isDisabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
        child: GestureDetector(
          onTap: isDisabled ? null : onTap,
          child: AnimatedContainer(
            duration: AuraMotion.fast,
            margin: const EdgeInsets.symmetric(
              horizontal: AuraSpace.s8,
              vertical: 1,
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
                  height: 38,
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
                      vertical: AuraSpace.s8,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selected ? entry.selectedIcon : entry.icon,
                          size: AuraIconSize.md,
                          color: iconColor,
                        ),
                        const SizedBox(width: AuraSpace.s10),
                        Expanded(
                          child: Text(
                            entry.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AuraText.small.copyWith(
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: textColor,
                            ),
                          ),
                        ),
                        if (isDisabled && entry.disabledReason != null) ...[
                          const SizedBox(width: AuraSpace.s6),
                          Text(
                            entry.disabledReason!,
                            style: AuraText.micro.copyWith(
                              color: AuraSurface.faint.withValues(alpha: 0.5),
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        if (isDisabled && entry.adminOnly && !isDisabled) ...[
                          const SizedBox(width: AuraSpace.s6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: _institutionAccentSoft,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              'Admin',
                              style: AuraText.micro.copyWith(
                                color: _institutionAccentText,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
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
// INSTITUTION BOTTOM NAV — teal accented, 5-item summary
// ─────────────────────────────────────────────────────────────────────────────

class _InstitutionBottomNav extends StatelessWidget {
  const _InstitutionBottomNav({
    required this.currentPath,
    required this.compact,
    required this.identity,
  });

  final String currentPath;
  final bool compact;
  final InstitutionIdentity? identity;

  @override
  Widget build(BuildContext context) {
    final id = identity?.id ?? '';
    // Primary nav: Explore, Activity, Live, Invite + overflow "More".
    final items = <_InstBottomItem>[
      _InstBottomItem(
        label: 'Explore',
        icon: Icons.explore_outlined,
        selectedIcon: Icons.explore_rounded,
        path: id.isNotEmpty
            ? '/institution/$id/explore'
            : '/institution/dashboard',
        matcher: (p) =>
            p == '/institution/dashboard' ||
            (p.startsWith('/institution/') && p.contains('/explore')),
      ),
      _InstBottomItem(
        label: 'Activity',
        icon: Icons.timeline_outlined,
        selectedIcon: Icons.timeline_rounded,
        path: id.isNotEmpty ? '/institution/$id/activity' : null,
        matcher: (p) =>
            p.startsWith('/institution/') && p.contains('/activity'),
      ),
      _InstBottomItem(
        label: 'Live',
        icon: Icons.radio_outlined,
        selectedIcon: Icons.radio_rounded,
        path: '/institution/live-rooms',
        matcher: (p) =>
            p == '/institution/live-rooms' ||
            (p.startsWith('/institution/') && p.contains('/live')),
      ),
      _InstBottomItem(
        label: 'Invite',
        icon: Icons.outbound_outlined,
        selectedIcon: Icons.outbound_rounded,
        path: id.isNotEmpty ? '/institution/$id/invites' : '/invite',
        matcher: (p) =>
            p == '/invite' ||
            (p.startsWith('/institution/') && p.contains('/invite')),
      ),
    ];

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
              for (final item in items)
                Expanded(
                  child: _InstitutionBottomNavBtn(
                    label: item.label,
                    icon: item.icon,
                    selectedIcon: item.selectedIcon,
                    selected: item.matcher(currentPath),
                    compact: compact,
                    disabled: item.path == null,
                    onTap: item.path == null || item.matcher(currentPath)
                        ? null
                        : () => context.go(item.path!),
                  ),
                ),
              Expanded(
                child: _InstitutionBottomNavMore(
                  identity: identity,
                  compact: compact,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InstBottomItem {
  const _InstBottomItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.path,
    required this.matcher,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String? path;
  final bool Function(String) matcher;
}

/// Overflow menu for the institution bottom nav. Hosts the secondary
/// "Workspace tools" entries (Messages, Spaces, Announcements, Members,
/// Domains, Profile) on tablet/mobile, where there is no side nav.
class _InstitutionBottomNavMore extends StatelessWidget {
  const _InstitutionBottomNavMore({
    required this.identity,
    required this.compact,
  });

  final InstitutionIdentity? identity;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final id = identity?.id ?? '';
    final slug = identity?.slug ?? '';
    final isAdmin = identity?.isAdmin ?? false;

    final entries = <(_MoreEntry, String?)>[
      (
        const _MoreEntry(
          label: 'Messages',
          icon: Icons.mail_outline_rounded,
        ),
        id.isNotEmpty ? '/institution/$id/messages' : null,
      ),
      (
        const _MoreEntry(label: 'Spaces', icon: Icons.forum_outlined),
        id.isNotEmpty ? '/institution/$id/spaces' : null,
      ),
      (
        const _MoreEntry(
          label: 'Announcements',
          icon: Icons.campaign_outlined,
        ),
        id.isNotEmpty ? '/institution/$id/announcements' : null,
      ),
      (
        const _MoreEntry(label: 'Members', icon: Icons.people_outline_rounded),
        id.isNotEmpty ? '/institution/$id/members' : null,
      ),
      if (isAdmin)
        (
          const _MoreEntry(
            label: 'Join Requests',
            icon: Icons.person_add_outlined,
          ),
          id.isNotEmpty
              ? '/institution/$id/join-requests?admin=true'
              : null,
        ),
      (
        const _MoreEntry(label: 'Domains', icon: Icons.language_rounded),
        '/institution/domains',
      ),
      (
        const _MoreEntry(label: 'Profile', icon: Icons.badge_outlined),
        '/institution/profile',
      ),
      if (isAdmin)
        (
          const _MoreEntry(label: 'Edit Profile', icon: Icons.edit_outlined),
          '/institution/edit-profile',
        ),
      (
        const _MoreEntry(
          label: 'Public Preview',
          icon: Icons.open_in_new_rounded,
        ),
        slug.isNotEmpty ? '/institutions/$slug' : null,
      ),
    ];

    return PopupMenuButton<String>(
      tooltip: 'More',
      offset: const Offset(0, -8),
      color: AuraSurface.overlay,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AuraRadius.r16),
        side: const BorderSide(color: AuraSurface.divider),
      ),
      itemBuilder: (_) {
        return [
          for (final pair in entries)
            PopupMenuItem<String>(
              enabled: pair.$2 != null,
              value: pair.$2 ?? '',
              child: Row(
                children: [
                  Icon(pair.$1.icon,
                      size: 16,
                      color: pair.$2 == null
                          ? AuraSurface.faint
                          : AuraSurface.muted),
                  const SizedBox(width: AuraSpace.s10),
                  Text(
                    pair.$1.label,
                    style: AuraText.small.copyWith(
                      color: pair.$2 == null
                          ? AuraSurface.faint
                          : AuraSurface.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ];
      },
      onSelected: (target) {
        if (target.isNotEmpty) context.go(target);
      },
      child: _InstitutionBottomNavBtn(
        label: 'More',
        icon: Icons.more_horiz_rounded,
        selectedIcon: Icons.more_horiz_rounded,
        selected: false,
        compact: compact,
        disabled: false,
        onTap: null,
      ),
    );
  }
}

class _MoreEntry {
  const _MoreEntry({required this.label, required this.icon});
  final String label;
  final IconData icon;
}

class _InstitutionBottomNavBtn extends StatelessWidget {
  const _InstitutionBottomNavBtn({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.compact,
    required this.disabled,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final bool compact;
  final bool disabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final iconColor = selected
        ? _institutionAccentText
        : disabled
            ? AuraSurface.faint.withValues(alpha: 0.35)
            : AuraSurface.faint;

    return Semantics(
      button: !disabled,
      label: label,
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
                selected ? selectedIcon : icon,
                size: compact ? 20 : 22,
                color: iconColor,
              ),
              const SizedBox(height: AuraSpace.s4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AuraText.micro.copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: iconColor,
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
