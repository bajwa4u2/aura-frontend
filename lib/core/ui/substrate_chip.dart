import 'package:flutter/material.dart';

import 'aura_surface.dart';

/// Substrate-state chip — renders a typed enum value using the
/// canonical color semantics defined in
/// `company/visuals/system/governance/governance-grammar.md` §3.2
/// and `company/visuals/system/topology/topology-grammar.md` §6.
///
/// Use `SubstrateChip` wherever a screen surfaces a typed enum value
/// (an accountability tag, a speech mode, a verification state, a
/// governance state). The chip guarantees the rendering is consistent
/// with the public website and the AU-01 flagship cognition artifact
/// — same colors, same mono typography, same opacity for inactive
/// states.
///
/// The chip carries the enum value literally in mono uppercase. Per
/// canon, color is never the sole signal — the typed label always
/// accompanies it.
class SubstrateChip extends StatelessWidget {
  const SubstrateChip({
    super.key,
    required this.label,
    required this.state,
    this.icon,
    this.dimmed = false,
  });

  /// The literal enum value (rendered uppercase in mono).
  final String label;

  /// Substrate state class (drives color).
  final SubstrateChipState state;

  /// Optional inline icon (Material icon). Kept small per canon.
  final IconData? icon;

  /// When true, the chip is rendered at 30% opacity (inactive in a
  /// chip-set where one chip is the active state).
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final color = _foreground(state);
    final background = _background(state);
    final opacity = dimmed ? 0.30 : 1.0;

    return Opacity(
      opacity: opacity,
      child: Container(
        // 2px vertical padding (not 4) — the 4px variant was ~6-8px
        // taller per chip than the bespoke chips it replaced, which
        // pushed many migrated cards (spaces hub cards, feed badges,
        // messages header chip row) past their parent constraint and
        // tripped "BOTTOM OVERFLOWED BY N PIXELS" warnings in debug
        // (silent clip in release). Keeping 10px horizontal padding —
        // the wider hit-area is fine; only vertical was the regression.
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 6),
            ],
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: color,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _foreground(SubstrateChipState state) {
    switch (state) {
      case SubstrateChipState.verdant:
        return AuraSurface.coVerdant;
      case SubstrateChipState.sun:
        return AuraSurface.coSun;
      case SubstrateChipState.rose:
        return AuraSurface.coRose;
      case SubstrateChipState.teal:
        return AuraSurface.coTeal;
      case SubstrateChipState.mist:
        return AuraSurface.coMist;
    }
  }

  Color _background(SubstrateChipState state) {
    return _foreground(state).withValues(alpha: 0.16);
  }
}

/// Five canonical substrate state classes per
/// `system/governance/governance-grammar.md` §3.2 and §6.
enum SubstrateChipState {
  /// Allowed, verified, resolved, ready, trusted_ready, pass.
  /// Aura: RESOLVED accountability tag.
  verdant,

  /// Caution, pending, degraded, hold, update, capable_unproven,
  /// human-review-required. Aura: UPDATE accountability tag.
  sun,

  /// Blocked, refused, failed, critical, unsubscribed,
  /// client_action_required.
  rose,

  /// Governance / authority / institutional / company accent.
  /// Aura: COMMITMENT accountability tag, AUTHORIZED_INSTITUTIONAL.
  teal,

  /// Honest-unknown — substrate cannot yet evaluate. Per the
  /// runtime-truth doctrine, never coerced to pass or fail.
  mist,
}
