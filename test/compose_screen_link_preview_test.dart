import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:aura/core/institutions/institution_access_provider.dart';
import 'package:aura/core/net/dio_provider.dart';
import 'package:aura/features/posts/presentation/compose_screen.dart';

/// Compose Link Intelligence / OG Preview -- Phase 1.
///
/// Mounts the real, full `ComposeScreen` (member post composer) -- not a
/// minimal harness -- and drives an actual paste-a-URL flow through it,
/// verified via the save-draft action (`PUT /posts/draft`). Draft save and
/// publish share the exact same `_buildComposePayload()`, and top-level
/// publish additionally requires a primary topic selection (a separate,
/// unrelated UI interaction) via `_canPublish` -- exercising draft save
/// proves the link-preview payload wiring identically without coupling
/// this test to topic-picker mechanics.
void main() {
  testWidgets(
    'member compose: pasting a URL resolves a preview and the saved draft payload carries it',
    (tester) async {
      _useLargeSurface(tester);
      final posts = <Map<String, dynamic>>[];
      final resolveCalls = <String>[];
      final dio = _composeDio(posts: posts, resolveCalls: resolveCalls);

      await tester.pumpWidget(_wrap(dio));
      await tester.pumpAndSettle();

      final textField = find.byType(TextField).first;
      await tester.enterText(textField, 'check this out https://example.com/article');
      await tester.pump(const Duration(milliseconds: 600)); // detector debounce
      await tester.pumpAndSettle();

      expect(resolveCalls, contains('https://example.com/article'));
      // The resolved preview's title renders as a real card in the tree.
      expect(find.text('A Great Article'), findsOneWidget);

      await tester.tap(find.text('Save draft'));
      await tester.pumpAndSettle();

      expect(posts, isNotEmpty);
      final sent = posts.last;
      expect(sent['linkPreviewId'], 'lp-1');
      expect(sent['linkSourceUrl'], 'https://example.com/article');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets(
    'member compose: removing the pasted URL clears the preview and the payload',
    (tester) async {
      _useLargeSurface(tester);
      final posts = <Map<String, dynamic>>[];
      final resolveCalls = <String>[];
      final dio = _composeDio(posts: posts, resolveCalls: resolveCalls);

      await tester.pumpWidget(_wrap(dio));
      await tester.pumpAndSettle();

      final textField = find.byType(TextField).first;
      await tester.enterText(textField, 'see https://example.com/article');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(find.text('A Great Article'), findsOneWidget);

      await tester.enterText(textField, 'no link anymore');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      expect(find.text('A Great Article'), findsNothing);

      await tester.tap(find.text('Save draft'));
      await tester.pumpAndSettle();

      expect(posts, isNotEmpty);
      expect(posts.last['linkPreviewId'], isNull);
      expect(posts.last['linkSourceUrl'], isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets(
    'member compose: a URL that fails to resolve still allows saving with the plain link',
    (tester) async {
      _useLargeSurface(tester);
      final posts = <Map<String, dynamic>>[];
      final dio = _composeDio(posts: posts, resolveCalls: [], failResolve: true);

      await tester.pumpWidget(_wrap(dio));
      await tester.pumpAndSettle();

      final textField = find.byType(TextField).first;
      await tester.enterText(textField, 'see https://unresolvable.example.com');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      // No card (resolve failed / network error) -- but posting must still work.
      await tester.tap(find.text('Save draft'));
      await tester.pumpAndSettle();

      expect(posts, isNotEmpty);
      expect(posts.last['linkPreviewId'], isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
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
            builder: (context, state) => const Material(child: ComposeScreen()),
          ),
          GoRoute(
            path: '/posts/:id',
            builder: (context, state) => const SizedBox.shrink(),
          ),
          GoRoute(
            path: '/home',
            builder: (context, state) => const SizedBox.shrink(),
          ),
        ],
      ),
    ),
  );
}

Dio _composeDio({
  required List<Map<String, dynamic>> posts,
  required List<String> resolveCalls,
  bool failResolve = false,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final path = options.path;
        final method = options.method;

        if (method == 'GET' && (path == '/posts/held/latest' || path == '/posts/draft')) {
          return handler.resolve(
            Response(requestOptions: options, statusCode: 404, data: 'no draft'),
          );
        }

        if (method == 'GET' && path == '/users/me') {
          return handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {'id': 'user-1', 'handle': 'me', 'displayName': 'Me'},
            ),
          );
        }

        if (method == 'GET' &&
            (path.contains('/integrations/') || path.contains('/social/'))) {
          return handler.resolve(
            Response(requestOptions: options, statusCode: 404, data: 'not connected'),
          );
        }

        if (method == 'GET' && path.contains('topic')) {
          return handler.resolve(
            Response(requestOptions: options, statusCode: 200, data: {'data': <dynamic>[]}),
          );
        }

        if (method == 'POST' && path == '/link-previews/resolve') {
          final url = (options.data as Map)['url'] as String;
          resolveCalls.add(url);
          if (failResolve) {
            return handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
              ),
            );
          }
          return handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'data': {
                  'eligible': true,
                  'internal': false,
                  'sourceUrl': url,
                  'canonicalUrl': url,
                  'linkPreviewId': 'lp-1',
                  'status': 'READY',
                  'title': 'A Great Article',
                  'description': 'Learn something new.',
                  'siteName': 'example.com',
                  'imageUrl': null,
                  'faviconUrl': null,
                },
              },
            ),
          );
        }

        if (method == 'PUT' && path == '/posts/draft') {
          posts.add(Map<String, dynamic>.from(options.data as Map));
          return handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'data': {'id': 'post-1', 'text': options.data['text']},
              },
            ),
          );
        }

        if (method == 'POST' && (path == '/posts' || path == '/posts/draft/publish')) {
          posts.add(Map<String, dynamic>.from(options.data as Map));
          return handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'data': {'id': 'post-1', 'text': options.data['text']},
              },
            ),
          );
        }

        if (method == 'PATCH' && path.startsWith('/posts/')) {
          posts.add(Map<String, dynamic>.from(options.data as Map));
          return handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'data': {'id': 'post-1', 'text': options.data['text']},
              },
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
