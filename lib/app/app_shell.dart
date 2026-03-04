import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/ui/aura_space.dart';
import '../core/ui/aura_surface.dart';
import '../core/ui/aura_text.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});
  final Widget child;

  static const double _maxContentWidth = 1080;

  static const _tabs = [
    _TabItem(label: 'Home', icon: Icons.home_outlined, path: '/home'),
    _TabItem(label: 'Search', icon: Icons.search, path: '/search'),
    _TabItem(label: 'Updates', icon: Icons.notifications_none, path: '/updates'),
    _TabItem(label: 'Me', icon: Icons.person_outline, path: '/me'),
  ];

  int _indexForPath(String path) {
    for (var i = 0; i < _tabs.length; i++) {
      final tabPath = _tabs[i].path;
      if (path == tabPath || path.startsWith('$tabPath/')) {
        return i;
      }
    }
    return 0;
  }

  bool _isPublicRoutePath(String path) {
    // IMPORTANT: use PATH ONLY (no query params). Queries broke your logic:
    // /login?redirect=/home was not matching /login and the bottom nav appeared.
    const publicPrefixes = <String>[
      '/public',
      '/privacy',
      '/contact', // ✅ added (legal/public)
      '/mission',
      '/founder',
      '/investors',
      '/institutions',
      '/patrons',
      '/supporters',
      '/announcements',

      // Auth routes (exactly as in router.dart)
      '/login',
      '/register',
      '/forgot-password',
      '/reset-password',
      '/verify-email',
      '/verify-pending',

      // Institution flows
      '/institution/sign-in',
      '/institution/request-verification',
    ];

    for (final p in publicPrefixes) {
      if (path == p || path.startsWith('$p/')) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uri = GoRouterState.of(context).uri;
    final path = uri.path; // ✅ path only, no query
    final currentIndex = _indexForPath(path);
    final showBottomNav = !_isPublicRoutePath(path);

    return Scaffold(
      backgroundColor: AuraSurface.page,
      body: Column(
        children: [
          // Main content region (cinematic centered stage)
          Expanded(
            child: Container(
              color: AuraSurface.page,
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _maxContentWidth),
                  child: child,
                ),
              ),
            ),
          ),

          // Minimal legal rail (quiet, integrated)
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: AuraSurface.page,
              border: Border(
                top: BorderSide(color: AuraSurface.divider),
              ),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AuraSpace.md,
              vertical: AuraSpace.sm,
            ),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: AuraSpace.sm,
              runSpacing: AuraSpace.xs,
              children: const [
                _LegalLink(label: 'Privacy', path: '/privacy'),
                _LegalLink(label: 'Contact', path: '/contact'), // ✅ added
              ],
            ),
          ),

          // Bottom navigation (member area only)
          if (showBottomNav)
            Container(
              decoration: const BoxDecoration(
                color: AuraSurface.card,
                border: Border(
                  top: BorderSide(color: AuraSurface.divider),
                ),
              ),
              child: NavigationBarTheme(
                data: NavigationBarThemeData(
                  backgroundColor: AuraSurface.card,
                  indicatorColor: AuraSurface.accentSoft,
                  labelTextStyle: MaterialStatePropertyAll(
                    AuraText.small.copyWith(
                      fontWeight: FontWeight.w500,
                      color: AuraSurface.muted,
                    ),
                  ),
                  iconTheme: const MaterialStatePropertyAll(
                    IconThemeData(
                      color: AuraSurface.muted,
                    ),
                  ),
                ),
                child: NavigationBar(
                  height: 64,
                  selectedIndex: currentIndex.clamp(0, _tabs.length - 1),
                  onDestinationSelected: (i) {
                    final tab = _tabs[i];
                    context.go(tab.path);
                  },
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home),
                      label: 'Home',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.search),
                      selectedIcon: Icon(Icons.search),
                      label: 'Search',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.notifications_none),
                      selectedIcon: Icon(Icons.notifications),
                      label: 'Updates',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.person_outline),
                      selectedIcon: Icon(Icons.person),
                      label: 'Me',
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TabItem {
  const _TabItem({
    required this.label,
    required this.icon,
    required this.path,
  });

  final String label;
  final IconData icon;
  final String path;
}

class _LegalLink extends StatelessWidget {
  const _LegalLink({required this.label, required this.path});

  final String label;
  final String path;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => context.go(path),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.sm,
          vertical: AuraSpace.xs,
        ),
        foregroundColor: AuraSurface.muted,
        textStyle: AuraText.small,
      ),
      child: Text(label),
    );
  }
}