import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/notifications/notification_presentation.dart';

// Release-Client Cross-System Quality Doctrine — Legacy Global Runtime
// Overlay Cleanup (roadmap item 11). Pure-function coverage for the
// consolidated title/body resolver that replaced NotificationBridge's two
// nearly-duplicate copies, and specifically proves the "vague" defect is
// gone: a bare actor name or the literal 'Update' is no longer the outcome
// for any recognized notification kind.

void main() {
  group('resolveNotificationTitle — kind-specific phrases', () {
    test('LIKE with an actor produces a specific, non-vague title', () {
      final title = resolveNotificationTitle({
        'type': 'LIKE',
        'actor': {'displayName': 'Amjad'},
      });
      expect(title, 'Amjad liked your post');
    });

    test('FOLLOW with an actor', () {
      final title = resolveNotificationTitle({
        'type': 'FOLLOW',
        'actor': {'displayName': 'Iffat'},
      });
      expect(title, 'Iffat started following you');
    });

    test('MESSAGE with an actor', () {
      final title = resolveNotificationTitle({
        'type': 'MESSAGE',
        'actor': {'handle': 'amjad'},
      });
      expect(title, 'amjad sent you a message');
    });

    test('MENTION with an actor', () {
      final title = resolveNotificationTitle({
        'type': 'MENTION',
        'actor': {'displayName': 'Amjad'},
      });
      expect(title, 'Amjad mentioned you');
    });

    test('a recognized kind with NO actor still produces a specific title, not a bare fallback', () {
      final title = resolveNotificationTitle({'type': 'REPLY'});
      expect(title, 'Replied to your post');
    });

    test('INSTITUTION_POST_PUBLISHED', () {
      final title = resolveNotificationTitle({
        'type': 'INSTITUTION_POST_PUBLISHED',
        'actor': {'displayName': 'Aura Institute'},
      });
      expect(title, 'Aura Institute published a new post');
    });

    test('MEETING_REMINDER', () {
      final title = resolveNotificationTitle({
        'type': 'MEETING_REMINDER',
        'actor': {'displayName': 'Amjad'},
      });
      expect(title, 'Amjad has an upcoming meeting');
    });
  });

  group('resolveNotificationTitle — calls stay routed to call presentation, unchanged', () {
    test('missed call', () {
      final title = resolveNotificationTitle({
        'type': 'CALL',
        'callState': 'MISSED',
        'actor': {'displayName': 'Amjad'},
      });
      expect(title, 'Missed call from Amjad');
    });

    test('call ended, no actor', () {
      final title = resolveNotificationTitle({
        'type': 'REALTIME',
        'callState': 'ENDED',
      });
      expect(title, 'Call ended');
    });

    test('ringing call with an actor', () {
      final title = resolveNotificationTitle({
        'type': 'LIVE',
        'actor': {'displayName': 'Iffat'},
      });
      expect(title, 'Iffat started a call');
    });
  });

  group('resolveNotificationTitle — fallback chain', () {
    test('unrecognized kind with a backend-provided title uses it over a bare actor name', () {
      final title = resolveNotificationTitle({
        'type': 'SYSTEM',
        'title': 'Backend-provided title',
        'actor': {'displayName': 'Should not appear'},
      });
      expect(title, 'Backend-provided title');
    });

    test('unrecognized kind with only an actor falls back to the bare name', () {
      final title = resolveNotificationTitle({
        'type': 'SOME_FUTURE_KIND',
        'actor': {'displayName': 'Amjad'},
      });
      expect(title, 'Amjad');
    });

    test('genuinely unrecognized kind with nothing else falls back to Update — last resort only', () {
      final title = resolveNotificationTitle({'type': 'SOME_FUTURE_KIND'});
      expect(title, 'Update');
    });
  });

  group('resolveNotificationBody', () {
    test('prefers an explicit body over previewText/data.body', () {
      final body = resolveNotificationBody({
        'body': 'Explicit body',
        'data': {'previewText': 'preview', 'body': 'data body'},
      });
      expect(body, 'Explicit body');
    });

    test('falls back to data.previewText, then data.body', () {
      expect(
        resolveNotificationBody({
          'data': {'previewText': 'preview text'},
        }),
        'preview text',
      );
      expect(
        resolveNotificationBody({
          'data': {'body': 'fallback body'},
        }),
        'fallback body',
      );
    });

    test('empty when nothing is present', () {
      expect(resolveNotificationBody(const {}), '');
    });
  });
}
