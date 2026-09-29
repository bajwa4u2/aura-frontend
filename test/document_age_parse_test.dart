import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/admin/data/operator_identity.dart';

/// The reviewer's age advice, as the server sends it (founder, 2026-09-29).
void main() {
  test('reads the advice, wrapped or bare', () {
    final advice = {
      'state': 'READ',
      'readAt': '2026-09-29T15:00:00.000Z',
      'advice': {
        'documentDateOfBirth': '2010-02-04',
        'source': 'MRZ',
        'age': 16,
        'bucket': 'EU_EEA',
        'publicationAge': 18,
        'oldEnoughToPublish': false,
        'declaredDateOfBirth': '2006-02-04',
        'declaredMatches': false,
        'differsByYears': 4,
      },
    };
    for (final raw in [advice, {'ok': true, 'data': advice}]) {
      final a = DocumentAge.fromJson(raw);
      expect(a.isRead, isTrue);
      expect(a.age, 16);
      expect(a.oldEnoughToPublish, isFalse);
      expect(a.differsByYears, 4);
    }
  });

  test('unread and unreadable are not a date', () {
    expect(DocumentAge.fromJson({'state': 'UNREAD'}).isRead, isFalse);
    expect(DocumentAge.fromJson({'ok': true, 'data': {'state': 'UNREADABLE'}}).state, 'UNREADABLE');
    expect(DocumentAge.fromJson(null).state, 'UNREAD');
    // A submission's own state is not an age state.
    expect(DocumentAge.fromJson({'state': 'PENDING_REVIEW'}).state, 'UNREAD');
  });
}
