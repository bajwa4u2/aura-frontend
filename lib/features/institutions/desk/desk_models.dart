import '../../../core/identity/person_identity_model.dart';

/// THE DESK (DD-43): one queue of what waits for this person at this
/// institution, from `GET /institutions/:id/desk`.
enum DeskItemType {
  question,
  issue,
  commitment,
  joinRequest,
  draft,
  meeting,
  followUp,
  unknown;

  static DeskItemType fromWire(Object? raw) => switch ((raw ?? '').toString().toUpperCase()) {
        'QUESTION' => DeskItemType.question,
        'ISSUE' => DeskItemType.issue,
        'COMMITMENT' => DeskItemType.commitment,
        'JOIN_REQUEST' => DeskItemType.joinRequest,
        'DRAFT' => DeskItemType.draft,
        'MEETING' => DeskItemType.meeting,
        'FOLLOW_UP' => DeskItemType.followUp,
        _ => DeskItemType.unknown,
      };
}

enum DeskUrgency {
  now,
  overdue,
  dueSoon,
  waiting;

  static DeskUrgency fromWire(Object? raw) => switch ((raw ?? '').toString().toUpperCase()) {
        'NOW' => DeskUrgency.now,
        'OVERDUE' => DeskUrgency.overdue,
        'DUE_SOON' => DeskUrgency.dueSoon,
        _ => DeskUrgency.waiting,
      };
}

/// The Desk's tabs, in the order they are shown.
enum DeskTab {
  all('all', 'All'),
  questions('questions', 'Questions'),
  commitments('commitments', 'Commitments'),
  joinRequests('joinRequests', 'Join requests'),
  drafts('drafts', 'Drafts'),
  meetings('meetings', 'Meetings');

  const DeskTab(this.wire, this.label);
  final String wire;
  final String label;

  bool holds(DeskItemType t) => switch (this) {
        DeskTab.all => true,
        DeskTab.questions => t == DeskItemType.question || t == DeskItemType.issue,
        DeskTab.commitments => t == DeskItemType.commitment,
        DeskTab.joinRequests => t == DeskItemType.joinRequest,
        DeskTab.drafts => t == DeskItemType.draft,
        DeskTab.meetings => t == DeskItemType.meeting || t == DeskItemType.followUp,
      };
}

class DeskItem {
  const DeskItem({
    required this.key,
    required this.type,
    required this.id,
    required this.title,
    required this.since,
    required this.urgency,
    this.person,
    this.dueAt,
    this.meta = const {},
  });

  final String key;
  final DeskItemType type;
  final String id;
  final String title;
  final AuraPersonIdentity? person;
  final DateTime since;
  final DateTime? dueAt;
  final DeskUrgency urgency;
  final Map<String, Object?> meta;

  bool get isRecord => type == DeskItemType.question || type == DeskItemType.issue || type == DeskItemType.commitment;

  factory DeskItem.fromJson(Map<String, dynamic> j) {
    final p = j['person'];
    return DeskItem(
      key: (j['key'] ?? '').toString(),
      type: DeskItemType.fromWire(j['type']),
      id: (j['id'] ?? '').toString(),
      title: (j['title'] ?? '').toString(),
      person: p is Map ? AuraPersonIdentity.fromJson(Map<String, dynamic>.from(p)) : null,
      since: DateTime.tryParse((j['since'] ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0),
      dueAt: DateTime.tryParse((j['dueAt'] ?? '').toString()),
      urgency: DeskUrgency.fromWire(j['urgency']),
      meta: j['meta'] is Map ? Map<String, Object?>.from(j['meta'] as Map) : const {},
    );
  }
}

class DeskSnapshot {
  const DeskSnapshot({required this.items, required this.counts});

  final List<DeskItem> items;
  final Map<String, int> counts;

  int count(DeskTab tab) => counts[tab.wire] ?? items.where((i) => tab.holds(i.type)).length;

  factory DeskSnapshot.fromJson(Map<String, dynamic> j) {
    final raw = j['items'];
    final counts = <String, int>{};
    if (j['counts'] is Map) {
      (j['counts'] as Map).forEach((k, v) => counts[k.toString()] = v is num ? v.toInt() : int.tryParse('$v') ?? 0);
    }
    return DeskSnapshot(
      items: [
        if (raw is List)
          for (final e in raw.whereType<Map>()) DeskItem.fromJson(Map<String, dynamic>.from(e)),
      ],
      counts: counts,
    );
  }

  static const empty = DeskSnapshot(items: [], counts: {});
}

/// MEMORY (DD-43): what the institution said before, beside the answer
/// being written. From `GET /institutions/:id/engagement/:recordId/memory`.
class InstitutionMemory {
  const InstitutionMemory({
    required this.topic,
    required this.answeredOnTopic,
    required this.pastAnswers,
    required this.askerCount,
    required this.askerRecords,
    required this.openCommitments,
    required this.overdueCommitments,
    required this.commitments,
  });

  final String topic;
  final int answeredOnTopic;
  final List<({String recordId, String question, String? answer, DateTime? answeredAt, String status})> pastAnswers;
  final int askerCount;
  final List<({String recordId, String question, String status, DateTime? routedAt})> askerRecords;
  final int openCommitments;
  final int overdueCommitments;
  final List<({String recordId, String question, DateTime? dueAt, bool overdue})> commitments;

  factory InstitutionMemory.fromJson(Map<String, dynamic> root) {
    final j = root['memory'] is Map ? Map<String, dynamic>.from(root['memory'] as Map) : root;
    int n(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
    DateTime? d(Object? v) => v == null ? null : DateTime.tryParse(v.toString());
    List<Map<String, dynamic>> list(Object? v) =>
        [if (v is List) for (final e in v.whereType<Map>()) Map<String, dynamic>.from(e)];
    final asker = j['asker'] is Map ? Map<String, dynamic>.from(j['asker'] as Map) : <String, dynamic>{};
    final commitments = j['commitments'] is Map ? Map<String, dynamic>.from(j['commitments'] as Map) : <String, dynamic>{};
    return InstitutionMemory(
      topic: (j['topic'] ?? '').toString(),
      answeredOnTopic: n(j['answeredOnTopic']),
      pastAnswers: [
        for (final a in list(j['pastAnswers']))
          (
            recordId: (a['recordId'] ?? '').toString(),
            question: (a['question'] ?? '').toString(),
            answer: a['answer']?.toString(),
            answeredAt: d(a['answeredAt']),
            status: (a['status'] ?? '').toString(),
          ),
      ],
      askerCount: n(asker['count']),
      askerRecords: [
        for (final r in list(asker['records']))
          (
            recordId: (r['recordId'] ?? '').toString(),
            question: (r['question'] ?? '').toString(),
            status: (r['status'] ?? '').toString(),
            routedAt: d(r['routedAt']),
          ),
      ],
      openCommitments: n(commitments['open']),
      overdueCommitments: n(commitments['overdue']),
      commitments: [
        for (final c in list(commitments['items']))
          (
            recordId: (c['recordId'] ?? '').toString(),
            question: (c['question'] ?? '').toString(),
            dueAt: d(c['dueAt']),
            overdue: c['overdue'] == true,
          ),
      ],
    );
  }
}
