import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:aura/core/institutions/institution_access_provider.dart';
import 'package:aura/core/net/dio_provider.dart';
import 'package:aura/features/posts/presentation/compose_screen.dart';

import 'support/reference_golden.dart';

/// Every top-level post says what it is. A new post opens on the choice
/// (founder, 2026-09-29, option C, after trying B live:
/// https://claude.ai/artifact/JEuASkaxxbMCHC1dWXMev7). Mounts the real
/// ComposeScreen at the founder's window (943 x 442).
void main() {
  Future<List<Map<String, dynamic>>> openWithDraft(
    WidgetTester tester, {
    required bool raiseAllowed,
    String? intent,
    bool shareAllowed = true,
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
      shareAllowed: shareAllowed,
    )));
    await tester.pumpAndSettle();
    return published;
  }

  testWidgets('a new post opens on "What are you posting?", and the choice is sent',
      (tester) async {
    final published = await openWithDraft(tester, raiseAllowed: true);

    expect(find.text('What are you posting?'), findsOneWidget);
    expect(find.text('Publish post'), findsNothing,
        reason: 'nothing to publish until the post says what it is');
    await expectReferenceGolden(find.byType(MaterialApp), 'goldens/compose_intent_doors_943.png');

    await tester.tap(find.text('A question you want answered.'));
    await tester.pumpAndSettle();
    expect(find.text('What are you posting?'), findsNothing);

    await tester.tap(find.text('Publish post'));
    await tester.pumpAndSettle();
    expect(published.last['intent'], 'ASK');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('unverified (Nimra): Ask and Raise issue say so as the composer opens',
      (tester) async {
    final published = await openWithDraft(tester, raiseAllowed: false);

    // Founder, 2026-09-29: "wire ask through identity check too".
    expect(find.textContaining('Asking a question needs your identity verified'),
        findsOneWidget);
    expect(find.textContaining('Raising an issue needs your identity verified'),
        findsOneWidget);
    // Share update during its grace: allowed, and the date is said.
    expect(find.textContaining('sharing an update needs your identity verified too'),
        findsOneWidget);
    expect(find.text('Verify'), findsNWidgets(3));
    await expectReferenceGolden(find.byType(MaterialApp), 'goldens/compose_intent_unverified_943.png');

    // Pressing either is refused; nothing is chosen, nothing is sent.
    await tester.tap(find.text('A question you want answered.'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('A problem, stated so that someone can respond to it.'));
    await tester.pumpAndSettle();
    expect(find.text('What are you posting?'), findsOneWidget);
    expect(published, isEmpty);

    // Share update is open to everyone.
    await tester.tap(find.text('News or progress others should know.'));
    await tester.pumpAndSettle();
    expect(find.text('What are you posting?'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('unverified: the Ask and Raise issue chips say so too, and keep the choice made',
      (tester) async {
    await openWithDraft(tester, raiseAllowed: false);
    await tester.tap(find.text('News or progress others should know.'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Raise issue'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Raising an issue needs your identity verified'),
        findsOneWidget);
    await tester.tap(find.text('Ask'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Asking a question needs your identity verified'),
        findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('after the grace, Share update is refused too: every public post needs identity',
      (tester) async {
    final published = await openWithDraft(tester, raiseAllowed: false, shareAllowed: false);

    expect(find.textContaining('Sharing an update needs your identity verified'),
        findsOneWidget);
    await tester.tap(find.text('News or progress others should know.'));
    await tester.pumpAndSettle();
    expect(find.text('What are you posting?'), findsOneWidget);
    expect(published, isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('a draft that already says what it is opens on its text and publishes',
      (tester) async {
    final published = await openWithDraft(tester, raiseAllowed: true, intent: 'UPDATE');

    expect(find.text('What are you posting?'), findsNothing);
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
  bool shareAllowed = true,
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
          // As the real server answers: every response is wrapped. The
          // unwrapped fixture hid the defect that let an unverified person
          // raise an issue (2026-09-29).
          return handler.resolve(ok({'ok': true, 'data': {
            'raiseIssue': raiseAllowed,
            'ask': raiseAllowed,
            'shareUpdate': shareAllowed,
            'identityVerified': raiseAllowed,
            // Far enough ahead that the grace is always running in this test.
            'shareUpdateFrom': '2099-10-15T04:00:00.000Z',
          }}));
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
