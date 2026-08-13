/// Realtime Architecture Correction — Phase 4 (Notification/Ringing
/// Projection Migration), Part F/G.
///
/// ONE PROJECTION AUTHORITY for the incoming-call notification/ringing
/// surface. Before this module, `incoming_live_overlay.dart` and
/// `notification_bridge.dart` each carried their own, near-duplicate copies
/// of kind/session/call-state resolution and terminal-payload
/// classification — literal drift risk (their fallback text-match phrase
/// lists had already diverged), and exactly what the founder directive's
/// Part F forbids ("do NOT allow each platform/widget to independently
/// interpret raw realtime events"). Both files now import this module
/// instead of maintaining their own copies.
///
/// Governing rule (frozen): LIFECYCLE TRUTH -> CANONICAL EVENT -> PROJECTION
/// -> DELIVERY/PRESENTATION. This module never infers or creates lifecycle
/// truth — [isTerminalCallPayload]'s free-text fallback matching is
/// PRESENTATION classification of an already-delivered payload (should this
/// stop ringing?), never a source of session/participant lifecycle state.
library;

/// Presentation intent for the incoming-call surface — the architecture's
/// SHOW_INCOMING_CALL / UPDATE_INCOMING_CALL / CLEAR_INCOMING_CALL / NO_ACTION
/// vocabulary (Part F).
enum CallPresentationIntent { show, update, clear, noAction }

const Set<String> _kCallKinds = <String>{
  'LIVE',
  'CALL',
  'REALTIME',
  'CALL_RINGING',
  'LIVE_RINGING',
};

/// Wire event name -> presentation intent. Covers BOTH legacy event names
/// (still the primary transport today) and the canonical dot-case wire
/// names dual-emitted since Phase 2/3 — both project to the same intent, so
/// whichever arrives first or either arriving is harmless (Part G: duplicate
/// delivery must be harmless).
CallPresentationIntent projectCallPresentationEvent(String eventName) {
  switch (eventName) {
    case 'call:incoming':
    case 'invite.issued':
      return CallPresentationIntent.show;
    case 'participant.ringing':
      return CallPresentationIntent.update;
    case 'call:terminal':
    case 'call:declined':
    case 'session:ended':
    case 'session:removed':
    case 'realtime:removed':
    case 'participant.accepted':
    case 'participant.declined':
    case 'participant.expired':
    // Canonical SESSION_CANCELLED's wire name (CANONICAL_WIRE_NAME map,
    // aura-backend/src/realtime/canonical/event-contract.ts) — the ONE
    // canonical event with no pre-existing legacy equivalent name.
    // Session-scoped (`session.` prefix), matching session.ended/
    // session.failed — NOT `participant.cancelled` (a pre-existing
    // backend wire-name inconsistency, corrected at the source in Phase 4
    // Gate 2, 2026-08-16). Backend already also carries `reason:
    // 'CANCELLED'` on the legacy `call:terminal` payload (Phase 3), so this
    // case is redundant-but-safe with that existing path, not the sole
    // source.
    case 'session.cancelled':
    case 'session.ended':
    case 'session.failed':
      return CallPresentationIntent.clear;
    default:
      return CallPresentationIntent.noAction;
  }
}

String resolveNotificationKind(Map<String, dynamic> payload) {
  final data = mapOf(payload['data']);
  return firstNonEmptyString(<String>[
    stringOf(payload['notificationKind']),
    stringOf(payload['type']),
    stringOf(payload['communicationType']),
    stringOf(payload['kind']),
    stringOf(data['notificationKind']),
    stringOf(data['communicationType']),
    stringOf(data['type']),
  ]).toUpperCase();
}

bool isCallKind(String kind) => _kCallKinds.contains(kind);

String resolveCallSessionId(Map<String, dynamic> payload) {
  final data = mapOf(payload['data']);
  return firstNonEmptyString(<String>[
    stringOf(data['realtimeSessionId']),
    stringOf(data['sessionId']),
    stringOf(payload['realtimeSessionId']),
    stringOf(payload['sessionId']),
  ]);
}

String resolveCallState(Map<String, dynamic> payload) {
  final data = mapOf(payload['data']);
  return firstNonEmptyString(<String>[
    stringOf(data['callState']),
    stringOf(data['status']),
    stringOf(data['state']),
    stringOf(data['result']),
    stringOf(payload['callState']),
    stringOf(payload['status']),
    stringOf(payload['state']),
    stringOf(payload['result']),
  ]).toUpperCase();
}

const Set<String> _kTerminalStateValues = <String>{
  'MISSED',
  'ENDED',
  'DECLINED',
  'EXPIRED',
  'CANCELLED',
  'CANCELED',
  'FAILED',
  'TIMEOUT',
  'TIMED_OUT',
  'NO_ANSWER',
  'REJECTED',
  'COMPLETED',
  'CLOSED',
};

/// Merged union of both prior implementations' free-text fallback phrases
/// (incoming_live_overlay.dart had one — 'ended a call' — that
/// notification_bridge.dart lacked). Only consulted when no structured
/// state field matched, exactly as both predecessors did.
const List<String> _kTerminalSearchPhrases = <String>[
  'missed a call',
  'missed call',
  'call ended',
  'ended a call',
  'call declined',
  'declined a call',
  'call expired',
  'call cancelled',
  'call canceled',
  'no answer',
];

/// True when [payload] describes a call that has already reached a terminal
/// outcome — never an interrupt/ringing candidate. Structured `callState`/
/// `status`/`state`/`result` fields are checked first; free text is only a
/// fallback for payload shapes that omit them.
bool isTerminalCallPayload(Map<String, dynamic> payload) {
  final data = mapOf(payload['data']);
  final stateCandidates = <String>[
    stringOf(payload['callState']).toUpperCase(),
    stringOf(payload['status']).toUpperCase(),
    stringOf(payload['state']).toUpperCase(),
    stringOf(payload['result']).toUpperCase(),
    stringOf(payload['callStatus']).toUpperCase(),
    stringOf(payload['deliveryState']).toUpperCase(),
    stringOf(data['callState']).toUpperCase(),
    stringOf(data['status']).toUpperCase(),
    stringOf(data['state']).toUpperCase(),
    stringOf(data['result']).toUpperCase(),
    stringOf(data['callStatus']).toUpperCase(),
    stringOf(data['deliveryState']).toUpperCase(),
    stringOf(data['inviteStatus']).toUpperCase(),
  ];
  if (stateCandidates.any(_kTerminalStateValues.contains)) return true;

  final searchable = <String>[
    stringOf(payload['title']),
    stringOf(payload['body']),
    stringOf(payload['message']),
    stringOf(payload['previewText']),
    stringOf(data['title']),
    stringOf(data['body']),
    stringOf(data['message']),
    stringOf(data['previewText']),
    stringOf(data['summary']),
  ].join(' ').toLowerCase();

  return _kTerminalSearchPhrases.any(searchable.contains);
}

/// True when [payload] is a genuine incoming-call interrupt candidate —
/// call-kind, attention=INTERRUPT, and not already terminal.
bool isCallInterruptPayload(Map<String, dynamic> payload) {
  final data = mapOf(payload['data']);
  final attention = firstNonEmptyString(<String>[
    stringOf(payload['attention']),
    stringOf(data['attention']),
  ]).toUpperCase();
  return isCallKind(resolveNotificationKind(payload)) &&
      attention == 'INTERRUPT' &&
      !isTerminalCallPayload(payload);
}

/// Session-scoped precedence guard (Part G). Once a session's presentation
/// has been authoritatively cleared, a late/reordered/duplicate SHOW for
/// that EXACT session id is refused — protecting against late `call:incoming`
/// / `invite.issued` delivery resurrecting a ringing card after
/// ACCEPTED/DECLINED/EXPIRED/SESSION_CANCELLED/SESSION_ENDED truth already
/// arrived (test matrix items 8, 9, 10, 20). A session id is one-shot — a
/// new call is always a new session id — so tombstoning is permanent for
/// the lifetime of this guard, bounded to avoid unbounded growth over a
/// long-lived app session.
class IncomingCallPrecedenceGuard {
  IncomingCallPrecedenceGuard({this.maxTombstones = 200});

  final int maxTombstones;
  final Set<String> _tombstonedSessionIds = <String>{};
  final List<String> _tombstoneOrder = <String>[];

  /// False if [sessionId] has already been authoritatively cleared — the
  /// caller must not (re)show presentation for it.
  bool shouldShow(String sessionId) {
    if (sessionId.isEmpty) return true;
    return !_tombstonedSessionIds.contains(sessionId);
  }

  /// Records that [sessionId] has reached a terminal/non-actionable state.
  /// Idempotent — recording the same session twice (duplicate terminal
  /// delivery) is harmless (Part G).
  void recordClear(String sessionId) {
    if (sessionId.isEmpty) return;
    if (_tombstonedSessionIds.add(sessionId)) {
      _tombstoneOrder.add(sessionId);
      while (_tombstoneOrder.length > maxTombstones) {
        final oldest = _tombstoneOrder.removeAt(0);
        _tombstonedSessionIds.remove(oldest);
      }
    }
  }

  /// Clears all tombstones — for auth-drop teardown, mirroring
  /// `IncomingCallBridgeNotifier.clear()`.
  void reset() {
    _tombstonedSessionIds.clear();
    _tombstoneOrder.clear();
  }
}

// ── Primitive helpers (shared, module-public so both consumer files can
// drop their own private copies) ────────────────────────────────────────────

Map<String, dynamic> mapOf(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, val) => MapEntry(key.toString(), val));
  }
  return const <String, dynamic>{};
}

String stringOf(dynamic value) => value == null ? '' : value.toString().trim();

String firstNonEmptyString(List<String> values) {
  for (final value in values) {
    final text = value.trim();
    if (text.isNotEmpty) return text;
  }
  return '';
}
