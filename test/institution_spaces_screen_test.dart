import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/institutions/institution_access_provider.dart';
import 'package:aura/core/net/dio_provider.dart';
import 'package:aura/features/institutions/presentation/institution_spaces_screen.dart';

/// Identity Foundation Phase 1 -- institution-space member selection.
///
/// Mirrors new_conversation_screen_test.dart's coverage for the
/// institution-space surface: search, stable selection across search
/// changes, duplicate prevention, self-exclusion, and submitted
/// participantIds matching what was visibly selected.
void main() {
  testWidgets(
    'institution-space creation: search, select multiple, self excluded, submits matching participantIds',
    (tester) async {
      _useLargeSurface(tester);
      final posts = <Map<String, dynamic>>[];
      final dio = _institutionDio(posts: posts);

      await tester.pumpWidget(_wrap(dio));
      await tester.pumpAndSettle();

      // Admin-only "New Space" trailing action opens the create form.
      await tester.tap(find.text('New Space'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'Engineering Circle');

      // The roster loads once; the current user ("Admin Person") must not
      // appear as a selectable candidate.
      expect(find.text('Admin Person'), findsNothing);
      expect(find.text('Alice Adams'), findsOneWidget);
      expect(find.text('Bob Brown'), findsOneWidget);

      await tester.tap(find.text('Alice Adams'));
      await tester.pumpAndSettle();
      // Selected chip + roster row both render "Alice Adams" now.
      expect(find.text('Alice Adams'), findsNWidgets(2));

      await tester.tap(find.text('Bob Brown'));
      await tester.pumpAndSettle();
      expect(find.text('Alice Adams'), findsNWidgets(2));
      expect(find.text('Bob Brown'), findsNWidgets(2));

      // Search the picker's own search field (second TextField: title,
      // description, then the picker's search box).
      final pickerSearch = find.byType(TextField).at(2);
      await tester.enterText(pickerSearch, 'alice');
      await tester.pumpAndSettle();
      // Bob's roster row is filtered out locally, but his selected chip
      // (rendered above the search box, not part of the filtered list)
      // must still be visible -- selection survives a search change here
      // exactly as it does in NewConversationScreen.
      expect(find.text('Bob Brown'), findsOneWidget); // chip only
      expect(find.text('Alice Adams'), findsNWidgets(2)); // chip + row

      await tester.enterText(pickerSearch, '');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create space'));
      await tester.pumpAndSettle();

      expect(posts, hasLength(1));
      expect(posts.single['title'], 'Engineering Circle');
      final submittedIds = List<String>.from(posts.single['participantIds'] as List);
      expect(submittedIds.toSet(), {'user-alice', 'user-bob'});
      expect(submittedIds.length, 2); // no duplicates

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets('re-selecting the same roster member does not duplicate the submitted id', (
    tester,
  ) async {
    _useLargeSurface(tester);
    final posts = <Map<String, dynamic>>[];
    final dio = _institutionDio(posts: posts);

    await tester.pumpWidget(_wrap(dio));
    await tester.pumpAndSettle();

    await tester.tap(find.text('New Space'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Circle');

    // Select then deselect then reselect Alice -- must never produce two
    // distinct selection entries for the same canonical userId. The
    // roster row (not the selected chip) is what's tappable to toggle;
    // it renders after the chip in the widget tree, so `.last` targets it.
    await tester.tap(find.text('Alice Adams'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alice Adams').last);
    await tester.pumpAndSettle();
    expect(find.text('Alice Adams'), findsOneWidget); // deselected: row only
    await tester.tap(find.text('Alice Adams'));
    await tester.pumpAndSettle();
    expect(find.text('Alice Adams'), findsNWidgets(2)); // reselected: row + chip

    await tester.tap(find.text('Create space'));
    await tester.pumpAndSettle();

    expect(posts, hasLength(1));
    expect(posts.single['participantIds'], ['user-alice']);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
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
  return ProviderScope(
    overrides: [
      dioProvider.overrideWithValue(dio),
      institutionIdentityProvider.overrideWithValue(
        const InstitutionIdentity(
          id: 'inst-1',
          name: 'Test Institution',
          slug: 'test-institution',
          isAuthorizedSpeaker: true,
          capabilities: {},
          role: 'OWNER',
        ),
      ),
    ],
    child: const MaterialApp(
      home: Material(child: InstitutionSpacesScreen(institutionId: 'inst-1')),
    ),
  );
}

Dio _institutionDio({List<Map<String, dynamic>>? posts}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final path = options.path;

        if (options.method == 'GET' && path == '/institutions/inst-1/spaces') {
          return handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {'ok': true, 'spaces': <Map<String, dynamic>>[]},
            ),
          );
        }

        if (options.method == 'GET' && path == '/users/me') {
          return handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'id': 'user-admin',
                'handle': 'admin',
                'displayName': 'Admin Person',
              },
            ),
          );
        }

        if (options.method == 'GET' && path == '/institutions/inst-1/members') {
          return handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'ok': true,
                'members': [
                  {
                    'id': 'membership-admin',
                    'userId': 'user-admin',
                    'role': 'OWNER',
                    'user': {
                      'id': 'user-admin',
                      'displayName': 'Admin Person',
                      'handle': 'admin',
                    },
                  },
                  {
                    'id': 'membership-alice',
                    'userId': 'user-alice',
                    'role': 'MEMBER',
                    'user': {
                      'id': 'user-alice',
                      'displayName': 'Alice Adams',
                      'handle': 'alice',
                    },
                  },
                  {
                    'id': 'membership-bob',
                    'userId': 'user-bob',
                    'role': 'MEMBER',
                    'user': {
                      'id': 'user-bob',
                      'displayName': 'Bob Brown',
                      'handle': 'bob',
                    },
                  },
                ],
              },
            ),
          );
        }

        if (options.method == 'POST' && path == '/institutions/inst-1/spaces') {
          posts?.add(Map<String, dynamic>.from(options.data as Map));
          return handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'ok': true,
                'space': {
                  'id': 'space-1',
                  'title': options.data['title'],
                  'type': 'CIRCLE',
                  'visibility': options.data['visibility'] ?? 'INVITE_ONLY',
                  'memberCount': 1 + ((options.data['participantIds'] as List?)?.length ?? 0),
                  'threadCount': 1,
                },
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
