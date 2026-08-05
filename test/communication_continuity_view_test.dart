import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/auth/session_providers.dart';
import 'package:aura/core/institutions/institution_access_provider.dart';
import 'package:aura/features/posts/data/continuity_providers.dart';
import 'package:aura/features/posts/domain/communication_continuity.dart';
import 'package:aura/features/posts/presentation/widgets/communication_continuity_view.dart';

const _postId = 'post-1';
const _authorId = 'author-1';

Widget _harness({
  required ContinuityResult? result,
  String? postIntent,
  String? viewerId = 'author-1',
  List<MemberAffiliation> affiliations = const [],
}) {
  return ProviderScope(
    overrides: [
      continuityProvider.overrideWith((ref, id) async => result),
      authMeDataProvider.overrideWith(
        (ref) async => viewerId == null ? {} : {'id': viewerId},
      ),
      myAffiliationsProvider.overrideWith((ref) => affiliations),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: CommunicationContinuityView(
          postId: _postId,
          postAuthorId: _authorId,
          postIntent: postIntent,
        ),
      ),
    ),
  );
}

MemberAffiliation _affiliation(String id, {String role = 'MEMBER', bool canSpeakOfficially = false}) {
  return MemberAffiliation(
    id: id,
    name: 'Institution $id',
    slug: 'inst-$id',
    role: role,
    canSpeakOfficially: canSpeakOfficially,
    isVerified: true,
  );
}

void main() {
  testWidgets('renders nothing for Share Update (null intent-equivalent)', (tester) async {
    await tester.pumpWidget(_harness(result: const ContinuityNone(), postIntent: 'UPDATE'));
    await tester.pumpAndSettle();
    expect(find.byType(CommunicationContinuityView), findsOneWidget);
    expect(find.text('Communication status'), findsNothing);
  });

  testWidgets('renders nothing when postIntent is null', (tester) async {
    await tester.pumpWidget(_harness(result: const ContinuityNone(), postIntent: null));
    await tester.pumpAndSettle();
    expect(find.text('Communication status'), findsNothing);
  });

  group('Ask', () {
    testWidgets('Pending renders nothing (informal, no status shown)', (tester) async {
      await tester.pumpWidget(
        _harness(result: const AskContinuity(status: AskContinuityStatus.pending), postIntent: 'ASK'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Communication status'), findsNothing);
    });

    testWidgets('Answered shows an Answered card', (tester) async {
      await tester.pumpWidget(
        _harness(result: const AskContinuity(status: AskContinuityStatus.answered), postIntent: 'ASK'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Communication status'), findsOneWidget);
      expect(find.text('Answered.'), findsOneWidget);
    });

    testWidgets('Stale shows a no-fault message', (tester) async {
      await tester.pumpWidget(
        _harness(result: const AskContinuity(status: AskContinuityStatus.stale), postIntent: 'ASK'),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining("don't always find an answer"), findsOneWidget);
    });
  });

  group('Raise Issue', () {
    testWidgets('Unrouted shows the no-institution-matched message', (tester) async {
      await tester.pumpWidget(
        _harness(
          result: const RaiseIssueContinuity(unrouted: true, accountabilityLifecycles: []),
          postIntent: 'ISSUE',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('has not yet been routed'), findsOneWidget);
    });

    testWidgets('single institution Pending shows Pending status', (tester) async {
      final lifecycle = AccountabilityLifecycle(
        institutionId: 'inst-a',
        status: AccountabilityStatus.pending,
        overdue: false,
        acknowledgedAt: null,
        resolutionHistory: const [],
        reopenedAt: null,
        routedAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      await tester.pumpWidget(
        _harness(
          result: RaiseIssueContinuity(unrouted: false, accountabilityLifecycles: [lifecycle]),
          postIntent: 'ISSUE',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Pending'), findsOneWidget);
    });

    testWidgets('Acknowledge button is hidden when the viewer has no affiliation with the institution', (tester) async {
      final lifecycle = AccountabilityLifecycle(
        institutionId: 'inst-a',
        status: AccountabilityStatus.pending,
        overdue: false,
        acknowledgedAt: null,
        resolutionHistory: const [],
        reopenedAt: null,
        routedAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      await tester.pumpWidget(
        _harness(
          result: RaiseIssueContinuity(unrouted: false, accountabilityLifecycles: [lifecycle]),
          postIntent: 'ISSUE',
          affiliations: const [],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Acknowledge'), findsNothing);
    });

    testWidgets('Acknowledge button appears when the viewer has an affiliation with that institution', (tester) async {
      final lifecycle = AccountabilityLifecycle(
        institutionId: 'inst-a',
        status: AccountabilityStatus.pending,
        overdue: false,
        acknowledgedAt: null,
        resolutionHistory: const [],
        reopenedAt: null,
        routedAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      await tester.pumpWidget(
        _harness(
          result: RaiseIssueContinuity(unrouted: false, accountabilityLifecycles: [lifecycle]),
          postIntent: 'ISSUE',
          affiliations: [_affiliation('inst-a')],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Acknowledge'), findsOneWidget);
    });

    testWidgets('Resolve button is hidden for a plain member', (tester) async {
      final lifecycle = AccountabilityLifecycle(
        institutionId: 'inst-a',
        status: AccountabilityStatus.responded,
        overdue: false,
        acknowledgedAt: null,
        resolutionHistory: const [],
        reopenedAt: null,
        routedAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      await tester.pumpWidget(
        _harness(
          result: RaiseIssueContinuity(unrouted: false, accountabilityLifecycles: [lifecycle]),
          postIntent: 'ISSUE',
          affiliations: [_affiliation('inst-a', role: 'MEMBER')],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Resolve'), findsNothing);
    });

    testWidgets('Resolve button appears for an Owner', (tester) async {
      final lifecycle = AccountabilityLifecycle(
        institutionId: 'inst-a',
        status: AccountabilityStatus.responded,
        overdue: false,
        acknowledgedAt: null,
        resolutionHistory: const [],
        reopenedAt: null,
        routedAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      await tester.pumpWidget(
        _harness(
          result: RaiseIssueContinuity(unrouted: false, accountabilityLifecycles: [lifecycle]),
          postIntent: 'ISSUE',
          affiliations: [_affiliation('inst-a', role: 'OWNER')],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Resolve'), findsOneWidget);
    });

    testWidgets('Resolved shows the resolution statement text', (tester) async {
      final lifecycle = AccountabilityLifecycle(
        institutionId: 'inst-a',
        status: AccountabilityStatus.resolved,
        overdue: false,
        acknowledgedAt: null,
        resolutionHistory: [
          ResolutionHistoryEntry(
            statement: 'We repaved the road on July 30.',
            resolvedByUserId: 'u1',
            resolvedAt: DateTime(2026, 7, 30),
          ),
        ],
        reopenedAt: null,
        routedAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 7, 30),
      );
      await tester.pumpWidget(
        _harness(
          result: RaiseIssueContinuity(unrouted: false, accountabilityLifecycles: [lifecycle]),
          postIntent: 'ISSUE',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('We repaved the road on July 30.'), findsOneWidget);
    });

    testWidgets('Reopen button is hidden for a non-author viewer', (tester) async {
      final lifecycle = AccountabilityLifecycle(
        institutionId: 'inst-a',
        status: AccountabilityStatus.resolved,
        overdue: false,
        acknowledgedAt: null,
        resolutionHistory: const [],
        reopenedAt: null,
        routedAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      await tester.pumpWidget(
        _harness(
          result: RaiseIssueContinuity(unrouted: false, accountabilityLifecycles: [lifecycle]),
          postIntent: 'ISSUE',
          viewerId: 'someone-else',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Reopen'), findsNothing);
    });

    testWidgets('Reopen button appears for the original author on a Resolved, not-yet-reopened record', (tester) async {
      final lifecycle = AccountabilityLifecycle(
        institutionId: 'inst-a',
        status: AccountabilityStatus.resolved,
        overdue: false,
        acknowledgedAt: null,
        resolutionHistory: const [],
        reopenedAt: null,
        routedAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      await tester.pumpWidget(
        _harness(
          result: RaiseIssueContinuity(unrouted: false, accountabilityLifecycles: [lifecycle]),
          postIntent: 'ISSUE',
          viewerId: _authorId,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Reopen'), findsOneWidget);
    });

    testWidgets('two institutions in different states render independently — never blended', (tester) async {
      final a = AccountabilityLifecycle(
        institutionId: 'inst-a',
        status: AccountabilityStatus.resolved,
        overdue: false,
        acknowledgedAt: null,
        resolutionHistory: const [],
        reopenedAt: null,
        routedAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      final b = AccountabilityLifecycle(
        institutionId: 'inst-b',
        status: AccountabilityStatus.pending,
        overdue: false,
        acknowledgedAt: null,
        resolutionHistory: const [],
        reopenedAt: null,
        routedAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      await tester.pumpWidget(
        _harness(
          result: RaiseIssueContinuity(unrouted: false, accountabilityLifecycles: [a, b]),
          postIntent: 'ISSUE',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Resolved'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
    });
  });
}
