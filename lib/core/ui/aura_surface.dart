import 'package:flutter/material.dart';

/// Centralized surface + stroke tokens for Aura.
///
/// Night Chamber, everywhere (founder, 2026-09-30: "night chamber only").
/// The same ink, gold and warm text the public front door wears, so signed-in
/// Aura and public Aura are one look. See `aura_chamber.dart`.
class AuraSurface {
  AuraSurface._();

  /// Ink canvas — the base of every surface.
  static const Color page = Color(0xFF0E1116);

  /// Inset surface — for nested well areas, sidebar backgrounds, text fields.
  static const Color subtle = Color(0xFF12161D);

  /// Primary panel surface — default card background.
  static const Color card = Color(0xFF151922);

  /// Elevated surface — dialogs, overlays, popups.
  static const Color elevated = Color(0xFF1A1F29);

  /// Heavy overlay — bottom sheets, side drawers.
  static const Color overlay = Color(0xFF1E2330);

  /// Primary text — warm paper white.
  static const Color ink = Color(0xFFE8E4DA);

  /// Muted text — readable secondary on ink.
  static const Color muted = Color(0xFFA9AEB9);

  /// Faint text — placeholder, disabled, tertiary.
  static const Color faint = Color(0xFF8C919C);

  /// Hairline divider — the chamber's rule.
  static const Color divider = Color(0xFF232833);

  /// Alias kept for backward compatibility.
  static const Color cardBorder = divider;

  /// The gold of the ring in the mark — Aura's one accent.
  static const Color accent = Color(0xFFD2AC62);

  /// Soft accent — glow / active / hover backgrounds.
  static const Color accentSoft = Color(0x33D2AC62);

  /// Accent text — gold reads on ink as it is.
  static const Color accentText = Color(0xFFD2AC62);

  /// Text and icons ON the accent. White on gold does not read; ink does.
  static const Color onAccent = Color(0xFF0E1116);

  // ── Semantic status surfaces ────────────────────────────────────────────────

  static const Color goodBg = Color(0xFF0E2318);
  static const Color goodInk = Color(0xFF5FD99A);

  static const Color warnBg = Color(0xFF221B0E);
  static const Color warnInk = Color(0xFFEDC264);

  static const Color dangerBg = Color(0xFF231010);
  static const Color dangerInk = Color(0xFFF07878);

  static const Color infoBg = Color(0xFF12161D);
  static const Color infoInk = Color(0xFF6BAEED);

  // ─── Canonical substrate tokens ─────────────────────────────────
  // Mirror `company/visuals/system/tokens/design-tokens.md` and the
  // governance grammar at `system/governance/governance-grammar.md`
  // §3.2 (the COMMITMENT / UPDATE / RESOLVED chip-color triad).
  //
  // These are the visual identifiers used on the public website and
  // the AU-01 flagship cognition artifact. New substrate-substantive
  // surfaces should reference these directly so Aura and the website
  // remain visually coherent. Existing AuraSurface constants above
  // are preserved unchanged for backward compatibility.
  static const Color coTeal = Color(0xFF0D9488);
  static const Color coTealDeep = Color(0xFF176B5D);
  static const Color coVerdant = Color(0xFF22C55E);
  static const Color coSun = Color(0xFFEAB308);
  static const Color coRose = Color(0xFFF43F5E);
  static const Color coMist = Color(0xFFA6AECC);
  static const Color coSnow = Color(0xFFF5F7FB);
}
