/// Centralized spacing tokens for Aura.
/// Use these instead of hard-coded padding/margins.
///
/// Important:
/// - Keep legacy `sXX` tokens for existing code.
/// - Add semantic aliases (xxs/xs/sm/md/lg/xl/xxl) for newer layouts.
/// - Do not remove or rename anything here.
class AuraSpace {
  AuraSpace._();

  // Legacy fixed tokens (existing code depends on these)
  static const double s4 = 4;
  static const double s6 = 6;
  static const double s8 = 8;
  static const double s10 = 10;
  static const double s12 = 12;
  static const double s14 = 14;
  static const double s16 = 16;
  static const double s18 = 18;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s28 = 28;
  static const double s32 = 32;

  // Semantic aliases (cinematic system)
  static const double xxs = s4;
  static const double xs = s8;
  static const double sm = s12;
  static const double md = s16;
  static const double lg = s20;
  static const double xl = s24;
  static const double xxl = s32;
}