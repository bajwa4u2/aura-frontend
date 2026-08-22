/// The publication classes Aura lets people engage with.
///
/// Mirrors the backend `PublicationTargetType`. Reactions and saves used to
/// belong to Post by birth order rather than by design; when institution posts
/// arrived the storage was cloned, and when articles arrived they could carry
/// neither. This is the client half of the generalisation — deliberately not
/// an Article-specific client, because an Article-specific client is how the
/// next publication type would end up without engagement again.
enum PublicationTarget {
  post,
  institutionPost,
  article,
  announcement;

  String get wireValue => switch (this) {
        PublicationTarget.post => 'POST',
        PublicationTarget.institutionPost => 'INSTITUTION_POST',
        PublicationTarget.article => 'ARTICLE',
        PublicationTarget.announcement => 'ANNOUNCEMENT',
      };
}

/// The reactions a person can express. Mirrors the backend `ReactionType`.
enum AuraReaction {
  like,
  love,
  laugh,
  sad,
  angry;

  String get wireValue => name.toUpperCase();

  /// The glyph shown in the picker and on the count row.
  String get glyph => switch (this) {
        AuraReaction.like => '\u{1F44D}',
        AuraReaction.love => '\u{2764}\u{FE0F}',
        AuraReaction.laugh => '\u{1F602}',
        AuraReaction.sad => '\u{1F622}',
        AuraReaction.angry => '\u{1F620}',
      };

  String get label => switch (this) {
        AuraReaction.like => 'Like',
        AuraReaction.love => 'Love',
        AuraReaction.laugh => 'Funny',
        AuraReaction.sad => 'Sad',
        AuraReaction.angry => 'Angry',
      };

  static AuraReaction? fromWire(String? v) {
    if (v == null) return null;
    for (final r in AuraReaction.values) {
      if (r.wireValue == v.trim().toUpperCase()) return r;
    }
    return null;
  }
}

/// Engagement state for one publication, as this actor sees it.
class EngagementState {
  const EngagementState({
    this.myReaction,
    this.count = 0,
    this.breakdown = const {},
    this.saved = false,
  });

  final AuraReaction? myReaction;
  final int count;
  final Map<AuraReaction, int> breakdown;
  final bool saved;

  EngagementState copyWith({
    AuraReaction? myReaction,
    bool clearReaction = false,
    int? count,
    Map<AuraReaction, int>? breakdown,
    bool? saved,
  }) =>
      EngagementState(
        myReaction: clearReaction ? null : (myReaction ?? this.myReaction),
        count: count ?? this.count,
        breakdown: breakdown ?? this.breakdown,
        saved: saved ?? this.saved,
      );
}
