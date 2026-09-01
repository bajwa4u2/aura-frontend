/// WHAT MAKES A READING STALE, AND WHAT DOES NOT.
///
/// `OperatorReach.stale` was in the vocabulary from the beginning, with a
/// precise definition — *the value is real but was read some time ago and could
/// not be refreshed*. Nothing ever produced it. Every authority that failed to
/// refresh threw away the reading it already held and reported `unavailable`,
/// so an operator watching a live console lost the last known state at exactly
/// the moment the network got worse, and was shown a read failure instead of
/// the answer from ninety seconds ago.
///
/// This is the missing half: somewhere to keep the last good reading, so a
/// failed refresh can be honest rather than blank.
///
/// THREE REFUSALS, EACH DELIBERATE.
///
///  1. **Staleness is not a clock threshold.** Nothing here decides that a
///     reading has "gone off" after N minutes. Aura's authorities do not
///     publish a freshness contract, and inventing one would mean the console
///     asserting something no source told it. A reading becomes stale when a
///     REFRESH FAILED — an event, not an age.
///
///  2. **`updatedAt` is not a reading time.** WORK, SUBJECTS, INTEGRITY and
///     RECORD carry `updatedAt` on their rows, which says when the SUBJECT
///     changed. Only health states `checkedAt`, discovery states a per-source
///     `lastFetchedAt`, and media retention states its `lastRun`. Treating a
///     subject's edit time as a reading time would report a person last edited
///     in March as a stale reading of that person, which is nonsense.
///
///  3. **Never-run and unavailable are not stale.** A media pass that has never
///     run is empty. A discovery source Aura holds no credential for is
///     unavailable by configuration, and a provider that reports zero is
///     reporting a result. None of those becomes stale, and none of them
///     acquires an age, because staleness requires a previous reading to have
///     existed.
library;

/// A reading that succeeded, kept only so its successor can fail honestly.
///
/// Deliberately not a cache. Nothing reads this to avoid a request; the only
/// reader is the failure path of the request that would have replaced it.
class OperatorReading<T> {
  const OperatorReading(this.value, this.readAt);

  final T value;

  /// When this reading was taken — the client's own observation moment, not a
  /// timestamp from inside the payload. It answers "how old is what I am
  /// looking at", which is the question a stale banner has to answer.
  final DateTime readAt;
}

/// Per-container memory of the last good reading for each authority.
///
/// Scoped to the `ProviderContainer` rather than held statically, so a test
/// starts with no memory and one test cannot leak a previous reading into the
/// next. That matters more than it sounds: a leaked reading would let a
/// deliberately-failing case render a stale value it was never given, and the
/// test would pass for the wrong reason.
class OperatorReadingMemory {
  final _readings = <String, OperatorReading<Object?>>{};

  /// Remember a successful reading. Called only on the success path.
  void remember<T>(String authority, T value, DateTime readAt) {
    _readings[authority] = OperatorReading<Object?>(value, readAt);
  }

  /// The last good reading for an authority, or null when there has never been
  /// one. Null is the honest answer for a console opened cold into a failure:
  /// there is nothing old to show, so the surface must say it could not read
  /// rather than pretend to a history it does not have.
  OperatorReading<T>? recall<T>(String authority) {
    final held = _readings[authority];
    if (held == null) return null;
    final value = held.value;
    if (value is! T) return null;
    return OperatorReading<T>(value, held.readAt);
  }

  /// Forget everything. Used when authority changes — a reading taken as one
  /// operator must never be shown to another, stale or otherwise.
  void forget() => _readings.clear();
}

/// The reading keys used as memory slots.
///
/// Named constants rather than free strings so a typo cannot silently create a
/// second, permanently-empty memory that makes an authority look as though it
/// has never had a good reading.
abstract final class OperatorReadingKey {
  static const health = 'health';
  static const work = 'work';
  static const discoveryCoverage = 'discovery.coverage';
  static const mediaRetention = 'media.retention';
}
