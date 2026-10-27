import 'dart:convert';
import 'dart:io';

import 'package:aura/features/admin/areas/subjects_area.dart';
import 'package:aura/features/admin/data/admin_models.dart';
import 'package:flutter_test/flutter_test.dart';

// The operator directory shows when each person joined and was last seen
// (2026-10-27): newest-first with no dates made six accounts from 2 to 22 Oct
// read as daily sign-ups.
void main() {
  test('the server contract carries lastSeenAt, seen and never-seen', () {
    final body = jsonDecode(
        File('test/contracts/admin/users.list.json').readAsStringSync()) as Map;
    final items = (body['items'] as List).cast<Map>();
    final people = items.map((m) => AdminUserSummary.fromJson(Map<String, dynamic>.from(m))).toList();
    expect(people.first.lastActiveAt, DateTime.parse('2026-10-26T13:09:00.000Z'));
    expect(people.skip(1).every((p) => p.lastActiveAt == null), isTrue);
  });

  test('the row line names both dates, or says never signed in', () {
    final joined = DateTime.utc(2026, 10, 7, 19, 23);
    final seen = subjectSeenLine(joined, DateTime.utc(2026, 10, 26, 13, 9));
    expect(seen, startsWith('Joined '));
    expect(seen, contains(' · Last seen '));
    expect(subjectSeenLine(joined, null), endsWith(' · Never signed in'));
  });
}
