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
/// FOUNDER RULING (2026-08-17, F055) — identity order must express how the
/// human conversation actually formed:
///   • 1:1 — the counterpart is primary;
///   • a group grown from a pair — the FOUNDING conversational counterpart
///     comes first, then people follow in their original admission
///     chronology;
///   • leaving and rejoining must NOT rewrite someone's semantic position;
///   • the current user is implicit ("You"), never the derived counterpart;
///   • deterministic canonical ordering resolves genuinely simultaneous
///     ties only.
///
/// Implementation: founding parties (no entry invitation) sort ahead of
/// admitted ones, then `firstJoinedAt` — the IMMUTABLE admission
/// chronology — orders each band. Mutable `joinedAt` is deliberately NOT
/// consulted: it is rewritten on re-entry and would let a returning
/// founder sort behind people admitted years later. `directKey` is
/// likewise unusable, as the backend clears it permanently once topology
/// grows beyond the founding pair.
List<ConversationParty> orderedOtherParties(Conversation c, String myUserId) {
  final others = c.parties
      .where((p) => p.isActive && !(p.isPerson && p.userId == myUserId))
      .toList();
  others.sort((a, b) {
    // Founding band first — how the conversation began.
    if (a.enteredByInvitation != b.enteredByInvitation) {
      return a.enteredByInvitation ? 1 : -1;
    }
    final af = a.firstJoinedAt;
    final bf = b.firstJoinedAt;
    if (af != null && bf != null && af != bf) return af.compareTo(bf);
    if (af != null && bf == null) return -1;
    if (af == null && bf != null) return 1;
    // Genuinely simultaneous (founding pair written in one transaction):
    // deterministic canonical tiebreak so the label can never flap.
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

/// Canonical avatar for a 1:1 conversation — the counterpart's real image.
/// Returns null for groups: a group's visual identity is a COMPOSITE of its
/// people (see [conversationAvatarIdentities] / `ConversationAvatar`), never
/// one arbitrary member's photo standing in for everyone.
String? conversationDisplayAvatarUrl(Conversation c, String myUserId) {
  final others = orderedOtherParties(c, myUserId);
  if (others.length != 1) return null;
  final url = (others.first.avatarUrl ?? '').trim();
  return url.isEmpty ? null : url;
}

/// One identity inside a conversation's visual identity.
class ConversationAvatarIdentity {
  const ConversationAvatarIdentity({required this.name, this.imageUrl});
  final String name;
  final String? imageUrl;
}

/// FOUNDER RULING (2026-08-17, F056): a generic letter tile is not Aura's
/// group identity. A group is presented as a compact composite of its
/// canonical participant identities, in the F055 formation order, with the
/// current user excluded; canonical initials appear only for a participant
/// who genuinely has no usable avatar. A custom conversation name controls
/// TEXTUAL identity but never erases the human visual identity underneath.
///
/// Returns at most [max] identities; callers render "+N" for the remainder
/// using [conversationAvatarOverflow].
List<ConversationAvatarIdentity> conversationAvatarIdentities(
  Conversation c,
  String myUserId, {
  int max = 3,
}) {
  final others = orderedOtherParties(c, myUserId);
  return others
      .take(max)
      .map(
        (p) => ConversationAvatarIdentity(
          name: _partyName(p),
          imageUrl: (p.avatarUrl ?? '').trim().isEmpty
              ? null
              : p.avatarUrl!.trim(),
        ),
      )
      .toList();
}

int conversationAvatarOverflow(Conversation c, String myUserId, {int max = 3}) {
  final total = orderedOtherParties(c, myUserId).length;
  return total > max ? total - max : 0;
}
