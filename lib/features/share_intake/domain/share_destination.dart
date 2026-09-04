import '../../../core/authority/capability_projection.dart';

/// WHERE A SHARE MAY GO, AND UNDER WHAT AUTHORITY.
///
/// Every destination Aura offers is a place a publication already exists in
/// the product. A share does not create a new kind of place and must not
/// invent one — the whole point of routing an OS payload through here is that
/// it lands somewhere with the same rules as anything else published there.
enum ShareDestinationKind {
  /// A private exchange with one Person or a small group.
  conversation,

  /// A membership-scoped container.
  space,

  /// A public statement, visible to anyone.
  publicPost,
}

extension ShareDestinationKindMeaning on ShareDestinationKind {
  /// Product vocabulary, frozen in C0. Never "chat", never "group", never
  /// "upload".
  String get label => switch (this) {
        ShareDestinationKind.conversation => 'Conversation',
        ShareDestinationKind.space => 'Space',
        ShareDestinationKind.publicPost => 'Public post',
      };

  /// What actually happens if the person confirms. Said plainly, because the
  /// difference between these three is the difference between a message and a
  /// public statement.
  String get consequence => switch (this) {
        ShareDestinationKind.conversation =>
          'Sent to the people in this conversation.',
        ShareDestinationKind.space => 'Posted to everyone in this Space.',
        ShareDestinationKind.publicPost =>
          'Published publicly, where anyone can read it.',
      };

  /// Whether reaching this destination is a public act. Drives the extra
  /// confirmation, and nothing else may be used to decide that.
  bool get isPublic => this == ShareDestinationKind.publicPost;

  /// THE ACT THIS DESTINATION WOULD PERFORM.
  ///
  /// The single line that keeps share intake inside the existing authority
  /// model rather than beside it. "Who may I publish this as" is not a
  /// question share intake is allowed to answer — it names the act, and
  /// `ActingContextAuthority` (C1) answers it with the same options the
  /// ordinary composer for that destination would get.
  ///
  /// A share sheet is therefore incapable of producing an acting identity that
  /// the person could not already use for the same act in the app.
  ConsequentialAct get act => switch (this) {
        ShareDestinationKind.conversation => ConsequentialAct.sendDirectMessage,
        // A member posting into a Space posts as themselves. An institution
        // speaking in its own Space is `publishInstitutionPost`, and it is the
        // destination that says so — see [ShareDestination.act].
        ShareDestinationKind.space => ConsequentialAct.publishPersonalPost,
        ShareDestinationKind.publicPost => ConsequentialAct.publishPersonalPost,
      };
}

/// ONE OFFERED DESTINATION.
///
/// Constructed only from destinations the person demonstrably has, never from
/// a "recently used" list. Inferring a destination is how a photograph meant
/// for one person reaches everyone.
class ShareDestination {
  const ShareDestination({
    required this.kind,
    required this.id,
    required this.title,
    this.subtitle,
    this.institutionId,
    this.available = true,
    this.unavailableReason,
  });

  final ShareDestinationKind kind;

  /// The conversation or Space id. Empty for a public post, which needs none.
  final String id;

  final String title;
  final String? subtitle;

  /// Set when this destination belongs to an institution, which changes the
  /// act and therefore the identities the authority will offer.
  final String? institutionId;

  /// False when the person can see the destination but may not publish into
  /// it. Shown rather than hidden: a destination that silently disappears
  /// looks like a bug, and a refusal nobody can see is indistinguishable from
  /// a broken button.
  final bool available;

  /// Why not. Required whenever [available] is false — every gate has words.
  final String? unavailableReason;

  bool get isPublic => kind.isPublic;

  /// The act confirming this destination would perform, institution-aware.
  ///
  /// Asked of the C1 authority, never decided here. Note what does NOT appear
  /// in this expression: the route, the platform the share came from, and
  /// anything the person did last time.
  ConsequentialAct get act {
    if (institutionId == null) return kind.act;
    return switch (kind) {
      ShareDestinationKind.conversation =>
        ConsequentialAct.correspondAsInstitution,
      ShareDestinationKind.space ||
      ShareDestinationKind.publicPost =>
        ConsequentialAct.publishInstitutionPost,
    };
  }
}
