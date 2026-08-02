// AXR-1 — Notification Synchronization: type→module projection contract.
//
// Pins the rule that module badges and the global bell derive from the
// same rows: unread rows count toward exactly their owning module, read
// rows count nowhere, and Activity-only types map to no module.
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/updates/module_attention.dart';

Map<String, dynamic> n(String type, {String? readAt}) => {
      'id': 'N-$type-${readAt ?? 'unread'}',
      'type': type,
      'readAt': readAt ?? '',
    };

void main() {
  test('unread events project into their owning modules', () {
    final attention = moduleAttentionFromItems([
      n('MESSAGE'),
      n('MESSAGE'),
      n('SPACE_INVITE'),
      n('FOLLOW'),
      n('ANNOUNCEMENT_PUBLISHED'),
      n('MEETING_REMINDER'),
      n('MEETING_STARTING'),
      n('MEETING_CANCELLED'),
      n('MENTION'),
      n('REPLY'),
    ]);
    expect(attention.messages, 2);
    expect(attention.institutions, 3);
    expect(attention.meetings, 3);
    expect(attention.mentions, 2);
  });

  test('read events count nowhere', () {
    final attention = moduleAttentionFromItems([
      n('MESSAGE', readAt: '2026-07-21T00:00:00Z'),
      n('MENTION', readAt: '2026-07-21T00:00:00Z'),
    ]);
    expect(attention.messages, 0);
    expect(attention.mentions, 0);
  });

  test('Activity-only types map to no module', () {
    expect(attentionModuleForType('LIKE'), isNull);
    expect(attentionModuleForType('SYSTEM'), isNull);
    expect(attentionModuleForType('POST_PUBLISHED'), isNull);
  });

  test('every meeting lifecycle type owns the Meetings module', () {
    for (final t in [
      'MEETING_BOOKED',
      'MEETING_REMINDER',
      'MEETING_STARTING',
      'MEETING_SUMMARY_SHARED',
      'MEETING_RESCHEDULED',
      'MEETING_CANCELLED',
      'MEETING_RSVP_ACCEPTED',
      'MEETING_RSVP_DECLINED',
      'MEETING_WAITING_ROOM_ARRIVAL',
    ]) {
      expect(attentionModuleForType(t), AttentionModule.meetings,
          reason: t);
    }
  });

  test('institution governance and publication types own Institutions', () {
    for (final t in [
      'FOLLOW',
      'ANNOUNCEMENT_PUBLISHED',
      'INSTITUTION_POST_PUBLISHED',
      'ROLE_CHANGED',
      'CAPABILITY_GRANTED',
      'CAPABILITY_REVOKED',
    ]) {
      expect(attentionModuleForType(t), AttentionModule.institutions,
          reason: t);
    }
  });

  test('unknown future types degrade to Activity-only, never crash', () {
    final attention = moduleAttentionFromItems([n('SOME_FUTURE_TYPE')]);
    expect(attention.messages + attention.institutions +
        attention.meetings + attention.mentions, 0);
  });
}
