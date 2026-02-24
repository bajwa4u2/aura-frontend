/// Centralized radius tokens for Aura.
/// Use these everywhere instead of hard-coded numbers.
///
/// Important:
/// - Keep legacy `rXX` tokens for existing code.
/// - Add semantic aliases (sm/md/lg/xl) for newer layouts.
/// - Do not remove or rename anything here.
class AuraRadius {
  AuraRadius._();

  /// Common radii
  static const double r10 = 10;
  static const double r12 = 12;
  static const double r14 = 14;
  static const double r16 = 16;
  static const double r18 = 18;
  static const double r22 = 22;
  static const double r24 = 24;

  /// Semantic aliases (cinematic system)
  /// These map to your existing radii so nothing changes unexpectedly.
  static const double sm = r12;
  static const double md = r14;
  static const double lg = r18;
  static const double xl = r22;

  /// Default card radius used across Aura
  static const double card = r18;
}