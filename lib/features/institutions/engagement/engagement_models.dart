import '../../../core/identity/person_identity_model.dart';
import '../../topics/topic.dart';

enum RoutedRecordStatus {
  pending,
  responded,
  committed,
  resolved;

  String get label {
    switch (this) {
      case RoutedRecordStatus.pending:
        return 'Needs Response';
      case RoutedRecordStatus.responded:
        return 'Official Response';
      case RoutedRecordStatus.committed:
        return 'Commitment';
      case RoutedRecordStatus.resolved:
        return 'Resolved';
    }
  }

  static RoutedRecordStatus fromWire(dynamic raw) {
    switch ((raw ?? '').toString().trim().toUpperCase()) {
      case 'RESPONDED':
        return RoutedRecordStatus.responded;
      case 'COMMITTED':
        return RoutedRecordStatus.committed;
      case 'RESOLVED':
        return RoutedRecordStatus.resolved;
      default:
        return RoutedRecordStatus.pending;
    }
  }
}

enum RecordIntent {
  ask,
  issue,
  shareUpdate,
  unknown;

  String get label {
    switch (this) {
      case RecordIntent.ask:
        return 'Ask';
      case RecordIntent.issue:
        return 'Raise Issue';
      case RecordIntent.shareUpdate:
        return 'Share Update';
      case RecordIntent.unknown:
        return '';
    }
  }

  static RecordIntent fromWire(dynamic raw) {
    switch ((raw ?? '').toString().trim().toUpperCase()) {
      case 'ASK':
        return RecordIntent.ask;
      case 'ISSUE':
        return RecordIntent.issue;
      case 'SHARE_UPDATE':
        return RecordIntent.shareUpdate;
      default:
        return RecordIntent.unknown;
    }
  }
}

/// A post routed to an institution for engagement.
///
/// F053/F116 — the author here used to be read as `['handle', 'handleOrSlug']`,
/// which made it look like an ACTOR UNION: `handleOrSlug` is the normalised
/// field a person's handle and an institution's slug share, so a consumer
/// holding this value could not tell which authority owned it.
///
/// The producer settles it. `InstitutionEngagementService.toDto` builds the
/// author from `row.post.author` — a User relation — selected with
/// `PERSON_REFERENCE_SELECT`, and emits `{ id, handle, displayName, avatarUrl }`.
/// There is no institution branch and `handleOrSlug` is never emitted on this
/// contract at all. The union was not lossy and it was not deliberate: it did
/// not exist. The client had invented an ambiguity the server never had, and
/// the correct repair is to stop reading a field that is never sent, not to add
/// an actorType to discriminate a union of one.
///
/// So the author is a PERSON, read by the canonical reader. No Actor model was
/// invented, and no person and institution authority was merged.
class RoutedRecord {
  const RoutedRecord({
    required this.id,
    required this.postId,
    required this.status,
    required this.intent,
    this.topic,
    this.participationMode,
    this.author = AuraPersonIdentity.unknown,
    this.postText,
    this.postCreatedAt,
  });

  final String id;
  final String postId;
  final RoutedRecordStatus status;
  final RecordIntent intent;
  final AuraTopic? topic;
  final String? participationMode;

  /// The person who wrote the routed post.
  final AuraPersonIdentity author;

  /// The author's name for a byline, or null when the producer named nobody.
  ///
  /// The ORDER is canonical — their name, then their handle. The nullability is
  /// this surface's own: both engagement screens hide the byline row when this
  /// is empty, and answering with the shared neutral word would put 'Someone'
  /// under a post instead of omitting a line nobody can fill. Naming an
  /// unresolved person stays the renderer's decision; the order is not.
  String? get authorName {
    if (author.displayName.trim().isEmpty && author.handle.trim().isEmpty) {
      return null;
    }
    return author.label;
  }

  String? get authorHandle {
    final handle = author.handle.trim();
    return handle.isEmpty ? null : handle;
  }

  /// The routed post's content.
  ///
  /// CONTRACT REPAIR 2026-08-19. This read `post['body']`, falling back to a
  /// top-level `postBody`. The producer emits neither: `Post.text` in the
  /// schema becomes `post.text` on `EngagementRecordDto`, and the client's own
  /// canonical post model (`feed/domain/post.dart`) already reads `text`. So
  /// `body` was never a second contract to be tolerant of — it was a key
  /// nothing has ever sent, and the screens guard with
  /// `if (content.isNotEmpty)`, so the post rendered as absent rather than as
  /// broken. One canonical field, no alias: `text`.
  final String? postText;

  /// When the post was WRITTEN — `post.createdAt`, not the record's `routedAt`.
  ///
  /// Same repair, same cause: this read a top-level `createdAt` the DTO does
  /// not emit. Both screens render it immediately after the author's name, so
  /// it is a byline timestamp; `routedAt` (when the post reached this
  /// institution) is a different fact and deliberately not substituted here.
  final DateTime? postCreatedAt;

  static String? _opt(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k]?.toString().trim() ?? '';
      if (v.isNotEmpty) return v;
    }
    return null;
  }

  factory RoutedRecord.fromJson(Map<String, dynamic> m) {
    DateTime? readDate(dynamic raw) {
      if (raw == null) return null;
      final s = raw.toString().trim();
      if (s.isEmpty) return null;
      return DateTime.tryParse(s);
    }

    final postRaw = m['post'] is Map
        ? Map<String, dynamic>.from(m['post'] as Map)
        : <String, dynamic>{};

    final authorRaw = postRaw['author'] is Map
        ? Map<String, dynamic>.from(postRaw['author'] as Map)
        : (m['author'] is Map
            ? Map<String, dynamic>.from(m['author'] as Map)
            : <String, dynamic>{});

    return RoutedRecord(
      id: (m['id'] ?? '').toString(),
      postId: _opt(m, ['postId']) ?? (postRaw['id']?.toString() ?? ''),
      status: RoutedRecordStatus.fromWire(m['status']),
      intent: RecordIntent.fromWire(
        _opt(postRaw, ['intent']) ?? _opt(m, ['intent']),
      ),
      topic: AuraTopic.fromWire(
        _opt(postRaw, ['primaryTopic']) ?? _opt(m, ['topic', 'primaryTopic']),
      ),
      participationMode: _opt(m, ['participationMode']),
      author: AuraPersonIdentity.fromJson(authorRaw),
      postText: _opt(postRaw, ['text']),
      postCreatedAt: readDate(postRaw['createdAt']),
    );
  }
}

class EngagementSummary {
  const EngagementSummary({
    required this.total,
    required this.pending,
    required this.responded,
    required this.committed,
    required this.resolved,
  });

  final int total;
  final int pending;
  final int responded;
  final int committed;
  final int resolved;

  factory EngagementSummary.fromJson(Map<String, dynamic> m) {
    int readInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse((v ?? '').toString()) ?? 0;
    }

    final data = m['data'] is Map
        ? Map<String, dynamic>.from(m['data'] as Map)
        : m;
    return EngagementSummary(
      total: readInt(data['total']),
      pending: readInt(data['pending'] ?? data['needsResponse']),
      responded: readInt(data['responded']),
      committed: readInt(data['committed']),
      resolved: readInt(data['resolved']),
    );
  }

  static const empty = EngagementSummary(
    total: 0,
    pending: 0,
    responded: 0,
    committed: 0,
    resolved: 0,
  );
}
