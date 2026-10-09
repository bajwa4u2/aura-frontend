import 'dart:convert';
import 'dart:typed_data';

import 'package:aura/core/authority/authority_providers.dart';
import 'package:aura/core/authority/capability_projection.dart';
import 'package:aura/core/net/dio_provider.dart';
import 'package:aura/core/notifications/notification_presentation.dart';
import 'package:aura/features/institutions/engagement/engagement_detail_screen.dart';
import 'package:aura/features/institutions/engagement/engagement_models.dart';
import 'package:aura/features/institutions/engagement/engagement_providers.dart';
import 'package:aura/features/me/presentation/my_questions_screen.dart';
import 'package:aura/features/posts/domain/communication_continuity.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// THE ENGAGEMENT LOOP CLOSES (2026-10-09): responding puts an official reply
/// on the person's post (it no longer publishes a separate post), a raised
/// issue can be committed to or resolved in the same step, and the person who
/// asked sees, by name, who answered.
class _Capture implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    requests.add(o);
    return ResponseBody.fromString(jsonEncode({'ok': true}), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

RoutedRecord _record({String intent = 'ISSUE', String status = 'PENDING'}) => RoutedRecord.fromJson({
      'id': 'rec-1',
      'status': status,
      'routedAt': '2026-10-09T12:00:00Z',
      'participationMode': 'ACCOUNTABLE',
      'post': {
        'id': 'post-1',
        'text': 'The streetlight on Goddard Rd has been out for a month.',
        'intent': intent,
        'primaryTopic': 'PUBLIC_SAFETY',
        'createdAt': '2026-10-09T11:00:00Z',
        'author': {'id': 'u-1', 'handle': 'sara', 'displayName': 'Sara'},
      },
    });

CapabilityProjection _speaker({bool publish = true}) => CapabilityProjection(InstitutionStanding.fromBackend(
      institutionId: 'inst-1',
      institutionName: 'City of Taylor',
      capabilities: ['OFFICIAL_REPRESENTATION', if (publish) 'PUBLISH_OFFICIAL'],
      roleWire: 'MEMBER',
    ));

Future<_Capture> _open(WidgetTester t, RoutedRecord record, {CapabilityProjection? projection}) async {
  t.view
    ..physicalSize = const Size(900, 1400)
    ..devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  final capture = _Capture();
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test/v1'))..httpClientAdapter = capture;
  await t.pumpWidget(ProviderScope(
    overrides: [
      dioProvider.overrideWithValue(dio),
      engagementDetailProvider(('inst-1', 'rec-1')).overrideWith((ref) async => record),
      capabilityProjectionForProvider.overrideWith((ref, id) => projection ?? _speaker()),
    ],
    child: const MaterialApp(
      home: Scaffold(body: EngagementDetailScreen(institutionId: 'inst-1', recordId: 'rec-1')),
    ),
  ));
  await t.pumpAndSettle();
  return capture;
}

void main() {
  testWidgets('responding to an issue can commit the institution, in one request to respond', (t) async {
    final capture = await _open(t, _record());
    expect(find.textContaining('Waiting for a response'), findsOneWidget);

    await t.tap(find.text('Respond'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).first, 'We will replace it by Friday.');
    await t.tap(find.text('Commits to act'));
    await t.pumpAndSettle();

    // DD-43: a commitment says when. Without a day nothing is sent.
    await t.tap(find.text('Send response'));
    await t.pumpAndSettle();
    expect(capture.requests.where((r) => r.path.endsWith('/respond')), isEmpty);
    expect(find.textContaining('choose a due date'), findsOneWidget);

    // The picker opens a week out; accept it.
    await t.tap(find.text('Choose'));
    await t.pumpAndSettle();
    await t.tap(find.text('OK'));
    await t.pumpAndSettle();
    final day = DateUtils.dateOnly(DateTime.now()).add(const Duration(days: 7));
    final iso = '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

    await t.tap(find.text('Send response'));
    await t.pumpAndSettle();

    final sent = capture.requests.where((r) => r.path.endsWith('/respond')).toList();
    expect(sent, hasLength(1));
    expect(sent.single.path, '/institutions/inst-1/engagement/rec-1/respond');
    expect(sent.single.data, {'text': 'We will replace it by Friday.', 'outcome': 'COMMITMENT', 'dueAt': iso});
    // Nothing is published as a separate institution post any more.
    expect(capture.requests.any((r) => r.path.contains('/posts')), isFalse);
  });

  testWidgets('a question is answered: no commit or resolve is offered', (t) async {
    await _open(t, _record(intent: 'ASK'));
    expect(find.textContaining('Waiting for an answer'), findsOneWidget);
    await t.tap(find.text('More'));
    await t.pumpAndSettle();
    expect(find.text('Acknowledge'), findsNothing); // issues only
    await t.tapAt(const Offset(5, 5));
    await t.pumpAndSettle();
    await t.tap(find.text('Respond'));
    await t.pumpAndSettle();
    expect(find.text('Commits to act'), findsNothing);
    expect(find.text('Marks it resolved'), findsNothing);
  });

  testWidgets('an issue waiting for a response can be acknowledged', (t) async {
    final capture = await _open(t, _record());
    // DD-43: everything but the one gold action is under More.
    await t.tap(find.text('More'));
    await t.pumpAndSettle();
    await t.tap(find.text('Acknowledge'));
    await t.pumpAndSettle();
    // The record and Memory refresh afterwards, so look for the request itself.
    expect(capture.requests.map((r) => r.path), contains('/institutions/inst-1/engagement/rec-1/acknowledge'));
  });

  testWidgets('someone who does not speak for the institution is told why there is no Respond', (t) async {
    await _open(t, _record(), projection: CapabilityProjection(InstitutionStanding.fromBackend(
      institutionId: 'inst-1',
      institutionName: 'City of Taylor',
      capabilities: const [],
      roleWire: 'MEMBER',
    )));
    expect(find.text('Respond'), findsNothing);
    expect(find.textContaining('Only someone who speaks officially'), findsOneWidget);
  });

  test('the asker sees who answered, by name', () {
    final answered = MyPublicRecord.fromJson({
      'postId': 'p1',
      'intent': 'ASK',
      'text': 'Is the library open on Sunday?',
      'createdAt': '2026-10-09T11:00:00Z',
      'continuity': {
        'intent': 'ASK',
        'status': 'ANSWERED',
        'routedTo': [{'id': 'i1', 'name': 'Taylor Library', 'slug': 'taylor-library'}],
        'answeredBy': [{'id': 'i1', 'name': 'Taylor Library', 'slug': 'taylor-library'}],
      },
    });
    expect(myRecordOutcome(answered), 'Answered by Taylor Library.');

    final issue = MyPublicRecord.fromJson({
      'postId': 'p2',
      'intent': 'ISSUE',
      'text': 'Streetlight out',
      'continuity': {
        'intent': 'ISSUE',
        'communicationStatus': 'Routed',
        'accountabilityLifecycles': [
          {
            'institutionId': 'i2',
            'institution': {'id': 'i2', 'name': 'City of Taylor', 'slug': 'city-of-taylor'},
            'status': 'COMMITTED',
            'routedAt': '2026-10-09T11:00:00Z',
            'updatedAt': '2026-10-09T12:00:00Z',
          },
        ],
      },
    });
    expect(myRecordOutcome(issue), 'City of Taylor: committed to act');
    final lifecycle = (issue.continuity as RaiseIssueContinuity).accountabilityLifecycles.single;
    expect(lifecycle.institutionName, 'City of Taylor');
  });

  test('the institution is told a question arrived, in its own name', () {
    final title = resolveNotificationTitle(
        {'type': 'PUBLIC_RECORD_ARRIVED', 'actorName': 'City of Taylor', 'intent': 'ISSUE'});
    expect(title, 'A public issue reached City of Taylor');
    final reminder = resolveNotificationTitle(
        {'type': 'PUBLIC_RECORD_ARRIVED', 'actorName': 'City of Taylor', 'intent': 'ASK', 'reminder': true});
    expect(reminder, 'A public question is still waiting for City of Taylor');
  });
}
