import 'package:flutter/material.dart';

import 'aura_space.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BREAKPOINTS
// ─────────────────────────────────────────────────────────────────────────────

const double kMobileBreak = 600;
const double kTabletBreak = 900;
const double kDesktopBreak = 1200;

// Max content widths
const double kMaxContentWidth = 960.0;
const double kMaxNarrowWidth = 640.0;
const double kMaxFormWidth = 480.0;

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
