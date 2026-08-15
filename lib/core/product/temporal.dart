/// HUMAN TEMPORAL PRESENTATION AUTHORITY — C0.
///
/// > **MACHINES STORE PRECISE TIME. PEOPLE EXPERIENCE MEANINGFUL TIME.**
///
/// ── WHY THIS EXISTS ──────────────────────────────────────────────────────
/// Measured drift: `relative_time.dart` had **9** consumers while **52 files**
/// computed elapsed time themselves; `local_timezone.dart` had **3** while
/// `toLocal()` appeared in **35**. Timestamp semantics had collapsed onto one
/// field — `createdAt` used 295x against `sentAt` 14x, with `receivedAt` and
/// `occurredAt` **never used at all**. The product literally could not say
/// when something was *received*.
///
/// ── WHAT THIS OWNS ───────────────────────────────────────────────────────
/// semantic event type · canonical timestamp selection · relative vs absolute
/// presentation · locale/timezone · humanized formatting · exact-time access ·
/// **sorting semantics** · aging/refresh behaviour.
///
/// ── WHAT IT DOES NOT OWN ─────────────────────────────────────────────────
/// **The owning domain decides which event time has product meaning.** This
/// authority renders that meaning coherently; it never guesses it. It is also
/// not a general duration utility — internal TTLs, cooldowns, debounces and
/// elapsed-timers are *not* human-facing time and legitimately stay local.
library;

import '../utils/local_timezone.dart';

/// What a timestamp **means** to a person.
///
/// The verb matters: FD-10 froze that Posted / Sent / Received / Published /
/// Updated / Invited / Started / Ended must correspond to real product
/// semantics and are never used interchangeably as decorative copy.
enum TimeEvent {
  posted,
  sent,
  received,
  replied,
  published,
  updated,
  invited,
  started,
  ended,
  scheduled,
  occurred,
}

extension TimeEventVerb on TimeEvent {
  /// The human verb for this event. Used when a surface communicates *what
  /// happened*, not merely when.
  String get verb {
    switch (this) {
      case TimeEvent.posted:
        return 'Posted';
      case TimeEvent.sent:
        return 'Sent';
      case TimeEvent.received:
        return 'Received';
      case TimeEvent.replied:
        return 'Replied';
      case TimeEvent.published:
        return 'Published';
      case TimeEvent.updated:
        return 'Updated';
      case TimeEvent.invited:
        return 'Invited';
      case TimeEvent.started:
        return 'Started';
      case TimeEvent.ended:
        return 'Ended';
      case TimeEvent.scheduled:
        return 'Starts';
      case TimeEvent.occurred:
        return 'Occurred';
    }
  }

  /// True when the event is inherently forward-looking, so a future instant
  /// is normal rather than a clock-skew artefact.
  bool get isFuture => this == TimeEvent.scheduled;
}

/// A timestamp **bound to its meaning**.
///
/// Carrying the event with the instant is what prevents a surface reaching for
/// `createdAt` because it was the convenient field.
class ProductTime {
  const ProductTime(this.instant, this.event);

  /// The absolute instant. Precision is never lost — [exact] always available.
  final DateTime instant;

  /// What this instant means in the owning domain.
  final TimeEvent event;

  /// Local-zone instant. The single place `toLocal()` is applied for
  /// human-facing time, so screens stop deciding timezone semantics.
  DateTime get local => instant.toLocal();

  /// Exact, unambiguous timestamp for details, audit-sensitive contexts,
  /// scheduled events, tooltips, expanded metadata and accessibility.
  ///
  /// **Humanized presentation never removes precision** — it is the ordinary
  /// communication layer, not a replacement for the real value.
  String get exact => AuraTemporal.absolute(this);
}

/// Granularity chosen for a humanized string.
enum TemporalStyle {
  /// `now` `5m` `2h` `3d` then a date. Dense rows, chips, inline stamps.
  compact,

  /// `just now` `3 minutes ago` `2 hours ago` then a date. Detail strips.
  phrase,

  /// `Posted 3 minutes ago`. Communicates the event, not only the time.
  semantic,
}

/// The canonical temporal authority.
class AuraTemporal {
  const AuraTemporal._();

  /// Test seam. Production leaves this null and uses the real clock.
  static DateTime Function()? debugClock;

  static DateTime _now() => (debugClock ?? DateTime.now)();

  /// The device's zone as an **IANA identifier**, for anything that must send
  /// or store a zone rather than display one.
  ///
  /// Presentation uses [ProductTime.local]; this is the transport answer, and
  /// the two are deliberately different questions. `timeZoneName` alone is a
  /// display name or abbreviation and is not a valid zone identifier.
  static String get zoneId => resolveLocalTimezone();

  static const List<String> _months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// Humanized presentation of a product time.
  ///
  /// Thresholds live here **once**, so screens cannot invent inconsistent
  /// cut-offs. Ranges preserve the existing product style (`now` / `5m` /
  /// `2h` / `3d` / date) rather than introducing a new dialect.
  static String humanize(ProductTime time, {TemporalStyle style = TemporalStyle.phrase}) {
    if (style == TemporalStyle.semantic) {
      final base = humanize(time, style: TemporalStyle.phrase);
      return '${time.event.verb} $base';
    }

    final now = _now();
    final local = time.local;
    final diff = now.difference(local);

    // Forward-looking events read as upcoming, never as "0 minutes ago".
    if (diff.isNegative) {
      final ahead = local.difference(now);
      if (time.event.isFuture || ahead.inMinutes >= 1) {
        return _future(local, ahead, style);
      }
      return style == TemporalStyle.compact ? 'now' : 'just now';
    }

    if (diff.inSeconds < 60) {
      return style == TemporalStyle.compact ? 'now' : 'just now';
    }
    if (diff.inMinutes < 60) {
      final m = diff.inMinutes;
      return style == TemporalStyle.compact
          ? '${m}m'
          : '$m ${m == 1 ? 'minute' : 'minutes'} ago';
    }
    if (diff.inHours < 24) {
      final h = diff.inHours;
      return style == TemporalStyle.compact
          ? '${h}h'
          : '$h ${h == 1 ? 'hour' : 'hours'} ago';
    }
    if (diff.inDays < 7) {
      final d = diff.inDays;
      return style == TemporalStyle.compact
          ? '${d}d'
          : '$d ${d == 1 ? 'day' : 'days'} ago';
    }
    return _date(local);
  }

  static String _future(DateTime local, Duration ahead, TemporalStyle style) {
    if (ahead.inMinutes < 60) {
      final m = ahead.inMinutes < 1 ? 1 : ahead.inMinutes;
      return style == TemporalStyle.compact
          ? 'in ${m}m'
          : 'in $m ${m == 1 ? 'minute' : 'minutes'}';
    }
    if (ahead.inHours < 24) {
      final h = ahead.inHours;
      return style == TemporalStyle.compact
          ? 'in ${h}h'
          : 'in $h ${h == 1 ? 'hour' : 'hours'}';
    }
    return _date(local);
  }

  /// Calendar-aware label: `Today, 7:42 PM` / `Yesterday, 9:16 AM` / `Aug 12`.
  ///
  /// Uses **local calendar days**, not elapsed hours, so 23:50 -> 00:10 reads
  /// as "Yesterday" rather than "0 hours ago".
  static String calendar(ProductTime time) {
    final now = _now();
    final local = time.local;
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(local.year, local.month, local.day);
    final dayDelta = today.difference(that).inDays;

    if (dayDelta == 0) return 'Today, ${_clock(local)}';
    if (dayDelta == 1) return 'Yesterday, ${_clock(local)}';
    if (dayDelta == -1) return 'Tomorrow, ${_clock(local)}';
    return _date(local);
  }

  /// Exact timestamp — always available, never lost to humanization.
  static String absolute(ProductTime time) {
    final l = time.local;
    return '${_date(l)}, ${_clock(l)}';
  }

  static String _date(DateTime l) {
    final now = _now();
    final month = _months[l.month - 1];
    return l.year == now.year ? '$month ${l.day}' : '$month ${l.day}, ${l.year}';
  }

  static String _clock(DateTime l) {
    final h24 = l.hour;
    final suffix = h24 >= 12 ? 'PM' : 'AM';
    var h = h24 % 12;
    if (h == 0) h = 12;
    final m = l.minute.toString().padLeft(2, '0');
    return '$h:$m $suffix';
  }

  /// How often a humanized label must be recomputed to stay truthful.
  ///
  /// Prevents both failure modes named in the freeze: a stale `5 min ago`
  /// that never refreshed, and needless high-frequency client work.
  /// Returns null when the label is stable (dates do not age).
  static Duration? refreshInterval(ProductTime time) {
    final diff = _now().difference(time.local).abs();
    if (diff.inMinutes < 1) return const Duration(seconds: 15);
    if (diff.inHours < 1) return const Duration(minutes: 1);
    if (diff.inDays < 7) return const Duration(minutes: 30);
    return null;
  }

  // ── SORTING SEMANTICS ────────────────────────────────────────────────────

  /// Newest-first ordering **by the declared event**.
  ///
  /// Callers must state which event orders the list, which is what stops a
  /// feed being reordered by an invisible `updatedAt` metadata change.
  static int newestFirst(ProductTime a, ProductTime b) {
    assert(
      a.event == b.event,
      'Sorting mixes ${a.event} with ${b.event}. A list must be ordered by ONE '
      'declared event semantic (Human Temporal Presentation Authority).',
    );
    return b.instant.compareTo(a.instant);
  }

  /// Oldest-first ordering by the declared event.
  static int oldestFirst(ProductTime a, ProductTime b) => -newestFirst(a, b);

  /// Sort a list by a declared event, newest first.
  ///
  /// `orderedBy` documents the human question the order answers — e.g.
  /// *"latest meaningful conversation activity"*. It is required so a sort
  /// cannot be added without stating its semantics.
  static List<T> sortNewestFirst<T>(
    List<T> items,
    ProductTime Function(T) timeOf, {
    required String orderedBy,
  }) {
    assert(orderedBy.trim().isNotEmpty, 'Declare what this ordering means.');
    final copy = [...items];
    copy.sort((a, b) => timeOf(b).instant.compareTo(timeOf(a).instant));
    return copy;
  }
}
