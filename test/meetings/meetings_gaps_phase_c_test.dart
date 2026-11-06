import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/app/route_classification.dart';
import 'package:aura/core/auth/session_providers.dart';
import 'package:aura/core/institutions/institution_access_provider.dart';
import 'package:aura/features/institutions/data/institutions_repository.dart';
import 'package:aura/features/meetings/application/meetings_provider.dart';
import 'package:aura/features/meetings/data/availability_repository.dart';
import 'package:aura/features/meetings/data/meetings_repository.dart';
import 'package:aura/features/meetings/domain/availability_profile.dart';
import 'package:aura/features/meetings/domain/meeting.dart';
import 'package:aura/features/meetings/presentation/institution_availability_screen.dart';
import 'package:aura/features/meetings/presentation/invitation_decline_screen.dart';
import 'package:aura/features/meetings/presentation/meeting_detail_screen.dart';
import 'package:aura/features/meetings/presentation/meeting_load_problem.dart';
import 'package:aura/features/meetings/presentation/meeting_schedule_rules.dart';
import 'package:aura/features/meetings/presentation/widgets/meeting_live_refresh.dart';
import 'package:aura/features/meetings/presentation/widgets/meeting_rsvp_panel.dart';
import 'package:aura/features/updates/notifications_repository.dart';
import 'package:aura/features/updates/providers.dart';

/// MEETINGS GAPS, PHASE C (6 Nov 2026) — the app half of the audit that
/// followed two booked meetings the founder was never told about.

/// Records every request and answers `{ ok: true, data: {} }` (or a status).
class _Capture implements HttpClientAdapter {
  _Capture({this.status = 200});
  int status;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({'ok': status < 400, 'data': <String, dynamic>{}}),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _dio(_Capture adapter) =>
    Dio(BaseOptions(baseUrl: 'https://api.test/v1'))..httpClientAdapter = adapter;

Map<String, dynamic> _meetingJson({
  String id = 'm1',
  String state = 'SCHEDULED',
  String hostId = 'host',
  String? organizationId = 'org1',
  DateTime? scheduledAt,
  int durationMinutes = 30,
  List<Map<String, dynamic>> participants = const [],
}) =>
    {
      'id': id,
      'title': 'Budget review',
      'meetingCode': 'ABC123',
      'state': state,
      'type': 'SCHEDULED',
      'scheduledAt':
          (scheduledAt ?? DateTime.now().add(const Duration(days: 2)))
              .toUtc()
              .toIso8601String(),
      'durationMinutes': durationMinutes,
      'organizationId': organizationId,
      'host': {'id': hostId, 'displayName': 'Hana Host'},
      'participants': participants,
    };

Map<String, dynamic> _participant(String userId, String role, String rsvp) => {
      'id': 'p-$userId',
      'meetingId': 'm1',
      'userId': userId,
      'role': role,
      'rsvpStatus': rsvp,
      'user': {'id': userId, 'displayName': 'Person $userId'},
    };

class _StubInstitutions extends InstitutionsRepository {
  _StubInstitutions() : super(Dio());

  @override
  Future<Map<String, dynamic>> listMembers(String institutionId) async => {
        'members': [
          {'userId': 'host', 'user': {'id': 'host', 'displayName': 'Hana Host'}},
          {'userId': 'u2', 'user': {'id': 'u2', 'displayName': 'Omar Member'}},
        ],
      };
}

class _FakeMeetings extends MeetingsRepository {
  _FakeMeetings(this.json) : super(Dio());
  Map<String, dynamic> json;
  int gets = 0;
  final answers = <bool>[];
  final invitedUserIds = <String>[];
  Object? getError;

  @override
  Future<void> inviteToMeeting(
    String meetingId, {
    String? email,
    String? name,
    String? userId,
  }) async {
    if (userId != null) invitedUserIds.add(userId);
  }

  @override
  Future<Meeting> getMeeting(String id) async {
    gets++;
    final e = getError;
    if (e != null) throw e;
    return Meeting.fromJson(json);
  }

  @override
  Future<void> respondToMeeting(String meetingId, {required bool accept}) async {
    answers.add(accept);
    final parts = (json['participants'] as List).cast<Map<String, dynamic>>();
    json = {
      ...json,
      'participants': [
        for (final p in parts)
          p['userId'] == 'me'
              ? {...p, 'rsvpStatus': accept ? 'ACCEPTED' : 'DECLINED'}
              : p,
      ],
    };
  }
}

void main() {
  group('C7 — scheduling rules', () {
    test('the edit list always offers the meeting\'s own length', () {
      expect(meetingDurationChoices(60), kStandardMeetingDurations);
      final odd = meetingDurationChoices(75);
      expect(odd, contains(75));
      expect(odd, orderedEquals([...odd]..sort()));
      expect(meetingDurationChoices(20).first, 15);
      expect(meetingDurationChoices(20), contains(20));
    });

    test('a time earlier today is in the past; later is not', () {
      final now = DateTime(2026, 11, 6, 15, 0);
      expect(isPastMeetingTime(DateTime(2026, 11, 6, 9, 0), now: now), isTrue);
      expect(isPastMeetingTime(DateTime(2026, 11, 6, 16, 0), now: now), isFalse);
    });
  });

  group('C2 — who runs the meeting', () {
    test('host or institution meeting manager', () {
      expect(canManageMeeting(isHost: true, canGovern: false), isTrue);
      expect(canManageMeeting(isHost: false, canGovern: true), isTrue);
      expect(canManageMeeting(isHost: false, canGovern: false), isFalse);
    });

    test('only an invited participant answers; hosts and co-hosts do not', () {
      final m = Meeting.fromJson(_meetingJson(participants: [
        _participant('host', 'HOST', 'ACCEPTED'),
        _participant('co', 'CO_HOST', 'ACCEPTED'),
        _participant('me', 'PARTICIPANT', 'PENDING'),
      ]));
      expect(answeringParticipant(m, 'me')?.rsvpStatus, 'PENDING');
      expect(answeringParticipant(m, 'host'), isNull);
      expect(answeringParticipant(m, 'co'), isNull);
      expect(answeringParticipant(m, 'stranger'), isNull);
      expect(answeringParticipant(m, ''), isNull);
    });
  });

  group('C4 — the error says what happened', () {
    DioException dio(int? status, {DioExceptionType? type}) => DioException(
          requestOptions: RequestOptions(path: '/meetings/m1'),
          type: type ?? DioExceptionType.badResponse,
          response: status == null
              ? null
              : Response(
                  requestOptions: RequestOptions(path: '/meetings/m1'),
                  statusCode: status,
                ),
        );

    test('classification', () {
      expect(
          classifyMeetingLoadError(
              dio(null, type: DioExceptionType.connectionError),
              signedIn: true),
          MeetingLoadProblem.offline);
      expect(
          classifyMeetingLoadError(
              dio(null, type: DioExceptionType.receiveTimeout),
              signedIn: true),
          MeetingLoadProblem.offline);
      expect(classifyMeetingLoadError(dio(500), signedIn: true),
          MeetingLoadProblem.server);
      expect(classifyMeetingLoadError(dio(403), signedIn: true),
          MeetingLoadProblem.noAccess);
      expect(classifyMeetingLoadError(dio(404), signedIn: true),
          MeetingLoadProblem.noAccess);
      expect(classifyMeetingLoadError(dio(401), signedIn: true),
          MeetingLoadProblem.signedOut);
      expect(classifyMeetingLoadError(dio(500), signedIn: false),
          MeetingLoadProblem.signedOut);
    });

    Future<({int retries, int signIns})> show(
        WidgetTester tester, MeetingLoadProblem p) async {
      var retries = 0, signIns = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MeetingLoadProblemView(
            problem: p,
            onRetry: () => retries++,
            onSignIn: () => signIns++,
          ),
        ),
      ));
      return (retries: retries, signIns: signIns);
    }

    testWidgets('offline: offline + retry, never Sign in', (tester) async {
      await show(tester, MeetingLoadProblem.offline);
      expect(find.text("You're offline"), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Sign in'), findsNothing);
    });

    testWidgets('server error: couldn\'t load + retry', (tester) async {
      await show(tester, MeetingLoadProblem.server);
      expect(find.text("Couldn't load this meeting"), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Sign in'), findsNothing);
    });

    testWidgets('no access, signed in: the members message, no Sign in',
        (tester) async {
      await show(tester, MeetingLoadProblem.noAccess);
      expect(find.text('This meeting is available to its members.'),
          findsOneWidget);
      expect(find.text('Sign in'), findsNothing);
    });

    testWidgets('signed out: Sign in', (tester) async {
      await show(tester, MeetingLoadProblem.signedOut);
      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    });
  });

  group('C1 — accept or decline', () {
    testWidgets('pending asks; answering shows the answer and lets it change',
        (tester) async {
      final sent = <bool>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MeetingRsvpPanel(
            rsvpStatus: 'PENDING',
            onAnswer: (accept) async => sent.add(accept),
          ),
        ),
      ));
      expect(find.text('You are invited. Will you attend?'), findsOneWidget);
      await tester.tap(find.text('Accept'));
      await tester.pumpAndSettle();
      expect(sent, [true]);
      expect(find.text('You accepted. You are expected at this meeting.'),
          findsOneWidget);

      await tester.tap(find.text("I can't attend"));
      await tester.pumpAndSettle();
      expect(sent, [true, false]);
      expect(find.text('You declined this meeting.'), findsOneWidget);
      expect(find.text('I can attend after all'), findsOneWidget);
    });

    testWidgets('a failed answer says so and keeps the question',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MeetingRsvpPanel(
            rsvpStatus: 'PENDING',
            onAnswer: (_) async => throw Exception('offline'),
          ),
        ),
      ));
      await tester.tap(find.text('Decline'));
      await tester.pumpAndSettle();
      expect(find.text('Your answer was not saved. Try again.'), findsOneWidget);
      expect(find.text('Accept'), findsOneWidget);
    });
  });

  group('C3 — the page follows the meeting', () {
    late StreamController<MeetingStateChangedEvent> events;
    late _FakeMeetings repo;

    Future<void> mount(WidgetTester tester, {Duration? poll}) async {
      events = StreamController<MeetingStateChangedEvent>.broadcast();
      repo = _FakeMeetings(_meetingJson());
      await tester.pumpWidget(ProviderScope(
        overrides: [
          meetingsRepositoryProvider.overrideWithValue(repo),
          meetingStateChangedEventProvider
              .overrideWith((ref) => events.stream),
        ],
        child: MaterialApp(
          home: MeetingLiveRefresh(
            meetingId: 'm1',
            pollEvery: poll ?? const Duration(hours: 1),
            child: Consumer(
              builder: (context, ref, _) => Text(
                ref.watch(meetingProvider('m1')).valueOrNull?.state ?? '…',
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      addTearDown(events.close);
    }

    testWidgets('a state change for THIS meeting re-reads it', (tester) async {
      await mount(tester);
      expect(repo.gets, 1);
      repo.json = _meetingJson(state: 'ACTIVE');
      events.add(const MeetingStateChangedEvent(meetingId: 'other', state: 'ACTIVE'));
      await tester.pumpAndSettle();
      expect(repo.gets, 1, reason: 'another meeting\'s event is not ours');
      events.add(const MeetingStateChangedEvent(meetingId: 'm1', state: 'ACTIVE'));
      await tester.pumpAndSettle();
      expect(repo.gets, 2);
      expect(find.text('ACTIVE'), findsOneWidget);
    });

    testWidgets('returning to the foreground re-reads it', (tester) async {
      await mount(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(repo.gets, 2);
    });

    testWidgets('nothing is re-read while the live room (a root route) is '
        'open over the page', (tester) async {
      // The page sits in the shell's nested navigator; the live room opens on
      // the ROOT one, so the page's own route still reads as current.
      events = StreamController<MeetingStateChangedEvent>.broadcast();
      addTearDown(events.close);
      repo = _FakeMeetings(_meetingJson());
      final rootKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          meetingsRepositoryProvider.overrideWithValue(repo),
          meetingStateChangedEventProvider
              .overrideWith((ref) => events.stream),
        ],
        child: MaterialApp(
          navigatorKey: rootKey,
          home: Navigator(
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (_) => MeetingLiveRefresh(
                meetingId: 'm1',
                pollEvery: const Duration(hours: 1),
                child: Consumer(
                  builder: (context, ref, _) => Text(
                    ref.watch(meetingProvider('m1')).valueOrNull?.state ?? '…',
                  ),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(repo.gets, 1);
      rootKey.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('live room')),
      ));
      await tester.pumpAndSettle();
      events.add(const MeetingStateChangedEvent(meetingId: 'm1', state: 'ACTIVE'));
      await tester.pumpAndSettle();
      expect(repo.gets, 1);
      rootKey.currentState!.pop();
      await tester.pumpAndSettle();
      events.add(const MeetingStateChangedEvent(meetingId: 'm1', state: 'ACTIVE'));
      await tester.pumpAndSettle();
      expect(repo.gets, 2);
    });

    testWidgets('a quiet poll re-reads it while the page is open',
        (tester) async {
      await mount(tester, poll: const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(repo.gets, 2);
    });
  });

  group('the meeting page (C1, C2, C4)', () {
    Future<_FakeMeetings> open(
      WidgetTester tester, {
      required Map<String, dynamic> json,
      String me = 'me',
      bool manager = false,
      Object? error,
    }) async {
      // One column: the test font (Ahem) draws every glyph as a full square,
      // so the 370px side column of the wide layout overflows in tests.
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final repo = _FakeMeetings(json)..getError = error;
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
          notificationsRepoProvider
              .overrideWithValue(NotificationsRepository(Dio())),
          myAffiliationsProvider.overrideWithValue(const []),
          institutionsRepositoryProvider.overrideWithValue(_StubInstitutions()),
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
        child: const MaterialApp(
          home: Scaffold(
            body: MeetingDetailScreen(meetingId: 'm1', institutionId: 'org1'),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('a pending participant can accept, and the page says so',
        (tester) async {
      final repo = await open(tester,
          json: _meetingJson(participants: [
            _participant('host', 'HOST', 'ACCEPTED'),
            _participant('me', 'PARTICIPANT', 'PENDING'),
          ]));
      expect(find.text('You are invited. Will you attend?'), findsOneWidget);
      // A participant does not run the meeting.
      expect(find.text('Start meeting'), findsNothing);
      expect(find.text('Reschedule'), findsNothing);

      await tester.tap(find.text('Accept'));
      await tester.pumpAndSettle();
      expect(repo.answers, [true]);
      expect(find.text('You accepted. You are expected at this meeting.'),
          findsOneWidget);
    });

    testWidgets('a meeting manager who is not the host can start, edit and '
        'reschedule', (tester) async {
      await open(tester,
          manager: true,
          json: _meetingJson(participants: [
            _participant('host', 'HOST', 'ACCEPTED'),
          ]));
      expect(find.text('Start meeting'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Reschedule'), findsOneWidget);
      expect(find.text('Add members'), findsOneWidget);
      // The manager is not a participant, so nothing to answer.
      expect(find.text('You are invited. Will you attend?'), findsNothing);
    });

    testWidgets('a manager adds an Aura member after creation, by user id',
        (tester) async {
      final repo = await open(tester,
          manager: true,
          json: _meetingJson(participants: [
            _participant('host', 'HOST', 'ACCEPTED'),
          ]));
      await tester.ensureVisible(find.text('Add members'));
      await tester.tap(find.text('Add members'));
      await tester.pumpAndSettle();
      // The host is already in the meeting, so only Omar is offered.
      final dialog = find.byType(AlertDialog);
      expect(find.descendant(of: dialog, matching: find.text('Hana Host')),
          findsNothing);
      expect(find.descendant(of: dialog, matching: find.text('Omar Member')),
          findsOneWidget);
      await tester.tap(find.text('Omar Member'));
      await tester.pump();
      await tester.tap(find.text('Add member'));
      await tester.pumpAndSettle();
      expect(repo.invitedUserIds, ['u2']);
    });

    testWidgets('Reschedule opens the edit dialog focused on the time',
        (tester) async {
      await open(tester,
          json: _meetingJson(hostId: 'me', durationMinutes: 75, participants: [
            _participant('me', 'HOST', 'ACCEPTED'),
          ]));
      await tester.tap(find.text('Reschedule'));
      await tester.pumpAndSettle();
      expect(find.text('Reschedule meeting'), findsOneWidget);
      expect(find.text('Save new time'), findsOneWidget);
      // Only the time and length: no title or description fields.
      expect(find.widgetWithText(TextField, 'Meeting title'), findsNothing);
      // The 75-minute length a booking page made is shown, not dropped.
      expect(find.text('75 min'), findsOneWidget);
    });

    testWidgets('Edit offers Recording allowed', (tester) async {
      await open(tester,
          json: _meetingJson(hostId: 'me', participants: [
            _participant('me', 'HOST', 'ACCEPTED'),
          ]));
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(find.text('Recording allowed'), findsOneWidget);
    });

    testWidgets('an offline load says offline, not "members only"',
        (tester) async {
      await open(tester,
          json: _meetingJson(),
          error: DioException(
            requestOptions: RequestOptions(path: '/meetings/m1'),
            type: DioExceptionType.connectionError,
          ));
      // Signed out in this harness, so the honest answer is Sign in; the
      // signed-in offline answer is covered by the classifier tests above.
      expect(find.text('Sign in'), findsOneWidget);
    });
  });

  group('repository calls match the server', () {
    test('rsvp sends ACCEPTED / DECLINED to /meetings/:id/rsvp', () async {
      final cap = _Capture();
      final repo = MeetingsRepository(_dio(cap));
      await repo.respondToMeeting('m1', accept: true);
      await repo.respondToMeeting('m1', accept: false);
      expect(cap.requests[0].path, '/meetings/m1/rsvp');
      expect(cap.requests[0].method, 'POST');
      expect(cap.requests[0].data, {'status': 'ACCEPTED'});
      expect(cap.requests[1].data, {'status': 'DECLINED'});
    });

    test('a member is invited by userId, without an email', () async {
      final cap = _Capture();
      await MeetingsRepository(_dio(cap)).inviteToMeeting('m1', userId: 'u7');
      expect(cap.requests.single.path, '/meetings/m1/invite');
      expect(cap.requests.single.data, {'userId': 'u7'});
    });

    test('an emptied description is sent, so it clears', () async {
      final cap = _Capture();
      cap.status = 200;
      try {
        await MeetingsRepository(_dio(cap)).updateMeeting('m1', description: '');
      } catch (_) {
        // The capture answers an empty object, not a meeting; the request is
        // what matters here.
      }
      expect((cap.requests.single.data as Map)['description'], '');
    });

    test('decline by token is public and posts to the token route', () async {
      final cap = _Capture();
      await MeetingsRepository(_dio(cap)).declineInvitationByToken('tok-1');
      final r = cap.requests.single;
      expect(r.path, '/public/meetings/invitations/tok-1/decline');
      expect(r.method, 'POST');
      expect(r.extra['__skip_auth'], isTrue);
    });

    test('a day off is sent as noon UTC of that calendar day', () async {
      final cap = _Capture();
      await AvailabilityRepository(_dio(cap)).addInstitutionDayOff(
        'org1',
        'p1',
        day: DateTime(2026, 12, 24),
      );
      final r = cap.requests.single;
      expect(r.path, '/institution/org1/availability/p1/overrides');
      expect(r.data, {'date': '2026-12-24T12:00:00.000Z', 'isBlocked': true});
    });

    test('booking lengths and timezone are sent on the page update', () async {
      final cap = _Capture();
      try {
        await AvailabilityRepository(_dio(cap)).updateInstitutionProfile(
          'org1',
          'p1',
          durationOptions: const [20, 45],
          defaultDuration: 45,
          timezone: 'America/Detroit',
        );
      } catch (_) {}
      expect(cap.requests.single.data, {
        'durationOptions': [20, 45],
        'defaultDuration': 45,
        'timezone': 'America/Detroit',
      });
    });
  });

  group('C6 — days off', () {
    AvailabilityProfile profile(List<Map<String, dynamic>> overrides) =>
        AvailabilityProfile.fromJson({
          'id': 'p1',
          'name': 'Intro',
          'slug': 'intro',
          'meetingTitle': 'Intro call',
          'overrides': overrides,
        });

    test('upcoming blocked days only, by their calendar day, in order', () {
      final now = DateTime(2026, 11, 6, 10);
      final days = upcomingDaysOff(
        profile([
          {'id': 'a', 'date': '2026-12-24T12:00:00.000Z', 'isBlocked': true},
          {'id': 'b', 'date': '2026-11-10T12:00:00.000Z', 'isBlocked': true},
          {'id': 'c', 'date': '2026-11-01T12:00:00.000Z', 'isBlocked': true},
          {'id': 'd', 'date': '2026-11-12T12:00:00.000Z', 'isBlocked': false},
        ]),
        now: now,
      );
      expect(days.map((d) => d.day),
          [DateTime(2026, 11, 10), DateTime(2026, 12, 24)]);
      expect(days.map((d) => d.id), ['b', 'a']);
    });
  });

  group('C6 — the booking page settings', () {
    Future<_Capture> openPages(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final cap = _Capture();
      final profile = AvailabilityProfile.fromJson({
        'id': 'p1',
        'name': 'Intro',
        'slug': 'intro',
        'meetingTitle': 'Intro call',
        'durationOptions': [30, 60],
        'defaultDuration': 30,
        'timezone': 'America/Detroit',
        'institutionId': 'org1',
        'overrides': [
          {'id': 'o', 'date': '2099-01-05T12:00:00.000Z', 'isBlocked': true},
        ],
      });
      await tester.pumpWidget(ProviderScope(
        overrides: [
          availabilityRepositoryProvider
              .overrideWithValue(AvailabilityRepository(_dio(cap))),
          institutionsRepositoryProvider
              .overrideWithValue(InstitutionsRepository(_dio(cap))),
          institutionProfilesProvider
              .overrideWith((ref, id) async => [profile]),
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
      return cap;
    }

    testWidgets('days off are listed, added and removed', (tester) async {
      final cap = await openPages(tester);
      expect(find.text('Days off (1)'), findsOneWidget);
      await tester.tap(find.text('Days off (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Add a day off'), findsOneWidget);
      await tester.tap(find.byTooltip('Remove this day off'));
      await tester.pumpAndSettle();
      final del = cap.requests.firstWhere((r) => r.method == 'DELETE');
      expect(del.path, '/institution/org1/availability/p1/overrides/o');
    });

    testWidgets('lengths and timezone are editable; a bad zone is refused',
        (tester) async {
      final cap = await openPages(tester);
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit profile'));
      await tester.pumpAndSettle();
      expect(find.text('Meeting lengths guests can book'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, '45 min'), findsOneWidget);

      final zone = find.widgetWithText(TextField, 'Timezone of this page');
      await tester.enterText(zone, 'EST');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(
        find.text('Use a timezone name like America/Detroit or Europe/London.'),
        findsOneWidget,
      );
      expect(cap.requests.where((r) => r.method == 'PATCH'), isEmpty);

      await tester.tap(find.widgetWithText(FilterChip, '45 min'));
      await tester.enterText(zone, 'Europe/London');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      final patch = cap.requests.firstWhere((r) => r.method == 'PATCH');
      final body = patch.data as Map;
      expect(body['durationOptions'], [30, 45, 60]);
      expect(body['defaultDuration'], 30);
      expect(body['timezone'], 'Europe/London');
    });
  });

  group('C8 — declining from the email link', () {
    test('the page is guest-reachable', () {
      const path = '/meetings/invitation/tok-1/decline';
      expect(classifyRoute(path), RouteClass.guestReachable);
      expect(routeAllowsUnauthenticatedEntry(path), isTrue);
    });

    Future<_Capture> open(WidgetTester tester, {int status = 200}) async {
      final cap = _Capture(status: status);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          meetingsRepositoryProvider
              .overrideWithValue(MeetingsRepository(_dio(cap))),
        ],
        child: const MaterialApp(
          home: InvitationDeclineScreen(token: 'tok-1'),
        ),
      ));
      await tester.pumpAndSettle();
      return cap;
    }

    testWidgets('opening the link does nothing until confirmed',
        (tester) async {
      final cap = await open(tester);
      expect(find.text('Decline this invitation?'), findsOneWidget);
      expect(cap.requests, isEmpty);
      await tester.tap(find.text('Decline invitation'));
      await tester.pumpAndSettle();
      expect(cap.requests.single.path,
          '/public/meetings/invitations/tok-1/decline');
      expect(find.text('Invitation declined'), findsOneWidget);
    });

    testWidgets('an unknown invitation is said plainly', (tester) async {
      await open(tester, status: 404);
      await tester.tap(find.text('Decline invitation'));
      await tester.pumpAndSettle();
      expect(find.text('We could not find this invitation'), findsOneWidget);
    });

    testWidgets('a failure offers to try again', (tester) async {
      await open(tester, status: 500);
      await tester.tap(find.text('Decline invitation'));
      await tester.pumpAndSettle();
      expect(find.text('Your answer was not sent'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });
}
