import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// THE INBOX ACTION MODEL, PINNED FROM THE OUTSIDE.
///
/// Founder ruling 2026-08-24, §7–§9 and §24. The backend keeps pin, archive,
/// clear, unread and leave as five separate authorities; the client can still
/// undo that separation by wiring a gesture to the wrong one, or by letting a
/// widget mutate state directly and drift from the sheet.
///
/// These assert the properties a later change could quietly break:
///
///   * swipe reaches only the two REVERSIBLE actions;
///   * delete is never a swipe;
///   * delete is worded as the viewer's own history, not global destruction;
///   * swipe is gated on the PLATFORM, not the window width;
///   * no widget performs an inbox mutation without going through the one
///     place that also refreshes both ledgers.
void main() {
  String codeOnly(String src) => src
      .split(String.fromCharCode(10))
      .where((l) {
        final t = l.trimLeft();
        return !t.startsWith('//') && !t.startsWith('///') && !t.startsWith('*');
      })
      .join(String.fromCharCode(10));

  final actions = codeOnly(
    File('lib/features/conversation/presentation/conversation_row_actions.dart')
        .readAsStringSync(),
  );
  final row = codeOnly(
    File('lib/features/conversation/presentation/conversation_row.dart')
        .readAsStringSync(),
  );
  final landing = codeOnly(
    File('lib/features/conversation/presentation/messages_screen.dart')
        .readAsStringSync(),
  );

  group('swipe reaches only reversible actions', () {
    test('right swipe pins, left swipe archives', () {
      expect(row, contains('DismissDirection.startToEnd'));
      expect(row, contains('togglePin'));
      expect(row, contains('toggleArchive'));
    });

    test('delete is NOT reachable by swipe', () {
      // The ruled boundary: a destructive action must never be one accidental
      // gesture away.
      final confirmBlock = row.substring(
        row.indexOf('confirmDismiss'),
        row.indexOf('dismissThresholds'),
      );
      expect(confirmBlock.contains('deleteFromMyHistory'), isFalse);
      expect(confirmBlock.contains('clearHistory'), isFalse);
      expect(confirmBlock.contains('leave'), isFalse);
    });

    test('the row is never actually dismissed', () {
      // A row that vanished on swipe would look like deletion — exactly the
      // conflation this reconstruction exists to end. It stays, and its state
      // changes.
      expect(row, contains('return false'));
    });

    test('a deliberate threshold guards against stray scrolls', () {
      expect(row, contains('dismissThresholds'));
    });
  });

  group('delete says what it actually does', () {
    test('it is confirmed', () {
      expect(actions, contains('showDialog<bool>'));
      expect(actions, contains("if (confirmed != true) return"));
    });

    test('the wording is the viewer\'s own history, not global destruction',
        () {
      final src =
          File('lib/features/conversation/presentation/conversation_row_actions.dart')
              .readAsStringSync();
      expect(src, contains('YOUR conversation history'));
      expect(src, contains('they keep their own copy'));
      // And that it is not the reversible one.
      expect(src, contains('cannot be undone'));
      expect(src, contains('archive it instead'));
    });

    test('leave is worded as participation, not deletion', () {
      final src =
          File('lib/features/conversation/presentation/conversation_row_actions.dart')
              .readAsStringSync();
      expect(src, contains('Your history is not deleted'));
    });

    test('delete and leave are different methods', () {
      // One operation with a flag is how the two become indistinguishable.
      expect(actions, contains('deleteFromMyHistory'));
      expect(actions, contains('Future<void> leave('));
    });
  });

  group('every entry point reaches the same authority', () {
    test('the row mutates nothing directly', () {
      // No repository call in the row: it asks ConversationActions, which is
      // also the only place that refreshes both ledgers.
      expect(row.contains('conversationsRepositoryProvider'), isFalse);
      expect(row, contains('ConversationActions'));
    });

    test('the landing mutates nothing directly either', () {
      expect(landing.contains('setPinned'), isFalse);
      expect(landing.contains('clearHistory'), isFalse);
      expect(landing.contains('setArchived'), isFalse);
    });

    test('every ledger refreshes after every action', () {
      // The inbox list, the ARCHIVED list, and the unread authority the badge
      // reads. Refreshing some and not others is how they start disagreeing.
      //
      // The archived one was learned on a physical Pixel, 2026-08-24:
      // unarchiving from inside the archived view left the row sitting there
      // while it simultaneously reappeared in the inbox — the same
      // conversation in both lists at once.
      expect(actions, contains('conversationsListProvider'));
      expect(actions, contains('archivedConversationsProvider'));
      expect(actions, contains('conversationUnreadProvider'));
    });

    test('the archived ledger is shared, not private to the screen', () {
      // A ledger the one mutating authority cannot see is a ledger that goes
      // stale. It belongs beside the inbox list in the data layer.
      final repo = File(
        'lib/features/conversation/data/conversations_repository.dart',
      ).readAsStringSync();
      expect(repo, contains('archivedConversationsProvider'));
      expect(landing.contains('final archivedConversationsProvider'), isFalse);
    });

    test('touch and pointer open the SAME sheet', () {
      expect(row, contains('onLongPress: openSheet'));
      expect(row, contains('onSecondaryTap: openSheet'));
      // And it is discoverable without either gesture.
      expect(row, contains('_OverflowButton'));
    });

    test('the sheet carries the complete action set', () {
      for (final label in [
        'Unpin',
        'Mark as read',
        'Mark as unread',
        'Mute',
        'Archive',
        'Leave conversation',
        'Delete from my history',
      ]) {
        expect(actions, contains(label), reason: label);
      }
    });
  });

  group('the sheet never outgrows the viewport', () {
    test('it is height-bounded and scrollable', () {
      // Founder live finding, 2026-08-24: on a short window the sheet ran past
      // the bottom edge with no scroll, so Leave and Delete were rendered but
      // unreachable. A destructive action hidden below the fold is worse than
      // one that is absent — the person cannot tell it exists.
      expect(actions, contains('ConstrainedBox'));
      expect(actions, contains('maxHeight'));
      expect(actions, contains('SingleChildScrollView'));
    });

    test('the message sheet is bounded too — it is the longer one', () {
      final interactions = codeOnly(
        File('lib/features/conversation/presentation/message_interactions.dart')
            .readAsStringSync(),
      );
      expect(interactions, contains('ConstrainedBox'));
      expect(interactions, contains('SingleChildScrollView'));
    });
  });

  group('swipe is a platform idiom, not a width', () {
    test('it is decided from TargetPlatform', () {
      // A narrow desktop window is still a pointer; a wide tablet is still
      // touch. Deciding from width gives a desktop user a gesture they cannot
      // perform and takes one from a tablet user who expects it.
      expect(landing, contains('Theme.of(context).platform'));
      expect(landing, contains('TargetPlatform.android'));
      expect(landing, contains('TargetPlatform.windows'));
      expect(landing.contains('maxWidth <'), isFalse);
    });

    test('the row takes it as an explicit input', () {
      expect(row, contains('required this.allowSwipe'));
      expect(row, contains('if (!allowSwipe) return'));
    });
  });

  group('pinned is a region, not a re-sort', () {
    test('the landing separates pinned from the rest', () {
      expect(landing, contains('c.pinned'));
      expect(landing, contains('_RegionLabel'));
    });

    test('recency is not recomputed inside the region', () {
      // Pinning decides which chronology you read first; it does not rewrite
      // chronology. No sort call in the landing.
      expect(landing.contains('..sort('), isFalse);
      expect(landing.contains('.sort((') , isFalse);
    });
  });

  group('attention states stay distinct', () {
    test('a count and an asserted-unread dot are different marks', () {
      // Deriving "1" for a deliberate mark-unread would be a small lie: there
      // is no number to state.
      expect(row, contains('unreadCount > 0'));
      expect(row, contains('manuallyUnread'));
    });

    test('a retraction previews as a withdrawal, not as its old text', () {
      expect(row, contains('withdrew a message'));
    });

    test('attachment-only continuity describes its content', () {
      for (final what in ['a photo', 'a video', 'a voice message', 'a file']) {
        expect(row, contains(what), reason: what);
      }
    });
  });
}
