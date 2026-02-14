import 'package:flutter/material.dart';

/// Centralized radius tokens for Aura.
/// Quiet, consistent curvature across the system.
class AuraRadius {
  AuraRadius._();

  /// Small elements (chips, tiny containers)
  static const double r8 = 8;

  /// Buttons, small surfaces
  static const double r12 = 12;

  /// Callouts and compact surfaces
  static const double r14 = 14;

  /// Standard card radius
  static const double r18 = 18;

  /// Larger feature surfaces (hero blocks, etc.)
  static const double r22 = 22;

  /// Fully rounded (avatars, pills)
  static const double round = 999;
}
