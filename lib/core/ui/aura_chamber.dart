import 'package:flutter/material.dart';

/// AURA'S OWN LOOK: direction B, "Night Chamber" (founder, 2026-09-30:
/// "B is better and matching"). A flat ink ground, one gold accent that
/// matches the ring in the mark, a serif for what is said and a plain sans
/// for everything around it. No gradients, no glow.
///
/// First applied to the public front door. Other surfaces move to it only
/// with the founder's word, one surface at a time.
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
