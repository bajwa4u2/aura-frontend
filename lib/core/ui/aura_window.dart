import 'package:flutter/widgets.dart';

import 'aura_responsive.dart';

/// THE WINDOW, RESOLVED ONCE.
///
/// ── THE DEFECT THIS EXISTS TO END ───────────────────────────────────────────
///
/// Aura's adaptive behaviour was decided by whatever width a widget happened to
/// be handed. Every shell and surface ran its own `LayoutBuilder` and compared
/// `constraints.maxWidth` against the 600/900/1200 breakpoints. Nested inside
/// each other, those measurements disagree:
///
///   a 1400 px window  →  shell says DESKTOP, takes 288 px for navigation
///                     →  the surface measures 1112 and concludes TABLET
///                     →  it drops its contextual rail and re-centres
///
/// So the product's answer to "how much room is there?" depended on how many
/// ancestors had already spent some. Measured on Windows: at a 2011 px window
/// only 53% reached the work surface, and the same window at 1400 classified
/// itself two ways at once.
///
/// This resolves the question ONCE, from the window, and passes the answer
/// down. A surface asks what kind of window it is in — never how much room is
/// left after its ancestors.
///
/// ── WHY NOT JUST READ MediaQuery EVERYWHERE ─────────────────────────────────
///
/// Because that is what the breakpoint helpers already do, and it is right
/// only until something wraps the app in a smaller box: a preview pane, a
/// split view, a golden test at a fixed surface size. Naming the authority
/// makes the intent explicit and gives one place to change it. It also lets
/// the shell state its OWN posture — how much of the window navigation is
/// spending — which no MediaQuery can know.
class AuraWindow extends InheritedWidget {
  const AuraWindow({
    super.key,
    required this.width,
    required this.height,
    required this.navPosture,
    required super.child,
  });

  /// Logical width of the WINDOW, not of the caller's box.
  final double width;
  final double height;

  /// How much of the window primary navigation is currently spending.
  final AuraNavPosture navPosture;

  /// Installs the authority from the real window size.
  static Widget install({
    required BuildContext context,
    required AuraNavPosture navPosture,
    required Widget child,
  }) {
    final size = MediaQuery.sizeOf(context);
    return AuraWindow(
      width: size.width,
      height: size.height,
      navPosture: navPosture,
      child: child,
    );
  }

  /// The window as classified. Falls back to the ambient MediaQuery when no
  /// authority is installed — a screen rendered outside the shell (a golden,
  /// a dialog route, a test harness) still gets a truthful answer rather than
  /// an assertion failure.
  static AuraWindowInfo of(BuildContext context) {
    final w = context.dependOnInheritedWidgetOfExactType<AuraWindow>();
    if (w != null) {
      return AuraWindowInfo(
        width: w.width,
        height: w.height,
        navPosture: w.navPosture,
      );
    }
    final size = MediaQuery.sizeOf(context);
    return AuraWindowInfo(
      width: size.width,
      height: size.height,
      navPosture: AuraNavPosture.forWidth(size.width),
    );
  }

  @override
  bool updateShouldNotify(AuraWindow old) =>
      old.width != width ||
      old.height != height ||
      old.navPosture != navPosture;
}

/// How much room primary navigation is taking.
///
/// Navigation orients a person; it does not own the desktop. Compact is the
/// normal desktop posture — the previous behaviour spent 288 px on it at every
/// width above 900, which on a laptop was a fifth of the window and on a wide
/// display was 288 px of permanently-visible labels nobody was reading.
enum AuraNavPosture {
  /// No persistent navigation — drawer + bottom bar.
  hidden,

  /// Icons with a short label beneath. The desktop default.
  compact,

  /// Icons with labels beside them, identity block visible.
  expanded;

  static AuraNavPosture forWidth(double width) =>
      width < kMobileBreak ? AuraNavPosture.hidden : AuraNavPosture.compact;

  double get railWidth {
    switch (this) {
      case AuraNavPosture.hidden:
        return 0;
      case AuraNavPosture.compact:
        // 76 was too tight: it cut the captions to "Crea…", "Mes…" and
        // "Disc…", which is worse than no caption -- a truncated word asks
        // somebody to decode it. 92 holds "Messages", the longest of the
        // four, at caption size with room either side.
        return 92;
      case AuraNavPosture.expanded:
        return 264;
    }
  }
}

/// Which desktop composition the window can carry.
///
/// Named for what the window can HOLD, not for a device. A 1500 px browser
/// window and a 1500 px Windows window are the same composition problem, and
/// the fix belongs to both.
enum AuraWindowClass {
  /// Phone-shaped. One thing at a time.
  handset,

  /// A laptop window or a narrow desktop one: navigation plus the work.
  laptop,

  /// Room for the object being selected AND the work itself, side by side.
  desktop,

  /// Room for selection, work, and a contextual inspector when it has
  /// something to say.
  wide;

  bool get canHoldSelection =>
      this == AuraWindowClass.desktop || this == AuraWindowClass.wide;

  bool get canHoldInspector => this == AuraWindowClass.wide;
}

/// The resolved window, with the questions surfaces actually ask.
class AuraWindowInfo {
  const AuraWindowInfo({
    required this.width,
    required this.height,
    required this.navPosture,
  });

  final double width;
  final double height;
  final AuraNavPosture navPosture;

  /// THRESHOLDS ARE ABOUT WHAT FITS, not about device names.
  ///
  /// `desktop` starts where compact navigation, a usable selection list and a
  /// conversation that is still comfortable to read can coexist:
  /// 76 + 300 + 620 ≈ 1000, with margin. `wide` starts where an inspector can
  /// join them without squeezing the conversation: + ~320.
  ///
  /// Deliberately NOT the old 1200 — a 1100 px window can hold list + detail
  /// perfectly well, and refusing to until 1200 is what made a laptop window
  /// fall back to a phone flow.
  AuraWindowClass get windowClass {
    if (width < kMobileBreak) return AuraWindowClass.handset;
    if (width < 1040) return AuraWindowClass.laptop;
    if (width < 1480) return AuraWindowClass.desktop;
    return AuraWindowClass.wide;
  }

  bool get isHandset => windowClass == AuraWindowClass.handset;
  bool get isDesktopClass => windowClass != AuraWindowClass.handset;

  /// Room left for content once navigation has taken its share.
  double get workWidth => width - navPosture.railWidth;
}
