import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/notifications/notification_presentation.dart';

/// Every value of the backend `NotificationType` enum, transcribed from
/// prisma/schema.prisma on 2026-08-23. If the enum grows, this list is what
/// makes the drift visible instead of letting the new kind fall silently into
/// System forever.
const kBackendNotificationTypes = <String>[
  'FOLLOW', 'FOLLOW_REQUEST', 'FOLLOW_ACCEPTED', 'LIKE', 'SAVE', 'REPLY',
  'REPOST', 'MESSAGE', 'MENTION', 'SPACE_INVITE', 'THREAD_INVITE',
  'INVITE_ACCEPTED', 'POST_PUBLISHED', 'POST_PUBLISH_FAILED', 'SYSTEM',
  'ACCOUNTABILITY_TAGGED', 'PRIORITY_PINNED', 'THREAD_ACTIVITY',
  'SPACE_ACTIVITY', 'MEETING_BOOKED', 'MEETING_REMINDER', 'MEETING_STARTING',
  'MEETING_SUMMARY_SHARED', 'ANNOUNCEMENT_PUBLISHED',
  'INSTITUTION_POST_PUBLISHED', 'MEETING_RESCHEDULED', 'MEETING_CANCELLED',
  'MEETING_RSVP_ACCEPTED', 'MEETING_RSVP_DECLINED',
  'MEETING_WAITING_ROOM_ARRIVAL', 'MODERATION_ACTION_TAKEN', 'REPORT_RESOLVED',
  'ROLE_CHANGED', 'CAPABILITY_GRANTED', 'CAPABILITY_REVOKED', 'CALL_MISSED',
  'INSTITUTION_OWNERSHIP_RECOVERED', 'MEDIA_QUARANTINED',
  'MEDIA_QUARANTINE_LIFTED', 'INVITATION', 'IDENTITY',
  'INSTITUTION_AFFILIATION', 'ROLE_OR_CREDENTIAL', 'NOT_VERIFIED',
];

void main() {
  group('notification grouping', () {
    test('every backend notification type is explicitly named', () {
      // Real gate: a kind absent from the map still RESOLVES (it falls to
      // System), so resolution alone proves nothing. This asserts each enum
      // value is NAMED, which is what forces a new kind to be classified
      // deliberately instead of being absorbed by the fallback.
      final unnamed = kBackendNotificationTypes
          .where((k) => !kNotificationGroups.containsKey(k))
          .toList();

      expect(
        unnamed,
        isEmpty,
        reason: 'unclassified notification kinds would silently fall to System',
      );
    });

    test('the classification names nothing that does not exist', () {
      // The list this replaced contained INVITE_DECLINED and INVITE_REVOKED,
      // which were never valid enum values -- dead entries nobody noticed
      // because a filter matching nothing looks the same as an empty inbox.
      final phantom = kNotificationGroups.keys
          .where((k) => !kBackendNotificationTypes.contains(k))
          .toList();

      expect(phantom, isEmpty);
    });

    test('the defects this replaced stay fixed', () {
      // The old filter looked for MESSAGE_RECEIVED while the enum value is
      // MESSAGE, so the Messages tab matched nothing at all -- 40 production
      // rows, 5 of them unread, permanently unreachable.
      expect(
        notificationGroupForKind('MESSAGE'),
        NotificationGroup.conversations,
      );

      // The single largest production kind (95 rows) belonged to no filter.
      expect(notificationGroupForKind('CALL_MISSED'), NotificationGroup.calls);

      // Meetings had no group either.
      expect(
        notificationGroupForKind('MEETING_STARTING'),
        NotificationGroup.meetings,
      );
    });

    test('an unknown kind stays reachable rather than disappearing', () {
      expect(
        notificationGroupForKind('SOMETHING_NOT_YET_INVENTED'),
        NotificationGroup.system,
      );
      expect(notificationGroupForKind(''), NotificationGroup.system);
    });

    test('grouping reads the same payload shapes the resolver does', () {
      expect(
        resolveNotificationGroup({'type': 'like'}),
        NotificationGroup.social,
      );
      expect(
        resolveNotificationGroup({
          'data': {'notificationKind': 'MEETING_BOOKED'},
        }),
        NotificationGroup.meetings,
      );
    });

    test('every group has a label', () {
      for (final group in NotificationGroup.values) {
        expect(notificationGroupLabel(group), isNotEmpty);
      }
    });
  });
}
