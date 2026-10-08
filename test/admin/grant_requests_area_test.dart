import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/admin/areas/grant_requests_area.dart';
import 'package:aura/features/admin/data/operator_grants.dart';
import 'package:aura/features/admin/domain/operator_area.dart';
import 'package:aura/features/admin/domain/operator_authority_provider.dart';
import 'package:aura/features/admin/domain/operator_capability.dart';
import 'package:aura/features/admin/domain/operator_routes.dart';
import 'package:aura/features/monetization/domain/monetization_models.dart';
import 'package:aura/features/monetization/providers/monetization_providers.dart';

/// The founder had no way to see or decide Institutional Grant requests.
/// This is the queue: list, approve, decline (with an optional reason), and
/// the truthful loading, empty and error states.

Map<String, dynamic> _row(String id, {String? message}) => {
  'id': id,
  'institutionId': 'inst_$id',
  'status': 'PENDING',
  'requestedTier': 'COMMUNITY',
  'message': message,
  'requestedAt': '2026-10-06T14:30:00.000Z',
  'institution': {
    'id': 'inst_$id',
    'name': 'Riverside Library $id',
    'slug': 'riverside-$id',
    'plan': 'FREE',
  },
  'requestedBy': {
    'id': 'u_$id',
    'handle': 'ayesha',
    'displayName': 'Ayesha Khan',
    'avatarUrl': null,
  },
};

class _FakeRepo extends OperatorGrantRepository {
  _FakeRepo(this.rows, {this.fail = false}) : super(Dio());

  List<Map<String, dynamic>> rows;
  bool fail;
  int reads = 0;
  final approved = <String>[];
  final declined = <String, String?>{};

  @override
  Future<List<OperatorGrantRequest>> pending() async {
    reads++;
    if (fail) throw Exception('offline');
    return [for (final r in rows) OperatorGrantRequest.fromJson(r)];
  }

  @override
  Future<void> approve(String grantId) async {
    approved.add(grantId);
    rows = rows.where((r) => r['id'] != grantId).toList();
  }

  @override
  Future<void> decline(String grantId, {String? reason}) async {
    declined[grantId] = reason;
    rows = rows.where((r) => r['id'] != grantId).toList();
  }
}

OperatorAuthority _authority(Set<OperatorCapability> caps) => OperatorAuthority(
  userId: 'op',
  roles: const {OperatorRole.owner},
  capabilities: caps,
  unknownCapabilities: const {},
);

Future<void> _pump(
  WidgetTester tester,
  _FakeRepo repo, {
  Set<OperatorCapability> caps = const {
    OperatorCapability.institutionsRead,
    OperatorCapability.institutionsWrite,
  },
}) async {
  tester.view
    ..physicalSize = const Size(1200, 1800)
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        operatorAuthorityProvider.overrideWithValue(
          AsyncValue.data(_authority(caps)),
        ),
        operatorGrantRepositoryProvider.overrideWithValue(repo),
        monetizationConfigProvider.overrideWith(
          (ref) async => MonetizationConfig.fromJson({
            'monetizationMode': 'visible',
            'tiers': [
              {'tier': 'COMMUNITY', 'label': 'Community'},
            ],
          }),
        ),
      ],
      child: const MaterialApp(home: Scaffold(body: GrantRequestsArea())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('the wire: institution, tier, requester, message and time', () {
    final r = OperatorGrantRequest.fromJson(_row('g1', message: 'We are new.'));
    expect(r.institutionName, 'Riverside Library g1');
    expect(r.requestedTier, 'COMMUNITY');
    expect(r.requesterLabel, 'Ayesha Khan · @ayesha');
    expect(r.message, 'We are new.');
    expect(r.requestedAt, DateTime.utc(2026, 10, 6, 14, 30));
  });

  test('the queue lives in WORK, and its permission opens WORK', () {
    expect(OperatorArea.forPath(kOperatorGrantRequestsRoot), OperatorArea.work);
    expect(
      OperatorArea.work.isVisibleTo(
        _authority({OperatorCapability.institutionsRead}),
      ),
      isTrue,
    );
  });

  testWidgets('lists what is waiting, with who asked and when', (tester) async {
    await _pump(tester, _FakeRepo([_row('g1', message: 'We are new.')]));
    expect(find.text('Institutional grant requests'), findsOneWidget);
    expect(find.text('1 waiting'), findsOneWidget);
    expect(find.text('Riverside Library g1'), findsOneWidget);
    expect(find.text('Community'), findsOneWidget);
    expect(find.text('Ayesha Khan · @ayesha'), findsOneWidget);
    expect(find.text('We are new.'), findsOneWidget);
    // Dates always carry their time.
    expect(find.textContaining(':30'), findsOneWidget);
    expect(find.text('Approve'), findsOneWidget);
    expect(find.text('Decline'), findsOneWidget);
  });

  testWidgets('approve: the ceremony, the call, and a fresh list',
      (tester) async {
    final repo = _FakeRepo([_row('g1')]);
    await _pump(tester, repo);

    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();
    expect(find.text('Approve the grant'), findsOneWidget);
    // Confirm in the sheet (the last "Approve" on screen).
    await tester.tap(find.text('Approve').last);
    await tester.pumpAndSettle();
    expect(repo.approved, ['g1']);

    // Close the outcome and see the refreshed queue.
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(repo.reads, greaterThanOrEqualTo(2));
    expect(find.text('Nothing is waiting'), findsOneWidget);
  });

  testWidgets('decline: a reason is optional and reaches the server',
      (tester) async {
    final repo = _FakeRepo([_row('g1'), _row('g2')]);
    await _pump(tester, repo);

    await tester.tap(find.text('Decline').first);
    await tester.pumpAndSettle();
    expect(find.text('Decline the request'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Not an institution yet.');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Decline').last);
    await tester.pumpAndSettle();
    expect(repo.declined, {'g1': 'Not an institution yet.'});

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    // And without one.
    await tester.tap(find.text('Decline').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Decline').last);
    await tester.pumpAndSettle();
    expect(repo.declined['g2'], isNull);
    expect(repo.declined.containsKey('g2'), isTrue);
  });

  testWidgets('nothing waiting is said as a result', (tester) async {
    await _pump(tester, _FakeRepo(const []));
    expect(find.text('Nothing is waiting'), findsOneWidget);
    expect(find.text('0 waiting'), findsOneWidget);
  });

  testWidgets('a read failure is a failure, never an empty queue',
      (tester) async {
    await _pump(tester, _FakeRepo(const [], fail: true));
    expect(find.text('The grant requests could not be loaded'), findsOneWidget);
    expect(find.text('Nothing is waiting'), findsNothing);
  });

  testWidgets('read-only operators see the queue but cannot decide',
      (tester) async {
    await _pump(
      tester,
      _FakeRepo([_row('g1')]),
      caps: const {OperatorCapability.institutionsRead},
    );
    expect(find.text('Riverside Library g1'), findsOneWidget);
    expect(find.text('Approve'), findsNothing);
    expect(
      find.text('You may read these requests, but not decide them.'),
      findsOneWidget,
    );
  });

  testWidgets('an operator without the permission is told which one',
      (tester) async {
    await _pump(
      tester,
      _FakeRepo([_row('g1')]),
      caps: const {OperatorCapability.moderationRead},
    );
    expect(find.text('Riverside Library g1'), findsNothing);
  });
}
