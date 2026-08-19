// RC7, COMPOSE HALF — the composer restored the draft's CONTENT but not its
// IDENTITY.
//
// The post composer's lifecycle is deliberately unlike the article editor's:
// `PUT /posts/draft` upserts the author's ONE held draft, so a remount can
// never mint a duplicate and the route needs no id in it. What the restore
// dropped was the id of the draft it had just loaded — `_draftPostId` stayed
// null after every refresh.
//
// Everything keyed to that id therefore reported a draft that plainly existed
// as absent: ambient governance never ran, so the panel read "Not yet
// reviewed" for work already assessed, and acknowledging a pending action
// silently did nothing.
//
// Driven through the REAL ComposeScreen with only the transport canned.
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:aura/core/auth/session_providers.dart';
import 'package:aura/core/net/dio_provider.dart';
import 'package:aura/features/posts/presentation/compose_screen.dart';

const _draftId = 'post-draft-77';

void main() {
  testWidgets('RC7 — a restored draft is governed by its real id', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 1600);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final calls = <String>[];
    await tester.pumpWidget(_app(_composeDio(calls)));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 2)); // governance debounce
    await tester.pump();

    expect(calls, contains('GET /posts/held/latest'),
        reason: 'The composer restores the author\'s single held draft.');
    expect(
      calls,
      contains('POST /posts/$_draftId/integrity/review'),
      reason: 'Before the fix the restored draft had no id, so ambient '
          'governance never spoke about it at all.',
    );

    // And the text really did come back — identity was restored ALONGSIDE
    // content, not instead of it.
    expect(find.text('a draft already in progress'), findsOneWidget);
  });

  testWidgets('RC7 — no draft to restore means nothing is governed',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 1600);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final calls = <String>[];
    await tester.pumpWidget(_app(_composeDio(calls, draft: false)));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    expect(
      calls.where((c) => c.contains('integrity/review')),
      isEmpty,
      reason: 'A composer with no draft must not invent one to review.',
    );
  });
}

Widget _app(Dio dio) {
  return ProviderScope(
    overrides: [
      dioProvider.overrideWithValue(dio),
      authMeDataProvider.overrideWith((ref) async => {
            'id': 'user-1',
            'accountType': 'PUBLIC',
            'identityBaselineComplete': true,
          }),
    ],
    child: MaterialApp.router(
      routerConfig: GoRouter(
        initialLocation: '/compose',
        routes: [
          GoRoute(
            path: '/compose',
            builder: (context, state) => const Scaffold(body: ComposeScreen()),
          ),
          GoRoute(path: '/login', builder: (_, __) => const SizedBox.shrink()),
        ],
      ),
    ),
  );
}

Dio _composeDio(List<String> calls, {bool draft = true}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      final signature = '${options.method} ${options.path}';
      calls.add(signature);

      Response<dynamic> ok(dynamic data) => Response(
            requestOptions: options,
            statusCode: 200,
            data: data,
          );

      if (options.path == '/posts/held/latest' ||
          options.path == '/posts/draft') {
        if (!draft) {
          return handler.reject(DioException(
            requestOptions: options,
            response: Response(requestOptions: options, statusCode: 404),
            type: DioExceptionType.badResponse,
          ));
        }
        return handler.resolve(ok({
          'item': {
            'id': _draftId,
            'text': 'a draft already in progress',
            'visibility': 'PUBLIC',
            'updatedAt': '2026-08-19T00:00:00.000Z',
            'media': <dynamic>[],
            'tagReferences': <dynamic>[],
          },
        }));
      }

      if (options.path.contains('/integrity/review')) {
        return handler.resolve(ok({
          'data': {
            'assessment': null,
            'pendingAction': null,
          },
        }));
      }

      return handler.resolve(ok({'data': <String, dynamic>{}}));
    },
  ));
  return dio;
}
