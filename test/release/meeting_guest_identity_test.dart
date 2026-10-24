import 'package:aura/features/realtime/domain/realtime_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// A MEETING GUEST IS ONE PERSON, NAMED BY THEIR GUEST SESSION.
///
/// 2026-10-23: a guest's participant row (userId null, guestSessionId set)
/// showed as a second, nameless "Participant" beside the guest.
void main() {
  test('a guest row is identified by its guest session', () {
    final p = RealtimeParticipant.fromJson(const {
      'id': 'row-1',
      'userId': null,
      'guestSessionId': 'guest-1',
      'role': 'PARTICIPANT',
      'joinState': 'ACTIVE',
    });
    expect(p.id, 'row-1');
    expect(p.userId, 'guest-1');
  });

  test('a member keeps their account id', () {
    final p = RealtimeParticipant.fromJson(const {
      'id': 'row-2',
      'userId': 'user-1',
      'role': 'HOST',
      'joinState': 'ACTIVE',
    });
    expect(p.userId, 'user-1');
  });

  test('a guest keeps their name when the room is rebuilt from the session', () {
    final p = RealtimeParticipant.fromJson(const {
      'id': 'row-1',
      'userId': null,
      'guestSessionId': 'guest-1',
      'guestSession': {'guestName': 'Phone Guest'},
      'user': null,
    });
    expect(p.displayName, 'Phone Guest');
  });
}
