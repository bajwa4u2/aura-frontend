import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aura/core/net/dio_provider.dart';
import 'package:aura/features/create/presentation/new_conversation_screen.dart';

void main() {
  testWidgets('member selections survive search result replacement', (
    tester,
  ) async {
    _useLargeSurface(tester);
    final dio = _conversationDio();
    await tester.pumpWidget(_wrap(dio));
    await tester.pumpAndSettle();

    await _selectMember(tester, 'alice', 'Alice Adams');
    expect(find.text('Alice Adams'), findsNWidgets(2));

    await _selectMember(tester, 'bob', 'Bob Brown');

    expect(find.text('Alice Adams'), findsOneWidget);
    expect(find.text('Bob Brown'), findsNWidgets(2));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  // Identity Foundation Phase 1 -- shared identity resolution repair.
  // Regression test for the fixed defect: `_DirectoryEntry.id` and
  // `.userId` used to be resolved via independently-ordered fallback
  // chains, so the same underlying user could produce two different `id`
  // values depending on which listing surfaced them (e.g. a relationship
  // wrapper's own row id vs the raw user id). That let one real person
  // appear as two selectable/selected entries. This fixture simulates
  // exactly that: the same userId ("user-alice") is returned under two
  // different wrapper `id`s across two searches.
  testWidgets(
    'the same underlying member is not treated as two entries when surfaced under different wrapper ids',
    (tester) async {
      _useLargeSurface(tester);
      final posts = <Map<String, dynamic>>[];
      final dio = _conversationDioWithDivergentWrapperIds(posts: posts);
      await tester.pumpWidget(_wrap(dio));
      await tester.pumpAndSettle();

      await _selectMember(tester, 'alice', 'Alice Adams');
      expect(find.text('Alice Adams'), findsNWidgets(2)); // directory row + chip

      // Re-search (different query text so the listener re-fires, but still
      // a substring of "Alice Adams" so the client-side filter matches) for
      // the same person surfaced under a different wrapper id -- simulating
      // the same user appearing through another endpoint/listing. Tapping
      // her row here is recognized as toggling the SAME already-selected
      // entry off (deselect), not adding a second, differently-keyed one --
      // proving the two listings resolved to one canonical identity. Before
      // the fix, this tap would have added a distinct second chip instead.
      await _selectMember(tester, 'adams', 'Alice Adams');
      expect(find.text('Alice Adams'), findsOneWidget); // chip gone, row remains

      // Re-select via the same (now deselected) row to restore one
      // participant, then submit.
      await tester.tap(find.text('Alice Adams').first);
      await tester.pumpAndSettle();
      expect(find.text('Alice Adams'), findsNWidgets(2));

      await tester.tap(find.text('Start conversation'));
      await tester.pumpAndSettle();

      expect(posts, hasLength(1));
      // Exactly one canonical participant id -- not two -- and it's the
      // real userId, not either listing's own wrapper id.
      expect(posts.single['participantIds'], ['user-alice']);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets('direct conversation submits PRIVATE payload', (tester) async {
    _useLargeSurface(tester);
    final posts = <Map<String, dynamic>>[];
    final dio = _conversationDio(posts: posts);
    await tester.pumpWidget(_wrap(dio));
    await tester.pumpAndSettle();

    await _selectMember(tester, 'alice', 'Alice Adams');
    await tester.tap(find.text('Start conversation'));
    await tester.pumpAndSettle();

    expect(posts, hasLength(1));
    expect(posts.single, {
      'type': 'PRIVATE',
      'visibility': 'PRIVATE',
      'participantIds': ['user-alice'],
      'title': 'Alice Adams',
    });

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  for (final mode in const ['CIRCLE', 'WORKROOM', 'SALON']) {
    testWidgets('shared space submits $mode payload', (tester) async {
      _useLargeSurface(tester);
      final posts = <Map<String, dynamic>>[];
      final dio = _conversationDio(posts: posts);
      await tester.pumpWidget(_wrap(dio));
      await tester.pumpAndSettle();

      await _selectMember(tester, 'alice', 'Alice Adams');
      await _selectMember(tester, 'bob', 'Bob Brown');
      await tester.enterText(find.byType(TextField).at(1), '$mode planning');
      await tester.pumpAndSettle();

      if (mode != 'CIRCLE') {
        await tester.tap(find.text(_labelForMode(mode)));
        await tester.pumpAndSettle();
      }

      await tester.tap(find.text('Create space'));
      await tester.pumpAndSettle();

      expect(posts, hasLength(1));
      expect(posts.single, {
        'type': mode,
        'visibility': 'PRIVATE',
        'participantIds': ['user-alice', 'user-bob'],
        'title': '$mode planning',
      });

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }
}

void _useLargeSurface(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1200, 1400);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Widget _wrap(Dio dio) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) =>
            const Material(child: NewConversationScreen()),
      ),
      GoRoute(
        path: '/me/correspondence',
        builder: (context, state) => const SizedBox.shrink(),
      ),
      GoRoute(
        path: '/me/correspondence/:spaceId',
        builder: (context, state) => const SizedBox.shrink(),
      ),
      GoRoute(
        path: '/me/correspondence/:spaceId/thread/:threadId',
        builder: (context, state) => const SizedBox.shrink(),
      ),
    ],
  );

  return ProviderScope(
    overrides: [dioProvider.overrideWithValue(dio)],
    child: MaterialApp.router(routerConfig: router),
  );
}

Dio _conversationDio({List<Map<String, dynamic>>? posts}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final path = options.path;
        if (options.method == 'GET' && path == '/users/me') {
          return handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'data': {'id': 'user-me', 'handle': 'me'},
              },
            ),
          );
        }

        if (options.method == 'GET' &&
            (path == '/users/me/followers' || path == '/users/me/following')) {
          return handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {'data': <Map<String, dynamic>>[]},
            ),
          );
        }

        if (options.method == 'GET' && path == '/search') {
          final query = (options.queryParameters['q'] ?? '').toString();
          return handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'data': {
                  'users': [_memberForQuery(query)],
                },
              },
            ),
          );
        }

        if (options.method == 'POST' && path == '/spaces') {
          posts?.add(Map<String, dynamic>.from(options.data as Map));
          return handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'data': {'id': 'space-1', 'threadId': 'thread-1'},
              },
            ),
          );
        }

        return handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.badResponse,
            response: Response(
              requestOptions: options,
              statusCode: 404,
              data: 'Unhandled ${options.method} $path',
            ),
          ),
        );
      },
    ),
  );
  return dio;
}

/// Same shape as [_conversationDio], but `/search` returns Alice under a
/// distinct wrapper `id` per query string while keeping the same canonical
/// `userId` -- reproducing "the same person surfaced via two listings with
/// different row ids" without needing two different real endpoints.
Dio _conversationDioWithDivergentWrapperIds({
  List<Map<String, dynamic>>? posts,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final path = options.path;
        if (options.method == 'GET' && path == '/users/me') {
          return handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'data': {'id': 'user-me', 'handle': 'me'},
              },
            ),
          );
        }

        if (options.method == 'GET' &&
            (path == '/users/me/followers' || path == '/users/me/following')) {
          return handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {'data': <Map<String, dynamic>>[]},
            ),
          );
        }

        if (options.method == 'GET' && path == '/search') {
          final query = (options.queryParameters['q'] ?? '').toString();
          return handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'data': {
                  'users': [
                    {
                      // Distinct row/relationship id per listing, same
                      // canonical user underneath.
                      'id': 'wrapper-$query',
                      'userId': 'user-alice',
                      'displayName': 'Alice Adams',
                    },
                  ],
                },
              },
            ),
          );
        }

        if (options.method == 'POST' && path == '/spaces') {
          posts?.add(Map<String, dynamic>.from(options.data as Map));
          return handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'data': {'id': 'space-1', 'threadId': 'thread-1'},
              },
            ),
          );
        }

        return handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.badResponse,
            response: Response(
              requestOptions: options,
              statusCode: 404,
              data: 'Unhandled ${options.method} $path',
            ),
          ),
        );
      },
    ),
  );
  return dio;
}

Map<String, dynamic> _memberForQuery(String query) {
  final normalized = query.toLowerCase();
  if (normalized.contains('bob')) {
    return {'id': 'user-bob', 'userId': 'user-bob', 'displayName': 'Bob Brown'};
  }

  return {
    'id': 'user-alice',
    'userId': 'user-alice',
    'displayName': 'Alice Adams',
  };
}

Future<void> _selectMember(
  WidgetTester tester,
  String query,
  String displayName,
) async {
  await tester.enterText(find.byType(TextField).first, query);
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pumpAndSettle();
  await tester.tap(find.text(displayName).first);
  await tester.pumpAndSettle();
}

String _labelForMode(String mode) {
  switch (mode) {
    case 'WORKROOM':
      return 'Workroom';
    case 'SALON':
      return 'Salon';
    default:
      return 'Circle';
  }
}
