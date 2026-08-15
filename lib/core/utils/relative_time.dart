/// Compatibility shim over the **Human Temporal Presentation Authority**.
///
/// These three functions used to own their own thresholds and their own
/// formatting. C0 moved that ownership to `core/product/temporal.dart`; this
/// file now forwards, so there is exactly **one** implementation of humanized
/// time in the client.
///
/// Two behaviours changed deliberately when ownership moved, and both are
/// corrections rather than redesign:
///
///  1. Older values now read `Aug 12` / `Aug 12, 2025` instead of the machine
///     form `2026-08-12`. A raw ISO date in a feed card is precisely the
///     "machines store precise time, people experience meaningful time"
///     defect the authority exists to remove.
///  2. Future instants no longer render as `now`. `formatRelative` previously
///     took a negative difference through its `inSeconds < 60` branch, so a
///     scheduled item read as if it had already happened.
///
/// New code must call [AuraTemporal] with a [ProductTime] so the *meaning* of
/// the timestamp travels with it. These wrappers cannot know whether they were
/// handed a posted, sent, or published instant — which is the ambiguity being
/// retired.
library;

import '../product/temporal.dart';

/// Compact relative timestamp: `now`, `5m`, `2h`, `3d`, then a date.
@Deprecated(
  'Use AuraTemporal.humanize(ProductTime(when, TimeEvent.x), '
  'style: TemporalStyle.compact) so the event semantics are declared.',
)
String formatRelative(DateTime when) => AuraTemporal.humanize(
      ProductTime(when, TimeEvent.occurred),
      style: TemporalStyle.compact,
    );

/// Long-form past phrase: `just now`, `3 minutes ago`, `2 hours ago`, date.
@Deprecated(
  'Use AuraTemporal.humanize(ProductTime(when, TimeEvent.x)) so the event '
  'semantics are declared.',
)
String formatPastPhrase(DateTime when) =>
    AuraTemporal.humanize(ProductTime(when, TimeEvent.occurred));

/// Compact "Started X min ago" — the second clause of the live-room presence
/// line. Returns null when the source timestamp is null so the caller can omit
/// the segment.
@Deprecated(
  'Use AuraTemporal.humanize(ProductTime(when, TimeEvent.started), '
  'style: TemporalStyle.semantic).',
)
String? formatStartedAgo(DateTime? when) {
  if (when == null) return null;
  final time = ProductTime(when, TimeEvent.started);
  final phrase = AuraTemporal.humanize(time);
  if (phrase == 'just now') return 'Just started';
  return 'Started $phrase';
}
