/// Centralized radius tokens for Aura.
class AuraRadius {
  AuraRadius._();

  // Fixed tokens — existing code depends on these
  static const double r10 = 10;
  static const double r12 = 12;
  static const double r14 = 14;
  static const double r16 = 16;
  static const double r18 = 18;
  static const double r22 = 22;
  static const double r24 = 24;

  // Semantic aliases
  static const double sm = r12;
  static const double md = r14;
  static const double lg = r18;
  static const double xl = r22;

  /// Default card radius
  static const double card = r18;

  /// Full pill / capsule shape
  static const double pill = 999;
}
