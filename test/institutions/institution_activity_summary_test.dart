import 'package:aura/features/institutions/activity/institution_activity_screen.dart';
import 'package:aura/features/institutions/domain/institution_activity_event.dart';
import 'package:flutter_test/flutter_test.dart';

/// The events the backend sends for institution activity (fix/institutions-1.7)
/// read as plain sentences: field names never reach the screen.
InstitutionActivityEvent _event(
  String kind, {
  Map<String, dynamic>? actor,
  Map<String, dynamic>? metadata,
  String? targetType,
}) =>
    InstitutionActivityEvent.fromJson({
      'id': 'e1',
      'institutionId': 'i1',
      'actorUserId': actor == null ? null : 'u1',
      'kind': kind,
      'targetType': targetType,
      'targetId': 't1',
      'metadata': metadata,
      'visibility': 'ADMIN',
      'createdAt': '2026-10-21T20:00:00.000Z',
      if (actor != null) 'actor': actor,
    });

const _amina = {'id': 'u1', 'handle': 'amina', 'displayName': 'Amina'};

void main() {
  test('join requests name who asked and who decided', () {
    expect(
      institutionActivitySummary(_event('JOIN_REQUEST_CREATED',
          actor: _amina, targetType: 'INSTITUTION_JOIN_REQUEST')),
      'Amina requested to join.',
    );
    expect(
      institutionActivitySummary(_event('JOIN_REQUEST_APPROVED',
          actor: _amina, metadata: {'requesterUserId': 'u2'})),
      'Amina approved a join request.',
    );
    expect(
      institutionActivitySummary(_event('JOIN_REQUEST_REJECTED',
          actor: _amina, metadata: {'requesterUserId': 'u2'})),
      'Amina declined a join request.',
    );
    expect(
      institutionActivitySummary(_event('MEMBER_JOINED',
          actor: _amina, metadata: {'role': 'MEMBER', 'via': 'JOIN_REQUEST'})),
      'Amina joined the institution.',
    );
  });

  test('a profile change names its parts in words, never field names', () {
    expect(
      institutionActivitySummary(_event('INSTITUTION_UPDATED',
          actor: _amina,
          metadata: {
            'changedFields': ['name', 'description'],
          })),
      'Amina updated the name and description.',
    );
    expect(
      institutionActivitySummary(_event('INSTITUTION_UPDATED',
          actor: _amina,
          metadata: {
            'changedFields': ['logoUrl'],
          })),
      'Amina updated the logo.',
    );
    expect(
      institutionActivitySummary(
          _event('INSTITUTION_UPDATED', actor: _amina, metadata: {})),
      'Amina updated the institution profile.',
    );
  });

  test('parts lists read naturally and never show raw names', () {
    expect(institutionProfilePartsWords(['xUrl', 'tagline', 'city']),
        'the X link, tagline and city');
    expect(
        institutionProfilePartsWords(
            ['name', 'tagline', 'city', 'country', 'mission']),
        'the name, tagline and 3 other parts');
    expect(institutionProfilePartsWords(['somethingNew']), 'the profile');
    expect(institutionProfilePartsWords(null), isNull);
  });

  test('suspension has no actor', () {
    expect(institutionActivitySummary(_event('INSTITUTION_SUSPENDED')),
        'Institution was suspended.');
  });
}
