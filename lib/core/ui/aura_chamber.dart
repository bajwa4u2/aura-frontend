import 'package:flutter/material.dart';

/// AURA'S OWN LOOK: direction B, "Night Chamber" (founder, 2026-09-30:
/// "B is better and matching"). A flat ink ground, one gold accent that
/// matches the ring in the mark, a serif for what is said and a plain sans
/// for everything around it. No gradients, no glow.
///
/// First applied to the public front door, then to all of Aura at once
/// (founder, 2026-09-30: "night chamber only", "do at once").
abstract final class AuraChamber {
  // Colour
  static const Color ink = Color(0xFF0E1116);
  static const Color raised = Color(0xFF151922);
  static const Color rule = Color(0xFF232833);
  static const Color ruleStrong = Color(0xFF3A404C);
  static const Color text = Color(0xFFE8E4DA);
  static const Color muted = Color(0xFFA9AEB9);
  static const Color faint = Color(0xFF8C919C);
  static const Color gold = Color(0xFFD2AC62);

  // Type
  static const String serif = 'AuraSerif';
  static const String sans = 'AuraSans';

  static const TextStyle display = TextStyle(
    fontFamily: serif,
    fontWeight: FontWeight.w500,
    fontSize: 46,
    height: 1.1,
    color: text,
  );

  static const TextStyle heading = TextStyle(
    fontFamily: serif,
    fontWeight: FontWeight.w500,
    fontSize: 30,
    height: 1.2,
    color: text,
  );

  static const TextStyle lede = TextStyle(
    fontFamily: sans,
    fontSize: 17,
    height: 1.65,
    color: muted,
  );

  static const TextStyle body = TextStyle(
    fontFamily: sans,
    fontSize: 15,
    height: 1.55,
    color: text,
  );

  static const TextStyle small = TextStyle(
    fontFamily: sans,
    fontSize: 13.5,
    height: 1.45,
    color: muted,
  );

  static const TextStyle eyebrow = TextStyle(
    fontFamily: sans,
    fontSize: 11.5,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.6,
    color: faint,
  );
}

/// Marks a subtree as dressed in look B. Shared widgets (the feed card)
/// read it and take the chamber's surface and gold; outside it they keep
/// the look they have. This is how B reaches the public front door without
/// changing the signed-in app (founder, 2026-09-30: one surface at a time).
class AuraChamberScope extends InheritedWidget {
  const AuraChamberScope({super.key, required super.child});

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AuraChamberScope>() != null;

  @override
  bool updateShouldNotify(AuraChamberScope oldWidget) => false;
}

/// The public estate's theme in look B: Public Sans for every piece of text
/// that does not name a family, the ink ground, gold as the primary colour.
/// Wraps the public shell only; the signed-in shells keep their theme.
ThemeData auraChamberTheme(ThemeData base) {
  final scheme = base.colorScheme.copyWith(
    primary: AuraChamber.gold,
    onPrimary: AuraChamber.ink,
    secondary: AuraChamber.gold,
    onSecondary: AuraChamber.ink,
    surface: AuraChamber.raised,
    onSurface: AuraChamber.text,
    outline: AuraChamber.ruleStrong,
    outlineVariant: AuraChamber.rule,
  );
  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: AuraChamber.ink,
    canvasColor: AuraChamber.ink,
    cardColor: AuraChamber.raised,
    dividerColor: AuraChamber.rule,
    textTheme: base.textTheme.apply(fontFamily: AuraChamber.sans),
    primaryTextTheme: base.primaryTextTheme.apply(fontFamily: AuraChamber.sans),
    textSelectionTheme: base.textSelectionTheme.copyWith(
      cursorColor: AuraChamber.gold,
      selectionColor: AuraChamber.gold.withValues(alpha: 0.3),
      selectionHandleColor: AuraChamber.gold,
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      fillColor: AuraChamber.raised,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AuraChamber.gold),
      ),
    ),
  );
}

/// Translates one of the legacy surface colours into look B when [context]
/// sits inside [AuraChamberScope]; outside it the colour is returned as is.
/// Lets shared public layouts wear B without forking them, while the
/// signed-in app keeps its palette.
Color chamberTone(BuildContext context, Color legacy) {
  if (!AuraChamberScope.of(context)) return legacy;
  final v = legacy.toARGB32();
  switch (v) {
    // The legacy tokens now carry chamber values; the public layouts stay
    // flat (no subtle or elevated steps), as approved on the front door.
    case 0xFF12161D: // subtle
      return AuraChamber.ink;
    case 0xFF1A1F29: // elevated
    case 0xFF1E2330: // overlay
      return AuraChamber.raised;
    case 0x14FFFFFF: // a translucent hairline
      return AuraChamber.rule;
    case 0x33D2AC62: // accentSoft
      return const Color(0x1FD2AC62);
  }
  return legacy;
}

/// Gradients in look B: inside [AuraChamberScope] the accent gradient becomes
/// flat gold and every surface gradient the flat raised ink. B has no
/// gradients. Outside the scope the gradient is returned as is.
Gradient chamberGradient(BuildContext context, Gradient legacy) {
  if (!AuraChamberScope.of(context)) return legacy;
  final isAccent = legacy is LinearGradient &&
      legacy.colors.isNotEmpty &&
      legacy.colors.first.toARGB32() == 0xFFD2AC62;
  final c = isAccent ? AuraChamber.gold : AuraChamber.raised;
  return LinearGradient(colors: [c, c]);
}
