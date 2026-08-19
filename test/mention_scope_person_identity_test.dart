// F053/F116 — THE MENTION SCOPE IS NOT RETIREMENT-OWNED.
//
// `lib/core/tagging/mention_scope_providers.dart` was reading its person
// through `CorrespondenceIdentity`, which belongs to the family governed for
// retirement under CO-RC-C7-005. That made its debt look retirement-owned. It
// is not: this file is core, and it serves DirectThreadScreen at
// `/direct/:threadId`, which no retirement discharges. A deletion that never
// reaches a file cannot clear that file's debt.
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/tagging/mention_scope_providers.dart';
import 'package:aura/core/tagging/tag_entities.dart';

void main() {
  group('member mention suggestions', () {
    test('a member row resolves through the canonical person', () {
      final out = memberTagSuggestionsForTest([
        {
          'userId': 'u-1',
          'user': {
            'displayName': 'Hana Yusuf',
            'handle': 'hana',
            'avatarUrl': 'https://cdn.example/h.png',
          },
        },
      ]);

      expect(out, hasLength(1));
      expect(out.first.kind, TagKind.member);
      expect(out.first.canonicalId, 'u-1');
      expect(out.first.display, 'Hana Yusuf');
      // Prose naming: a mention inserts '@Hana Yusuf', never '@@hana'.
      expect(out.first.insertText, '@Hana Yusuf');
      expect(out.first.subtitle, '@hana');
      expect(out.first.imageUrl, 'https://cdn.example/h.png');
    });

    test('a handle-only member is named by the canonical order, undecorated', () {
      final out = memberTagSuggestionsForTest([
        {'userId': 'u-2', 'user': {'handle': 'omar'}},
      ]);

      expect(out.first.display, 'omar');
      expect(out.first.insertText, '@omar');
    });

    test('a member the reader cannot name is SKIPPED, not offered as Member', () {
      // The old reader invented 'Member' — the same defect removed from the
      // member directory. A mention must be insertable; '@Someone' is not a
      // mention anyone can act on, so the row is dropped instead.
      final out = memberTagSuggestionsForTest([
        {'userId': 'u-3'},
      ]);

      expect(out, isEmpty);
    });

    test('a flattened row without a user envelope still resolves', () {
      final out = memberTagSuggestionsForTest([
        {'id': 'u-4', 'displayName': 'Kareem', 'handle': 'kareem'},
      ]);

      expect(out, hasLength(1));
      expect(out.first.canonicalId, 'u-4');
      expect(out.first.display, 'Kareem');
    });
  });
}
