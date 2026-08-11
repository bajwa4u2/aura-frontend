import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:aura/core/auth/session_providers.dart';
import 'package:aura/core/net/dio_provider.dart';
import 'package:aura/features/activity/presentation/activity_screen.dart';

/// Communication Timeline Authority -- Phase 1.
///
/// Mounts the real, full `ActivityScreen` -- not a minimal harness -- and
/// proves the previously-dead `type == 'LIVE'` rendering path (confirmed
/// dead in the investigation: `/notifications` could never return a LIVE
/// row before this chapter) now renders real call-outcome chronology
/// correctly for each of the four founder-approved Phase 1 outcomes, with
/// the exact item shapes the backend now actually returns: MISSED via its
/// own Notification(CALL_MISSED) row, and COMPLETED/DECLINED/CANCELLED via
/// NotificationsController.list()'s server-side Timeline merge.
void main() {
  testWidgets(
    'Activity renders a missed call (Notification-sourced) with attention and a "Missed" title',
    (tester) async {
      _useLargeSurface(tester);
      final dio = _activityDio(items: [_missedCallItem()]);

      await tester.pumpWidget(_wrap(dio));
      await tester.pumpAndSettle();

      expect(find.textContaining('Missed audio call from Caller One'), findsOneWidget);
    },
  );

  testWidgets(
    'Activity renders a completed outgoing call (Timeline-merged) with the outgoing phrasing',
    (tester) async {
      _useLargeSurface(tester);
      final dio = _activityDio(
        items: [_timelineItem(outcome: 'CALL_COMPLETED', direction: 'OUTGOING')],
      );

      await tester.pumpWidget(_wrap(dio));
      await tester.pumpAndSettle();

      expect(find.textContaining('You made a audio call'), findsOneWidget);
    },
  );

  testWidgets(
    'Activity renders a completed incoming call (Timeline-merged) with the incoming phrasing',
    (tester) async {
      _useLargeSurface(tester);
      final dio = _activityDio(
        items: [_timelineItem(outcome: 'CALL_COMPLETED', direction: 'INCOMING')],
      );

      await tester.pumpWidget(_wrap(dio));
      await tester.pumpAndSettle();

      expect(find.textContaining('Caller One called you'), findsOneWidget);
    },
  );

  testWidgets(
    'Activity renders a declined call (Timeline-merged)',
    (tester) async {
      _useLargeSurface(tester);
      final dio = _activityDio(
        items: [_timelineItem(outcome: 'CALL_DECLINED', direction: 'INCOMING')],
      );

      await tester.pumpWidget(_wrap(dio));
      await tester.pumpAndSettle();

      expect(find.textContaining('You declined a call from Caller One'), findsOneWidget);
    },
  );

  testWidgets(
    'Activity renders an outgoing cancelled call (Timeline-merged)',
    (tester) async {
      _useLargeSurface(tester);
      final dio = _activityDio(
        items: [_timelineItem(outcome: 'CALL_CANCELLED', direction: 'OUTGOING')],
      );

      await tester.pumpWidget(_wrap(dio));
      await tester.pumpAndSettle();

      expect(find.textContaining('You cancelled a audio call'), findsOneWidget);
    },
  );

  testWidgets(
    'A mixed feed renders every outcome without collapsing or duplicating rows',
    (tester) async {
      _useLargeSurface(tester);
      final dio = _activityDio(
        items: [
          _missedCallItem(),
          _timelineItem(outcome: 'CALL_COMPLETED', direction: 'OUTGOING', id: 'timeline:2'),
          _timelineItem(outcome: 'CALL_DECLINED', direction: 'INCOMING', id: 'timeline:3'),
          _timelineItem(outcome: 'CALL_CANCELLED', direction: 'INCOMING', id: 'timeline:4'),
        ],
      );

      await tester.pumpWidget(_wrap(dio));
      await tester.pumpAndSettle();

      expect(find.textContaining('Missed audio call from Caller One'), findsOneWidget);
      expect(find.textContaining('You made a audio call'), findsOneWidget);
      expect(find.textContaining('You declined a call from Caller One'), findsOneWidget);
      expect(find.textContaining('Caller One cancelled a audio call'), findsOneWidget);
    },
  );
}

void _useLargeSurface(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1400, 1600);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Map<String, dynamic> _missedCallItem() {
  return {
    'id': 'notif-missed-1',
    'type': 'LIVE',
    'actorType': 'USER',
    'actor': {
      'id': 'caller-1',
      'handle': 'caller1',
      'displayName': 'Caller One',
      'avatarUrl': null,
    },
    'threadId': 'thread-1',
    'readAt': null,
    'createdAt': '2026-08-13T00:00:00.000Z',
    'data': {
      'notificationKind': 'CALL_MISSED',
      'mediaMode': 'AUDIO',
      'sessionId': 'session-1',
      'threadId': 'thread-1',
    },
    'payload': {
      'notificationKind': 'CALL_MISSED',
      'mediaMode': 'AUDIO',
      'sessionId': 'session-1',
      'threadId': 'thread-1',
    },
  };
}

Map<String, dynamic> _timelineItem({
  required String outcome,
  required String direction,
  String id = 'timeline:1',
}) {
  return {
    'id': id,
    'type': 'LIVE',
    'actorType': 'USER',
    'actor': {
      'id': 'caller-1',
      'handle': 'caller1',
      'displayName': 'Caller One',
      'avatarUrl': null,
    },
    'threadId': 'thread-1',
    'readAt': '2026-08-13T00:00:00.000Z', // Timeline rows carry no attention.
    'createdAt': '2026-08-13T00:00:00.000Z',
    'data': {
      'notificationKind': outcome,
      'realtimeType': outcome,
      'mediaMode': 'AUDIO',
      'sessionId': 'session-1',
      'threadId': 'thread-1',
      'direction': direction,
    },
    'payload': {
      'notificationKind': outcome,
      'realtimeType': outcome,
      'mediaMode': 'AUDIO',
      'sessionId': 'session-1',
      'threadId': 'thread-1',
      'direction': direction,
    },
  };
}

Widget _wrap(Dio dio) {
  return ProviderScope(
    overrides: [
      dioProvider.overrideWithValue(dio),
      isAuthedProvider.overrideWithValue(true),
      isGuestSessionProvider.overrideWithValue(false),
    ],
    child: MaterialApp.router(
      routerConfig: GoRouter(
        initialLocation: '/activity',
        routes: [
          GoRoute(
            path: '/activity',
            builder: (context, state) => const ActivityScreen(),
          ),
          GoRoute(
            path: '/:catchAll(.*)',
            builder: (context, state) => const SizedBox.shrink(),
          ),
        ],
      ),
    ),
  );
}

Dio _activityDio({required List<Map<String, dynamic>> items}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final path = options.path;
        final method = options.method;

        if (method == 'GET' && path == '/notifications') {
          return handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {'items': items, 'nextCursor': null},
            ),
          );
        }

        if (method == 'GET' && path == '/notifications/unread-count') {
          return handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {'unreadCount': items.where((i) => i['readAt'] == null).length},
            ),
          );
        }

        return handler.resolve(
          Response(requestOptions: options, statusCode: 404, data: 'unhandled ${options.method} $path'),
        );
      },
    ),
  );
  return dio;
}
