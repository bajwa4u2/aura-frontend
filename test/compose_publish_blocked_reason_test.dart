import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:aura/core/institutions/institution_access_provider.dart';
import 'package:aura/core/net/dio_provider.dart';
import 'package:aura/features/posts/presentation/compose_screen.dart';
import 'package:aura/features/topics/aura_topic_selector.dart';

/// Publish greyed out with its reason only in a tooltip is silent on a phone,
/// which has no hover (2026-10-21). The reason is said beside the button, and
/// when the topic is all that is missing, the line leads to the selector.
void main() {
  for (final size in const [Size(390, 844), Size(943, 442)]) {
    testWidgets(
        'a post without a topic says so beside Publish and opens the selector '
        '(${size.width.toInt()} wide)', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(_wrap(_dio()));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('compose-publish-blocked-reason')),
          findsOneWidget);
      expect(find.text('Choose a topic first.'), findsOneWidget);
      expect(find.byType(AuraTopicSelector), findsNothing,
          reason: 'the selector starts inside the collapsed Enrichment panel');

      await tester.tap(find.byKey(const ValueKey('compose-choose-topic')));
      await tester.pumpAndSettle();
      expect(find.byType(AuraTopicSelector), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }

  testWidgets('a post that can be published shows no blocked line',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(_wrap(_dio(primaryTopic: 'COMMUNITY')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('compose-publish-blocked-reason')),
        findsNothing);
    expect(find.byKey(const ValueKey('compose-choose-topic')), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

Widget _wrap(Dio dio) {
  return ProviderScope(
    overrides: [
      dioProvider.overrideWithValue(dio),
      institutionIdentityProvider.overrideWithValue(null),
    ],
    child: MaterialApp.router(
      routerConfig: GoRouter(
        initialLocation: '/compose',
        routes: [
          GoRoute(
            path: '/compose',
            builder: (context, state) => const Scaffold(body: ComposeScreen()),
          ),
          GoRoute(path: '/posts/:id', builder: (context, state) => const SizedBox.shrink()),
          GoRoute(path: '/home', builder: (context, state) => const SizedBox.shrink()),
        ],
      ),
    ),
  );
}

Dio _dio({String? primaryTopic}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final path = options.path;
        final method = options.method;
        Response<dynamic> ok(dynamic data) =>
            Response(requestOptions: options, statusCode: 200, data: data);

        if (method == 'GET' && path == '/posts/held/latest') {
          return handler.resolve(ok({
            'id': 'draft-1',
            'text': 'The bus route to the district hospital was cut last month.',
            'visibility': 'PUBLIC',
            'primaryTopic': ?primaryTopic,
            'intent': 'UPDATE',
          }));
        }
        if (method == 'GET' && path == '/public-record/capabilities/me') {
          return handler.resolve(ok({'ok': true, 'data': {
            'raiseIssue': true,
            'ask': true,
            'shareUpdate': true,
            'identityVerified': true,
            'shareUpdateFrom': '2099-10-15T04:00:00.000Z',
          }}));
        }
        if (method == 'GET' && path == '/users/me') {
          return handler.resolve(ok({'id': 'user-1', 'handle': 'me', 'displayName': 'Me'}));
        }
        if (method == 'PUT' && path == '/posts/draft') {
          return handler.resolve(ok({'data': {'id': 'draft-1'}}));
        }
        if (method == 'GET' && path.contains('topic')) {
          return handler.resolve(ok({'data': <dynamic>[]}));
        }
        return handler.resolve(
          Response(requestOptions: options, statusCode: 404, data: 'not here'),
        );
      },
    ),
  );
  return dio;
}
