/// SHARED OPERATOR PRIMITIVES.
///
/// Seven areas, one visual vocabulary. These exist so "degraded" looks the
/// same in NOW as it does in PLATFORM, and so an age of nine days reads the
/// same weight wherever an operator meets it. Without a kit, seven areas
/// become seven dialects and the console stops being one product — which is
/// how the last one ended up as eighteen small applications sharing a sidebar.
library;

import 'package:flutter/material.dart';

import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';

/// The operator status vocabulary. Deliberately small: an operator should be
/// able to learn five colours, not twenty.
enum OperatorTone {
  /// Working as intended. Used sparingly — most things being fine is the
  /// default, and colouring it all green teaches people to ignore green.
  good,

  /// Waiting on a human. The ordinary state of a queue.
  pending,

  /// Needs attention soon.
  warn,

  /// Needs attention now.
  danger,

  /// Not a judgement — a fact with no valence.
  neutral,
}

extension OperatorToneColors on OperatorTone {
  Color get ink => switch (this) {
        OperatorTone.good => AuraSurface.goodInk,
        OperatorTone.pending => AuraSurface.accentText,
        OperatorTone.warn => AuraSurface.warnInk,
        OperatorTone.danger => AuraSurface.dangerInk,
        OperatorTone.neutral => AuraSurface.muted,
      };

  Color get bg => switch (this) {
        OperatorTone.good => AuraSurface.goodBg,
        OperatorTone.pending => AuraSurface.accentSoft,
        OperatorTone.warn => AuraSurface.warnBg,
        OperatorTone.danger => AuraSurface.dangerBg,
        OperatorTone.neutral => AuraSurface.elevated,
      };
}

/// A short state word carried verbatim from an authority.
///
/// The label is NOT prettified. `NEEDS_MORE_INFO` and `NEEDS_INFO` belong to
/// different authorities and mean different things; rewriting either into
/// "Needs info" would be the console quietly redefining someone else's
/// decision. Underscores become spaces and nothing else changes.
class OperatorStatePill extends StatelessWidget {
  const OperatorStatePill({
    super.key,
    required this.state,
    this.tone = OperatorTone.neutral,
    this.dense = false,
  });

  final String state;
  final OperatorTone tone;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final text = state.replaceAll('_', ' ');
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? AuraSpace.s6 : AuraSpace.s8,
        vertical: dense ? 2 : AuraSpace.s4,
      ),
      decoration: BoxDecoration(
        color: tone.bg,
        borderRadius: BorderRadius.circular(AuraRadius.sm),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: dense ? 10 : 11,
          height: 1.2,
          letterSpacing: 0.3,
          fontWeight: FontWeight.w600,
          color: tone.ink,
        ),
      ),
    );
  }
}

/// How long something has waited.
///
/// Age is a FACT, never a deadline. Aura publishes no response commitment for
/// its queues, so this escalates in weight with time without ever claiming a
/// target was missed. The thresholds are presentation, not policy.
class OperatorAge extends StatelessWidget {
  const OperatorAge({super.key, required this.days, this.dense = false});

  final int days;
  final bool dense;

  OperatorTone get _tone {
    if (days >= 14) return OperatorTone.danger;
    if (days >= 7) return OperatorTone.warn;
    return OperatorTone.neutral;
  }

  String get _label {
    if (days <= 0) return 'today';
    if (days == 1) return '1 day';
    return '$days days';
  }

  @override
  Widget build(BuildContext context) {
    final tone = _tone;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.schedule_rounded,
          size: dense ? 12 : 13,
          color: tone.ink,
        ),
        const SizedBox(width: AuraSpace.s4),
        Text(
          _label,
          style: TextStyle(
            fontSize: dense ? 11 : 12,
            color: tone.ink,
            fontWeight: days >= 7 ? FontWeight.w600 : FontWeight.w500,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// A section heading inside an area. Areas own their content; the shell owns
/// the chrome, so headings live here rather than in a scaffold.
class OperatorSection extends StatelessWidget {
  const OperatorSection({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AuraSpace.s12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AuraSurface.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.1,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          color: AuraSurface.muted,
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
        child,
      ],
    );
  }
}

/// A panel. The console's one container shape.
class OperatorPanel extends StatelessWidget {
  const OperatorPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AuraSpace.s16),
    this.tone,
  });

  final Widget child;
  final EdgeInsets padding;

  /// Tints the border only. A panel that fills with colour shouts; a panel
  /// with a coloured edge points.
  final OperatorTone? tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(
          color: tone == null
              ? AuraSurface.divider
              : tone!.ink.withValues(alpha: 0.35),
        ),
      ),
      child: child,
    );
  }
}

/// Nothing to do — stated as a RESULT.
///
/// A healthy system is the normal case and the console should not apologise
/// for it with a shrug icon and "no data". "Nothing needs your attention" is
/// information an operator is glad to receive.
class OperatorClear extends StatelessWidget {
  const OperatorClear({
    super.key,
    required this.title,
    this.detail,
    this.icon = Icons.check_circle_outline_rounded,
  });

  final String title;
  final String? detail;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AuraSpace.s16),
      child: Column(
        children: [
          Icon(icon, size: 26, color: AuraSurface.goodInk),
          const SizedBox(height: AuraSpace.s10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AuraSurface.ink,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (detail != null) ...[
            const SizedBox(height: AuraSpace.s4),
            Text(
              detail!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AuraSurface.muted, fontSize: 12.5),
            ),
          ],
        ],
      ),
    );
  }
}

/// Something failed. Distinct from empty, always.
class OperatorFailure extends StatelessWidget {
  const OperatorFailure({
    super.key,
    required this.title,
    this.detail,
    this.onRetry,
  });

  final String title;
  final String? detail;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return OperatorPanel(
      tone: OperatorTone.danger,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 18, color: AuraSurface.dangerInk),
          const SizedBox(width: AuraSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AuraSurface.ink,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (detail != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    detail!,
                    style: const TextStyle(
                        color: AuraSurface.muted, fontSize: 12.5, height: 1.35),
                  ),
                ],
              ],
            ),
          ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

/// A quiet loading state. An operator console that flashes spinners on every
/// panel reads as fragile; these hold the shape instead.
class OperatorLoading extends StatelessWidget {
  const OperatorLoading({super.key, this.lines = 3});

  final int lines;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < lines; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AuraSpace.s8),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: AuraSurface.card,
                borderRadius: BorderRadius.circular(AuraRadius.md),
                border: Border.all(color: AuraSurface.divider),
              ),
            ),
          ),
      ],
    );
  }
}

/// The operator holds no authority for this surface. Never a dead end: it says
/// what is missing so the person knows what to ask for.
class OperatorInsufficientCapability extends StatelessWidget {
  const OperatorInsufficientCapability({super.key, required this.needs});

  /// Human-readable capability name, e.g. "moderation".
  final String needs;

  @override
  Widget build(BuildContext context) {
    return OperatorPanel(
      child: Row(
        children: [
          const Icon(Icons.lock_outline_rounded,
              size: 18, color: AuraSurface.muted),
          const SizedBox(width: AuraSpace.s12),
          Expanded(
            child: Text(
              'You do not hold $needs authority. An operator who does can act '
              'on this.',
              style: const TextStyle(
                  color: AuraSurface.muted, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
