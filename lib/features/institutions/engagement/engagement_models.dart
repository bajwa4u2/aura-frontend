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

class RoutedRecord {
  const RoutedRecord({
    required this.id,
    required this.postId,
    required this.institutionId,
    required this.status,
    required this.intent,
    this.topic,
    this.participationMode,
    this.authorName,
    this.authorHandle,
    this.postBody,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String postId;
  final String institutionId;
  final RoutedRecordStatus status;
  final RecordIntent intent;
  final AuraTopic? topic;
  final String? participationMode;
  final String? authorName;
  final String? authorHandle;
  final String? postBody;
  final DateTime? createdAt;
  final DateTime? updatedAt;

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
      postId: _opt(m, ['postId']) ?? '',
      institutionId: _opt(m, ['institutionId']) ?? '',
      status: RoutedRecordStatus.fromWire(m['status']),
      intent: RecordIntent.fromWire(
        _opt(postRaw, ['intent']) ?? _opt(m, ['intent']),
      ),
      topic: AuraTopic.fromWire(
        _opt(postRaw, ['primaryTopic']) ?? _opt(m, ['topic', 'primaryTopic']),
      ),
      participationMode: _opt(m, ['participationMode']),
      authorName: _opt(authorRaw, ['name', 'displayName']),
      authorHandle: _opt(authorRaw, ['handle', 'handleOrSlug']),
      postBody: _opt(postRaw, ['body']) ?? _opt(m, ['postBody']),
      createdAt: readDate(m['createdAt']),
      updatedAt: readDate(m['updatedAt']),
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
      pending: readInt(data['pending']),
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
