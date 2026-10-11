import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/institutions/announcements/integrity/announcement_integrity.dart';
import 'package:aura/features/institutions/data/institutions_repository.dart';
import 'package:aura/features/institutions/desk/desk_models.dart';
import 'package:aura/features/institutions/domain/institution_post.dart';
import 'package:aura/features/institutions/posts/integrity/institution_post_integrity_review_sheet.dart';
import 'package:aura/features/institutions/scheduling/scheduled_publication.dart';

/// SCHEDULED PUBLICATION (2026-10-11): the app half.
///
/// The backend decides; these pin what the app shows and which call it makes:
/// the time is offered only inside the window the backend accepts, the label
/// always carries the written date and time, and the integrity review ends by
/// SCHEDULING (never publishing) when a time was chosen.

Map<String, dynamic> _review({required String outcome, bool satisfied = false}) => {
      'assessment': {
        'overallStatus': 'CLEAR',
        'summaryExplanation': 'Nothing found.',
        'decisionExplanation': '',
        'reviewedAt': '2026-10-11T12:00:00Z',
      },
      'pendingAction': {
        'decisionId': 'd1',
        'outcome': outcome,
        'reason': 'Reviewed.',
        'satisfied': satisfied,
      },
    };

class _FakeRepo extends InstitutionsRepository {
  _FakeRepo() : super(Dio());

  final List<String> calls = [];
  DateTime? scheduledFor;

  @override
  Future<Map<String, dynamic>> requestInstitutionPostIntegrityReview(
    String institutionId,
    String postId,
  ) async =>
      _review(outcome: 'CONTINUE');

  @override
  Future<InstitutionPost> scheduleInstitutionPost(
    String institutionId,
    String postId, {
    required DateTime publishAt,
    String? timezone,
  }) async {
    calls.add('schedule');
    scheduledFor = publishAt;
    return InstitutionPost.fromJson({
      'id': postId,
      'title': 'Holiday hours',
      'body': 'We close at noon.',
      'visibility': 'PUBLIC',
      'distribution': 'INSTITUTION_ONLY',
      'status': 'DRAFT',
      'scheduledPublishAt': publishAt.toUtc().toIso8601String(),
    });
  }

  @override
  Future<InstitutionPost> publishInstitutionPost(String institutionId, String postId) async {
    calls.add('publish');
    throw StateError('must not publish when scheduling');
  }
}

void main() {
  group('the schedule window', () {
    final now = DateTime(2026, 10, 11, 9, 0);

    test('refuses a time under 5 minutes away, in the backend\'s words', () {
      expect(
        scheduleTimeProblem(now.add(const Duration(minutes: 3)), now: now),
        'Choose a time at least 5 minutes from now, or publish now.',
      );
    });

    test('refuses a time more than a year away', () {
      expect(
        scheduleTimeProblem(now.add(const Duration(days: 400)), now: now),
        'Choose a time within the next year.',
      );
    });

    test('accepts a time inside the window', () {
      expect(scheduleTimeProblem(now.add(const Duration(hours: 2)), now: now), isNull);
    });

    test('the picker suggests the next quarter hour (DD-47)', () {
      expect(nextQuarterHour(DateTime(2026, 10, 11, 13, 2)), DateTime(2026, 10, 11, 13, 15));
      expect(nextQuarterHour(DateTime(2026, 10, 11, 13, 10)), DateTime(2026, 10, 11, 13, 15));
      // 5 minutes ahead is 13:17, so the next quarter is 13:30.
      expect(nextQuarterHour(DateTime(2026, 10, 11, 13, 12)), DateTime(2026, 10, 11, 13, 30));
      // Across the hour and the day.
      expect(nextQuarterHour(DateTime(2026, 10, 11, 23, 58)), DateTime(2026, 10, 12, 0, 15));
      // Always inside the window the backend accepts.
      final now = DateTime(2026, 10, 11, 13, 2);
      expect(scheduleTimeProblem(nextQuarterHour(now), now: now), isNull);
    });

    test('when scheduling, the review says "Ready to schedule" (DD-47)', () {
      expect(AnnouncementIntegrityOutcome.continueOutcome.schedulerLabel, 'Ready to schedule');
      expect(AnnouncementIntegrityOutcome.continueOutcome.publisherLabel, 'Ready to publish');
      expect(AnnouncementIntegrityOutcome.requireAcknowledgement.schedulerLabel,
          'Review before scheduling');
    });

    test('the label is the written date with its time', () {
      final label = publishesLabel(DateTime(2026, 10, 14, 9, 0));
      expect(label, startsWith('Publishes Wed, Oct 14, 2026 · '));
      expect(label, contains('9:00'));
    });
  });

  group('what the backend sends', () {
    test('a scheduled post carries its time and zone', () {
      final post = InstitutionPost.fromJson({
        'id': 'p1',
        'title': 'T',
        'body': 'B',
        'visibility': 'PUBLIC',
        'distribution': 'INSTITUTION_ONLY',
        'status': 'DRAFT',
        'scheduledPublishAt': '2026-10-14T13:00:00.000Z',
        'scheduledTimezone': 'America/New_York',
      });
      expect(post.schedule.isScheduled, isTrue);
      expect(post.schedule.publishAt, DateTime.utc(2026, 10, 14, 13));
      expect(post.schedule.timezone, 'America/New_York');
    });

    test('a post with no schedule fields has none', () {
      final post = InstitutionPost.fromJson({
        'id': 'p1',
        'title': 'T',
        'body': 'B',
        'visibility': 'PUBLIC',
        'distribution': 'INSTITUTION_ONLY',
        'status': 'PUBLISHED',
      });
      expect(post.schedule.isScheduled, isFalse);
      expect(post.schedule.hasFailed, isFalse);
    });

    test('a failed schedule is read with its reason', () {
      final s = PublicationSchedule.fromJson({
        'scheduleFailedAt': '2026-10-14T13:01:00.000Z',
        'scheduleFailureReason': 'Official institutional voice requires Pro plan',
      });
      expect(s.hasFailed, isTrue);
      expect(s.isScheduled, isFalse);
      expect(s.failureReason, contains('Pro plan'));
    });

    test('an edit that needs an integrity answer says so', () {
      final check = ScheduleCheck.fromJson({
        'ok': false,
        'code': 'INTEGRITY_ACTION_REQUIRED',
        'outcome': 'REQUIRE_ACKNOWLEDGEMENT',
      })!;
      expect(check.ok, isFalse);
      expect(check.needsIntegrityReview, isTrue);
      expect(ScheduleCheck.fromJson(null), isNull);
    });

    test('the Desk reads SCHEDULED and holds it under Drafts', () {
      final type = DeskItemType.fromWire('SCHEDULED');
      expect(type, DeskItemType.scheduled);
      expect(DeskTab.drafts.holds(type), isTrue);
      expect(DeskTab.questions.holds(type), isFalse);
    });
  });

  testWidgets('the integrity review ends by scheduling, never publishing, when a time was chosen',
      (tester) async {
    final repo = _FakeRepo();
    final at = DateTime.now().add(const Duration(days: 2));
    bool? result;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [institutionsRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await showInstitutionPostIntegrityReviewSheet(
                      context: context,
                      ref: ref,
                      institutionId: 'inst1',
                      postId: 'p1',
                      scheduleAt: at,
                      timezone: 'America/New_York',
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // The sheet says when, and its last step is Schedule.
    expect(find.textContaining(publishesLabel(at)), findsOneWidget);
    expect(find.text('Ready to schedule'), findsOneWidget);
    expect(find.text('Publish'), findsNothing);
    await tester.tap(find.text('Schedule'));
    await tester.pumpAndSettle();

    expect(repo.calls, ['schedule']);
    expect(repo.scheduledFor, at);
    expect(result, isTrue);
  });
}
