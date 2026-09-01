/// HOW THE CONSOLE TELLS THE TRUTH ABOUT WHAT IT KNOWS.
///
/// Every area depends on several authorities. When one of them cannot answer,
/// three things must all remain true:
///
///   1. the rest of the area still works,
///   2. the operator is told which part is missing,
///   3. the gap is never rendered as a business fact.
///
/// The first reconstruction failed all three at once: a worklist read failure
/// erased NOW's attention section, emptied WORK, blanked INTEGRITY's conduct
/// half, and made a subject's waiting list vanish with nothing said.
///
/// These are the widgets that make the honest version cheap enough that no
/// surface has an excuse.
library;

import 'package:flutter/material.dart';

import '../../../core/product/product_language.dart';
import '../../../core/product/temporal.dart';

import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../domain/operator_signal.dart';
import 'operator_kit.dart';


/// A one-line admission, sized to sit inside a section without taking it over.
///
/// Deliberately NOT a full-surface error. The section it belongs to keeps its
/// own content; this says what is missing from it.
class OperatorDisclosure extends StatelessWidget {
  const OperatorDisclosure({
    super.key,
    required this.sentence,
    this.tone = OperatorTone.warn,
    this.onRetry,
    this.icon,
  });

  /// Written as a fact about the READING, never about Aura. "Support could not
  /// be read" — not "Support is empty".
  final String sentence;

  final OperatorTone tone;
  final VoidCallback? onRetry;
  final IconData? icon;

  /// The standard disclosure for a signal that needs one. Returns null when
  /// the reading is complete — the common case, which should cost nothing.
  static Widget? forSignal(
    OperatorSignal<Object?> signal, {
    required String subject,
    VoidCallback? onRetry,
  }) {
    switch (signal.reach) {
      case OperatorReach.partial:
        final missing = signal.missing;
        return OperatorDisclosure(
          sentence: missing.isEmpty
              ? 'Some of $subject could not be read. This is not a complete '
                  'picture.'
              : 'Not everything is here: ${_list(missing)} could not be read.',
          onRetry: onRetry,
          icon: Icons.report_gmailerrorred_rounded,
        );
      case OperatorReach.stale:
        // STALE MUST CARRY ITS AGE.
        //
        // "This is the last reading" tells an operator the value is old. It
        // does not tell them whether old means four minutes or four days, and
        // those lead to opposite decisions. The signal already carries
        // `readAt` precisely so the age can be stated instead of implied; not
        // stating it left the most useful half of the fact in the object.
        //
        // When no reading time was recorded the sentence stays as it was
        // rather than inventing an age — an unknown age is not "just now".
        // THE CANONICAL FORMATTER, NOT A LOCAL ONE.
        //
        // The C0 anti-drift gate forbids new local elapsed-time formatting and
        // it is right to: a console that invents its own "7 minutes ago" drifts
        // from every other surface in Aura. AuraTemporal carries the event
        // semantics with the instant, and `occurred` is what a reading is.
        final readAt = signal.readAt;
        final age = readAt == null
            ? null
            : AuraTemporal.humanize(ProductTime(readAt, TimeEvent.occurred));
        return OperatorDisclosure(
          sentence: signal.detail ??
              (age == null
                  ? 'This is the last reading of $subject. It could not be '
                      'refreshed.'
                  : 'This is the last reading of $subject, taken $age. It '
                      'could not be refreshed.'),
          tone: OperatorTone.pending,
          onRetry: onRetry,
          icon: Icons.history_rounded,
        );
      case OperatorReach.unavailable:
        return OperatorDisclosure(
          sentence: '$subject ${signal.detail ?? 'could not be read'}. '
              'This is a read failure, not an empty result.',
          tone: OperatorTone.danger,
          onRetry: onRetry,
          icon: Icons.cloud_off_rounded,
        );
      case OperatorReach.pending:
      case OperatorReach.complete:
      case OperatorReach.unauthorized:
        return null;
    }
  }

  static String _list(List<String> items) {
    if (items.length == 1) return items.single;
    if (items.length == 2) return '${items[0]} and ${items[1]}';
    return '${items.take(items.length - 1).join(', ')} and ${items.last}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.s12,
        AuraSpace.s10,
        AuraSpace.s12,
        AuraSpace.s10,
      ),
      decoration: BoxDecoration(
        color: tone.bg.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AuraRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon ?? Icons.info_outline_rounded,
            size: 15,
            color: tone.ink,
          ),
          const SizedBox(width: AuraSpace.s8),
          Expanded(
            child: Text(
              sentence,
              style: const TextStyle(
                color: AuraSurface.ink,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: AuraSpace.s8),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: AuraSpace.s8),
              ),
              child: Text(ProductLabels.of(ProductAction.retry)),
            ),
          ],
        ],
      ),
    );
  }
}

/// Renders a signal without ever letting a failure become an empty result.
///
/// The single place the whole console decides what to draw for each state, so
/// no area can quietly invent a different answer. `partial` and `stale` reach
/// [builder] WITH their value AND their disclosure — that combination is the
/// one the old code had no way to express.
class OperatorSignalView<T> extends StatelessWidget {
  const OperatorSignalView({
    super.key,
    required this.signal,
    required this.subject,
    required this.builder,
    this.loading,
    this.onRetry,
    this.unauthorizedNeeds,
    this.unauthorizedSentence,
  });

  final OperatorSignal<T> signal;

  /// What is being read, as an operator would name it: "the worklist",
  /// "platform health". Used in every state sentence.
  final String subject;

  final Widget Function(BuildContext context, T value) builder;
  final Widget? loading;
  final VoidCallback? onRetry;
  /// The capability NAME — a noun that fills "You do not hold ___ authority".
  final String? unauthorizedNeeds;

  /// The whole sentence, where the noun slot cannot say it. See
  /// [OperatorInsufficientCapability.sentence].
  final String? unauthorizedSentence;

  @override
  Widget build(BuildContext context) {
    switch (signal.reach) {
      case OperatorReach.pending:
        return loading ?? const OperatorLoading(lines: 2);

      case OperatorReach.unauthorized:
        return OperatorInsufficientCapability(
          needs: unauthorizedNeeds ?? signal.detail ?? subject,
          sentence: unauthorizedSentence,
        );

      case OperatorReach.unavailable:
        return OperatorFailure(
          title: '$subject could not be read',
          detail: 'This is a read failure, not an empty result. Nothing has '
              'been lost.',
          onRetry: onRetry,
        );

      case OperatorReach.complete:
      case OperatorReach.partial:
      case OperatorReach.stale:
        final value = signal.value;
        if (value == null) {
          // Defensive: a value-bearing reach with no value is a programming
          // error, and rendering nothing would hide it.
          return OperatorFailure(
            title: '$subject is in an unexpected state',
            onRetry: onRetry,
          );
        }
        final disclosure = OperatorDisclosure.forSignal(
          signal,
          subject: subject,
          onRetry: onRetry,
        );
        if (disclosure == null) return builder(context, value);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            disclosure,
            const SizedBox(height: AuraSpace.s12),
            builder(context, value),
          ],
        );
    }
  }
}
