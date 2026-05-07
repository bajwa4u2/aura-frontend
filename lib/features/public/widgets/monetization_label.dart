import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../domain/monetization_kind.dart';

/// Visible-in-context monetization stripe rendered on feed cards and
/// thread replies whenever a paid action is in play. Two visual moods:
///   * Authority (free) — calm accent (Official response).
///   * Paid — neutral surface with a small `$` glyph so the reader can
///     immediately tell payment was involved without it being alarming.
///
/// Phase 1: UI only. Tap currently shows a SnackBar pointing at the
/// transparency page (route placeholder until that screen ships in
/// Phase 2). The widget is safe to render anywhere in the public
/// surface — it has no provider dependency.
class MonetizationLabel extends StatelessWidget {
  const MonetizationLabel({
    super.key,
    required this.kind,
    this.compact = false,
  });

  final MonetizationKind kind;

  /// When true, render as an inline pill (next to the OFFICIAL eyebrow);
  /// otherwise render as a full-width stripe band beneath the card body.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final paid = kind.isPaid;
    final bg = paid ? AuraSurface.subtle : AuraSurface.accentSoft;
    final ink = paid ? AuraSurface.muted : AuraSurface.accentText;
    final border = paid
        ? AuraSurface.divider
        : AuraSurface.accent.withValues(alpha: 0.4);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // Phase 2 — tap routes to the transparency page so the
          // reader gets the full explanation of what each label
          // means, not just a one-line confirmation.
          context.push('/aura/participation');
        },
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? AuraSpace.s8 : AuraSpace.s10,
            vertical: compact ? 3 : 5,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AuraRadius.pill),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                paid
                    ? Icons.attach_money_rounded
                    : Icons.verified_rounded,
                size: compact ? 11 : 12,
                color: ink,
              ),
              const SizedBox(width: 4),
              Text(
                kind.stripeLabel,
                style: AuraText.micro.copyWith(
                  color: ink,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                  fontSize: compact ? 9 : 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
