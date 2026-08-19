import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/directory/directory_entry.dart';

/// Identity Foundation Phase 1 -- canonical member/person identity
/// resolution, extracted from `new_conversation_screen.dart` so every
/// selection surface (personal Thread/Space creation, institution-space
/// creation) shares one resolver instead of each re-implementing its own
/// field-precedence logic.
void main() {
  group('memberEntryFromMap', () {
    test('id is always derived from userId, never resolved independently', () {
      final entry = memberEntryFromMap({
        'id': 'relationship-row-99',
        'userId': 'user-alice',
        'displayName': 'Alice Adams',
      });

      expect(entry, isNotNull);
      expect(entry!.userId, 'user-alice');
      expect(entry.id, 'user-alice');
      expect(entry.id, entry.userId);
    });

    test('falls back to handle when no id-bearing field is present', () {
      final entry = memberEntryFromMap({
        'handle': 'bob',
        'displayName': 'Bob Brown',
      });

      expect(entry!.id, 'bob');
      expect(entry.userId, isEmpty);
    });

    test('falls back to displayName when neither userId nor handle exist', () {
      final entry = memberEntryFromMap({'displayName': 'Nameless Person'});

      expect(entry!.id, 'Nameless Person');
    });

    test('an entry with NO identity field at all is dropped, not invented', () {
      // F053/F116 — this used to degrade to a row labelled 'Member' with
      // 'Member' as its own selection id: a picker row for nobody, named by a
      // word the directory invented. The canonical reader answers "there is no
      // person here", and the sibling `_candidateFromMap` on the invite screen
      // already dropped such rows. One behaviour, one authority.
      final entry = memberEntryFromMap(const <String, dynamic>{});
      expect(entry, isNull);
    });

    test('a handle-only person is named the way the whole product names one',
        () {
      final withHandleOnly = memberEntryFromMap({
        'userId': 'user-1',
        'handle': '@carol',
      });
      // The canonical order and the canonical decoration — '@carol', not the
      // directory's own bare 'carol'. The rendered '@' the payload carried is
      // stripped first as payload hygiene, so it is never doubled.
      expect(withHandleOnly!.displayName, '@carol');
      expect(withHandleOnly.handle, 'carol');
      expect(withHandleOnly.profileRoute, '/u/carol');

      final withNeither = memberEntryFromMap({'userId': 'user-1'});
      // The one neutral word the whole product shares — not 'Member'.
      expect(withNeither!.displayName, 'Someone');
      expect(withNeither.profileRoute, isNull);
    });
  });

  group('dedupeDirectoryEntries', () {
    test('collapses the same userId surfaced under different wrapper ids', () {
      final first = memberEntryFromMap({
        'id': 'wrapper-a',
        'userId': 'user-alice',
        'displayName': 'Alice Adams',
      })!;
      final second = memberEntryFromMap({
        'id': 'wrapper-b',
        'userId': 'user-alice',
        'displayName': 'Alice Adams',
      })!;

      final result = dedupeDirectoryEntries([first, second]);

      expect(result, hasLength(1));
      expect(result.single.userId, 'user-alice');
    });

    test('keeps genuinely different users distinct', () {
      final alice = memberEntryFromMap({
        'userId': 'user-alice',
        'displayName': 'Alice Adams',
      })!;
      final bob = memberEntryFromMap({
        'userId': 'user-bob',
        'displayName': 'Bob Brown',
      })!;

      final result = dedupeDirectoryEntries([alice, bob]);

      expect(result, hasLength(2));
    });

    test('falls back to normalized handle when userId is unavailable on both', () {
      final withAt = memberEntryFromMap({
        'handle': '@dana',
        'displayName': 'Dana',
      })!;
      final withoutAt = memberEntryFromMap({
        'handle': 'dana',
        'displayName': 'Dana',
      })!;

      final result = dedupeDirectoryEntries([withAt, withoutAt]);

      expect(result, hasLength(1));
    });
  });
}
