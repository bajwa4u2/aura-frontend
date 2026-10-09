import 'dart:io';

import 'package:aura/features/institutions/presentation/answer_record_section.dart';
import 'package:flutter_test/flutter_test.dart';

/// ANSWERING THE PUBLIC (2026-10-09): the topic setup promised responses and
/// resolutions are visible on the public profile; this is where.
void main() {
  test('the record reads counts and the latest resolutions', () {
    final r = AnswerRecord.fromJson({
      'received': 11,
      'waiting': 2,
      'answered': 5,
      'committed': 1,
      'resolved': 3,
      'recentResolutions': [
        {
          'postId': 'p1',
          'issue': 'The streetlight on Goddard Rd is out.',
          'statement': 'Replaced on 8 October by the city crew.',
          'resolvedAt': '2026-10-08T15:00:00Z',
        },
      ],
    });
    expect(r.received, 11);
    expect(r.waiting + r.answered + r.committed + r.resolved, 11);
    expect(r.recentResolutions.single.statement, 'Replaced on 8 October by the city crew.');
  });

  test('the institution page carries it, and it hides when nothing reached the institution', () {
    final page = File('lib/features/institutions/presentation/institution_detail_screen.dart').readAsStringSync();
    expect(page.contains('AnswerRecordSection(slug: institution.slug)'), isTrue);
    final section = File('lib/features/institutions/presentation/answer_record_section.dart').readAsStringSync();
    expect(section.contains('record.received == 0) return const SizedBox.shrink()'), isTrue);
  });
}
