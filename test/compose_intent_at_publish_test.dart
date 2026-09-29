import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:aura/core/institutions/institution_access_provider.dart';
import 'package:aura/core/net/dio_provider.dart';
import 'package:aura/features/posts/presentation/compose_screen.dart';

/// Every top-level post says what it is. Written first, then asked at Publish
/// when nothing was chosen (founder, 2026-09-29, option B:
/// https://claude.ai/artifact/JEuASkaxxbMCHC1dWXMev7). Mounts the real
/// ComposeScreen at the founder's window (943 x 442).
void main() {
  Future<List<Map<String, dynamic>>> openWithDraft(
    WidgetTester tester, {
    required bool raiseAllowed,
    String? intent,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(943, 442);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final published = <Map<String, dynamic>>[];
    await tester.pumpWidget(_wrap(_dio(
      published: published,
      raiseAllowed: raiseAllowed,
      draftIntent: intent,
    )));
    await tester.pumpAndSettle();
    return published;
  }

  testWidgets('Publish with nothing chosen asks what the post is, then sends it',
      (tester) async {
    final published = await openWithDraft(tester, raiseAllowed: true);

    await tester.tap(find.text('Publish post'));
    await tester.pumpAndSettle();

    expect(find.text('What is this post?'), findsOneWidget);
    expect(published, isEmpty, reason: 'nothing is sent before the answer');
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/compose_intent_at_publish_943.png'));

    await tester.tap(find.text('A question you want answered.'));
    await tester.pumpAndSettle();

    final shown = find.byType(SnackBar).evaluate().map((e) => ((e.widget as SnackBar).content as Text).data).toList();
    expect(published, isNotEmpty, reason: 'snackbar: $shown');
    expect(published.last['intent'], 'ASK');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('without a current verification, Raise issue says so before anything is lost',
      (tester) async {
    final published = await openWithDraft(tester, raiseAllowed: false);

    await tester.tap(find.text('Publish post'));
    await tester.pumpAndSettle();

    expect(find.text('Needs your identity verified. Your draft is kept.'), findsOneWidget);
    expect(find.text('Verify'), findsOneWidget);
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/compose_intent_unverified_943.png'));

    // Choosing it does nothing; nothing is sent.
    await tester.tap(find.text('Needs your identity verified. Your draft is kept.'));
    await tester.pumpAndSettle();
    expect(published, isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('a draft that already says what it is publishes without asking',
      (tester) async {
    final published = await openWithDraft(tester, raiseAllowed: true, intent: 'UPDATE');

    await tester.tap(find.text('Publish post'));
    await tester.pumpAndSettle();

    expect(find.text('What is this post?'), findsNothing);
    expect(published.last['intent'], 'UPDATE');

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
          GoRoute(path: '/verify-identity', builder: (context, state) => const SizedBox.shrink()),
        ],
      ),
    ),
  );
}

Dio _dio({
  required List<Map<String, dynamic>> published,
  required bool raiseAllowed,
  String? draftIntent,
}) {
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
            'primaryTopic': 'COMMUNITY',
            'intent': ?draftIntent,
          }));
        }
        if (method == 'GET' && path == '/public-record/capabilities/me') {
          return handler.resolve(ok({'raiseIssue': raiseAllowed}));
        }
        if (method == 'GET' && path == '/users/me') {
          return handler.resolve(ok({'id': 'user-1', 'handle': 'me', 'displayName': 'Me'}));
        }
        if (method == 'PUT' && path == '/posts/draft') {
          return handler.resolve(ok({'data': {'id': 'draft-1'}}));
        }
        if (method == 'POST' && path == '/posts/draft/publish') {
          published.add(Map<String, dynamic>.from(options.data as Map));
          return handler.resolve(ok({'data': {'id': 'post-1'}}));
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
