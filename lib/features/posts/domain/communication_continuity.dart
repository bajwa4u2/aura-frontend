/// Communication Governance v1.0, Roadmap Milestone 8.
///
/// Parses the exact wire shape `GET /posts/:id/continuity` returns
/// (`public-record-continuity-read.service.ts`'s `ContinuityDto`). This is
/// a representation of the backend contract, not a reinterpretation of it —
/// every status value here is one the backend already computed.
library;

Map<String, dynamic> _asMap(dynamic v) {
  if (v is Map) return Map<String, dynamic>.from(v);
  return const <String, dynamic>{};
}

String? _asString(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

/// One resolution certification — `{ statement, resolvedByUserId, resolvedAt }`.
/// Append-only on the backend: a second resolution never replaces the first.
class ResolutionHistoryEntry {
  const ResolutionHistoryEntry({
    required this.statement,
    required this.resolvedByUserId,
    required this.resolvedAt,
  });

  final String statement;
  final String? resolvedByUserId;
  final DateTime? resolvedAt;

  factory ResolutionHistoryEntry.fromJson(Map<String, dynamic> j) {
    return ResolutionHistoryEntry(
      statement: _asString(j['statement']) ?? '',
      resolvedByUserId: _asString(j['resolvedByUserId']),
      resolvedAt: DateTime.tryParse(_asString(j['resolvedAt']) ?? ''),
    );
  }
}

enum AccountabilityStatus {
  pending,
  responded,
  committed,
  resolved,
  reopened,
  stale,
  dormant,
  institutionNoLongerActive,
  unknown,
}

AccountabilityStatus _statusFromWire(String? raw) {
  switch ((raw ?? '').toUpperCase().trim()) {
    case 'PENDING':
      return AccountabilityStatus.pending;
    case 'RESPONDED':
      return AccountabilityStatus.responded;
    case 'COMMITTED':
      return AccountabilityStatus.committed;
    case 'RESOLVED':
      return AccountabilityStatus.resolved;
    case 'REOPENED':
      return AccountabilityStatus.reopened;
    case 'STALE':
      return AccountabilityStatus.stale;
    case 'DORMANT':
      return AccountabilityStatus.dormant;
    case 'INSTITUTION_NO_LONGER_ACTIVE':
      return AccountabilityStatus.institutionNoLongerActive;
    default:
      return AccountabilityStatus.unknown;
  }
}

/// One institution's independent Accountability Lifecycle for a Raise
/// Issue. Per the Communication Lifecycle vs. Accountability Lifecycle
/// doctrine, a Raise Issue routed to N institutions has N of these — never
/// one blended value.
class AccountabilityLifecycle {
  const AccountabilityLifecycle({
    required this.institutionId,
    required this.status,
    required this.overdue,
    required this.acknowledgedAt,
    required this.resolutionHistory,
    required this.reopenedAt,
    required this.routedAt,
    required this.updatedAt,
  });

  final String institutionId;
  final AccountabilityStatus status;
  final bool overdue;
  final DateTime? acknowledgedAt;
  final List<ResolutionHistoryEntry> resolutionHistory;
  final DateTime? reopenedAt;
  final DateTime routedAt;
  final DateTime updatedAt;

  bool get isAcknowledged => acknowledgedAt != null;
  bool get isReopened => reopenedAt != null;

  factory AccountabilityLifecycle.fromJson(Map<String, dynamic> j) {
    final historyRaw = j['resolutionHistory'];
    final history = <ResolutionHistoryEntry>[];
    if (historyRaw is List) {
      for (final e in historyRaw) {
        if (e is Map) {
          history.add(ResolutionHistoryEntry.fromJson(_asMap(e)));
        }
      }
    }
    return AccountabilityLifecycle(
      institutionId: _asString(j['institutionId']) ?? '',
      status: _statusFromWire(_asString(j['status'])),
      overdue: j['overdue'] == true,
      acknowledgedAt: DateTime.tryParse(_asString(j['acknowledgedAt']) ?? ''),
      resolutionHistory: history,
      reopenedAt: DateTime.tryParse(_asString(j['reopenedAt']) ?? ''),
      routedAt:
          DateTime.tryParse(_asString(j['routedAt']) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          DateTime.tryParse(_asString(j['updatedAt']) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

enum AskContinuityStatus { pending, answered, stale, unknown }

AskContinuityStatus _askStatusFromWire(String? raw) {
  switch ((raw ?? '').toUpperCase().trim()) {
    case 'PENDING':
      return AskContinuityStatus.pending;
    case 'ANSWERED':
      return AskContinuityStatus.answered;
    case 'STALE':
      return AskContinuityStatus.stale;
    default:
      return AskContinuityStatus.unknown;
  }
}

/// The parsed result of `GET /posts/:id/continuity`. Exactly one of the
/// three shapes below — Share Update (and any post with no continuity)
/// parses to [ContinuityResult.none], matching the backend's `null`.
sealed class ContinuityResult {
  const ContinuityResult();

  static ContinuityResult? fromJson(dynamic raw) {
    if (raw == null) return const ContinuityNone();
    final map = _asMap(raw);
    final intent = _asString(map['intent'])?.toUpperCase();
    if (intent == 'ISSUE') {
      final communicationStatus = _asString(map['communicationStatus']) ?? '';
      final lifecycles = <AccountabilityLifecycle>[];
      final raw2 = map['accountabilityLifecycles'];
      if (raw2 is List) {
        for (final e in raw2) {
          if (e is Map) {
            lifecycles.add(AccountabilityLifecycle.fromJson(_asMap(e)));
          }
        }
      }
      return RaiseIssueContinuity(
        unrouted: communicationStatus.toUpperCase() == 'UNROUTED',
        accountabilityLifecycles: lifecycles,
      );
    }
    if (intent == 'ASK') {
      return AskContinuity(status: _askStatusFromWire(_asString(map['status'])));
    }
    return const ContinuityNone();
  }
}

class RaiseIssueContinuity extends ContinuityResult {
  const RaiseIssueContinuity({
    required this.unrouted,
    required this.accountabilityLifecycles,
  });

  final bool unrouted;
  final List<AccountabilityLifecycle> accountabilityLifecycles;
}

class AskContinuity extends ContinuityResult {
  const AskContinuity({required this.status});

  final AskContinuityStatus status;
}

/// Share Update, or any post with no Accountability Lifecycle to show.
class ContinuityNone extends ContinuityResult {
  const ContinuityNone();
}
