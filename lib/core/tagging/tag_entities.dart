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

  TagReference toReference({
    String? sourceText,
    int? startOffset,
    int? endOffset,
  }) => TagReference(
    kind: kind,
    canonicalId: canonicalId,
    entityId: canonicalId,
    display: display,
    insertText: insertText,
    sourceText: sourceText ?? insertText,
    startOffset: startOffset,
    endOffset: endOffset,
    identity: TagIdentity(
      id: canonicalId,
      type: kind.name,
      displayLabel: display,
      imageUrl: imageUrl,
    ),
  );
}

class TagIdentity {
  const TagIdentity({
    required this.id,
    required this.type,
    required this.displayLabel,
    this.handleOrSlug,
    this.imageUrl,
    this.route,
    this.status,
  });

  final String id;
  final String type;
  final String displayLabel;
  final String? handleOrSlug;
  final String? imageUrl;
  final String? route;
  final String? status;

  factory TagIdentity.fromJson(Map<String, dynamic> json) {
    return TagIdentity(
      id: (json['id'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      displayLabel: (json['displayLabel'] ?? json['name'] ?? '').toString(),
      handleOrSlug: json['handleOrSlug']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
      route: json['route']?.toString(),
      status: json['status']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'type': type,
    'displayLabel': displayLabel,
    if ((handleOrSlug ?? '').isNotEmpty) 'handleOrSlug': handleOrSlug,
    if ((imageUrl ?? '').isNotEmpty) 'imageUrl': imageUrl,
    if ((route ?? '').isNotEmpty) 'route': route,
    if ((status ?? '').isNotEmpty) 'status': status,
  };
}

/// Structured record of an inserted governed tag. The composer still stores
/// plain text in the field; this companion record lets publish/update payloads
/// carry the canonical entity chosen by autocomplete.
class TagReference {
  const TagReference({
    required this.kind,
    required this.canonicalId,
    required this.display,
    required this.insertText,
    this.entityId,
    this.sourceText,
    this.startOffset,
    this.endOffset,
    this.identity,
  });

  final TagKind kind;
  final String canonicalId;
  final String? entityId;
  final String display;
  final String insertText;
  final String? sourceText;
  final int? startOffset;
  final int? endOffset;
  final TagIdentity? identity;

  bool get isMention => kind == TagKind.member || kind == TagKind.institution;

  String get durableEntityId => (entityId ?? canonicalId).trim();

  String get durableSourceText {
    final source = (sourceText ?? '').trim();
    if (source.isNotEmpty) return source;
    return insertText.trim();
  }

  String get displayLabel {
    final resolved = (identity?.displayLabel ?? '').trim();
    if (resolved.isNotEmpty) return resolved;
    return display.trim();
  }

  String get displayToken {
    final label = displayLabel.trim();
    if (label.isEmpty) return durableSourceText;
    return '@$label';
  }

  TagReference withSourceText(String value, {int? start, int? end}) {
    return TagReference(
      kind: kind,
      canonicalId: canonicalId,
      entityId: entityId,
      display: display,
      insertText: value,
      sourceText: value,
      startOffset: start,
      endOffset: end,
      identity: identity,
    );
  }

  factory TagReference.fromJson(Map<String, dynamic> json) {
    final rawKind = (json['kind'] ?? '').toString().toLowerCase();
    final kind = rawKind == 'institution'
        ? TagKind.institution
        : rawKind == 'topic'
        ? TagKind.topic
        : TagKind.member;
    final identityJson = json['identity'];
    final identity = identityJson is Map
        ? TagIdentity.fromJson(Map<String, dynamic>.from(identityJson))
        : null;
    final entityId =
        (json['entityId'] ?? json['id'] ?? json['canonicalId'] ?? '')
            .toString();
    final sourceText = (json['sourceText'] ?? json['insertText'] ?? '')
        .toString();
    final label =
        (json['displayLabel'] ??
                json['display'] ??
                identity?.displayLabel ??
                '')
            .toString();
    return TagReference(
      kind: kind,
      canonicalId: entityId,
      entityId: entityId,
      display: label,
      insertText: sourceText,
      sourceText: sourceText,
      startOffset: _readInt(json['startOffset']),
      endOffset: _readInt(json['endOffset']),
      identity: identity,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'kind': kind.name,
    'id': durableEntityId,
    'canonicalId': durableEntityId,
    'entityId': durableEntityId,
    'display': displayLabel,
    'displayLabel': displayLabel,
    'insertText': durableSourceText,
    'sourceText': durableSourceText,
    if (startOffset != null) 'startOffset': startOffset,
    if (endOffset != null) 'endOffset': endOffset,
    if (identity != null) 'identity': identity!.toJson(),
  };
}

int? _readInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse((value ?? '').toString());
}
