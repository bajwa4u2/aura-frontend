import 'package:flutter/material.dart';

import '../aura_radius.dart';
import '../aura_responsive.dart';
import '../aura_space.dart';
import '../aura_surface.dart';
import '../aura_text.dart';

/// Aura Surface Composition Architecture
/// ─────────────────────────────────────
///
/// One way for every route to declare what kind of surface it is, and
/// one place for the shell to decide how that surface is composed —
/// max width, left/right rails, density, footer behavior. Eliminates
/// route-by-route layout improvisation.
///
/// Usage pattern from a shell:
///
///   AuraSurfaceScaffold(
///     type: AuraSurfaceType.institutionWorkspace,
///     header: const _InstitutionHeader(...),
///     leftRail: const _InstitutionSideNav(...),
///     center: child,                                  // routed body
///     contextRail: AuraContextRail(modules: [...]),
///     footer: !isDesktop ? const _InstitutionBottomNav(...) : null,
///   );
///
/// The scaffold decides whether the left rail / context rail are
/// actually rendered based on the resolved `AuraSurfacePolicy` for the
/// surface type and the current viewport width. The caller does not
/// branch on `isDesktop` itself; that branching lives in one place.
///
/// What this is NOT:
///   * a new responsive primitive replacing AdaptiveCardGrid / Wrap —
///     surface composition orchestrates SHELL-level zones; rails inside
///     the center still use AdaptiveCardGrid where appropriate.
///   * a forced visual style — the scaffold lays out zones; the caller
///     supplies the actual widgets, with their own design.

// ─────────────────────────────────────────────────────────────────────────────
// SURFACE TYPE TAXONOMY
// ─────────────────────────────────────────────────────────────────────────────

/// What kind of surface a route is. The shell uses this to resolve a
/// composition policy. Every route should declare exactly one type.
enum AuraSurfaceType {
  /// Member home / public home / activity / updates — one main column of
  /// cards with optional right rail for discovery context.
  discourseFeed,

  /// Generic operational workspace — settings, profile editing, member
  /// workspace pages, billing.
  workspace,

  /// Institution workspace — the institution shell wraps these. Wider
  /// surface with explicit support for left primary nav + right
  /// governance/activity context.
  institutionWorkspace,

  /// Threads, conversations, correspondence. Two-pane on desktop
  /// (thread list + thread body) when supported.
  messaging,

  /// Admin dashboards. Wide, dense, table-heavy. Optional right rail
  /// for queue / audit pulse.
  adminControl,

  /// User / institution profile pages. Header + tabs + body, no rail.
  profile,

  /// Public marketing landing — wider chrome, hero composition.
  publicMarketing,

  /// Long-form reading — Privacy / Terms / Mission / Founder. Narrow
  /// reading column with intentional gutters; no rails.
  readingDocument,

  /// Realtime call / live session screens. Full-bleed.
  realtime,

  /// Settings hierarchies (when surface itself is the table-of-contents).
  settings,

  /// Modal / utility / single-purpose. No rails, narrow.
  utility,
}

// ─────────────────────────────────────────────────────────────────────────────
// POLICY VOCABULARY
// ─────────────────────────────────────────────────────────────────────────────

/// When a rail (left or context) is allowed to appear.
enum AuraRailVisibility {
  /// Render at every viewport that has room.
  always,

  /// Render only at the desktop breakpoint (≥ kDesktopBreak).
  desktopOnly,

  /// Render at tablet and above (≥ kTabletBreak). Used by the institution
  /// workspace, whose left rail is the single navigation home on tablet too.
  tabletUp,

  /// Never render.
  never,
}

/// Composition mode for the center surface. Drives max-width selection.
enum AuraSurfaceComposition {
  /// One column. center surface uses its policy max-width centered.
  singleColumn,

  /// center surface plus structural rails — used by workspace/admin/
  /// institution surfaces that need horizontal information distribution.
  multiZone,

  /// Center surface stretches edge-to-edge (e.g., realtime call).
  fullBleed,
}

/// Vertical/horizontal density used by surface body padding.
enum AuraSurfaceDensity {
  compact,
  balanced,
  spacious,
}

// ─────────────────────────────────────────────────────────────────────────────
// POLICY RESOLUTION
// ─────────────────────────────────────────────────────────────────────────────

/// Resolved composition behavior for a single surface type.
class AuraSurfacePolicy {
  const AuraSurfacePolicy({
    required this.maxContentWidth,
    required this.composition,
    required this.leftRailVisibility,
    required this.contextRailVisibility,
    required this.density,
    required this.bodyHorizontalPadding,
  });

  /// Cap applied to the center surface's width. The scaffold centers
  /// the center column inside this cap, leaving any extra room for rails
  /// or intentional gutters.
  final double maxContentWidth;

  final AuraSurfaceComposition composition;
  final AuraRailVisibility leftRailVisibility;
  final AuraRailVisibility contextRailVisibility;
  final AuraSurfaceDensity density;

  /// Horizontal padding applied to the center column. The scaffold owns
  /// this so screens don't reinvent breakpoint-aware padding.
  final EdgeInsets bodyHorizontalPadding;

  /// Default policy per surface type. Callers can override fields by
  /// passing a custom `policy` to AuraSurfaceScaffold.
  static AuraSurfacePolicy forType(AuraSurfaceType type) {
    switch (type) {
      case AuraSurfaceType.discourseFeed:
        return const AuraSurfacePolicy(
          maxContentWidth: kFeedWidth,
          composition: AuraSurfaceComposition.multiZone,
          leftRailVisibility: AuraRailVisibility.never,
          contextRailVisibility: AuraRailVisibility.desktopOnly,
          density: AuraSurfaceDensity.balanced,
          bodyHorizontalPadding:
              EdgeInsets.symmetric(horizontal: AuraSpace.s16),
        );
      case AuraSurfaceType.institutionWorkspace:
        return const AuraSurfacePolicy(
          maxContentWidth: kWorkspaceWidth,
          composition: AuraSurfaceComposition.multiZone,
          // The institution left rail is the single nav home on tablet too.
          leftRailVisibility: AuraRailVisibility.tabletUp,
          contextRailVisibility: AuraRailVisibility.desktopOnly,
          density: AuraSurfaceDensity.balanced,
          bodyHorizontalPadding:
              EdgeInsets.symmetric(horizontal: AuraSpace.s20),
        );
      case AuraSurfaceType.workspace:
        return const AuraSurfacePolicy(
          maxContentWidth: kWorkspaceWidth,
          composition: AuraSurfaceComposition.multiZone,
          leftRailVisibility: AuraRailVisibility.never,
          contextRailVisibility: AuraRailVisibility.desktopOnly,
          density: AuraSurfaceDensity.balanced,
          bodyHorizontalPadding:
              EdgeInsets.symmetric(horizontal: AuraSpace.s20),
        );
      case AuraSurfaceType.adminControl:
        return const AuraSurfacePolicy(
          maxContentWidth: kWorkspaceWidth,
          composition: AuraSurfaceComposition.multiZone,
          leftRailVisibility: AuraRailVisibility.desktopOnly,
          contextRailVisibility: AuraRailVisibility.desktopOnly,
          density: AuraSurfaceDensity.compact,
          bodyHorizontalPadding:
              EdgeInsets.symmetric(horizontal: AuraSpace.s16),
        );
      case AuraSurfaceType.messaging:
        return const AuraSurfacePolicy(
          maxContentWidth: kFeedWidth,
          composition: AuraSurfaceComposition.multiZone,
          leftRailVisibility: AuraRailVisibility.desktopOnly,
          contextRailVisibility: AuraRailVisibility.never,
          density: AuraSurfaceDensity.compact,
          bodyHorizontalPadding: EdgeInsets.zero,
        );
      case AuraSurfaceType.profile:
        return const AuraSurfacePolicy(
          maxContentWidth: kFeedWidth,
          composition: AuraSurfaceComposition.singleColumn,
          leftRailVisibility: AuraRailVisibility.never,
          contextRailVisibility: AuraRailVisibility.never,
          density: AuraSurfaceDensity.balanced,
          bodyHorizontalPadding:
              EdgeInsets.symmetric(horizontal: AuraSpace.s16),
        );
      case AuraSurfaceType.publicMarketing:
        return const AuraSurfacePolicy(
          maxContentWidth: kHeroWidth,
          composition: AuraSurfaceComposition.singleColumn,
          leftRailVisibility: AuraRailVisibility.never,
          contextRailVisibility: AuraRailVisibility.never,
          density: AuraSurfaceDensity.spacious,
          bodyHorizontalPadding:
              EdgeInsets.symmetric(horizontal: AuraSpace.s16),
        );
      case AuraSurfaceType.readingDocument:
        return const AuraSurfacePolicy(
          maxContentWidth: kReadWidth,
          composition: AuraSurfaceComposition.singleColumn,
          leftRailVisibility: AuraRailVisibility.never,
          contextRailVisibility: AuraRailVisibility.never,
          density: AuraSurfaceDensity.spacious,
          bodyHorizontalPadding:
              EdgeInsets.symmetric(horizontal: AuraSpace.s16),
        );
      case AuraSurfaceType.realtime:
        return const AuraSurfacePolicy(
          maxContentWidth: double.infinity,
          composition: AuraSurfaceComposition.fullBleed,
          leftRailVisibility: AuraRailVisibility.never,
          contextRailVisibility: AuraRailVisibility.never,
          density: AuraSurfaceDensity.balanced,
          bodyHorizontalPadding: EdgeInsets.zero,
        );
      case AuraSurfaceType.settings:
        return const AuraSurfacePolicy(
          maxContentWidth: kWorkspaceWidth,
          composition: AuraSurfaceComposition.multiZone,
          leftRailVisibility: AuraRailVisibility.desktopOnly,
          contextRailVisibility: AuraRailVisibility.never,
          density: AuraSurfaceDensity.balanced,
          bodyHorizontalPadding:
              EdgeInsets.symmetric(horizontal: AuraSpace.s20),
        );
      case AuraSurfaceType.utility:
        return const AuraSurfacePolicy(
          maxContentWidth: kFormWidth,
          composition: AuraSurfaceComposition.singleColumn,
          leftRailVisibility: AuraRailVisibility.never,
          contextRailVisibility: AuraRailVisibility.never,
          density: AuraSurfaceDensity.compact,
          bodyHorizontalPadding:
              EdgeInsets.symmetric(horizontal: AuraSpace.s16),
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SURFACE SCAFFOLD
// ─────────────────────────────────────────────────────────────────────────────

/// The shell-level orchestrator. Composes header / left rail / center /
/// right context rail / footer per the resolved policy and the current
/// viewport width. Single source of truth for which zones render at
/// which width.
///
/// Layout precedence (top to bottom):
///   1. header (full width across all zones)
///   2. Row:
///        - leftRail   (only if policy allows AND viewport ≥ desktop)
///        - center     (bounded by policy.maxContentWidth, centered)
///        - contextRail (only if policy allows AND viewport ≥ desktop)
///   3. footer (full width across all zones)
///
/// At narrower viewports the rails are dropped; the center takes the
/// remaining space and the caller is expected to surface any rail
/// content inline (or as a sheet) per its own decision. This keeps the
/// scaffold predictable — at tablet/mobile, the center is everything.
class AuraSurfaceScaffold extends StatelessWidget {
  const AuraSurfaceScaffold({
    super.key,
    required this.type,
    required this.center,
    this.header,
    this.leftRail,
    this.contextRail,
    this.footer,
    this.policy,
  });

  final AuraSurfaceType type;

  /// Top chrome across all zones — typically the shell header.
  final Widget? header;

  /// Persistent left rail. Rendered only when policy allows AND viewport
  /// ≥ desktop. Pass null for surfaces that have no left rail.
  final Widget? leftRail;

  /// The routed body content for this surface.
  final Widget center;

  /// Right-side context rail. Rendered only when policy allows AND
  /// viewport ≥ desktop. Pass null for surfaces with no context rail.
  /// On narrower viewports the caller is responsible for surfacing any
  /// rail content inline.
  final Widget? contextRail;

  /// Bottom chrome across all zones — typically the mobile bottom nav.
  final Widget? footer;

  /// Optional override of the per-type policy.
  final AuraSurfacePolicy? policy;

  /// **Layout-only.** This widget does NOT wrap in Scaffold / SafeArea /
  /// overlay layers — the caller (shell) owns those concerns so it can
  /// position live banners, incoming-call overlays, scaffold messengers,
  /// etc. around the composed surface.
  @override
  Widget build(BuildContext context) {
    final resolved = policy ?? AuraSurfacePolicy.forType(type);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isDesktop = width >= kDesktopBreak;
        final isTablet = width >= kTabletBreak;

        final showLeftRail = leftRail != null &&
            _allowed(resolved.leftRailVisibility, isDesktop, isTablet);
        final showContextRail = contextRail != null &&
            _allowed(resolved.contextRailVisibility, isDesktop, isTablet);

        return Column(
          children: [
            if (header != null) header!,
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showLeftRail) leftRail!,
                  Expanded(
                    child: _CenterColumn(
                      maxWidth: resolved.maxContentWidth,
                      padding: _adaptiveBodyPadding(
                        resolved.bodyHorizontalPadding,
                        isDesktop,
                        isTablet,
                      ),
                      composition: resolved.composition,
                      child: center,
                    ),
                  ),
                  if (showContextRail) contextRail!,
                ],
              ),
            ),
            if (footer != null) footer!,
          ],
        );
      },
    );
  }

  static bool _allowed(AuraRailVisibility v, bool isDesktop, bool isTablet) {
    switch (v) {
      case AuraRailVisibility.always:
        return true;
      case AuraRailVisibility.desktopOnly:
        return isDesktop;
      case AuraRailVisibility.tabletUp:
        return isTablet;
      case AuraRailVisibility.never:
        return false;
    }
  }

  /// Slight horizontal padding shrink on tablet/mobile so the center
  /// uses the full narrow viewport.
  static EdgeInsets _adaptiveBodyPadding(
    EdgeInsets base,
    bool isDesktop,
    bool isTablet,
  ) {
    if (isDesktop) return base;
    if (isTablet) {
      return EdgeInsets.symmetric(
        horizontal: (base.left * 0.75).clamp(AuraSpace.s12, base.left),
      );
    }
    return const EdgeInsets.symmetric(horizontal: AuraSpace.s12);
  }
}

class _CenterColumn extends StatelessWidget {
  const _CenterColumn({
    required this.maxWidth,
    required this.padding,
    required this.composition,
    required this.child,
  });

  final double maxWidth;
  final EdgeInsets padding;
  final AuraSurfaceComposition composition;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (composition == AuraSurfaceComposition.fullBleed) {
      return child;
    }
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CONTEXT RAIL
// ─────────────────────────────────────────────────────────────────────────────

/// Right-side context rail. Container for stacked [AuraRailModule]s.
/// Has its own scroll surface so long rail content does not couple to
/// the center scroll.
///
/// The scaffold decides whether this widget is rendered at all (per
/// surface policy + viewport); this widget only worries about its
/// internal layout.
///
/// **Adaptive width.** When `width` is null the rail picks its own width
/// based on the viewport (320 / 340 / 360 across desktop / 1440 /
/// ultrawide). Inter-module spacing tracks the same scale so a wider
/// rail breathes instead of looking sparse. This is what gives Aura its
/// "comfortable at 1440 / ultrawide without becoming cluttered" feel
/// the multi-rail orchestration brief asks for, while keeping the
/// existing `AuraRailModule` contract unchanged — no new layout
/// primitives.
class AuraContextRail extends StatelessWidget {
  const AuraContextRail({
    super.key,
    required this.modules,
    this.width,
  });

  final List<Widget> modules;

  /// Optional explicit width. When null the rail adapts to viewport
  /// width. Pass a concrete value only when you need to override the
  /// adaptive default (e.g., experimental surfaces).
  final double? width;

  /// Adaptive rail width across desktop / 1440 / ultrawide. Public so
  /// callers (rare) can ask the same question the rail asks internally
  /// when they need to budget the center column.
  static double widthFor(double viewportWidth) {
    if (viewportWidth >= 1680) return 360;
    if (viewportWidth >= 1440) return 340;
    return 320;
  }

  /// Inter-module spacing. Slightly looser on wider rails so dense rail
  /// stacks read as intentional spacing instead of cramped lists.
  static double spacingFor(double railWidth) {
    if (railWidth >= 360) return AuraSpace.s16;
    if (railWidth >= 340) return AuraSpace.s14;
    return AuraSpace.s12;
  }

  @override
  Widget build(BuildContext context) {
    final viewportWidth = MediaQuery.of(context).size.width;
    final resolvedWidth = width ?? widthFor(viewportWidth);
    final spacing = spacingFor(resolvedWidth);
    if (modules.isEmpty) return SizedBox(width: resolvedWidth);
    return Container(
      width: resolvedWidth,
      decoration: const BoxDecoration(
        border: Border(
          left: BorderSide(color: AuraSurface.divider),
        ),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AuraSpace.s16,
          AuraSpace.s16,
          AuraSpace.s16,
          AuraSpace.s24,
        ),
        itemCount: modules.length,
        separatorBuilder: (_, __) => SizedBox(height: spacing),
        itemBuilder: (_, i) => modules[i],
      ),
    );
  }
}

/// A single rail module — title row + body. Used by surfaces to compose
/// their right context rail from typed widgets instead of ad-hoc
/// Container blocks.
class AuraRailModule extends StatelessWidget {
  const AuraRailModule({
    super.key,
    required this.title,
    required this.body,
    this.icon,
    this.action,
    this.tone = AuraRailModuleTone.neutral,
  });

  final String title;
  final Widget body;
  final IconData? icon;

  /// Optional trailing action (chip/icon button) shown in the title row.
  final Widget? action;

  final AuraRailModuleTone tone;

  @override
  Widget build(BuildContext context) {
    final accent = tone == AuraRailModuleTone.accent;
    return Container(
      padding: const EdgeInsets.all(AuraSpace.s14),
      decoration: BoxDecoration(
        color: accent ? AuraSurface.accentSoft : AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(
          color: accent
              ? AuraSurface.accent.withValues(alpha: 0.32)
              : AuraSurface.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: accent
                      ? AuraSurface.accentText
                      : AuraSurface.muted,
                ),
                const SizedBox(width: AuraSpace.s8),
              ],
              Expanded(
                child: Text(
                  title,
                  style: AuraText.small.copyWith(
                    fontWeight: FontWeight.w800,
                    color: accent
                        ? AuraSurface.accentText
                        : AuraSurface.ink,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              if (action != null) action!,
            ],
          ),
          const SizedBox(height: AuraSpace.s10),
          body,
        ],
      ),
    );
  }
}

enum AuraRailModuleTone { neutral, accent }
