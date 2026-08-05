import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/posts/domain/communication_continuity.dart';

void main() {
  group('ContinuityResult.fromJson', () {
    test('null raw parses to ContinuityNone', () {
      expect(ContinuityResult.fromJson(null), isA<ContinuityNone>());
    });

    test('UPDATE-shaped payload (defensive) parses to ContinuityNone', () {
      final result = ContinuityResult.fromJson({'intent': 'UPDATE'});
      expect(result, isA<ContinuityNone>());
    });

    test('ISSUE, Unrouted, empty accountabilityLifecycles', () {
      final result = ContinuityResult.fromJson({
        'intent': 'ISSUE',
        'communicationStatus': 'Unrouted',
        'accountabilityLifecycles': [],
      });
      expect(result, isA<RaiseIssueContinuity>());
      final issue = result as RaiseIssueContinuity;
      expect(issue.unrouted, isTrue);
      expect(issue.accountabilityLifecycles, isEmpty);
    });

    test('ISSUE, Routed, single institution with full field set', () {
      final result = ContinuityResult.fromJson({
        'intent': 'ISSUE',
        'communicationStatus': 'Routed',
        'accountabilityLifecycles': [
          {
            'institutionId': 'inst-a',
            'status': 'COMMITTED',
            'overdue': true,
            'acknowledgedAt': '2026-08-01T00:00:00.000Z',
            'resolutionHistory': [],
            'reopenedAt': null,
            'routedAt': '2026-06-21T08:05:37.308Z',
            'updatedAt': '2026-07-01T00:00:00.000Z',
          },
        ],
      });
      expect(result, isA<RaiseIssueContinuity>());
      final issue = result as RaiseIssueContinuity;
      expect(issue.unrouted, isFalse);
      expect(issue.accountabilityLifecycles, hasLength(1));
      final lifecycle = issue.accountabilityLifecycles.single;
      expect(lifecycle.institutionId, 'inst-a');
      expect(lifecycle.status, AccountabilityStatus.committed);
      expect(lifecycle.overdue, isTrue);
      expect(lifecycle.isAcknowledged, isTrue);
      expect(lifecycle.isReopened, isFalse);
      expect(lifecycle.resolutionHistory, isEmpty);
    });

    test('ISSUE with two institutions — parsed independently, never merged', () {
      final result = ContinuityResult.fromJson({
        'intent': 'ISSUE',
        'communicationStatus': 'Routed',
        'accountabilityLifecycles': [
          {
            'institutionId': 'inst-a',
            'status': 'RESOLVED',
            'overdue': false,
            'acknowledgedAt': null,
            'resolutionHistory': [
              {
                'statement': 'Repaved the road.',
                'resolvedByUserId': 'user-1',
                'resolvedAt': '2026-08-02T00:00:00.000Z',
              },
            ],
            'reopenedAt': null,
            'routedAt': '2026-06-21T00:00:00.000Z',
            'updatedAt': '2026-08-02T00:00:00.000Z',
          },
          {
            'institutionId': 'inst-b',
            'status': 'PENDING',
            'overdue': false,
            'acknowledgedAt': null,
            'resolutionHistory': [],
            'reopenedAt': null,
            'routedAt': '2026-06-21T00:00:00.000Z',
            'updatedAt': '2026-06-21T00:00:00.000Z',
          },
        ],
      }) as RaiseIssueContinuity;

      expect(result.accountabilityLifecycles, hasLength(2));
      final a = result.accountabilityLifecycles.firstWhere((l) => l.institutionId == 'inst-a');
      final b = result.accountabilityLifecycles.firstWhere((l) => l.institutionId == 'inst-b');
      expect(a.status, AccountabilityStatus.resolved);
      expect(a.resolutionHistory.single.statement, 'Repaved the road.');
      expect(b.status, AccountabilityStatus.pending);
      expect(b.resolutionHistory, isEmpty);
    });

    test('REOPENED status parses correctly', () {
      final result = ContinuityResult.fromJson({
        'intent': 'ISSUE',
        'communicationStatus': 'Routed',
        'accountabilityLifecycles': [
          {
            'institutionId': 'inst-a',
            'status': 'REOPENED',
            'overdue': false,
            'acknowledgedAt': null,
            'resolutionHistory': [
              {'statement': 'First fix.', 'resolvedByUserId': 'u1', 'resolvedAt': '2026-08-02T00:00:00.000Z'},
            ],
            'reopenedAt': '2026-08-05T00:00:00.000Z',
            'routedAt': '2026-06-21T00:00:00.000Z',
            'updatedAt': '2026-08-05T00:00:00.000Z',
          },
        ],
      }) as RaiseIssueContinuity;
      final lifecycle = result.accountabilityLifecycles.single;
      expect(lifecycle.status, AccountabilityStatus.reopened);
      expect(lifecycle.isReopened, isTrue);
      expect(lifecycle.resolutionHistory, hasLength(1));
    });

    test('institution no longer active status parses correctly', () {
      final result = ContinuityResult.fromJson({
        'intent': 'ISSUE',
        'communicationStatus': 'Routed',
        'accountabilityLifecycles': [
          {
            'institutionId': 'inst-a',
            'status': 'INSTITUTION_NO_LONGER_ACTIVE',
            'overdue': false,
            'acknowledgedAt': null,
            'resolutionHistory': [],
            'reopenedAt': null,
            'routedAt': '2026-06-21T00:00:00.000Z',
            'updatedAt': '2026-06-21T00:00:00.000Z',
          },
        ],
      }) as RaiseIssueContinuity;
      expect(result.accountabilityLifecycles.single.status, AccountabilityStatus.institutionNoLongerActive);
    });

    test('ASK Pending/Answered/Stale all parse correctly', () {
      final pending = ContinuityResult.fromJson({'intent': 'ASK', 'status': 'PENDING'}) as AskContinuity;
      final answered = ContinuityResult.fromJson({'intent': 'ASK', 'status': 'ANSWERED'}) as AskContinuity;
      final stale = ContinuityResult.fromJson({'intent': 'ASK', 'status': 'STALE'}) as AskContinuity;
      expect(pending.status, AskContinuityStatus.pending);
      expect(answered.status, AskContinuityStatus.answered);
      expect(stale.status, AskContinuityStatus.stale);
    });
  });
}
