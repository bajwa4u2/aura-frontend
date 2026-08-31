/// THE OPERATOR STATE MODEL.
///
/// The reconstruction's first version let a failed dependency become a
/// business fact. A worklist read failure emptied NOW's attention section, a
/// health payload the client could not parse became "5 services degraded" over
/// a healthy platform, and a section whose source failed simply disappeared
/// from a subject page with nothing said.
///
/// Those are three shapes of one mistake: the console had no vocabulary for
/// the difference between *not knowing* and *knowing something bad*.
///
/// This is that vocabulary, and it is deliberately small enough that every
/// surface can use all of it:
///
///   UNKNOWN      is not DEGRADED — nothing has told us.
///   UNAVAILABLE  is not FAILED   — we could not ask.
///   PARTIAL      is not COMPLETE — we asked, some answered.
///   EMPTY        is not UNKNOWN  — we asked, the answer is nothing.
///
/// Nothing here decides anything about Aura. It decides what the console is
/// entitled to claim.
library;

/// How much an operator may trust what they are looking at.
///
/// This describes the READING, not the subject. A perfectly healthy platform
/// read through a broken connection is [OperatorReach.unavailable]; a platform
/// on fire read successfully is [OperatorReach.complete].
enum OperatorReach {
  /// The answer has not arrived yet. Never rendered as a result.
  pending,

  /// Every source answered. The value can be reported as fact.
  complete,

  /// Some sources answered and some did not. The value is REAL but not TOTAL,
  /// and the surface must say which parts are missing — a partial total shown
  /// as a total is the most dangerous state in an operator console.
  partial,

  /// The value is real but was read some time ago and could not be refreshed.
  stale,

  /// Nothing could be read. This is NOT an empty result and must never be
  /// rendered as one.
  unavailable,

  /// The operator holds no capability for this. A different fact from
  /// unavailable: nothing is broken, and nothing will be by retrying.
  unauthorized,
}

extension OperatorReachFacts on OperatorReach {
  /// Whether a value exists at all. `partial` and `stale` DO carry a value.
  bool get hasValue =>
      this == OperatorReach.complete ||
      this == OperatorReach.partial ||
      this == OperatorReach.stale;

  /// Whether the operator should be told something about the reading itself.
  bool get needsDisclosure =>
      this == OperatorReach.partial ||
      this == OperatorReach.stale ||
      this == OperatorReach.unavailable;

  /// Whether trying again could change the answer. Retrying an authorization
  /// refusal only produces the same refusal.
  bool get isRetryable =>
      this == OperatorReach.unavailable || this == OperatorReach.stale;
}

/// What is true about the thing being described.
///
/// Separate from [OperatorReach] on purpose. "We cannot tell" is a fact about
/// the reading; "it is degraded" is a fact about Aura. Collapsing them is
/// exactly how a healthy platform came to be reported as five services down.
enum OperatorCondition {
  /// Working as intended.
  healthy,

  /// Working, with something a human should look at before it becomes a
  /// problem.
  attention,

  /// Working less than fully. A real, positive claim — only ever set because
  /// a source SAID so.
  degraded,

  /// Not working. Also a positive claim.
  failed,

  /// NOTHING HAS SAID. The default, and never an accusation. A source that is
  /// silent leaves its subject unknown; it does not make it degraded.
  unknown,
}

extension OperatorConditionFacts on OperatorCondition {
  /// Worst-first ordering, so a list can be sorted by what matters.
  ///
  /// `unknown` sits ABOVE healthy and BELOW degraded: not knowing is worth an
  /// operator's attention, and it is not evidence of harm.
  int get severity => switch (this) {
        OperatorCondition.failed => 4,
        OperatorCondition.degraded => 3,
        OperatorCondition.attention => 2,
        OperatorCondition.unknown => 1,
        OperatorCondition.healthy => 0,
      };

  /// Only a positive claim counts as bad news.
  bool get isAdverse =>
      this == OperatorCondition.degraded || this == OperatorCondition.failed;

  String get label => switch (this) {
        OperatorCondition.healthy => 'Healthy',
        OperatorCondition.attention => 'Needs attention',
        OperatorCondition.degraded => 'Degraded',
        OperatorCondition.failed => 'Failed',
        OperatorCondition.unknown => 'Unknown',
      };
}

/// A value, and an honest account of how well it is known.
///
/// Surfaces render an [OperatorSignal] rather than an `AsyncValue` so that
/// "some of it" and "none of it" are different pictures. `AsyncValue` has no
/// third state between data and error, which is why a partial worklist had
/// nowhere to go except into an error that erased the whole area.
class OperatorSignal<T> {
  const OperatorSignal._({
    required this.reach,
    this.value,
    this.missing = const [],
    this.detail,
    this.readAt,
  });

  const OperatorSignal.pending() : this._(reach: OperatorReach.pending);

  /// Everything answered.
  const OperatorSignal.complete(T value, {DateTime? readAt})
      : this._(reach: OperatorReach.complete, value: value, readAt: readAt);

  /// Some answered. [missing] NAMES what did not, because "partial" without
  /// naming the gap is only a softer way of hiding it.
  const OperatorSignal.partial(
    T value, {
    required List<String> missing,
    DateTime? readAt,
  }) : this._(
          reach: OperatorReach.partial,
          value: value,
          missing: missing,
          readAt: readAt,
        );

  /// Real, but older than it should be.
  const OperatorSignal.stale(T value, {DateTime? readAt, String? detail})
      : this._(
          reach: OperatorReach.stale,
          value: value,
          readAt: readAt,
          detail: detail,
        );

  /// Nothing could be read. NOT an empty result.
  const OperatorSignal.unavailable({String? detail})
      : this._(reach: OperatorReach.unavailable, detail: detail);

  /// The operator holds no capability for this.
  const OperatorSignal.unauthorized({String? needs})
      : this._(reach: OperatorReach.unauthorized, detail: needs);

  final OperatorReach reach;

  /// Present whenever [OperatorReachFacts.hasValue] — including when partial
  /// or stale, because half an answer is still an answer.
  final T? value;

  /// The sources that did not answer, named.
  final List<String> missing;

  /// Why, in words an operator reads. Never an exception's `toString()`.
  final String? detail;

  /// When the value was actually read. Drives staleness honestly rather than
  /// by guessing from a rebuild.
  final DateTime? readAt;

  bool get hasValue => reach.hasValue && value != null;

  /// The value, or a fallback. NEVER use this to paper over
  /// [OperatorReach.unavailable] — a fallback rendered as fact is the defect
  /// this class exists to prevent.
  T orElse(T fallback) => hasValue ? value as T : fallback;

  OperatorSignal<R> map<R>(R Function(T value) transform) {
    if (!hasValue) {
      return OperatorSignal<R>._(
        reach: reach,
        missing: missing,
        detail: detail,
        readAt: readAt,
      );
    }
    return OperatorSignal<R>._(
      reach: reach,
      value: transform(value as T),
      missing: missing,
      detail: detail,
      readAt: readAt,
    );
  }

  /// Builds one signal out of many, keeping the WORST reach and collecting
  /// every missing source.
  ///
  /// This is how an area with several dependencies stays up when one of them
  /// falls over: the area is partial and says so, instead of failing whole.
  static OperatorReach worstOf(Iterable<OperatorReach> reaches) {
    var worst = OperatorReach.complete;
    var sawValue = false;
    for (final reach in reaches) {
      if (reach.hasValue) sawValue = true;
      worst = _rank(reach) > _rank(worst) ? reach : worst;
    }
    // Something answered, so the whole is PARTIAL rather than unavailable —
    // the distinction the first reconstruction had no way to express.
    if (sawValue &&
        (worst == OperatorReach.unavailable ||
            worst == OperatorReach.unauthorized)) {
      return OperatorReach.partial;
    }
    return worst;
  }

  static int _rank(OperatorReach reach) => switch (reach) {
        OperatorReach.complete => 0,
        OperatorReach.stale => 1,
        OperatorReach.partial => 2,
        OperatorReach.pending => 3,
        OperatorReach.unauthorized => 4,
        OperatorReach.unavailable => 5,
      };

  @override
  String toString() => 'OperatorSignal($reach, missing: $missing)';
}
