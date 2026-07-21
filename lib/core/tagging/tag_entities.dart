/// AXR-1 — Universal Governed Tagging: entity model.
///
/// One tagging vocabulary for the whole platform. A [TagKind] describes a
/// governed entity class that can be referenced from any text surface
/// (posts, comments, replies, messages, announcements, meeting notes,
/// Studio-generated content, future editors). Adding a new entity kind is
/// an enum case + a suggest source — no redesign of the field, overlay,
/// or rendering layers.
library;

/// Governed entity classes addressable from text.
enum TagKind {
  /// A verified member — sigil `@`, canonical reference is the handle
  /// (the platform's existing public identity key, resolved to userId
  /// server-side at publish time by the mention fanout).
  member,

  /// A verified institution — sigil `@`, canonical reference is the slug.
  institution,

  /// A governed content topic — sigil `#`, canonical reference is the
  /// closed-taxonomy wire token (see `features/topics/topic.dart`).
  topic;

  /// The sigil character that invokes this kind in a composer.
  String get sigil {
    switch (this) {
      case TagKind.member:
      case TagKind.institution:
        return '@';
      case TagKind.topic:
        return '#';
    }
  }
}

/// A single ranked suggestion offered by the governed autocomplete.
class TagSuggestion {
  const TagSuggestion({
    required this.kind,
    required this.canonicalId,
    required this.display,
    required this.insertText,
    this.subtitle,
    this.imageUrl,
  });

  final TagKind kind;

  /// Stable internal identifier (userId / institutionId / topic wire
  /// token). Persisted by surfaces that keep structured entity records;
  /// the inserted text form carries the public canonical reference.
  final String canonicalId;

  /// Human-readable name shown in the suggestion row and rendered after
  /// selection.
  final String display;

  /// Exactly what selection inserts into the text (including sigil),
  /// e.g. `@msbajwa`, `@aura-platform`, `#Technology`.
  final String insertText;

  /// Secondary line for the suggestion row (e.g. `@handle`, jurisdiction).
  final String? subtitle;

  /// Avatar / logo for the suggestion row, when the entity has one.
  final String? imageUrl;
}
