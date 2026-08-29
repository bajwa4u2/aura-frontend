/// WHERE CONTENT GOES INSIDE AURA.
///
/// Deliberately NOT `DestinationCapability`, and the separation is the point.
/// They answer different questions and must not be allowed to blur:
///
///   AuraDestination        where this content lives in Aura — Feed, a
///                          Conversation. Always available; a person can
///                          always publish to their own feed or send to
///                          somebody. It has no tokens, no OAuth, no provider.
///
///   DestinationCapability  whether an EXTERNAL provider will accept it —
///                          LinkedIn, TikTok. Availability depends on
///                          connections we do not own and cannot guarantee.
///
/// Collapsing the two is how external provider health starts deciding whether
/// Aura content is publishable. The ordering is fixed: create valid Aura
/// content, choose an Aura destination, and only then offer optional external
/// distribution. A provider being down must never make a photograph
/// unshareable to a friend.
library;

/// The Aura surfaces a composition can be sent to.
enum AuraDestinationKind {
  /// The author's own feed — a post.
  feed,

  /// One conversation — a message.
  conversation,
}

/// A chosen destination, with whatever that choice needs to be actionable.
class AuraDestination {
  const AuraDestination._({
    required this.kind,
    this.conversationId,
    this.conversationTitle,
  });

  /// Publish to the feed as a post.
  const AuraDestination.feed() : this._(kind: AuraDestinationKind.feed);

  /// Send into one conversation.
  const AuraDestination.conversation({
    required String id,
    String? title,
  }) : this._(
          kind: AuraDestinationKind.conversation,
          conversationId: id,
          conversationTitle: title,
        );

  final AuraDestinationKind kind;

  /// Which conversation. Meaningless for [AuraDestinationKind.feed], and the
  /// reason a destination is a small object rather than a bare enum: the
  /// choice carries what acting on it requires.
  final String? conversationId;
  final String? conversationTitle;

  bool get isFeed => kind == AuraDestinationKind.feed;
  bool get isConversation => kind == AuraDestinationKind.conversation;

  /// Is this choice complete enough to act on?
  ///
  /// A conversation destination without an id is a half-made decision, and
  /// publishing on one would be a silent no-op.
  bool get isActionable =>
      isFeed || (conversationId ?? '').trim().isNotEmpty;

  String get label => switch (kind) {
        AuraDestinationKind.feed => 'Your feed',
        AuraDestinationKind.conversation =>
          (conversationTitle ?? '').trim().isEmpty
              ? 'A conversation'
              : conversationTitle!.trim(),
      };

  /// What sending here is called, in the words the destination already uses.
  ///
  /// A post is published; a message is sent. Using one verb for both would
  /// make one of the two surfaces read as somebody else's product.
  String get actionVerb => switch (kind) {
        AuraDestinationKind.feed => 'Publish',
        AuraDestinationKind.conversation => 'Send',
      };
}
