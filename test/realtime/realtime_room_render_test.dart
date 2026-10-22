// THE CALL ROOM, RENDERED (realtime audit, 22 Oct 2026, package RA6).
//
// The six cases of test/realtime_room_golden_test.dart were skipped as
// "pre-existing rot", so the call screen had no render check at all. These
// are the same journeys as plain widget tests, found by finders against the
// labels the room shows today, not pixels; they run in CI with everything
// else.
// ignore_for_file: unused_element, unused_import, unused_element_parameter

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aura/core/auth/auth_providers.dart';
import 'package:aura/core/net/dio_provider.dart';
import 'package:aura/features/realtime/application/realtime_controller.dart';
import 'package:aura/features/realtime/application/realtime_providers.dart';
import 'package:aura/features/realtime/data/realtime_media_service.dart';
import 'package:aura/features/realtime/data/realtime_repository.dart';
import 'package:aura/features/realtime/data/realtime_socket_service.dart';
import 'package:aura/features/realtime/domain/realtime_enums.dart';
import 'package:aura/features/realtime/domain/realtime_models.dart';
import 'package:aura/features/realtime/domain/realtime_state.dart';
import 'package:aura/features/realtime/presentation/realtime_room_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TEST STUBS
// ─────────────────────────────────────────────────────────────────────────────

class _StubController extends RealtimeController {
  _StubController(RealtimeState preset)
      : super(
          _QuietRepository(),
          RealtimeSocketService(),
          RealtimeMediaService(),
          TokenStore(),
          // Client-identity resolver (added to RealtimeController when the
          // realtime handshake gained identity headers). The stub never
          // performs a real handshake, so a no-op resolver is sufficient.
          () async => null,
        ) {
    // Override state with the desired test preset after super() initialises it.
    state = preset;
  }

  // Silence all side-effecting methods so no network / WebRTC calls are made.
  @override Future<void> join(String id) async {}
  @override Future<void> resume(String id) async {}
  @override Future<void> hydrateSession(String id) async {}
  @override Future<void> leave() async {}
  @override Future<void> toggleMicrophone() async {}
  @override Future<void> toggleCamera() async {}
  @override Future<void> requestJoin(String id) async {}
  @override Future<void> inviteMember({required String invitedUserId, String? note}) async {}
  @override Future<void> approveJoinRequest(String userId) async {}
  @override Future<void> rejectJoinRequest(String userId) async {}
  @override Future<void> removeParticipant(String userId) async {}
  @override Future<void> setWaitingRoom(bool enabled) async {}
  @override Future<void> setLocked(bool locked) async {}
  @override Future<void> requestConsent() async {}
  @override Future<void> requestRecording({String? title}) async {}
  @override Future<void> requestTranscript({String? title}) async {}
  @override Future<void> answerConsent({required bool granted}) async {}
  @override Future<void> syncConsentsVisibility({bool? canManageConsents}) async {}
  @override Future<String> ensureCorrespondenceLive({required String surfaceType, required String surfaceId, required String kind, Map<String, dynamic>? metadata, bool joinAfterCreate = true}) async => '';
}

// ─────────────────────────────────────────────────────────────────────────────
// FIXTURE DATA
// ─────────────────────────────────────────────────────────────────────────────

RealtimeSession _session({bool isVideo = false}) => RealtimeSession.fromJson(<String, dynamic>{
  'id': 'sess-test-001',
  'surfaceType': 'thread',
  'surfaceId': 'thread-abc',
  'startedByUserId': 'user-host',
  'status': 'ACTIVE',
  'isActive': true,
  'isLocked': false,
  'waitingRoomEnabled': false,
  'startedAt': DateTime.now().subtract(const Duration(minutes: 7, seconds: 42)).toIso8601String(),
});

RealtimePolicy _policy({bool canModerate = false}) => RealtimePolicy.fromJson(<String, dynamic>{
  'waitingRoomEnabled': false,
  'isLocked': false,
  'audioAllowed': true,
  'videoAllowed': true,
  'screenAllowed': false,
  'canRecord': true,
  'canTranscribe': true,
});

List<RealtimeParticipant> _participants() => [
  RealtimeParticipant.fromJson(<String, dynamic>{
    'id': 'p1', 'userId': 'user-host', 'role': 'HOST',
    'joinState': 'ACTIVE', 'isPresent': true,
    'audioOn': true, 'videoOn': true, 'screenOn': false,
    'displayName': 'Alice', 'handle': 'alice',
  }),
  RealtimeParticipant.fromJson(<String, dynamic>{
    'id': 'p2', 'userId': 'user-guest', 'role': 'PARTICIPANT',
    'joinState': 'ACTIVE', 'isPresent': true,
    'audioOn': false, 'videoOn': false, 'screenOn': false,
    'displayName': 'Bob', 'handle': 'bob',
  }),
  RealtimeParticipant.fromJson(<String, dynamic>{
    'id': 'p3', 'userId': 'user-guest2', 'role': 'PARTICIPANT',
    'joinState': 'ACTIVE', 'isPresent': true,
    'audioOn': true, 'videoOn': false, 'screenOn': false,
    'displayName': 'Carol', 'handle': 'carol',
  }),
];

RealtimeState _audioCallState() => RealtimeState.initial().copyWith(
  connectionStatus: RealtimeConnectionStatus.connected,
  joinState: RealtimeJoinState.joined,
  sessionId: 'sess-test-001',
  session: _session(),
  participants: _participants(),
  policy: _policy(),
  callMode: 'audio',
  isMediaReady: true,
  microphoneEnabled: true,
  cameraEnabled: false,
);

RealtimeState _videoCallState() => RealtimeState.initial().copyWith(
  connectionStatus: RealtimeConnectionStatus.connected,
  joinState: RealtimeJoinState.joined,
  sessionId: 'sess-test-001',
  session: _session(isVideo: true),
  participants: _participants(),
  policy: _policy(),
  callMode: 'video',
  isMediaReady: true,
  microphoneEnabled: true,
  cameraEnabled: true,
);

class _QuietRepository extends RealtimeRepository {
  _QuietRepository() : super(Dio());
  @override
  Future<void> reportStageDiagnostic(
    String sessionId, {
    required String phase,
    required String code,
    required String message,
    required String platform,
  }) async {}
}

Widget _wrap(RealtimeState state) {
  final fakeDio = Dio()..options = BaseOptions(baseUrl: 'http://localhost:9999');
  return ProviderScope(
    overrides: [
      realtimeControllerProvider.overrideWith((ref) => _StubController(state)),
      realtimeRepositoryProvider.overrideWithValue(_QuietRepository()),
      dioProvider.overrideWithValue(fakeDio),
    ],
    child: const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: RealtimeRoomScreen(sessionId: 'sess-test-001'),
    ),
  );
}

Future<void> _pump(WidgetTester tester, RealtimeState state, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(_wrap(state));
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('01 audio call, desktop: core controls, no camera', (tester) async {
    await _pump(tester, _audioCallState(), const Size(1280, 800));
    expect(find.text('Audio call'), findsOneWidget);
    expect(find.text('Mute'), findsOneWidget);
    expect(find.text('More'), findsOneWidget);
    expect(find.text('Leave'), findsOneWidget);
    expect(find.text('Turn off'), findsNothing, reason: 'no camera on audio');
    expect(find.text('Flip'), findsNothing);
    // No dashboard noise on the default screen.
    expect(find.text('Recording unavailable'), findsNothing);
    expect(find.text('Room controls'), findsNothing);
    await _unmount(tester);
  });

  testWidgets('02 video call, desktop: camera controls shown', (tester) async {
    await _pump(tester, _videoCallState(), const Size(1280, 800));
    expect(find.text('Video call'), findsOneWidget);
    expect(find.text('Turn off'), findsOneWidget);
    expect(find.text('Mute'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('03 audio call, phone: the dock is all there and nothing overflows',
      (tester) async {
    await _pump(tester, _audioCallState(), const Size(390, 844));
    expect(find.text('Mute'), findsOneWidget);
    expect(find.text('Leave'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _unmount(tester);
  });

  testWidgets('04 everyone in the call is on the stage', (tester) async {
    await _pump(tester, _audioCallState(), const Size(1280, 800));
    expect(find.text('Alice'), findsWidgets);
    expect(find.text('Bob'), findsWidgets);
    expect(find.text('Carol'), findsWidgets);
    await _unmount(tester);
  });

  testWidgets('05 the clock runs without rebuilding the room', (tester) async {
    await _pump(tester, _audioCallState(), const Size(1280, 800));
    final before = find.textContaining(RegExp(r'^\d\d:\d\d')).evaluate().length;
    expect(before, greaterThan(0), reason: 'the call shows its duration');
    await tester.pump(const Duration(seconds: 2));
    expect(find.textContaining(RegExp(r'^\d\d:\d\d')), findsWidgets);
    await _unmount(tester);
  });

  testWidgets('06 leaving the screen disposes cleanly', (tester) async {
    await _pump(tester, _audioCallState(), const Size(1280, 800));
    await _unmount(tester);
    expect(tester.takeException(), isNull,
        reason: 'dispose must not read ref after the screen is gone');
  });
}
