import 'dart:io';

import 'package:aura/features/updates/module_attention.dart';
import 'package:flutter_test/flutter_test.dart';

/// ONE CANONICAL RESOLVER FOR CONVERSATION UNREAD TRUTH.
///
/// Founder ruling (2026-08-23) §6. Three questions had collapsed into one
/// implementation, and the collapse is the defect:
///
///   MESSAGE UNREAD → what Conversation content have I not read?
///   ATTENTION      → what directed event have I not acknowledged?
///   ACTIVITY       → what has happened?
///
/// The intended chain, and the only one presentation may consume:
///
///   ConversationMessage chronology + ConversationHumanState
///     → Conversation unread authority
///     → all Messages unread presentation
void main() {
  final shell = File('lib/app/shell/member_shell.dart').readAsStringSync();

  group('the Messages badge asks Conversation state, not attention', () {
    test('it derives from the Conversation unread authority', () {
      expect(shell, contains('conversationUnreadProvider'));
      expect(shell, contains('conversationUnread.conversations'));
    });

    test('it does NOT count MESSAGE notification rows', () {
      // The precise defect: `_memberBadgeFor` returned `attention.messages`,
      // a count of unread Notification rows of type MESSAGE. A person who had
      // read every message still saw a badge until the row was acknowledged.
      final resolver = RegExp(
        r"case '/messages':[\s\S]{0,200}?return ([^\n;]+);",
      ).firstMatch(shell)?.group(1);

      expect(resolver, isNotNull, reason: 'the Messages badge resolver is gone');
      expect(
        resolver,
        isNot(contains('attention')),
        reason: 'message unread must not derive from the attention ledger',
      );
    });

    test('institutions still asks attention, and that is correct', () {
      // An institutional event IS a directed attention item, not unread
      // conversation content. Converging it too would be the same collapse in
      // the other direction.
      final resolver = RegExp(
        r"case '/institutions':[\s\S]{0,200}?return ([^\n;]+);",
      ).firstMatch(shell)?.group(1);

      expect(resolver, contains('attention'));
    });
  });

  group('the attention ledger keeps its own question', () {
    test('MESSAGE still maps to the messages module for ATTENTION', () {
      // Attention is not being deleted — a message notification is still a
      // directed attention item. It simply no longer answers "unread".
      expect(
        attentionModuleForType('MESSAGE'),
        AttentionModule.messages,
      );
    });

    test('attention counts only unacknowledged rows', () {
      final attention = moduleAttentionFromItems([
        {'type': 'MESSAGE', 'readAt': ''},
        {'type': 'MESSAGE', 'readAt': '2026-08-23T00:00:00Z'},
      ]);
      expect(attention.messages, 1);
    });
  });

  group('read advancement is deterministic, not eventual', () {
    final authority = File(
      'lib/features/conversation/data/conversation_unread_authority.dart',
    ).readAsStringSync();

    test('reading invalidates the unread authority immediately', () {
      // A two-minute poll must not be how the UI learns the outcome of a
      // mutation the app itself just performed.
      expect(authority, contains('ref.invalidate(conversationUnreadProvider)'));
      expect(authority, contains('ref.invalidate(conversationsListProvider)'));
    });

    test('attention is refreshed as a separate ledger, after the read', () {
      // Scoped to the function BODY: `refreshAttention` also appears in the
      // parameter list above it, and matching that would test declaration
      // order rather than execution order.
      final body = authority.substring(authority.indexOf('await markRead();'));

      final unread = body.indexOf('invalidate(conversationUnreadProvider)');
      final attention = body.indexOf('await refreshAttention()');

      expect(unread, greaterThan(0),
          reason: 'unread is invalidated after the cursor advances');
      expect(attention, greaterThan(unread),
          reason: 'attention is synchronised after, as a separate ledger');
    });

    test('the authority is not autoDispose', () {
      // The shell watches it continuously; an autoDispose provider would tear
      // down and refetch as subscribers come and go, which is how a badge
      // starts flickering between truths.
      expect(
        authority,
        contains('final conversationUnreadProvider =\n    FutureProvider<'),
      );
      expect(authority, isNot(contains('FutureProvider.autoDispose<ConversationUnread>')));
    });
  });

  test('no legacy read state re-enters unread presentation', () {
    // DirectThread and member-Space authority cutovers are closed. Their read
    // state must not reappear as a presentation input.
    for (final legacy in [
      'participantALastReadAt',
      'participantBLastReadAt',
      'ThreadReadState',
      'threadReadState',
    ]) {
      expect(shell, isNot(contains(legacy)), reason: legacy);
    }
  });
}
