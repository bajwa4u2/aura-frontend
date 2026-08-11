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

    test('falls back all the way to the generic "Member" id/label when no identity field exists at all', () {
      final entry = memberEntryFromMap({'bio': 'no identity fields here'});

      // stableId's fallback chain (userId -> handle -> displayName) never
      // hits an empty string because displayName itself already defaults
      // to 'Member' -- so this never returns null, it degrades to a
      // generic placeholder entry. Documenting the actual behavior here,
      // not asserting it should be different.
      expect(entry, isNotNull);
      expect(entry!.id, 'Member');
      expect(entry.userId, isEmpty);
    });

    test('displayName falls back to handle, then to "Member"', () {
      final withHandleOnly = memberEntryFromMap({
        'userId': 'user-1',
        'handle': '@carol',
      });
      expect(withHandleOnly!.displayName, 'carol');

      final withNeither = memberEntryFromMap({'userId': 'user-1'});
      expect(withNeither!.displayName, 'Member');
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
