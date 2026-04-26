import 'package:flutter/material.dart';

/// Centralized surface + stroke tokens for Aura.
/// Deep navy direction — premium, institutional, trust-forward.
class AuraSurface {
  AuraSurface._();

  /// Deep navy canvas — the base of every surface.
  static const Color page = Color(0xFF0D1520);

  /// Inset surface — for nested well areas, sidebar backgrounds, text fields.
  static const Color subtle = Color(0xFF111D2E);

  /// Primary panel surface — default card background.
  static const Color card = Color(0xFF152438);

  /// Elevated surface — dialogs, overlays, popups.
  static const Color elevated = Color(0xFF1B2E44);

  /// Heavy overlay — bottom sheets, side drawers.
  static const Color overlay = Color(0xFF203454);

  /// Primary text — luminous cool white.
  static const Color ink = Color(0xFFE2ECF5);

  /// Muted text — readable secondary on navy.
  static const Color muted = Color(0xFF7A96B5);

  /// Faint text — placeholder, disabled, tertiary.
  static const Color faint = Color(0xFF4B6882);

  /// Hairline divider — barely-there separator.
  static const Color divider = Color(0x14FFFFFF);

  /// Alias kept for backward compatibility.
  static const Color cardBorder = divider;

  /// Signature indigo accent.
  static const Color accent = Color(0xFF5B6CFF);

  /// Soft accent — glow / active / hover backgrounds.
  static const Color accentSoft = Color(0x335B6CFF);

  /// Accent text — lighter indigo for text on dark navy.
  static const Color accentText = Color(0xFF8B9EFF);

  // ── Semantic status surfaces ────────────────────────────────────────────────

  static const Color goodBg = Color(0xFF0E2318);
  static const Color goodInk = Color(0xFF5FD99A);

  static const Color warnBg = Color(0xFF221B0E);
  static const Color warnInk = Color(0xFFEDC264);

  static const Color dangerBg = Color(0xFF231010);
  static const Color dangerInk = Color(0xFFF07878);

  static const Color infoBg = Color(0xFF0F1E2E);
  static const Color infoInk = Color(0xFF6BAEED);
}
