import 'dart:io';

import 'package:aura/features/activity/data/activity_history_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// ONE ACTIVITY DESTINATION, TWO SEMANTICS THAT MUST NOT COLLAPSE.
///
/// Founder ruling (2026-08-23):
///
///   ATTENTION — directed items with acknowledgement/read semantics, feeding
///   the drawer signal.
///   HISTORY   — factual continuity with NO read semantics, feeding nothing.
///
/// These prove the separation from the outside: that History carries no read
/// state, that reading it changes nothing, and that neither view's mechanics
/// leak into the other.
/// Comments EXPLAIN the invariants, so they legitimately contain the words the
/// code must not. Matching prose would flag the documentation that states the
/// rule — so these checks read code only.
String codeOnly(String source) => source
    .split(String.fromCharCode(10))
    .where((l) {
      final t = l.trimLeft();
      return !t.startsWith('//') && !t.startsWith('///') && !t.startsWith('*');
    })
    .join(String.fromCharCode(10));

void main() {
  final historyView = codeOnly(File(
    'lib/features/activity/presentation/activity_history_view.dart',
  ).readAsStringSync());
  final historyRepo = codeOnly(File(
    'lib/features/activity/data/activity_history_repository.dart',
  ).readAsStringSync());
  final shell = codeOnly(
      File('lib/app/shell/member_shell.dart').readAsStringSync());

  group('History is continuity, not an inbox', () {
    test('it has no read or acknowledgement machinery', () {
      for (final forbidden in [
        'markRead',
        'markAllRead',
        'readAt',
        'unreadCount',
        'acknowledge',
      ]) {
        expect(historyView, isNot(contains(forbidden)), reason: forbidden);
        expect(historyRepo, isNot(contains(forbidden)), reason: forbidden);
      }
    });

    test('opening it mutates nothing — it only reads', () {
      // A GET-only surface. Any post/patch here would be the view acquiring
      // acknowledgement semantics by the back door.
      expect(historyRepo, contains('.get('));
      expect(historyRepo, isNot(contains('.post(')));
      expect(historyRepo, isNot(contains('.patch(')));
    });

    test('it never feeds the drawer attention signal', () {
      // The drawer count is attention only. If History could contribute, the
      // dot would start claiming things need acknowledging that do not.
      expect(historyView, isNot(contains('notificationsUnreadCountProvider')));
      expect(historyRepo, isNot(contains('notificationsUnreadCountProvider')));
    });
  });

  group('Attention keeps its own semantics', () {
    test('the drawer signal still derives from attention alone', () {
      expect(shell, contains('notificationsUnreadCountProvider'));
      // ...and not from history, which has no count to give.
      expect(shell, isNot(contains('activityHistory')));
    });

    test('Messages unread remains Conversation authority, untouched by either', () {
      // Three questions, three answers. This asserts the third did not get
      // absorbed while the first two were being separated.
      expect(shell, contains('conversationUnread.conversations'));
    });
  });

  group('the audience policy is the server\'s', () {
    test('the client filters nothing and calls that security', () {
      // A rule enforced in a widget is a rule anyone can skip by calling the
      // endpoint. The client renders what it is given.
      for (final clientSideRule in [
        'actorUserId ==',
        'targetUserId ==',
        'LIFECYCLE',
        'conversationParty',
      ]) {
        expect(historyView, isNot(contains(clientSideRule)),
            reason: clientSideRule);
      }
    });

    test('the server keyset cursor is passed back verbatim', () {
      // Deriving a cursor from the last item's timestamp would break the total
      // ordering the backend established and let a row slip between pages.
      expect(historyRepo, contains("'cursor': cursor"));
      expect(historyView, contains('cursor: _cursor'));
    });
  });

  group('history rows tell only what the record contains', () {
    test('a null destination is honest, not hidden', () {
      final item = ActivityHistoryItem.fromJson({
        'id': 'a1',
        'activityType': 'LIVE_ENDED',
        'occurredAt': '2026-08-23T10:00:00.000Z',
        'actor': {'id': 'u1', 'displayName': 'A Person', 'handle': 'aperson'},
        'target': null,
        'context': {'conversationId': 'c1', 'name': null},
        'destination': null,
      });

      expect(item.hasDestination, isFalse);
      expect(item.destination, isNull);
      // The row is still a true statement about the past.
      expect(item.activityType, 'LIVE_ENDED');
      expect(item.occurredAt, isNotNull);
    });

    test('an absent target is absent, never invented', () {
      final item = ActivityHistoryItem.fromJson({
        'id': 'a1',
        'activityType': 'LIVE_STARTED',
        'actor': {'id': 'u1', 'displayName': 'A Person', 'handle': 'aperson'},
        'target': null,
        'context': {'conversationId': 'c1'},
        'destination': '/messages/c/c1',
      });

      expect(item.target.isEmpty, isTrue);
      expect(item.actor.displayName, 'A Person');
      expect(item.destination, '/messages/c/c1');
    });

    test('actor comes through canonical person identity', () {
      final item = ActivityHistoryItem.fromJson({
        'id': 'a1',
        'activityType': 'LIVE_STARTED',
        'actor': {
          'id': 'u1',
          'displayName': 'A Person',
          'handle': 'aperson',
          'avatarUrl': 'https://auraplatform.org/media/m1/raw',
        },
        'context': {'conversationId': 'c1'},
      });

      expect(item.actor.avatarUrl, 'https://auraplatform.org/media/m1/raw');
      expect(item.actor.label, 'A Person');
    });
  });
}
