import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:aura/core/auth/session_providers.dart';
import 'package:aura/core/institutions/institution_access_provider.dart';
import 'package:aura/features/institutions/data/institutions_repository.dart';
import 'package:aura/features/institutions/domain/institution.dart';
import 'package:aura/features/meetings/application/meetings_provider.dart';
import 'package:aura/features/meetings/data/availability_repository.dart';
import 'package:aura/features/meetings/data/meetings_repository.dart';
import 'package:aura/features/meetings/domain/availability_profile.dart';
import 'package:aura/features/meetings/domain/meeting.dart';
import 'package:aura/features/meetings/domain/meeting_agenda_item.dart';
import 'package:aura/features/meetings/presentation/create_meeting_screen.dart';
import 'package:aura/features/meetings/presentation/institution_availability_screen.dart';
import 'package:aura/features/meetings/presentation/meeting_detail_screen.dart';
import 'package:aura/features/meetings/presentation/meeting_schedule_rules.dart';
import 'package:aura/features/meetings/presentation/widgets/meeting_agenda_items.dart';
import 'package:aura/features/updates/notifications_repository.dart';
import 'package:aura/features/updates/providers.dart';

/// MEETINGS, PHASE E (6 Nov 2026): answers in the list, recurring series,
/// follow-ups, agenda points, co-hosts, booking-page numbers.

/// Records each request; answers with [reply] (or `{}`) wrapped as the API.
class _Capture implements HttpClientAdapter {
  _Capture([this.reply]);
  final Object? Function(RequestOptions r)? reply;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({'ok': true, 'data': reply?.call(options) ?? {}}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _dio(_Capture c) =>
    Dio(BaseOptions(baseUrl: 'https://api.test/v1'))..httpClientAdapter = c;

Map<String, dynamic> _p(String id, String role, String rsvp) => {
      'id': 'p-$id',
      'meetingId': 'm1',
      'userId': id,
      'role': role,
      'rsvpStatus': rsvp,
      'user': {'id': id, 'displayName': 'Person $id'},
    };

Map<String, dynamic> _meeting({
  String state = 'SCHEDULED',
  String? seriesId,
  String? rule,
  List<Map<String, dynamic>>? participants,
}) =>
    {
      'id': 'm1',
      'title': 'Budget review',
      'meetingCode': 'ABC123',
      'state': state,
      'scheduledAt':
          DateTime.now().add(const Duration(days: 2)).toUtc().toIso8601String(),
      'durationMinutes': 30,
      'organizationId': 'org1',
      'host': {'id': 'host', 'displayName': 'Hana Host'},
      if (seriesId != null) 'seriesId': seriesId,
      if (rule != null) 'recurringRule': rule,
      'participants': participants ??
          [
            _p('host', 'HOST', 'ACCEPTED'),
            _p('a', 'PARTICIPANT', 'ACCEPTED'),
            _p('d', 'PARTICIPANT', 'DECLINED'),
            _p('n', 'PARTICIPANT', 'PENDING'),
          ],
    };

class _Meetings extends MeetingsRepository {
  _Meetings(this.json) : super(Dio());
  Map<String, dynamic> json;
  List<MeetingAgendaItem> agenda = const [];
  final calls = <String>[];

  @override
  Future<Meeting> getMeeting(String id) async => Meeting.fromJson(json);

  @override
  Future<List<MeetingAgendaItem>> listAgenda(String meetingId) async => agenda;

  @override
  Future<int> cancelSeriesFrom(String meetingId) async {
    calls.add('cancelSeries:$meetingId');
    return 3;
  }

  @override
  Future<Meeting> scheduleFollowUp(String meetingId,
      {required DateTime scheduledAt, int? durationMinutes, String? title}) async {
    calls.add('followUp:$title:$durationMinutes');
    return Meeting.fromJson({..._meeting(), 'id': 'm2', 'title': title});
  }

  @override
  Future<void> addCoHost(String meetingId, String userId) async =>
      calls.add('addCoHost:$userId');

  @override
  Future<void> addAgendaItem(String meetingId, String text) async =>
      calls.add('addAgenda:$text');

  @override
  Future<void> updateAgendaItem(String meetingId, String itemId,
          {String? text, bool? covered}) async =>
      calls.add('updateAgenda:$itemId:$covered');

  @override
  Future<void> removeAgendaItem(String meetingId, String itemId) async =>
      calls.add('removeAgenda:$itemId');

  @override
  Future<void> agendaItemToOutcome(String meetingId, String itemId,
          {required String type}) async =>
      calls.add('outcome:$itemId:$type');
}

class _Notifications extends NotificationsRepository {
  _Notifications() : super(Dio());
}

class _Institutions extends InstitutionsRepository {
  _Institutions() : super(Dio());

  @override
  Future<Institution> getById(String id) async => Institution(
        id: id,
        name: 'Org',
        slug: 'org',
        domain: 'org.test',
        jurisdiction: 'US',
        description: '',
        website: '',
        isVerified: true,
      );

  @override
  Future<Map<String, dynamic>> listMembers(String institutionId) async =>
      {'callerRole': 'OWNER', 'members': const []};
}

Future<_Meetings> _openDetail(
  WidgetTester tester, {
  required Map<String, dynamic> json,
  required String me,
  bool manager = false,
  List<MeetingAgendaItem> agenda = const [],
}) async {
  const page = Scaffold(
    body: MeetingDetailScreen(meetingId: 'm1', institutionId: 'org1'),
  );
  final router = GoRouter(
    initialLocation: '/record',
    routes: [
      GoRoute(path: '/record', builder: (_, __) => page),
      GoRoute(
        path: '/institution/:i/meetings/:id',
        builder: (_, state) =>
            Scaffold(body: Text('Opened ${state.pathParameters['id']}')),
      ),
    ],
  );
  tester.view.physicalSize = const Size(1000, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final repo = _Meetings(json)..agenda = agenda;
  await tester.pumpWidget(ProviderScope(
    overrides: [
      meetingsRepositoryProvider.overrideWithValue(repo),
      meetingStateChangedEventProvider
          .overrideWith((ref) => const Stream.empty()),
      meetingAssetsProvider.overrideWith((ref, id) async => const []),
      authMeDataProvider.overrideWith((ref) async => {
            'user': {'id': me},
          }),
      isAuthedProvider.overrideWithValue(false),
      isGuestSessionProvider.overrideWithValue(false),
      notificationsRepoProvider.overrideWithValue(_Notifications()),
      myAffiliationsProvider.overrideWithValue(const []),
      institutionsRepositoryProvider.overrideWithValue(_Institutions()),
      institutionIdentityProvider.overrideWithValue(manager
          ? const InstitutionIdentity(
              id: 'org1',
              name: 'Org',
              slug: 'org',
              isAuthorizedSpeaker: false,
              capabilities: {InstitutionCapabilities.manageMeetings},
            )
          : null),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  group('1 — the list shows each answer to the people who run it', () {
    test('labels', () {
      expect(rsvpLabel('ACCEPTED'), 'Accepted');
      expect(rsvpLabel('DECLINED'), 'Declined');
      expect(rsvpLabel('PENDING'), 'No answer yet');
    });

    testWidgets('the host sees answers', (tester) async {
      await _openDetail(tester, json: _meeting(), me: 'host');
      expect(find.text('Accepted'), findsOneWidget);
      expect(find.text('Declined'), findsOneWidget);
      expect(find.text('No answer yet'), findsOneWidget);
    });

    testWidgets('a participant does not', (tester) async {
      await _openDetail(tester, json: _meeting(), me: 'a');
      expect(find.text('Declined'), findsNothing);
      expect(find.text('No answer yet'), findsNothing);
    });
  });

  group('2 — recurring meetings', () {
    test('the create body goes to /meetings/series, first meeting returned',
        () async {
      final cap = _Capture((r) => r.method == 'POST'
          ? {
              'seriesId': 'm1',
              'meetingIds': ['m1', 'm2', 'm3'],
              'rule': 'FREQ=WEEKLY;COUNT=3',
            }
          : _meeting());
      final m = await MeetingsRepository(_dio(cap)).createMeeting(
        title: 'Standup',
        type: 'SCHEDULED',
        scheduledAt: '2026-11-10T15:00:00.000Z',
        repeatFrequency: 'BIWEEKLY',
        repeatCount: 3,
      );
      final post = cap.requests.first;
      expect(post.path, '/meetings/series');
      final body = post.data as Map;
      expect(body['recurrence'], {'frequency': 'BIWEEKLY', 'count': 3});
      expect((body['meeting'] as Map)['title'], 'Standup');
      expect(cap.requests[1].path, '/meetings/m1');
      expect(m.id, 'm1');
    });

    test('a single meeting still goes to /meetings', () async {
      final cap = _Capture((_) => _meeting());
      await MeetingsRepository(_dio(cap))
          .createMeeting(title: 'One', type: 'SCHEDULED');
      expect(cap.requests.single.path, '/meetings');
    });

    test('series label from the rule; nothing without a series', () {
      Meeting m(String? rule) =>
          Meeting.fromJson(_meeting(seriesId: 'm0', rule: rule));
      expect(meetingSeriesLabel(m('FREQ=WEEKLY;COUNT=8')),
          'Repeats weekly · 8 meetings in the series');
      expect(meetingSeriesLabel(m('FREQ=WEEKLY;INTERVAL=2;COUNT=4')),
          'Repeats every 2 weeks · 4 meetings in the series');
      expect(meetingSeriesLabel(m(null)), 'Part of a series');
      expect(meetingSeriesLabel(Meeting.fromJson(_meeting())), isNull);
    });

    testWidgets('create offers Repeat and How many times', (tester) async {
      tester.view.physicalSize = const Size(1400, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          institutionsRepositoryProvider.overrideWithValue(_Institutions()),
          myAvailabilityProfilesProvider.overrideWith((ref) async => const []),
          currentBookingIdentityProvider.overrideWith((ref) async => null),
        ],
        child: const MaterialApp(
          home: Material(child: CreateMeetingScreen(institutionId: 'org1')),
        ),
      ));
      await tester.pump();
      expect(find.text('Does not repeat'), findsOneWidget);
      expect(find.text('How many times'), findsNothing);
      await tester.ensureVisible(find.text('Does not repeat'));
      await tester.tap(find.text('Does not repeat'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Weekly').last);
      await tester.pumpAndSettle();
      expect(find.text('How many times'), findsOneWidget);
      expect(find.text('4 meetings'), findsOneWidget);
    });

    testWidgets('a series meeting says so; the host can cancel the rest',
        (tester) async {
      final repo = await _openDetail(tester,
          json: _meeting(seriesId: 'm0', rule: 'FREQ=WEEKLY;COUNT=8'),
          me: 'host');
      expect(find.text('Repeats weekly · 8 meetings in the series'),
          findsOneWidget);
      await tester.ensureVisible(find.text('Cancel this and later meetings'));
      await tester.tap(find.text('Cancel this and later meetings'));
      await tester.pumpAndSettle();
      expect(find.text('Cancel this and later meetings?'), findsOneWidget);
      await tester.tap(find.text('Cancel meetings'));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('cancelSeries:m1'));
    });
  });

  group('3 — follow-up', () {
    test('the request', () async {
      final cap = _Capture((_) => _meeting());
      await MeetingsRepository(_dio(cap)).scheduleFollowUp('m1',
          scheduledAt: DateTime.utc(2026, 11, 20, 15),
          durationMinutes: 45,
          title: 'Follow-up: Budget review');
      final r = cap.requests.single;
      expect(r.path, '/meetings/m1/follow-up');
      expect(r.data, {
        'scheduledAt': '2026-11-20T15:00:00.000Z',
        'durationMinutes': 45,
        'title': 'Follow-up: Budget review',
      });
    });

    testWidgets('the host schedules one with the title filled in',
        (tester) async {
      final repo = await _openDetail(tester, json: _meeting(), me: 'host');
      await tester.tap(find.text('Schedule a follow-up'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Follow-up: Budget review'),
          findsOneWidget);
      await tester.tap(find.text('Schedule follow-up'));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('followUp:Follow-up: Budget review:30'));
      // And the new meeting opens.
      expect(find.text('Opened m2'), findsOneWidget);
    });
  });

  group('4 — agenda points', () {
    test('the requests', () async {
      final cap = _Capture((r) => r.method == 'GET'
          ? [
              {'id': 'i1', 'text': 'Scope', 'position': 0, 'covered': true},
            ]
          : {});
      final repo = MeetingsRepository(_dio(cap));
      final items = await repo.listAgenda('m1');
      expect(items.single.covered, isTrue);
      await repo.addAgendaItem('m1', ' Budget ');
      await repo.updateAgendaItem('m1', 'i1', covered: false);
      await repo.removeAgendaItem('m1', 'i1');
      await repo.agendaItemToOutcome('m1', 'i1', type: 'DECISION');
      expect(cap.requests.map((r) => '${r.method} ${r.path} ${r.data}'), [
        'GET /meetings/m1/agenda null',
        'POST /meetings/m1/agenda {text: Budget}',
        'PATCH /meetings/m1/agenda/i1 {covered: false}',
        'DELETE /meetings/m1/agenda/i1 null',
        'POST /meetings/m1/agenda/i1/outcome {type: DECISION}',
      ]);
    });

    const items = [
      MeetingAgendaItem(id: 'i1', text: 'Scope', position: 0, covered: false),
      MeetingAgendaItem(id: 'i2', text: 'Budget', position: 1, covered: true),
    ];

    testWidgets('the host adds, ticks and removes points', (tester) async {
      final repo =
          await _openDetail(tester, json: _meeting(), me: 'host', agenda: items);
      expect(find.text('Scope'), findsOneWidget);
      await tester.enterText(
          find.widgetWithText(TextField, 'Add an agenda point'), 'Timeline');
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Remove this point').last);
      await tester.pumpAndSettle();
      expect(repo.calls, [
        'addAgenda:Timeline',
        'updateAgenda:i1:true',
        'removeAgenda:i2',
      ]);
      // The free-text notes still work alongside.
      expect(find.text('Save agenda'), findsOneWidget);
    });

    testWidgets('a participant reads the points', (tester) async {
      await _openDetail(tester, json: _meeting(), me: 'a', agenda: items);
      expect(find.text('Scope'), findsOneWidget);
      expect(find.byType(Checkbox), findsNothing);
      expect(find.byTooltip('Remove this point'), findsNothing);
      expect(find.text('Make it an outcome'), findsNothing);
    });

    testWidgets('after the meeting a point becomes an outcome',
        (tester) async {
      final repo = await _openDetail(tester,
          json: _meeting(state: 'ENDED'), me: 'host', agenda: items);
      await tester.ensureVisible(find.text('Make it an outcome').first);
      await tester.tap(find.text('Make it an outcome').first);
      await tester.pumpAndSettle();
      for (final (_, label) in kAgendaOutcomeKinds) {
        expect(find.text(label), findsWidgets);
      }
      await tester.tap(find.text('Decision').last);
      await tester.pumpAndSettle();
      expect(repo.calls, contains('outcome:i1:DECISION'));
    });
  });

  group('5 — co-hosts', () {
    test('the requests', () async {
      final cap = _Capture((_) => _meeting());
      final repo = MeetingsRepository(_dio(cap));
      await repo.addCoHost('m1', 'u2');
      await repo.removeCoHost('m1', 'u2');
      expect(cap.requests[0].path, '/meetings/m1/co-hosts');
      expect(cap.requests[0].data, {'userId': 'u2'});
      expect(cap.requests[1].method, 'DELETE');
      expect(cap.requests[1].path, '/meetings/m1/co-hosts/u2');
    });

    test('who may do what', () {
      expect(canManageMeeting(isHost: false, canGovern: false, isCoHost: true),
          isTrue);
      expect(canAppointCoHosts(isHost: false, canGovern: false), isFalse);
      expect(canAppointCoHosts(isHost: false, canGovern: true), isTrue);
    });

    testWidgets('the host makes a participant a co-host', (tester) async {
      final repo = await _openDetail(tester, json: _meeting(), me: 'host');
      await tester.tap(find.byTooltip('Options for Person a'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Make co-host'));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('addCoHost:a'));
    });

    testWidgets('a co-host runs the meeting but cannot cancel or appoint',
        (tester) async {
      await _openDetail(tester,
          json: _meeting(participants: [
            _p('host', 'HOST', 'ACCEPTED'),
            _p('co', 'CO_HOST', 'ACCEPTED'),
            _p('a', 'PARTICIPANT', 'ACCEPTED'),
          ]),
          me: 'co');
      expect(find.text('Co-host'), findsOneWidget);
      expect(find.text('Start meeting'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Cancel meeting'), findsNothing);
      expect(find.byTooltip('Options for Person a'), findsNothing);
      // A co-host does not answer the invitation either.
      expect(find.text('You are invited. Will you attend?'), findsNothing);
    });
  });

  group('6 — booking-page numbers', () {
    test('the line', () {
      final s = BookingPageStats.fromJson({
        'days': 90,
        'booked': 12,
        'upcoming': 3,
        'held': 6,
        'noShow': 1,
        'cancelledByBooker': 1,
        'cancelledByHost': 1,
      });
      expect(s.line,
          'Last 90 days: 12 booked · 3 upcoming · 6 held · 1 no-show · 2 cancelled');
    });

    testWidgets('each page shows its numbers', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final cap = _Capture((r) => r.path.endsWith('/stats')
          ? {
              'days': 90,
              'booked': 5,
              'upcoming': 1,
              'held': 2,
              'noShow': 2,
              'cancelledByBooker': 0,
              'cancelledByHost': 0,
            }
          : {});
      await tester.pumpWidget(ProviderScope(
        overrides: [
          availabilityRepositoryProvider
              .overrideWithValue(AvailabilityRepository(_dio(cap))),
          institutionsRepositoryProvider.overrideWithValue(_Institutions()),
          institutionProfilesProvider.overrideWith((ref, id) async => [
                AvailabilityProfile.fromJson({
                  'id': 'p1',
                  'name': 'Intro',
                  'slug': 'intro',
                  'meetingTitle': 'Intro call',
                }),
              ]),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: InstitutionBookingPages(institutionId: 'org1'),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(
        cap.requests.any(
            (r) => r.path == '/institution/org1/availability/p1/stats'),
        isTrue,
      );
      expect(
          find.text(
              'Last 90 days: 5 booked · 1 upcoming · 2 held · 2 no-shows · 0 cancelled'),
          findsOneWidget);
    });
  });
}
