import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_providers.dart';
import '../data/conversations_repository.dart';

/// Presentation identity helpers for the Conversation module.
/// Naming is DERIVED until customized (canon: no forced naming, ever).

final myUserIdProvider = Provider<String>((ref) {
  final me = ref.watch(authMeDataProvider).valueOrNull;
  final user = (me?['user'] is Map)
      ? Map<String, dynamic>.from(me!['user'] as Map)
      : const <String, dynamic>{};
  return (user['id'] ?? me?['id'] ?? '').toString();
});

/// Display name: custom name wins; otherwise derived from the OTHER
/// active parties' names ("Amina", "Amina & Tariq", "Amina, Tariq +1").
/// Canonical ordering of the other parties in a conversation.
///
/// FROZEN RULE (founder): identity order comes from the human
/// conversation relationship — never database order, DTO order, legacy
/// slot order, or socket arrival order. Implemented as the
/// conversation's own history: who entered it first, with a stable
/// display-name tiebreak so the name can never flap between loads for
/// parties that share a timestamp (or predate the field).
///
/// JUDGMENT CALL, flagged for founder ruling: "conversation entry order"
/// is this doc's reading of the human relationship. The alternative
/// reading — alphabetical by canonical display name — is deterministic
/// too but carries no relationship meaning. Change here, in one place,
/// if the founder rules otherwise.
List<ConversationParty> orderedOtherParties(Conversation c, String myUserId) {
  final others = c.parties
      .where((p) => p.isActive && !(p.isPerson && p.userId == myUserId))
      .toList();
  others.sort((a, b) {
    final aj = a.joinedAt;
    final bj = b.joinedAt;
    if (aj != null && bj != null && aj != bj) return aj.compareTo(bj);
    if (aj != null && bj == null) return -1;
    if (aj == null && bj != null) return 1;
    return _partyName(a).toLowerCase().compareTo(_partyName(b).toLowerCase());
  });
  return others;
}

String conversationDisplayName(Conversation c, String myUserId) {
  final custom = (c.name ?? '').trim();
  if (custom.isNotEmpty) return custom;
  final others = orderedOtherParties(c, myUserId);
  final names = others
      .map((p) => (p.userId != null || p.institutionId != null)
          ? _partyName(p)
          : '')
      .where((n) => n.isNotEmpty)
      .toList();
  if (names.isEmpty) return 'Conversation';
  if (names.length == 1) return names.first;
  if (names.length == 2) return '${names[0]} & ${names[1]}';
  return '${names[0]}, ${names[1]} +${names.length - 2}';
}

String _partyName(ConversationParty p) {
  final n = (p.displayName ?? '').trim();
  if (n.isNotEmpty) return n;
  return p.isPerson ? 'Aura member' : 'Institution';
}

/// Canonical avatar for a conversation row (2026-08-17, addendum §4:
/// Conversation identity == realtime identity — no per-surface dialects).
/// 1:1 → the counterpart's canonical avatarUrl; groups → null for now (a
/// letter tile until the group-avatar treatment is ruled on), never one
/// arbitrary member's photo masquerading as the group.
String? conversationDisplayAvatarUrl(Conversation c, String myUserId) {
  final others = orderedOtherParties(c, myUserId);
  if (others.length != 1) return null;
  final url = (others.first.avatarUrl ?? '').trim();
  return url.isEmpty ? null : url;
}
