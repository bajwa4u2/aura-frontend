/// WHAT A DISTRIBUTION DESTINATION IS ALLOWED TO SAY ABOUT ITSELF.
///
/// THE DEFECT THIS EXISTS TO END (founder, 2026-08-29): "sometimes TikTok
/// appears; LinkedIn can disappear entirely; destination presence/absence does
/// not feel deterministic."
///
/// It was not random. The composer resolved both destinations like this:
///
///     final results = await Future.wait([
///       _safeGet(dio, '/integrations/tiktok/account'),
///       _safeGet(dio, '/integrations/linkedin/account'),
///     ]);
///     // _safeGet: catch (_) { return null; }
///
/// and then reduced each answer to a single boolean, `connected`. A swallowed
/// error is indistinguishable from a considered "no", so a dropped request, an
/// expired token, a 500 and a genuinely unconnected account ALL collapsed into
/// the same false -- and the destination silently vanished. Whether it appeared
/// depended on whether a transient GET happened to succeed, which is exactly
/// what "feels random" means.
///
/// A BOOLEAN CANNOT CARRY THIS QUESTION. "Can I publish here?" has more than
/// two answers, and the useful ones are different actions: connect, reconnect,
/// wait, or nothing at all. Collapsing them loses the only part the person can
/// act on.
///
/// Silence remains correct for exactly one case -- a destination that has no
/// place on this surface at all. Everything else says what it is.
library;

/// What a destination currently is, for one composition.
enum DestinationState {
  /// Connected, authorised, and the content suits it. Offer it.
  available,

  /// Never connected. The action is "Connect", not absence.
  connectRequired,

  /// Was connected; the authorisation is no longer good. The action is
  /// "Reconnect" -- the single case the old boolean handled worst, because a
  /// token expiring made a destination the person had deliberately set up
  /// disappear without explanation.
  reconnectRequired,

  /// Connected, but this composition cannot go there -- a photo to a
  /// video-only destination, an empty draft, an unsupported combination.
  unsupportedContent,

  /// Connected and willing, but not from this platform build.
  unsupportedPlatform,

  /// The account itself is not eligible (provider-side restriction).
  accountNotEligible,

  /// We could not find out. NOT the same as "no" -- this is the state the old
  /// code silently spent on every network hiccup.
  temporarilyUnavailable,

  /// Genuinely has no place on this surface. The only state that may be
  /// invisible.
  notOffered,
}

/// One destination, resolved for one composition.
class DestinationCapability {
  const DestinationCapability({
    required this.id,
    required this.label,
    required this.state,
    this.accountLabel = '',
    this.detail,
  });

  final String id;
  final String label;
  final DestinationState state;

  /// The connected account, when there is one worth naming.
  final String accountLabel;

  /// Why, when the reason is worth showing. Never a raw exception.
  final String? detail;

  /// May the person publish here right now?
  bool get isPublishable => state == DestinationState.available;

  /// Should this destination be drawn at all?
  ///
  /// Everything except [DestinationState.notOffered]. A destination the person
  /// connected does not disappear because a request failed -- it says so.
  bool get isVisible => state != DestinationState.notOffered;

  /// Is there something the person can do to make it publishable?
  bool get hasRecoveryAction =>
      state == DestinationState.connectRequired ||
      state == DestinationState.reconnectRequired;

  /// The action word, when there is an action.
  String? get actionLabel => switch (state) {
        DestinationState.connectRequired => 'Connect',
        DestinationState.reconnectRequired => 'Reconnect',
        DestinationState.temporarilyUnavailable => 'Retry',
        _ => null,
      };

  /// What to say about this destination, in a person's words.
  String get statusLine => switch (state) {
        DestinationState.available =>
          accountLabel.isEmpty ? 'Connected' : accountLabel,
        DestinationState.connectRequired => 'Not connected',
        DestinationState.reconnectRequired =>
          'Sign in again to keep sharing here',
        DestinationState.unsupportedContent =>
          detail ?? 'This post cannot be shared here',
        DestinationState.unsupportedPlatform => 'Not available on this device',
        DestinationState.accountNotEligible =>
          detail ?? 'This account cannot publish here',
        DestinationState.temporarilyUnavailable => 'Could not check right now',
        DestinationState.notOffered => '',
      };

  DestinationCapability copyWith({
    DestinationState? state,
    String? accountLabel,
    String? detail,
  }) =>
      DestinationCapability(
        id: id,
        label: label,
        state: state ?? this.state,
        accountLabel: accountLabel ?? this.accountLabel,
        detail: detail ?? this.detail,
      );
}

/// Turn one provider probe into a state.
///
/// The probe reports what happened -- succeeded, refused authorisation, failed
/// to answer -- and this decides what that MEANS. Keeping the two apart is the
/// point: the old code did the deciding inside a `catch (_)`, where the only
/// available answer was "no".
DestinationState destinationStateFromProbe({
  required bool reachable,
  required bool connected,
  required bool authorisationValid,
  bool contentSupported = true,
  bool platformSupported = true,
  bool accountEligible = true,
}) {
  // Could not ask. Says so, rather than answering for the provider.
  if (!reachable) return DestinationState.temporarilyUnavailable;
  if (!platformSupported) return DestinationState.unsupportedPlatform;
  if (!connected) return DestinationState.connectRequired;
  // Connected but the token is no longer good: the case that used to make a
  // deliberately connected destination vanish.
  if (!authorisationValid) return DestinationState.reconnectRequired;
  if (!accountEligible) return DestinationState.accountNotEligible;
  if (!contentSupported) return DestinationState.unsupportedContent;
  return DestinationState.available;
}
