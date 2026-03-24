import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_providers.dart';
import '../core/auth/session_providers.dart';
import '../core/institutions/institution_access_provider.dart';
import '../core/net/dio_provider.dart';
import '../core/ui/aura_space.dart';
import '../core/ui/aura_surface.dart';
import '../core/ui/aura_text.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  static const double _memberContentWidth = 920;
  static const double _publicContentWidth = 1100;
  static const double _footerMaxWidth = 1180;
  static const double _headerHeight = 72;
  static const double _subnavHeight = 52;
  static const double _logoHeight = 44;
  static const double _mobileBottomNavReservedHeight = 88;
  static const double _desktopBreakpoint = 1100;
  static const double _tabletBreakpoint = 760;
  static const String _logoAsset = 'assets/brand/AURA_logo_master.svg';

  static const List<_PublicNavItem> _publicNavItems = [
    _PublicNavItem(label: 'Home', path: '/public'),
    _PublicNavItem(label: 'Explore', path: '/search'),
    _PublicNavItem(label: 'Institutions', path: '/institutions'),
  ];

  static const List<_NavItem> _memberNavItems = [
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
      path: '/search',
    ),
    _NavItem(
      label: 'Me',
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
      path: '/me',
    ),
  ];

  static const List<_NavItem> _institutionNavItems = [
    _NavItem(
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
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
      icon: Icons.account_balance_outlined,
      selectedIcon: Icons.account_balance,
      path: '/institution/profile',
    ),
    _NavItem(
      label: 'Domains',
      icon: Icons.domain_outlined,
      selectedIcon: Icons.domain,
      path: '/institution/domains',
    ),
  ];

  static const List<_FooterLinkData> _footerLinks = [
    _FooterLinkData(label: 'Mission', path: '/mission'),
    _FooterLinkData(label: 'Institutions', path: '/institutions'),
    _FooterLinkData(label: 'Investors', path: '/investors'),
    _FooterLinkData(label: 'Patrons', path: '/patrons'),
    _FooterLinkData(label: 'Supporters', path: '/supporters'),
    _FooterLinkData(label: 'Contact', path: '/contact'),
    _FooterLinkData(label: 'Privacy', path: '/privacy'),
    _FooterLinkData(label: 'Terms', path: '/terms'),
    _FooterLinkData(label: 'White paper', path: '/white-paper', optional: true),
    _FooterLinkData(label: 'Founder', path: '/founder', optional: true),
  ];

  static bool isInstitutionPath(String path) {
    return path == '/institution/dashboard' ||
        path == '/institution/domains' ||
        path == '/institution/profile' ||
        path == '/institution/request-verification' ||
        path == '/institution/announcements' ||
        path == '/institution/correspondence';
  }

  static bool isMemberPath(String path) {
    if (isInstitutionPath(path)) return false;

    return path == '/home' ||
        path == '/saved' ||
        path == '/updates' ||
        path == '/conversations' ||
        path == '/activity' ||
        path == '/create' ||
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
        path == '/admin' ||
        path == '/enter-institution' ||
        path == '/compose';
  }

  static bool isAuthPath(String path) {
    return path == '/login' ||
        path == '/register' ||
        path == '/auth' ||
        path == '/forgot-password' ||
        path == '/reset-password' ||
        path == '/verify-email' ||
        path == '/verify-pending';
  }

  static bool isWidePublicPath(String path) {
    return path == '/public' ||
        path == '/' ||
        path == '/search' ||
        path == '/institutions' ||
        path.startsWith('/institutions/') ||
        path.startsWith('/posts/') ||
        path.startsWith('/u/') ||
        path.startsWith('/author/');
  }

  static bool showPublicFooter(String path) {
    if (isMemberPath(path) || isInstitutionPath(path)) return false;
    if (path == '/institution/sign-in') return false;
    return true;
  }

  static bool showMemberFooter(String path, {required bool isDesktop}) {
    if (!isDesktop) return false;
    if (!isMemberPath(path)) return false;

    return path == '/home' ||
        path == '/saved' ||
        path == '/updates' ||
        path == '/me' ||
        path == '/me/edit' ||
        path == '/security' ||
        path == '/me/follow-requests' ||
        path == '/enter-institution';
  }

  static int memberIndexForPath(String path) {
    if (path == '/home') return 0;
    if (path == '/me/correspondence' || path.startsWith('/me/correspondence/')) {
      return 1;
    }
    if (path == '/compose' || path == '/create') return 2;
    if (path == '/search') return 3;
    if (path == '/me' || path.startsWith('/me/')) return 4;
    return 0;
  }

  static int institutionIndexForPath(String path) {
    if (path == '/institution/dashboard' || path == '/institution/request-verification') {
      return 0;
    }
    if (path == '/institution/announcements') return 1;
    if (path == '/institution/correspondence') return 2;
    if (path == '/institution/profile') return 3;
    if (path == '/institution/domains') return 4;
    return 0;
  }

  static String institutionSectionLabel(String path) {
    switch (path) {
      case '/institution/dashboard':
        return 'Dashboard';
      case '/institution/request-verification':
        return 'Standing';
      case '/institution/announcements':
        return 'Announcements';
      case '/institution/correspondence':
        return 'Correspondence';
      case '/institution/profile':
        return 'Profile';
      case '/institution/domains':
        return 'Domains';
      default:
        return 'Institution workspace';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = GoRouterState.of(context).uri.path;
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= _desktopBreakpoint;
    final isTablet = width >= _tabletBreakpoint;
    final isAuthed = ref.watch(isAuthedProvider);
    final institutionAccess = ref.watch(institutionAccessProvider).maybeWhen(
          data: (value) => value,
          orElse: () => const InstitutionAccess(state: InstitutionAccessState.none),
        );

    if (isInstitutionPath(path)) {
      return Scaffold(
        backgroundColor: AuraSurface.page,
        body: _InstitutionShellBody(
          child: child,
          path: path,
          isDesktop: isDesktop,
          isTablet: isTablet,
          institutionAccess: institutionAccess,
        ),
      );
    }

    if (isMemberPath(path)) {
      return Scaffold(
        backgroundColor: AuraSurface.page,
        body: _MemberShellBody(
          child: child,
          path: path,
          isDesktop: isDesktop,
          isTablet: isTablet,
        ),
      );
    }

    return Scaffold(
      backgroundColor: AuraSurface.page,
      body: _PublicShellBody(
        child: child,
        path: path,
        isDesktop: isDesktop,
        isTablet: isTablet,
        isAuthed: isAuthed,
      ),
    );
  }
}

class _PublicShellBody extends StatelessWidget {
  const _PublicShellBody({
    required this.child,
    required this.path,
    required this.isDesktop,
    required this.isTablet,
    required this.isAuthed,
  });

  final Widget child;
  final String path;
  final bool isDesktop;
  final bool isTablet;
  final bool isAuthed;

  @override
  Widget build(BuildContext context) {
    final bodyMaxWidth = AppShell.isWidePublicPath(path)
        ? AppShell._publicContentWidth
        : AppShell._memberContentWidth;

    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PublicHeader(
                path: path,
                isDesktop: isDesktop,
                isTablet: isTablet,
                isAuthed: isAuthed,
              ),
              _PublicNavigationBar(
                path: path,
                isDesktop: isDesktop,
              ),
            ],
          ),
        ),
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: bodyMaxWidth),
              child: SizedBox(
                width: double.infinity,
                child: child,
              ),
            ),
          ),
        ),
        if (AppShell.showPublicFooter(path))
          SafeArea(
            top: false,
            child: _ReferenceFooter(
              isDesktop: isDesktop,
            ),
          ),
      ],
    );
  }
}

class _MemberShellBody extends StatelessWidget {
  const _MemberShellBody({
    required this.child,
    required this.path,
    required this.isDesktop,
    required this.isTablet,
  });

  final Widget child;
  final String path;
  final bool isDesktop;
  final bool isTablet;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = AppShell.memberIndexForPath(path);

    return SafeArea(
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
                  _ShellSideNav(
                    items: AppShell._memberNavItems,
                    selectedIndex: selectedIndex,
                    currentPath: path,
                    width: 248,
                  ),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            bottom: isDesktop ? 0 : AppShell._mobileBottomNavReservedHeight,
                          ),
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxWidth: AppShell._memberContentWidth,
                              ),
                              child: SizedBox(
                                width: double.infinity,
                                child: child,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (AppShell.showMemberFooter(path, isDesktop: isDesktop))
                        const _ReferenceFooter(isDesktop: true),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!isDesktop)
            _ShellBottomNav(
              items: AppShell._memberNavItems,
              selectedIndex: selectedIndex,
              currentPath: path,
              compact: !isTablet,
            ),
        ],
      ),
    );
  }
}

class _InstitutionShellBody extends StatelessWidget {
  const _InstitutionShellBody({
    required this.child,
    required this.path,
    required this.isDesktop,
    required this.isTablet,
    required this.institutionAccess,
  });

  final Widget child;
  final String path;
  final bool isDesktop;
  final bool isTablet;
  final InstitutionAccess institutionAccess;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = AppShell.institutionIndexForPath(path);

    return SafeArea(
      top: true,
      bottom: false,
      child: Column(
        children: [
          _InstitutionHeader(
            isDesktop: isDesktop,
            isTablet: isTablet,
            institutionAccess: institutionAccess,
            sectionLabel: AppShell.institutionSectionLabel(path),
          ),
          Expanded(
            child: Row(
              children: [
                if (isDesktop)
                  _ShellSideNav(
                    items: AppShell._institutionNavItems,
                    selectedIndex: selectedIndex,
                    currentPath: path,
                    width: 276,
                  ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: isDesktop ? 0 : AppShell._mobileBottomNavReservedHeight,
                    ),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: AppShell._memberContentWidth,
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          child: child,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!isDesktop)
            _ShellBottomNav(
              items: AppShell._institutionNavItems,
              selectedIndex: selectedIndex,
              currentPath: path,
              compact: !isTablet,
            ),
        ],
      ),
    );
  }
}

class _PublicHeader extends StatelessWidget {
  const _PublicHeader({
    required this.path,
    required this.isDesktop,
    required this.isTablet,
    required this.isAuthed,
  });

  final String path;
  final bool isDesktop;
  final bool isTablet;
  final bool isAuthed;

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
          constraints: const BoxConstraints(maxWidth: AppShell._publicContentWidth),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: AuraSpace.s12,
            ),
            child: Row(
              children: [
                _AuraWordmark(
                  onTap: () => context.go(isAuthed ? '/home' : '/public'),
                ),
                const Spacer(),
                if (isDesktop)
                  _PublicHeaderActions(isAuthed: isAuthed)
                else
                  _PublicHeaderCompactActions(isAuthed: isAuthed),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PublicNavigationBar extends StatelessWidget {
  const _PublicNavigationBar({
    required this.path,
    required this.isDesktop,
  });

  final String path;
  final bool isDesktop;

  bool _selected(String currentPath, String itemPath) {
    if (itemPath == '/public') {
      return currentPath == '/' || currentPath == '/public';
    }
    if (itemPath == '/search') {
      return currentPath == '/search' ||
          currentPath.startsWith('/posts/') ||
          currentPath.startsWith('/u/') ||
          currentPath.startsWith('/author/');
    }
    if (itemPath == '/institutions') {
      return currentPath == '/institutions' || currentPath.startsWith('/institutions/');
    }
    return currentPath == itemPath;
  }

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = isDesktop ? AuraSpace.s24 : AuraSpace.s16;

    return Container(
      height: AppShell._subnavHeight,
      decoration: const BoxDecoration(
        color: AuraSurface.page,
        border: Border(
          bottom: BorderSide(color: AuraSurface.divider),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppShell._publicContentWidth),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var i = 0; i < AppShell._publicNavItems.length; i++) ...[
                      _PublicSubnavButton(
                        label: AppShell._publicNavItems[i].label,
                        selected: _selected(path, AppShell._publicNavItems[i].path),
                        onTap: () => context.go(AppShell._publicNavItems[i].path),
                      ),
                      if (i != AppShell._publicNavItems.length - 1)
                        const SizedBox(width: AuraSpace.s8),
                    ],
                  ],
                ),
              ),
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
      height: AppShell._headerHeight,
      decoration: const BoxDecoration(
        color: AuraSurface.page,
        border: Border(
          bottom: BorderSide(color: AuraSurface.divider),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppShell._publicContentWidth),
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
                _MemberHeaderTools(
                  compact: !isDesktop,
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
    required this.institutionAccess,
    required this.sectionLabel,
  });

  final bool isDesktop;
  final bool isTablet;
  final InstitutionAccess institutionAccess;
  final String sectionLabel;

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = isDesktop
        ? AuraSpace.s24
        : isTablet
            ? AuraSpace.s20
            : AuraSpace.s16;

    final institutionName = institutionAccess.institution?['name']?.toString().trim();
    final contextLabel = (institutionName != null && institutionName.isNotEmpty)
        ? institutionName
        : 'Institution workspace';

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
          constraints: const BoxConstraints(maxWidth: AppShell._publicContentWidth),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: AuraSpace.s12,
            ),
            child: Row(
              children: [
                _AuraWordmark(
                  onTap: () => context.go('/institution/dashboard'),
                ),
                const SizedBox(width: AuraSpace.s16),
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AuraSpace.s8,
                    runSpacing: AuraSpace.s6,
                    children: [
                      _ContextPill(
                        label: contextLabel,
                        icon: Icons.account_balance_outlined,
                      ),
                      _ContextPill(
                        label: sectionLabel,
                        icon: Icons.chevron_right,
                        quiet: true,
                      ),
                    ],
                  ),
                ),
                _InstitutionHeaderTools(compact: !isDesktop),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReferenceFooter extends StatelessWidget {
  const _ReferenceFooter({required this.isDesktop});

  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final year = DateTime.now().year;
    final padding = isDesktop ? AuraSpace.s24 : AuraSpace.s16;
    final primary = AppShell._footerLinks.where((link) => !link.optional).toList();
    final secondary = AppShell._footerLinks.where((link) => link.optional).toList();

    return Container(
      decoration: const BoxDecoration(
        color: AuraSurface.page,
        border: Border(
          top: BorderSide(color: AuraSurface.divider),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppShell._footerMaxWidth),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              padding,
              AuraSpace.s20,
              padding,
              AuraSpace.s20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aura',
                  style: AuraText.emphasis.copyWith(fontSize: 16),
                ),
                const SizedBox(height: AuraSpace.s8),
                Text(
                  'Reference only. Quiet routes for mission, policy, and institutional entry.',
                  style: AuraText.small,
                ),
                const SizedBox(height: AuraSpace.s16),
                Wrap(
                  spacing: AuraSpace.s16,
                  runSpacing: AuraSpace.s10,
                  children: [
                    for (final link in primary) _FooterLink(link: link),
                  ],
                ),
                if (secondary.isNotEmpty) ...[
                  const SizedBox(height: AuraSpace.s12),
                  Wrap(
                    spacing: AuraSpace.s16,
                    runSpacing: AuraSpace.s10,
                    children: [
                      for (final link in secondary) _FooterLink(link: link),
                    ],
                  ),
                ],
                const SizedBox(height: AuraSpace.s16),
                Text(
                  '© $year Aura Platform LLC',
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

class _FooterLink extends StatelessWidget {
  const _FooterLink({required this.link});

  final _FooterLinkData link;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.go(link.path),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AuraSpace.s4 / 2),
        child: Text(
          link.label,
          style: AuraText.small.copyWith(
            fontWeight: FontWeight.w600,
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

class _PublicSubnavButton extends StatelessWidget {
  const _PublicSubnavButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.s12,
          vertical: AuraSpace.s8,
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
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? AuraSurface.ink : AuraSurface.muted,
          ),
        ),
      ),
    );
  }
}

class _PublicHeaderActions extends StatelessWidget {
  const _PublicHeaderActions({required this.isAuthed});

  final bool isAuthed;

  @override
  Widget build(BuildContext context) {
    if (isAuthed) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlinedButton(
            onPressed: () => context.go('/home'),
            child: const Text('Open workspace'),
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton(
          onPressed: () => context.go('/login'),
          child: const Text('Sign in'),
        ),
        const SizedBox(width: AuraSpace.s8),
        FilledButton(
          onPressed: () => context.go('/register'),
          child: const Text('Join'),
        ),
      ],
    );
  }
}


class _PublicHeaderCompactActions extends StatelessWidget {
  const _PublicHeaderCompactActions({required this.isAuthed});

  final bool isAuthed;

  @override
  Widget build(BuildContext context) {
    if (isAuthed) {
      return OutlinedButton(
        onPressed: () => context.go('/home'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s12,
            vertical: AuraSpace.s10,
          ),
        ),
        child: const Text('Workspace'),
      );
    }

    return Wrap(
      spacing: AuraSpace.s8,
      runSpacing: AuraSpace.s8,
      children: [
        OutlinedButton(
          onPressed: () => context.go('/login'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(
              horizontal: AuraSpace.s12,
              vertical: AuraSpace.s10,
            ),
          ),
          child: const Text('Sign in'),
        ),
        FilledButton(
          onPressed: () => context.go('/register'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(
              horizontal: AuraSpace.s12,
              vertical: AuraSpace.s10,
            ),
          ),
          child: const Text('Join'),
        ),
      ],
    );
  }
}

class _PublicHeaderMenu extends StatelessWidget {
  const _PublicHeaderMenu({required this.isAuthed});

  final bool isAuthed;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Menu',
      color: AuraSurface.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AuraSurface.divider),
      ),
      onSelected: (value) {
        switch (value) {
          case 'login':
            context.go('/login');
            return;
          case 'register':
            context.go('/register');
            return;
          case 'home':
            context.go('/home');
            return;
          default:
            context.go(value);
        }
      },
      itemBuilder: (context) => [
        for (final item in AppShell._publicNavItems)
          PopupMenuItem<String>(
            value: item.path,
            child: Text(item.label, style: AuraText.small),
          ),
        const PopupMenuDivider(),
        if (isAuthed)
          const PopupMenuItem<String>(
            value: 'home',
            child: Text('Open workspace', style: AuraText.small),
          )
        else ...[
          const PopupMenuItem<String>(
            value: 'login',
            child: Text('Sign in', style: AuraText.small),
          ),
          const PopupMenuItem<String>(
            value: 'register',
            child: Text('Join', style: AuraText.small),
          ),
        ],
      ],
      child: const _HeaderIconButtonVisual(
        tooltip: 'Menu',
        icon: Icons.menu,
        progress: false,
      ),
    );
  }
}

class _MemberHeaderTools extends ConsumerStatefulWidget {
  const _MemberHeaderTools({required this.compact});

  final bool compact;

  @override
  ConsumerState<_MemberHeaderTools> createState() => _MemberHeaderToolsState();
}

class _MemberHeaderToolsState extends ConsumerState<_MemberHeaderTools> {
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
      container.invalidate(institutionAccessProvider);
    } finally {
      if (mounted) {
        setState(() => _busyLogout = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _HeaderIconButton(
            tooltip: 'Notifications',
            icon: Icons.notifications_none,
            onTap: () => context.push('/activity'),
          ),
          const SizedBox(width: AuraSpace.s8),
          _HeaderAccountButton(
            compact: true,
            busy: _busyLogout,
            onSelected: (value) => unawaited(_handleAccountAction(value)),
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _HeaderPillButton(
          tooltip: 'Notifications',
          icon: Icons.notifications_none,
          label: 'Notifications',
          onTap: () => context.push('/activity'),
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
}

class _InstitutionHeaderTools extends ConsumerStatefulWidget {
  const _InstitutionHeaderTools({required this.compact});

  final bool compact;

  @override
  ConsumerState<_InstitutionHeaderTools> createState() => _InstitutionHeaderToolsState();
}

class _InstitutionHeaderToolsState extends ConsumerState<_InstitutionHeaderTools> {
  bool _busyLogout = false;

  Future<void> _handleAccountAction(String value) async {
    switch (value) {
      case 'member_home':
        context.go('/home');
        return;
      case 'profile':
        context.go('/me');
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

    if (mounted) {
      context.go('/public');
    }

    await Future<void>.delayed(Duration.zero);

    try {
      await container.read(tokenStoreProvider).clear();
      container.invalidate(emailVerifiedProvider);
      container.invalidate(authStatusProvider);
      container.invalidate(isAuthedProvider);
      container.invalidate(institutionAccessProvider);
    } finally {
      if (mounted) {
        setState(() => _busyLogout = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _HeaderIconButton(
            tooltip: 'Member home',
            icon: Icons.home_outlined,
            onTap: () => context.go('/home'),
          ),
          const SizedBox(width: AuraSpace.s8),
          _InstitutionAccountButton(
            compact: true,
            busy: _busyLogout,
            onSelected: (value) => unawaited(_handleAccountAction(value)),
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _HeaderPillButton(
          tooltip: 'Member home',
          icon: Icons.home_outlined,
          label: 'Member home',
          onTap: () => context.go('/home'),
        ),
        const SizedBox(width: AuraSpace.s8),
        _InstitutionAccountButton(
          compact: false,
          busy: _busyLogout,
          onSelected: (value) => unawaited(_handleAccountAction(value)),
        ),
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

class _InstitutionAccountButton extends StatelessWidget {
  const _InstitutionAccountButton({
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
        tooltip: 'Workspace',
        onSelected: onSelected,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AuraSurface.divider),
        ),
        color: AuraSurface.card,
        itemBuilder: (context) => [
          const PopupMenuItem<String>(
            value: 'member_home',
            child: _AccountMenuItemRow(
              icon: Icons.home_outlined,
              label: 'Member home',
            ),
          ),
          const PopupMenuItem<String>(
            value: 'profile',
            child: _AccountMenuItemRow(
              icon: Icons.person_outline,
              label: 'Profile',
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
                tooltip: 'Workspace',
                icon: busy ? null : Icons.account_balance_outlined,
                progress: busy,
              )
            : _HeaderPillButtonVisual(
                tooltip: 'Workspace',
                icon: busy ? null : Icons.account_balance_outlined,
                label: busy ? 'Signing out…' : 'Workspace',
                progress: busy,
              ),
      ),
    );
  }
}

class _ContextPill extends StatelessWidget {
  const _ContextPill({
    required this.label,
    required this.icon,
    this.quiet = false,
  });

  final String label;
  final IconData icon;
  final bool quiet;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s12,
        vertical: AuraSpace.s8,
      ),
      decoration: BoxDecoration(
        color: quiet ? AuraSurface.page : AuraSurface.card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: AuraSurface.muted,
          ),
          const SizedBox(width: AuraSpace.s6),
          Text(
            label,
            style: AuraText.small.copyWith(
              fontWeight: FontWeight.w600,
              color: quiet ? AuraSurface.muted : AuraSurface.ink,
            ),
          ),
        ],
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
        padding: const EdgeInsets.symmetric(horizontal: AuraSpace.s12),
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

class _ShellSideNav extends StatelessWidget {
  const _ShellSideNav({
    required this.items,
    required this.selectedIndex,
    required this.currentPath,
    required this.width,
  });

  final List<_NavItem> items;
  final int selectedIndex;
  final String currentPath;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
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
              _ShellRailButton(
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

class _ShellRailButton extends StatelessWidget {
  const _ShellRailButton({
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

class _ShellBottomNav extends StatelessWidget {
  const _ShellBottomNav({
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
                child: _ShellNavButton(
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

class _ShellNavButton extends StatelessWidget {
  const _ShellNavButton({
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

class _PublicNavItem {
  const _PublicNavItem({required this.label, required this.path});

  final String label;
  final String path;
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

class _FooterLinkData {
  const _FooterLinkData({
    required this.label,
    required this.path,
    this.optional = false,
  });

  final String label;
  final String path;
  final bool optional;
}
