import 'package:flutter/material.dart';

import 'aura_space.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BREAKPOINTS — Canonical adaptive breakpoints. Every shell, page, and
// adaptive primitive MUST resolve responsive behavior through one of these
// three constants. The historical shell-specific 760/1100 pair has been
// retired in favor of this canonical 600/900/1200 system so a single
// surface never disagrees with the shell about which layout is active.
// ─────────────────────────────────────────────────────────────────────────────

/// Mobile / phone. Width strictly < 600 px is single-column, bottom-nav,
/// no side rails, compact typography.
const double kMobileBreak = 600;

/// Tablet / split-screen desktop. 600 ≤ width < 1200 keeps a compact
/// header + bottom nav. Side rails do NOT appear in this zone — the
/// content gets the full width so multi-column pages don't compress.
const double kTabletBreak = 900;

/// Desktop. Width ≥ 1200 unlocks the side-nav shell layout and gives
/// operational/workspace surfaces room for two-pane composition. Any
/// page that promotes from one column to multi-column composition does
/// so at this threshold.
const double kDesktopBreak = 1200;

// ─────────────────────────────────────────────────────────────────────────────
// CANONICAL CONTENT WIDTHS — Each surface picks ONE of these based on
// product category. No new inline `BoxConstraints(maxWidth: <literal>)`
// in feature code; if a surface needs a different width, propose adding
// a new canonical constant here. The five categories are:
//
//   Reading      → long-form text, legal, mission, document body
//   Feed         → social feed / timeline / one-column cards with optional rails
//   Workspace    → operational/admin/institution surfaces with structure
//   Hero         → public marketing / landing / auth split-screen
//   Form         → auth forms, dialogs, recovery flows
//
// Wider categories DO NOT replace narrower categories. A workspace page
// that is mostly a form should still use `kFormWidth`. Picking
// `kWorkspaceWidth` for a single-input form would create empty side
// gutters — which is the exact anti-pattern this contract bans.
// ─────────────────────────────────────────────────────────────────────────────

/// Long-form reading body. ~720 px ≈ 60–80 character line length at 16 sp,
/// the established readability target. Used by Privacy / Terms / Mission /
/// Founder / White Paper / Hubs and any in-app document surface.
const double kReadWidth = 720;

/// Social feed / timeline / one-column cards. Wide enough that a card
/// with media and a 3-line metadata block looks balanced; narrow enough
/// that a single-column post detail doesn't feel sparse on a 4K display.
/// Used by member home, public home content sections, post detail,
/// updates, activity, correspondence hub.
const double kFeedWidth = 1100;

/// Operational workspace — institution admin, member workspace, settings
/// dashboards, admin/control surfaces. Wider than feed because these
/// surfaces typically have multi-pane composition (table + filters,
/// editor + preview, list + detail). NEVER use this for single-column
/// content — that produces the "enterprise dashboard emptiness" the
/// product rule forbids.
const double kWorkspaceWidth = 1280;

/// Public marketing / landing / hero compositions. Slightly wider than
/// workspace because hero treatments are intentionally asymmetric
/// (large illustration on one side, text on the other) and benefit
/// from the extra horizontal canvas.
const double kHeroWidth = 1360;

/// Forms — auth, password reset, dialogs, settings sub-cards. A discrete
/// vertical stack of inputs reads better narrow.
const double kFormWidth = 480;

// Legacy alias kept for `AuraPageBody`'s constructor default; do not
// introduce new uses. `AuraPageBody` resolves to `kFeedWidth` by default
// — callers that need reading-width override per-instance.
const double kMaxContentWidth = kFeedWidth;

// ─────────────────────────────────────────────────────────────────────────────
// BREAKPOINT HELPERS
// ─────────────────────────────────────────────────────────────────────────────

class AuraBreakpoint {
  AuraBreakpoint._();

  static bool isMobile(BuildContext ctx) =>
      MediaQuery.sizeOf(ctx).width < kMobileBreak;

  static bool isTablet(BuildContext ctx) {
    final w = MediaQuery.sizeOf(ctx).width;
    return w >= kMobileBreak && w < kDesktopBreak;
  }

  static bool isDesktop(BuildContext ctx) =>
      MediaQuery.sizeOf(ctx).width >= kDesktopBreak;

  /// Adaptive horizontal page padding.
  static double pagePadding(BuildContext ctx) {
    final w = MediaQuery.sizeOf(ctx).width;
    if (w < kMobileBreak) return AuraSpace.s16;
    if (w < kTabletBreak) return AuraSpace.s20;
    if (w < kDesktopBreak) return AuraSpace.s24;
    return AuraSpace.s32;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AURA PAGE BODY
// Center + constrain content with adaptive side padding
// ─────────────────────────────────────────────────────────────────────────────

class AuraPageBody extends StatelessWidget {
  const AuraPageBody({
    super.key,
    required this.child,
    this.maxWidth = kMaxContentWidth,
    this.padding,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final hPad = AuraBreakpoint.pagePadding(context);
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding ?? EdgeInsets.symmetric(horizontal: hPad),
          child: child,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AURA KEYBOARD SAFE
// Keyboard-safe bottom padding
// ─────────────────────────────────────────────────────────────────────────────

class AuraKeyboardSafe extends StatelessWidget {
  const AuraKeyboardSafe({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AURA TWO PANEL
// Responsive two-panel layout: side rail + content
// ─────────────────────────────────────────────────────────────────────────────

class AuraTwoPanel extends StatelessWidget {
  const AuraTwoPanel({
    super.key,
    required this.rail,
    required this.content,
    this.railWidth = 240,
    this.breakpoint = kDesktopBreak,
  });

  final Widget rail;
  final Widget content;
  final double railWidth;
  final double breakpoint;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= breakpoint;
    if (!wide) return content;
    return Row(
      children: [
        SizedBox(width: railWidth, child: rail),
        Expanded(child: content),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AURA ACTION ROW
// Wrapping action row that stacks on mobile
// ─────────────────────────────────────────────────────────────────────────────

class AuraActionRow extends StatelessWidget {
  const AuraActionRow({
    super.key,
    required this.children,
    this.spacing = AuraSpace.s10,
  });

  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: spacing, runSpacing: spacing, children: children);
  }
}
