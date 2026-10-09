import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// MEMBER STANDING IN PLAIN WORDS (DD-42 phase 2, 2026-10-09): Owner, Admin,
/// Official voice, Meeting host, Member; who holds a staff seat comes from
/// the server's own rule and is shown to those who manage members.
void main() {
  final src = File('lib/features/institutions/presentation/institution_members_screen.dart').readAsStringSync();

  test('standing reads in plain words', () {
    expect(src.contains("_pill('Official voice'"), isTrue);
    expect(src.contains("_pill('Meeting host'"), isTrue);
    expect(src.contains("_pill('Representative'"), isFalse);
    expect(src.contains("'Make official voice'"), isTrue);
    expect(src.contains("'Make meeting host'"), isTrue);
  });

  test('seats come from the server and are shown to those who manage members', () {
    expect(src.contains("member['holdsSeat'] == true"), isTrue);
    expect(src.contains("holdsSeat && _canManageMembers"), isTrue);
    expect(src.contains("staff seats in use"), isTrue);
    // The app never re-derives the rule from roles or capabilities.
    expect(RegExp(r"holdsSeat\s*=\s*.*(OWNER|ADMIN|OFFICIAL_REPRESENTATION)").hasMatch(src), isFalse);
  });

  test('the subtitle promises only what the page shows', () {
    expect(src.contains('pending join requests'), isFalse);
  });
}
