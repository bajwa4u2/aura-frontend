import 'package:flutter/material.dart';

/// Centralized surface + stroke tokens for Aura.
/// Keep this file boring and stable.
/// Everything UI should reference these instead of hard-coded colors.
class AuraSurface {
  AuraSurface._();

  /// Deep graphite page background (dark-first cinematic base)
  static const Color page = Color(0xFF121418);

  /// Primary panel surface (default card surface)
  static const Color card = Color(0xFF1A1E24);

  /// Slightly elevated surface (dialogs / overlays / pop surfaces)
  static const Color elevated = Color(0xFF222833);

  /// Main text color (luminous but not pure white)
  static const Color ink = Color(0xFFE8EAED);

  /// Muted text color (still readable on dark)
  static const Color muted = Color(0xFF9AA3AF);

  /// Subtle divider / hairline separator
  /// Very soft light edge, not heavy border
  static const Color divider = Color(0x1FFFFFFF);

  /// Alias kept so older widgets don’t break.
  /// Prefer using `divider` going forward.
  static const Color cardBorder = divider;

  /// Signature accent (indigo, controlled usage)
  static const Color accent = Color(0xFF5B6CFF);

  /// Soft accent glow (hover / active states)
  static const Color accentSoft = Color(0x335B6CFF);

  // --- Semantic status surfaces (for badges, callouts, quiet system feedback) ---
  // These are intentionally low-chroma so Aura stays “quiet” and institutional.

  static const Color goodBg = Color(0xFF14251B);
  static const Color goodInk = Color(0xFF9FE3B7);

  static const Color warnBg = Color(0xFF2A2214);
  static const Color warnInk = Color(0xFFF2D08A);

  static const Color dangerBg = Color(0xFF2A1717);
  static const Color dangerInk = Color(0xFFF0A3A3);

  static const Color infoBg = Color(0xFF16212B);
  static const Color infoInk = Color(0xFF9BC7F0);
}