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
String conversationDisplayName(Conversation c, String myUserId) {
  final custom = (c.name ?? '').trim();
  if (custom.isNotEmpty) return custom;
  final others = c.parties
      .where((p) => p.isActive && !(p.isPerson && p.userId == myUserId))
      .toList();
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
  final others = c.parties
      .where((p) => p.isActive && !(p.isPerson && p.userId == myUserId))
      .toList();
  if (others.length != 1) return null;
  final url = (others.first.avatarUrl ?? '').trim();
  return url.isEmpty ? null : url;
}
