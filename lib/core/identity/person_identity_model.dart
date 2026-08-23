/// CANONICAL CLIENT PERSON IDENTITY — F053 / F116.
///
/// ─────────────────────────────────────────────────────────────────────────
/// THE SHARED CAUSE, NAMED BY THE AUDIT ITSELF
/// ─────────────────────────────────────────────────────────────────────────
///
/// F053 as issued: "the canonical identity system is not being consumed
/// consistently across the product." F116 restates it as a shared-consumption
/// problem rather than a list of broken screens. The consumer audit measured
/// the shape of it — 103 surfaces reading person fields off untyped maps, 75
/// private typed boundaries — and then said what actually causes it:
///
///   "it is a PRIVATE person shape, so it is enumerated: THE CLIENT HAS NO
///    SINGLE CANONICAL IDENTITY MODEL the way the backend now has
///    PERSON_IDENTITY_SELECT."
///
/// Every one of those sites is a symptom of one absence. Fixing them one at a
/// time without this model would produce 103 slightly different corrections —
/// which is exactly how the drift arose. PB-05 says as much: F116 may not be
/// closed by fixing one consumer.
///
/// ─────────────────────────────────────────────────────────────────────────
/// THE COUNTERPART, NOT A REINVENTION
/// ─────────────────────────────────────────────────────────────────────────
///
/// This mirrors the backend's `PERSON_IDENTITY_SELECT` field for field. It
/// does not add fields the projection does not carry, and it does not rename
/// them — a client shape that disagrees with the projection would just be the
/// 104th private person model.
///
/// ─────────────────────────────────────────────────────────────────────────
/// IT ABSORBS THE DRIFT THAT ALREADY COST US
/// ─────────────────────────────────────────────────────────────────────────
///
/// F057: the call room read `me['id']` while Conversation read
/// `me['user']['id']`, so when `/auth/me` nested the person the realtime
/// surface silently resolved an EMPTY id — host detection said "not host",
/// participant lookup matched nobody. That is a PARSING difference between
/// two hand-written readers of the same payload, and it is why the reader
/// here is tolerant by design: it accepts the person at the top level or
/// nested under the keys the API actually uses, and it accepts the field
/// aliases the API actually emits. One tolerant reader that every surface
/// shares cannot disagree with itself.
///
/// IDENTITY IS NOT AUTHORIZATION — the same boundary the backend authority
/// states. This says who someone is. Role, membership and capability stay
/// with their own authorities.
library;

import '../trust/verification.dart';

/// How a human being is represented when they appear inside another entity's
/// payload: a message author, a member, a caller, a mention target.
class AuraPersonIdentity {
  const AuraPersonIdentity({
    required this.userId,
    required this.displayName,
    required this.handle,
    this.avatarUrl,
    this.accountStatus,
    this.verification = const PersonVerification.none(),
  });

  final String userId;
  final String displayName;
  final String handle;
  final String? avatarUrl;

  /// Public-safe lifecycle projection ('ACTIVE' / 'DISABLED' / 'DELETED').
  /// Carried so a surface can represent a deleted author truthfully while
  /// still resolving their historical authorship. Never a moderation reason.
  final String? accountStatus;

  /// The governed verification set — mirroring `PersonIdentity.verification`
  /// on the backend, field for field.
  ///
  /// CARRIED HERE BECAUSE TRUST IS PART OF WHO SOMEONE IS (founder ruling
  /// 2026-08-23 §F). It was previously left to each surface to fetch or
  /// ignore, and the Institution roster ignored it — so a person verified on
  /// their profile appeared unverified on Members. A verified person must not
  /// become unverified by being looked at through a different endpoint.
  ///
  /// Empty is the honest default: absence of verification, never an error and
  /// never a claim. A payload that carries no `verification` key yields the
  /// empty set exactly as one that carries an empty list.
  final PersonVerification verification;

  bool get isEmpty => userId.isEmpty && displayName.isEmpty && handle.isEmpty;
  bool get isNotEmpty => !isEmpty;

  /// What to render when a person must be named.
  ///
  /// The order is the honest one: their own name, else their handle, else a
  /// neutral word. It is NOT "Participant" — F054's defect was a surface
  /// inventing a label for someone it had failed to resolve, and a shared
  /// fallback is the only way that stops being re-decided per screen.
  String get label {
    if (displayName.trim().isNotEmpty) return displayName.trim();
    if (handle.trim().isNotEmpty) return '@${handle.trim()}';
    return 'Someone';
  }

  /// The same identity, named for PROSE — no `@`.
  ///
  /// "amjad sent you a message" reads correctly; "@amjad sent you a message"
  /// does not. The FALLBACK ORDER stays canonical (name, then handle, then
  /// the neutral word); only the decoration is the sentence's business. Two
  /// renderings of one order, rather than two orders.
  String get proseName {
    if (displayName.trim().isNotEmpty) return displayName.trim();
    if (handle.trim().isNotEmpty) return handle.trim();
    return 'Someone';
  }

  /// The canonical route to this person, or null when there is no handle to
  /// address them by.
  String? get profileRoute =>
      handle.trim().isEmpty ? null : '/u/${handle.trim()}';

  static const AuraPersonIdentity unknown = AuraPersonIdentity(
    userId: '',
    displayName: '',
    handle: '',
  );

  /// THE ONE READER. Tolerant on purpose — see the F057 note above.
  ///
  /// [json] may be the person, or an envelope carrying them under any of the
  /// keys the API actually uses. Returns [unknown] rather than throwing: a
  /// surface that cannot resolve someone must say so, not crash, and must not
  /// invent a name for them either.
  factory AuraPersonIdentity.fromJson(Object? json) {
    final map = _personMapOf(json);
    if (map == null) return unknown;

    return AuraPersonIdentity(
      userId: _str(map, const ['userId', 'id', 'uid']),
      // `name` is included because several payloads emit it for a person;
      // `fullName` because the directory does.
      displayName: _str(map, const ['displayName', 'fullName', 'name']),
      handle: _str(map, const ['handle', 'username']),
      avatarUrl: _strOrNull(map, const ['avatarUrl', 'photoUrl', 'imageUrl']),
      accountStatus: _strOrNull(map, const ['accountStatus']),
      verification: PersonVerification.fromJson(map['verification']),
    );
  }

  /// Keys under which a person is nested in Aura payloads. Ordered: the most
  /// specific envelope wins, so an actor is not mistaken for the viewer.
  static const List<String> _nestedKeys = [
    // `person` is the name the backend uses when a payload carries the
    // canonical projection beside its own state — a discovery suggestion, for
    // one. Listed first because it is the most explicit envelope there is.
    'person',
    'user',
    'author',
    'sender',
    'senderUser',
    'actor',
    'member',
    'participant',
    'counterpart',
    'profile',
  ];

  static Map<String, dynamic>? _personMapOf(Object? json) {
    if (json is! Map) return null;
    final map = Map<String, dynamic>.from(json);

    // A payload that names a person directly wins over one that nests them —
    // otherwise a message's own `user` envelope could shadow the message
    // author the caller actually passed.
    final direct = _str(map, const ['displayName', 'fullName', 'name']) +
        _str(map, const ['handle', 'username']);
    if (direct.isNotEmpty) return map;

    for (final key in _nestedKeys) {
      final nested = map[key];
      if (nested is Map) {
        final inner = Map<String, dynamic>.from(nested);
        final has = _str(inner, const ['displayName', 'fullName', 'name']) +
            _str(inner, const ['handle', 'username']) +
            _str(inner, const ['userId', 'id', 'uid']);
        if (has.isNotEmpty) return inner;
      }
    }

    // An id-only payload is still a person — anonymous, but resolvable.
    return _str(map, const ['userId', 'id', 'uid']).isNotEmpty ? map : null;
  }

  static String _str(Map<String, dynamic> m, List<String> keys) =>
      _strOrNull(m, keys) ?? '';

  static String? _strOrNull(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isNotEmpty) return s;
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is AuraPersonIdentity &&
      other.userId == userId &&
      other.displayName == displayName &&
      other.handle == handle &&
      other.avatarUrl == avatarUrl &&
      other.verification.classes.join(',') == verification.classes.join(',') &&
      other.accountStatus == accountStatus;

  @override
  int get hashCode =>
      Object.hash(userId, displayName, handle, avatarUrl, accountStatus);

  @override
  String toString() => 'AuraPersonIdentity($userId, $handle)';
}
