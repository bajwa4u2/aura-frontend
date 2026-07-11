import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/meetings/domain/meeting_workspace.dart';

void main() {
  test('parses operational workspace categories without policy inference', () {
    final workspace = MeetingWorkspace.fromJson({
      'scope': {'type': 'INSTITUTION', 'institutionId': 'inst-1'},
      'generatedAt': '2026-07-11T12:00:00.000Z',
      'needsAttention': [
        {
          'meeting': _meetingJson('meeting-1', state: 'ACTIVE'),
          'relationship': {'kind': 'HOSTING', 'role': 'HOST'},
          'pendingGuestCount': 2,
          'startsSoon': true,
          'needsFollowUp': false,
        },
      ],
      'todayAndNext': [],
      'invitations': [
        {
          'meeting': _meetingJson('meeting-2'),
          'relationship': {
            'kind': 'INVITED',
            'role': 'PARTICIPANT',
            'rsvpStatus': 'PENDING',
          },
          'pendingGuestCount': 0,
          'startsSoon': false,
          'needsFollowUp': false,
        },
      ],
      'booking': {
        'profiles': [
          {
            'id': 'profile-1',
            'name': 'Founder conversations',
            'slug': 'founder',
            'meetingTitle': 'Founder conversation',
            'durationOptions': [30, 60],
            'defaultDuration': 30,
            'timezone': 'UTC',
            'isActive': true,
            'allowGuests': true,
            'waitingRoomEnabled': false,
            'requireApproval': true,
            'publicUrl': '/i/aura/meet/founder',
            'status': 'ACTIVE',
            'windowsCount': 3,
            'bookingCount': 4,
          },
        ],
        'activeCount': 1,
        'incompleteCount': 0,
        'canManage': true,
      },
      'followUp': [],
      'past': [],
    });

    expect(workspace.scopeType, 'INSTITUTION');
    expect(workspace.institutionId, 'inst-1');
    expect(workspace.needsAttention.single.pendingGuestCount, 2);
    expect(workspace.needsAttention.single.relationship.label, 'Hosting');
    expect(workspace.invitations.single.relationship.label, 'Invited');
    expect(workspace.booking.profiles.single.statusLabel, 'Active');
    expect(workspace.booking.profiles.single.publicUrl, '/i/aura/meet/founder');
    expect(workspace.isEmpty, isFalse);
  });

  test('empty workspace is detected as a product empty state', () {
    final workspace = MeetingWorkspace.fromJson({
      'scope': {'type': 'PERSONAL', 'institutionId': null},
      'generatedAt': '2026-07-11T12:00:00.000Z',
      'needsAttention': [],
      'todayAndNext': [],
      'invitations': [],
      'booking': {
        'profiles': [],
        'activeCount': 0,
        'incompleteCount': 0,
        'canManage': true,
      },
      'followUp': [],
      'past': [],
    });

    expect(workspace.isEmpty, isTrue);
  });
}

Map<String, dynamic> _meetingJson(String id, {String state = 'SCHEDULED'}) => {
  'id': id,
  'title': 'Workspace meeting',
  'description': null,
  'type': 'SCHEDULED',
  'state': state,
  'meetingCode': '123456',
  'joinUrl': 'https://aura.app/meetings/join/123456',
  'scheduledAt': '2026-07-12T12:00:00.000Z',
  'durationMinutes': 30,
  'timezone': 'UTC',
  'visibility': 'PRIVATE',
  'waitingRoomEnabled': true,
  'recordingEnabled': false,
  'screenShareEnabled': true,
  'chatEnabled': true,
  'allowGuests': false,
  'guestApprovalRequired': true,
  'participants': [],
  'createdAt': '2026-07-11T12:00:00.000Z',
  'updatedAt': '2026-07-11T12:00:00.000Z',
};
