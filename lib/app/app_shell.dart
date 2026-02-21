import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/ui/aura_space.dart';
import '../core/ui/aura_surface.dart';
import '../core/ui/aura_text.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});
  final Widget child;

  static const double _maxContentWidth = 980;

  static const _tabs = [
    _TabItem(label: 'Home', icon: Icons.home_outlined, path: '/home'),
    _TabItem(label: 'Search', icon: Icons.search, path: '/search'),
    _TabItem(label: 'Updates', icon: Icons.notifications_none, path: '/updates'),
    _TabItem(label: 'Me', icon: Icons.person_outline, path: '/me'),
  ];

  int _indexForLocation(String location) {
    for (var i = 0; i < _tabs.length; i++) {
      if (location == _tabs[i].path || location.startsWith('${_tabs[i].path}/')) {
        return i;
      }
    }
    return 0;
  }

  bool _isPublicRoute(String location) {
    // Keep this list conservative: anything not clearly "member" is treated as public.
    const publicPrefixes = <String>[
      '/public',
      '/login',
      '/register',
      '/privacy',
      '/mission',
      '/founder',
      '/investors',
      '/institutions',
      '/patrons',
      '/supporters',
      '/verify',
      '/verify-pending',
      '/forgot-password',
      '/reset-password',
    ];

    for (final p in publicPrefixes) {
      if (location == p || location.startsWith('$p/')) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.toString();
    final currentIndex = _indexForLocation(location);

    // Bottom nav shows only in member area.
    final showBottomNav = !_isPublicRoute(location);

    return Scaffold(
      backgroundColor: AuraSurface.page,
      body: Column(
        children: [
          // Content region (centers everything)
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _maxContentWidth),
                child: child,
              ),
            ),
          ),

          // Minimal legal rail (always). Keep it app-like, not website-like.
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AuraSurface.page,
              border: Border(top: BorderSide(color: AuraSurface.divider)),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AuraSpace.s16,
              vertical: AuraSpace.s10,
            ),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: AuraSpace.s10,
              runSpacing: AuraSpace.s8,
              children: const [
                _LegalLink(label: 'Privacy', path: '/privacy'),
              ],
            ),
          ),

          // Bottom nav (member area only)
          if (showBottomNav)
            NavigationBar(
              selectedIndex: currentIndex.clamp(0, _tabs.length - 1),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
                NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
                NavigationDestination(icon: Icon(Icons.notifications_none), label: 'Updates'),
                NavigationDestination(icon: Icon(Icons.person_outline), label: 'Me'),
              ],
              onDestinationSelected: (i) {
                final tab = _tabs[i];
                context.go(tab.path);
              },
            ),
        ],
      ),
    );
  }
}

class _TabItem {
  const _TabItem({required this.label, required this.icon, required this.path});
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
          horizontal: AuraSpace.s12,
          vertical: AuraSpace.s8,
        ),
        foregroundColor: AuraText.muted.color,
        textStyle: AuraText.small,
      ),
      child: Text(label),
    );
  }
}
