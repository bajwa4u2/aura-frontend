// ENGAGEMENT CONTENT CONTRACT — ONE FIELD, ONE MEANING.
//
// The client read `post['body']` (falling back to a top-level `postBody`)
// while the producer emits `post.text`. Neither key it looked for is ever
// sent, so `record.postText` was always null and BOTH engagement screens —
// which guard with `if (content.isNotEmpty)` — rendered the post as absent
// rather than as broken. A silent blank, not an error.
//
// Canonical field, established from the producer and not from naming taste:
//
//   prisma schema        Post.text
//   producer             EngagementRecordDto.post.text
//   client post model    feed/domain/post.dart reads json['text']
//
// `body` was never a second contract to be tolerant of. There is no alias
// here, and these tests exist so the wrong-field assumption cannot return
// quietly the way it arrived.
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/institutions/engagement/engagement_models.dart';

/// Exactly the shape `InstitutionEngagementService.toDto` produces.
Map<String, dynamic> producerRecord({
  String? text = 'What is your policy on winter closures?',
  String postCreatedAt = '2026-06-20T09:00:00.000Z',
}) =>
    {
      'id': 'rec-1',
      'status': 'PENDING',
      'routedAt': '2026-06-20T10:00:00.000Z',
      'topic': 'GOVERNMENT',
      'participationMode': 'RESPONDING',
      'post': {
        'id': 'post-1',
        'text': text,
        'intent': 'ASK',
        'primaryTopic': 'GOVERNMENT',
        'jurisdictionId': 'jur-1',
        'createdAt': postCreatedAt,
        'author': {
          'id': 'u-1',
          'handle': 'alice',
          'displayName': 'Alice',
          'avatarUrl': null,
        },
      },
    };

void main() {
  group('RoutedRecord content contract', () {
    test('the real producer shape yields the post content', () {
      final r = RoutedRecord.fromJson(producerRecord());

      expect(r.postText, 'What is your policy on winter closures?');
      expect(r.postId, 'post-1');
    });

    test('the old wrong-field assumption cannot silently return', () {
      // A payload carrying ONLY the key the client used to look for must NOT
      // resolve. If someone reintroduces a `body` alias to "be tolerant",
      // this fails — which is the point: tolerance is what hid the mismatch.
      final r = RoutedRecord.fromJson(const {
        'id': 'rec-2',
        'status': 'PENDING',
        'post': {'id': 'post-2', 'body': 'content under the wrong key'},
      });

      expect(r.postText, isNull);
    });

    test('a genuinely empty post is null, not an empty string', () {
      final r = RoutedRecord.fromJson(producerRecord(text: null));
      expect(r.postText, isNull);
    });

    test('the byline timestamp is the POST time, not the routing time', () {
      // routedAt (when the post reached this institution) and post.createdAt
      // (when the person wrote it) are different facts. Both screens print
      // this immediately after the author's name, so it is the second.
      final r = RoutedRecord.fromJson(producerRecord());

      expect(r.postCreatedAt, DateTime.parse('2026-06-20T09:00:00.000Z'));
      expect(r.postCreatedAt, isNot(DateTime.parse('2026-06-20T10:00:00.000Z')));
    });

    test('the record still carries its own engagement state', () {
      final r = RoutedRecord.fromJson(producerRecord());

      expect(r.id, 'rec-1');
      expect(r.status, RoutedRecordStatus.pending);
      expect(r.intent, RecordIntent.ask);
      expect(r.participationMode, 'RESPONDING');
      expect(r.authorName, 'Alice');
    });
  });
}
