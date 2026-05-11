import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/session_providers.dart';
import '../../core/ui/aura_design_system.dart';
import '../../core/ui/aura_radius.dart';
import '../../core/ui/aura_space.dart';
import '../../core/ui/aura_surface.dart';
import '../../core/ui/aura_text.dart';
import 'shell_shared.dart';

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
            // Phase 6.5 — `ShellFooter` is the public-trust closing surface
            // for public pages. Public-shell screens append it to their own
            // scroll so it flows below the page content (mission, privacy,
            // hubs, public home). Workspace shells (Member / Institution /
            // Admin) never reference `ShellFooter` — that is the boundary.
            child: Column(
              children: [
                _PublicHeader(isDesktop: isDesktop, isTablet: isTablet),
                Expanded(child: child),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PUBLIC HEADER
// ─────────────────────────────────────────────────────────────────────────────

class _PublicHeader extends ConsumerWidget {
  const _PublicHeader({required this.isDesktop, required this.isTablet});

  final bool isDesktop;
  final bool isTablet;

  static bool _worthRedirecting(String path) =>
      path != '/' &&
      path != '/public' &&
      !path.startsWith('/login') &&
      !path.startsWith('/register');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Header auth state must mirror the canonical bootstrap-aware status so
    // the page does not flash "Join | Sign in" for an authed user during the
    // /auth/refresh round-trip on web reload. While bootstrap is in flight we
    // render neither the authed nor the unauthed CTA — the wordmark stays.
    final authStatus = ref.watch(authStatusProvider);
    final isAuthed = authStatus == AuthStatus.authed;
    final isAuthLoading = authStatus == AuthStatus.loading;
    final currentUri = GoRouterState.of(context).uri;
    final currentPath = currentUri.path;

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
                AuraShellWordmark(
                  onTap: () => context.go(isAuthed ? '/home' : '/public'),
                ),
                const Spacer(),
                if (isAuthLoading) ...[
                  // Bootstrap settles within one round-trip. Render nothing
                  // rather than a misleading "Join | Sign in" or a premature
                  // "Open Aura" — the moment authStatus settles we re-render.
                ] else if (isAuthed) ...[
                  if (isTablet) ...[
                    _NavTextLink(
                      label: 'Institutions',
                      onTap: () => context.go('/institutions'),
                    ),
                    const SizedBox(width: AuraSpace.s12),
                    _NavTextLink(
                      label: 'Explore',
                      onTap: () => context.go('/search'),
                    ),
                    const SizedBox(width: AuraSpace.s12),
                  ],
                  _GoHomeButton(onTap: () => context.go('/home')),
                ] else ...[
                  if (isTablet) ...[
                    _NavTextLink(
                      label: 'Institutions',
                      onTap: () => context.go('/institutions'),
                    ),
                    const SizedBox(width: AuraSpace.s12),
                    _NavTextLink(
                      label: 'Explore',
                      onTap: () => context.go('/search'),
                    ),
                    const SizedBox(width: AuraSpace.s12),
                  ],
                  _SignInButton(onTap: () {
                    final redirect = _worthRedirecting(currentPath)
                        ? currentUri.toString()
                        : null;
                    context.go(redirect != null
                        ? '/login?redirect=${Uri.encodeComponent(redirect)}'
                        : '/login');
                  }),
                  const SizedBox(width: AuraSpace.s8),
                  _JoinButton(onTap: () {
                    final redirect = _worthRedirecting(currentPath)
                        ? currentUri.toString()
                        : null;
                    context.go(redirect != null
                        ? '/register?redirect=${Uri.encodeComponent(redirect)}'
                        : '/register');
                  }),
                ],
              ],
            ),
          ),
        ),
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
        style: AuraText.small.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _GoHomeButton extends StatelessWidget {
  const _GoHomeButton({required this.onTap});

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
              'Open Aura',
              style: AuraText.small.copyWith(
                  fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
        ),
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
