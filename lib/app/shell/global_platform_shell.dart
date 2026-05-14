import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui/aura_radius.dart';
import '../../core/ui/aura_responsive.dart';
import '../../core/ui/aura_space.dart';
import '../../core/ui/aura_surface.dart';
import '../../core/ui/aura_text.dart';
import '../route_targets.dart';
import 'shell_header_tools.dart';
import 'shell_shared.dart';

/// AURA PLATFORM CHROME — the persistent global layer.
///
/// This widget owns the top platform bar that must be present on every
/// authenticated route. It sits **above** the per-shell composition
/// (Member / Institution / Admin) and **below** nothing — it's the
/// outermost authenticated layer.
///
/// ─────────────────────────────────────────────────────────────────────
///   SHELL HIERARCHY (formal)
/// ─────────────────────────────────────────────────────────────────────
///
///   Scaffold / SafeArea / overlay wrappers (per shell — local concern)
///     └─ GlobalPlatformShell  ←─── persistent platform identity + tools
///         └─ (Member|Institution|Admin)Shell context bar
///             └─ AuraSurfaceScaffold  (left rail, center, right rail)
///                 └─ routed body
///
/// PublicShell is intentionally NOT wrapped by GlobalPlatformShell —
/// public marketing surfaces have their own neutral chrome and present
/// "Sign in" / "Join" affordances instead of authed tools.
///
/// ─────────────────────────────────────────────────────────────────────
///   OWNERSHIP BOUNDARIES
/// ─────────────────────────────────────────────────────────────────────
///
///   GlobalPlatformShell OWNS:
///     - Aura wordmark anchor (always links to `/home`)
///     - Global search button (when path is supplied)
///     - Notifications / activity bell
///     - Live indicator (active live-session pulse + menu)
///     - Account avatar + menu (profile / preferences / settings / sign out)
///     - Top-of-page background, divider, sticky height (56 px)
///     - The contract that these elements DO NOT MOVE between routes
///
///   Per-shell context bar (rendered BELOW GlobalPlatformShell) OWNS:
///     - Shell identity (e.g., institution avatar + name + workspace badge)
///     - Shell-scoped status indicators (verified badge, preview banner)
///     - Shell-specific compact nav at tablet/mobile breakpoints
///     - Anything that should change when the user crosses shells
///
///   AuraSurfaceScaffold (rendered BELOW context bar) OWNS:
///     - Three-zone composition (left rail / center / right rail)
///     - Per-surface width policy resolution
///     - Adaptive density / body padding
///     - Visibility rules for rails per breakpoint
///
///   Routed body widgets OWN:
///     - Their content. NOTHING ELSE.
///     - Specifically NOT: their own page-level navigation chrome,
///       account-level tools, platform identity, or shell switching.
///
/// ─────────────────────────────────────────────────────────────────────
///   UNIFIED NAVIGATION CONTRACT
/// ─────────────────────────────────────────────────────────────────────
///
///   GLOBAL (always present, ALWAYS in the platform bar):
///     - Aura wordmark → /home
///     - Search → /search   (or shell-specific search where appropriate)
///     - Notifications → /notifications
///     - Live → /realtime (with menu)
///     - Account menu → /me, /me/settings/communications, /security, logout
///
///   CONTEXTUAL (present only when the user is inside a specific shell):
///     - Institution: avatar, name, verified badge, workspace badge,
///       primary workspace nav (Explore / Activity / Spaces / etc.)
///     - Member: Works / Messages / Create / Institutions / Support
///       primary nav (typically in the left rail or bottom nav)
///     - Admin: control-surface nav (Queue / Users / Grants / Audit / etc.)
///
///   LOCAL (present only on a specific route or surface):
///     - Per-page action buttons (e.g., "Compose", "Invite member")
///     - Per-surface filters, tabs, segmented controls
///     - Anything the screen owns that doesn't outlive a route push
///
/// ─────────────────────────────────────────────────────────────────────
///   TRANSITION BEHAVIOR
/// ─────────────────────────────────────────────────────────────────────
///
/// When the user navigates between authenticated routes, the platform
/// bar is the **same widget instance** rendered by every shell — search,
/// notifications, live, account state stay visually stable. Only the
/// context bar below it changes.
///
/// When crossing between shells (e.g., entering an institution
/// workspace from member home), the platform bar remains identical;
/// the context bar swaps from member to institution; the routed body
/// rebuilds. This creates the "one continuous environment" feel by
/// keeping the top 56 px of the screen visually stable across the
/// transition.
///
/// ─────────────────────────────────────────────────────────────────────
///   STRUCTURAL RULES (enforced by review, not by code)
/// ─────────────────────────────────────────────────────────────────────
///
///   * `AuraSurfaceScaffold` MUST remain a pure layout primitive — it
///     never references session providers, never renders platform tools,
///     never owns the top of the screen.
///   * No shell may render `ShellHeaderTools` directly anymore — that
///     widget is the property of `GlobalPlatformShell`. (If you find a
///     shell still constructing `ShellHeaderTools`, that's a regression.)
///   * No shell may render its own Aura wordmark — there is exactly one
///     wordmark per page, and it lives here.
///   * No routed body may push its own AppBar/Scaffold over the
///     platform bar.
///
class GlobalPlatformShell extends StatelessWidget {
  const GlobalPlatformShell({
    super.key,
    required this.child,
    this.contextBar,
    this.showLive = true,
    this.searchPath = '/search',
    this.activityPath = '/notifications',
    this.invitePath,
  });

  /// The routed body + per-shell context. This widget composes the
  /// platform bar on top and renders `child` directly below.
  final Widget child;

  /// Optional per-shell context bar (institution identity, admin badge,
  /// etc.) rendered immediately below the platform bar and ABOVE the
  /// surface scaffold. Null = no context bar (e.g., member shell which
  /// has no per-shell identity row).
  final Widget? contextBar;

  /// Whether the Live indicator is part of the tools strip. Hidden on
  /// realtime fullscreen surfaces; defaults true.
  final bool showLive;

  /// Path the search button pushes to. Null suppresses search entirely
  /// (e.g., institution workspace where the global search would leak
  /// member content into institution scope).
  final String? searchPath;

  /// Path the notifications bell pushes to. Null suppresses the bell.
  final String? activityPath;

  /// Optional invite shortcut path. Most shells omit this.
  final String? invitePath;

  /// Logical height of the platform bar. Kept stable across breakpoints
  /// so the user perceives a continuous top edge while navigating.
  ///
  /// Reduced from 56 → 48 in the multi-context consolidation pass. The
  /// platform bar carries only the wordmark + 4 tool icons; 48 px gives
  /// the 32-px wordmark and 24-px tool icons each ~8 px vertical room
  /// without feeling cramped, and reclaims chrome for content. The
  /// global bar must NEVER carry shell-specific identity (institution
  /// avatar, admin badge, etc.) — those live in the per-shell context
  /// bar below, which is itself sized to ~37–41 px.
  static const double height = 48;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isDesktop = width >= kDesktopBreak;
        final isTablet = width >= kTabletBreak;
        return Column(
          children: [
            _PlatformBar(
              isDesktop: isDesktop,
              isTablet: isTablet,
              showLive: showLive,
              searchPath: searchPath,
              activityPath: activityPath,
              invitePath: invitePath,
            ),
            if (contextBar != null) contextBar!,
            Expanded(child: child),
          ],
        );
      },
    );
  }
}

class _PlatformBar extends StatelessWidget {
  const _PlatformBar({
    required this.isDesktop,
    required this.isTablet,
    required this.showLive,
    required this.searchPath,
    required this.activityPath,
    required this.invitePath,
  });

  final bool isDesktop;
  final bool isTablet;
  final bool showLive;
  final String? searchPath;
  final String? activityPath;
  final String? invitePath;

  @override
  Widget build(BuildContext context) {
    final hPad = isDesktop
        ? AuraSpace.s24
        : isTablet
            ? AuraSpace.s20
            : AuraSpace.s16;
    return Container(
      height: GlobalPlatformShell.height,
      decoration: const BoxDecoration(
        // Use `card` (slightly lifted above page) so the platform bar
        // reads as an authoritative line above content rather than
        // merging with it. With no context bar (member shell) this is
        // what creates the visible separation between the persistent
        // top chrome and the routed body below.
        color: AuraSurface.card,
        border: Border(bottom: BorderSide(color: AuraSurface.divider)),
        boxShadow: [
          // Subtle downward shadow gives the top bar the layered feel
          // the user asked for ("infrastructural"), without
          // overdecorating. Single soft shadow only — no neon/glow.
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: ConstrainedBox(
          // Wide bound: the platform bar spans more than any single
          // page surface so the wordmark and tools always sit at the
          // outer edges, regardless of which surface width is below.
          constraints: const BoxConstraints(maxWidth: 1440),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: hPad),
            child: Row(
              children: [
                AuraShellWordmark(onTap: () => _goHome(context)),
                const Spacer(),
                ShellHeaderTools(
                  isTablet: isTablet,
                  isDesktop: isDesktop,
                  showLive: showLive,
                  searchPath: searchPath,
                  activityPath: activityPath,
                  invitePath: invitePath,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _goHome(BuildContext context) {
    final currentPath = GoRouterState.of(context).uri.path;
    final target =
        shouldUseMemberShellForAuthed(currentPath) ? '/home' : '/home';
    context.go(target);
  }
}

/// Helper: a thin context-bar row used by shells that want to render a
/// shell-specific identity strip below the platform bar without
/// reinventing layout / padding / border tokens. Optional — shells may
/// render any widget as their context bar; this just removes ceremony
/// for the common "horizontal identity row" case.
class PlatformContextBar extends StatelessWidget {
  const PlatformContextBar({
    super.key,
    required this.child,
    this.color,
    this.borderColor,
    this.height = 56,
    this.gradient,
  });

  final Widget child;
  final Color? color;
  final Color? borderColor;
  final double height;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isDesktop = width >= kDesktopBreak;
        final isTablet = width >= kTabletBreak;
        final hPad = isDesktop
            ? AuraSpace.s24
            : isTablet
                ? AuraSpace.s20
                : AuraSpace.s16;
        return Container(
          height: height,
          decoration: BoxDecoration(
            color: gradient == null ? (color ?? AuraSurface.elevated) : null,
            gradient: gradient,
            border: Border(
              bottom: BorderSide(color: borderColor ?? AuraSurface.divider),
            ),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1440),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: hPad),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Decorative label component for use inside context bars (e.g., the
/// admin shell's "ADMIN" badge or institution "WORKSPACE" badge). Kept
/// here so shell context bars share a consistent badge style.
class PlatformContextBadge extends StatelessWidget {
  const PlatformContextBadge({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.background,
  });

  final String label;
  final IconData? icon;
  final Color? color;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final fg = color ?? AuraSurface.accentText;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s10,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: background ?? AuraSurface.accentSoft,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        border: Border.all(color: fg.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: AuraSpace.s6),
          ],
          Text(
            label,
            style: AuraText.micro.copyWith(
              color: fg,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
