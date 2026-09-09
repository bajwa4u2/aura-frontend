import 'call_state.dart';
import 'realtime_models.dart';

/// ONE CALL THAT HAPPENED, DESCRIBED FOR THE PERSON WHO WAS IN IT.
///
/// A CONSUMER OF CALL TRUTH, NEVER A SECOND SOURCE OF IT. Everything here is
/// read from the canonical `Call` the backend already projects onto the
/// session snapshot — phase, outcome, the four timestamps, the participant
/// roles. Nothing is derived that the server has not already decided, and
/// nothing is written back. There is no second lifecycle writer and no second
/// outcome engine; if a fact is not in the projection, this surface does not
/// claim it.
///
/// Why it exists: Call History used to open the CONVERSATION. That answered a
/// different question — "what have we said to each other" — when the person
/// had asked "what happened on that call". The conversation is real context,
/// but it is secondary, and it is reachable from here.
class CallOccurrence {
  const CallOccurrence({
    required this.sessionId,
    required this.call,
    required this.viewerUserId,
    required this.participants,
    this.conversationId,
    this.title,
  });

  final String sessionId;
  final CallState call;
  final String viewerUserId;

  /// Roster identities, for names. The call projection carries user ids and
  /// roles; the session roster carries who those ids are.
  final List<RealtimeParticipant> participants;

  /// The owning Conversation, when this call belonged to one. Secondary
  /// navigation — never where a history tap lands first.
  final String? conversationId;

  final String? title;

  bool get isVideo => call.isVideo;

  /// Whether the viewer placed this call. Read from the canonical initiator,
  /// not from who happens to be looking.
  bool get viewerIsCaller => call.isCaller(viewerUserId);

  /// THE OTHER PERSON, when there is exactly one.
  ///
  /// A two-party call is the case a history row is really about. Anything
  /// larger is described by its participant list instead of by a name, rather
  /// than picking one arbitrarily and calling it "the call with X".
  RealtimeParticipant? get counterpart {
    final others = participants
        .where((p) => p.userId.trim().isNotEmpty && p.userId != viewerUserId)
        .toList(growable: false);
    return others.length == 1 ? others.first : null;
  }

  /// Was anyone's phone actually rung?
  ///
  /// `ringPresentedAt` is written when a real endpoint reported alerting a
  /// real person. Its ABSENCE is meaningful — it is the difference between a
  /// call somebody ignored and a call that never reached them — so it is shown
  /// as its own fact rather than folded into the outcome.
  bool get everRang => call.ringPresentedAt != null;

  /// Did the call ever carry media between the parties?
  bool get everConnected => call.connectedAt != null;

  /// THE ONLY DURATION.
  ///
  /// Runs from `connectedAt`, which the backend writes once, and only when a
  /// usable media path existed. A call that was declined, missed, cancelled or
  /// that never connected has NO duration — not a zero, and not the time the
  /// room was open. Showing "0:47" for a call nobody answered would be a
  /// fabrication about the person's own call.
  Duration? get duration {
    final start = call.connectedAt;
    final end = call.endedAt;
    if (start == null || end == null) return null;
    final d = end.difference(start);
    return d.isNegative ? null : d;
  }
}

/// The human sentence for an outcome, from the viewer's side of the call.
///
/// The backend's seven outcomes, humanised and NOT collapsed. The
/// distinctions the founder named are load-bearing:
///
///     NO ANSWER  !=  FAILED
///     MISSED     !=  CANCELLED
///     ENDED      !=  ABANDONED
///
/// so nothing here maps two canonical outcomes onto one sentence.
String callOutcomeHeadline({
  required CallOutcome? outcome,
  required bool viewerIsCaller,
  required bool isVideo,
}) {
  final kind = isVideo ? 'Video call' : 'Voice call';
  switch (outcome) {
    case CallOutcome.connectedEnded:
      return kind;
    case CallOutcome.declined:
      return viewerIsCaller ? '$kind declined' : '$kind you declined';
    case CallOutcome.missed:
      // Their phone rang and nobody picked up. To the caller that is "no
      // answer"; to the person whose phone rang it is a missed call. Same
      // fact, two true sentences.
      return viewerIsCaller ? '$kind — no answer' : 'Missed $kind';
    case CallOutcome.notPresented:
      // Nothing ever rang. Never "missed": that would blame someone for
      // ignoring a call their phone never announced.
      return viewerIsCaller ? '$kind — could not reach them' : 'Attempted $kind';
    case CallOutcome.canceledBeforeAnswer:
      return viewerIsCaller ? '$kind you cancelled' : '$kind cancelled';
    case CallOutcome.acceptedNotConnected:
      // Answered, and then no media path. This is the one both ends
      // experienced identically.
      return '$kind that could not connect';
    case CallOutcome.failed:
      return '$kind failed';
    case CallOutcome.unknownLegacy:
    case null:
      return kind;
  }
}

/// A short line under the headline explaining what the outcome means, where a
/// person would otherwise be left guessing. Null when the headline says it all.
String? callOutcomeExplanation({
  required CallOutcome? outcome,
  required bool viewerIsCaller,
}) {
  switch (outcome) {
    case CallOutcome.notPresented:
      return viewerIsCaller
          ? 'Their device was never reached, so it did not ring.'
          : 'This call did not reach your device.';
    case CallOutcome.acceptedNotConnected:
      return 'The call was answered, but no audio or video path was established.';
    case CallOutcome.missed:
      return viewerIsCaller ? 'It rang, and was not answered.' : null;
    case CallOutcome.failed:
      return 'The call ended because of a fault, not because anyone hung up.';
    default:
      return null;
  }
}
