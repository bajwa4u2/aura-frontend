import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'conversations_repository.dart';

/// THE ONE ANSWER TO "DOES THIS HUMAN HAVE UNREAD CONVERSATION CONTENT?"
///
/// Founder ruling (2026-08-23), freezing three questions that had collapsed
/// into one implementation:
///
///   MESSAGE UNREAD → what Conversation content have I not read?
///   ATTENTION      → what directed event have I not acknowledged?
///   ACTIVITY       → what has happened?
///
/// They intersect. They are not interchangeable.
///
/// WHAT WAS WRONG. The Messages badge counted NOTIFICATION rows of type
/// MESSAGE with a null `readAt`. It never consulted Conversation read state at
/// all — so presentation derived from the attention ledger, and a person who
/// had read every message still saw a badge for as long as a notification row
/// stayed unacknowledged. A server-side bridge was added to clear those rows
/// when a conversation is read, but that patched across the conflation instead
/// of removing it, and it cannot clear a row that carries no conversationId —
/// production holds exactly such a row, permanently pinning the badge.
///
/// THE CANONICAL CHAIN, and the only one this provider consumes:
///
///   ConversationMessage chronology
///     + ConversationHumanState (lastReadMessageId / lastReadAt)
///     → per-conversation unreadCount   [computed server-side]
///     → this authority
///     → every Messages unread surface
///
/// The server already answers this per conversation; the defect was never that
/// the truth was missing, only that presentation asked a different ledger for
/// it. So this composes the canonical answer rather than recomputing one —
/// a second resolver with its own rules is the thing being removed.
///
/// NOT autoDispose. The shell watches this continuously for the Messages
/// badge; an autoDispose provider would tear down and refetch as subscribers
/// come and go, which is how a badge starts flickering between truths.
class ConversationUnread {
  const ConversationUnread({
    required this.conversations,
    required this.messages,
  });

  const ConversationUnread.none() : conversations = 0, messages = 0;

  /// How many conversations contain unread content. This is what a badge
  /// shows: a person thinks in conversations, not in individual messages.
  final int conversations;

  /// Total unread messages across those conversations, for surfaces that
  /// legitimately want the finer number.
  final int messages;

  bool get hasAny => conversations > 0;
}

/// The canonical resolver. Invalidate it after a read mutation — see
/// `advanceConversationRead`.
final conversationUnreadProvider =
    FutureProvider<ConversationUnread>((ref) async {
  final list = await ref.watch(conversationsRepositoryProvider).list();

  var conversations = 0;
  var messages = 0;
  for (final c in list) {
    if (c.unreadCount > 0) {
      conversations += 1;
      messages += c.unreadCount;
    }
  }
  return ConversationUnread(conversations: conversations, messages: messages);
});

/// Advance the canonical read cursor for a conversation, then make every
/// unread consumer truthful immediately.
///
/// THE 120-SECOND LAG WAS THE DEFECT AS PEOPLE EXPERIENCED IT. The unread
/// count refreshed on a poll, so after reading a conversation the badge kept
/// counting those messages for up to two minutes. A poll is reconciliation; it
/// is not how a UI should learn the outcome of a mutation the app itself just
/// performed. The invalidation here is deterministic and immediate, and the
/// poll remains only as resilience.
///
/// Attention is synchronized, not substituted: the server clears the message
/// attention rows linked to this conversation as a consequence of the read, so
/// the attention consumers are refreshed too — but they are refreshed as a
/// SEPARATE ledger reaching its own new truth, never as the source of the
/// Messages badge.
Future<void> advanceConversationRead(
  WidgetRef ref,
  String conversationId, {
  required Future<void> Function() markRead,
  Future<void> Function()? refreshAttention,
}) async {
  // A FAILED READ MUST NOT BE SILENT.
  //
  // The caller discards this future, which is correct — a person reading a
  // conversation should not be interrupted by a toast about a cursor. But the
  // 2026-08-24 defect lived for exactly that reason: every markRead returned
  // 500, and nothing anywhere said so. Unread simply never cleared, and the
  // only symptom was a badge that would not go away.
  //
  // So the failure is announced where an engineer will see it, and rethrown so
  // the ledgers below are NOT invalidated on a write that did not happen —
  // refreshing them after a failed read would redraw the same stale truth and
  // make the failure look like a rendering problem.
  try {
    await markRead();
  } catch (e) {
    debugPrint('conversation read failed for $conversationId: $e');
    rethrow;
  }

  // Conversation unread — the authority this badge derives from.
  ref.invalidate(conversationUnreadProvider);
  ref.invalidate(conversationsListProvider);

  // Attention — a different question, refreshed because the server may have
  // cleared linked rows, not because it answers the unread one.
  if (refreshAttention != null) await refreshAttention();
}
