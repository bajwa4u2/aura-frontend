/// WHAT COUNTS AS A NOTIFICATION *ARRIVING*.
///
/// This existed as private state inside `NotificationBridge`, which is why the
/// defect it now prevents was never testable and shipped for months: entering
/// Aura or refreshing replayed old attention through the global floating
/// overlay as though it had just happened.
///
/// The mechanism was a baseline that could never be established. The bridge
/// seeded its seen-set from whatever the controller already held, but at cold
/// start the controller holds nothing — so the baseline was EMPTY, and the
/// first successful fetch looked like thirty notifications arriving at once.
///
/// The rule this authority encodes:
///
///   The first successful load of a session is HISTORY, not arrival.
///
/// A notification that was sitting on the server before the app opened is not
/// a newly-arriving event. That is a determinism statement, not a presentation
/// preference — and suppressing its *presentation* hides nothing: the row stays
/// in the list, in the unread count, and in the badge.
///
/// Genuine arrivals — anything first seen after that baseline — are still
/// presented, which is the half that must survive.
class NotificationArrivalGate {
  final Set<String> _seen = <String>{};
  bool _baselineEstablished = false;

  /// Whether this session has learned what already existed.
  bool get baselineEstablished => _baselineEstablished;

  /// Ends the session's memory. The next session must establish its own
  /// baseline rather than inheriting one from a signed-out account.
  void reset() {
    _seen.clear();
    _baselineEstablished = false;
  }

  /// Record an already-present set as history without presenting any of it.
  ///
  /// Used when the bridge mounts on top of a controller that is already
  /// populated: those notifications existed before this widget did.
  void establishBaseline(Iterable<String> ids) {
    if (_baselineEstablished) return;
    _baselineEstablished = true;
    _seen.addAll(ids);
  }

  /// Given the previous and next id lists, return the ids that are genuinely
  /// NEW ARRIVALS and should be presented.
  ///
  /// `previousIds` is honoured for the same reason the bridge always did:
  /// an id already visible in the prior snapshot is a re-render, not an
  /// arrival, even if this gate has not recorded it yet.
  List<String> admit({
    required Iterable<String> previousIds,
    required Iterable<String> nextIds,
  }) {
    final next = nextIds.toList(growable: false);
    if (next.isEmpty) return const <String>[];

    if (!_baselineEstablished) {
      establishBaseline(next);
      return const <String>[];
    }

    final previous = previousIds.toSet();
    final admitted = <String>[];
    for (final id in next) {
      if (_seen.contains(id)) continue;
      _seen.add(id);
      if (previous.contains(id)) continue;
      admitted.add(id);
    }
    return admitted;
  }
}
