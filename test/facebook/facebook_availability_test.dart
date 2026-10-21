// Facebook Page and Instagram before Meta completes its review of Aura
// (2026-10-21). Facebook refuses Page access to everyone without a role on
// Aura's Meta app, so the server says who may connect. A member it is not
// open to sees why, with no Connect; the composer and the announcement editor
// do not offer either place. An older server does not say: behave as before.
import 'package:aura/core/institutions/institution_access_provider.dart';
import 'package:aura/core/net/dio_provider.dart';
import 'package:aura/features/announcements/presentation/announcement_distribution.dart';
import 'package:aura/features/me/presentation/widgets/facebook_page_connection.dart';
import 'package:aura/features/posts/presentation/compose_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _reason = 'Sharing to a Facebook Page opens once Meta completes its review of Aura.';

Map<String, dynamic>? _account(String mode) => switch (mode) {
      'closed' => {
          'ok': true,
          'available': false,
          'unavailableReason': _reason,
          'connected': false,
          'needsPage': false,
          'page': null,
          'instagram': null,
        },
      'legacy' => {
          'ok': true,
          'connected': false,
          'needsPage': false,
          'page': null,
          'instagram': null,
        },
      _ => null,
    };

Dio _dio(String mode) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final path = options.uri.path;
        final method = options.method;
        Response<dynamic> ok(dynamic data) =>
            Response(requestOptions: options, statusCode: 200, data: data);
        if (method == 'GET' && path == '/integrations/facebook/account') {
          return handler.resolve(ok(_account(mode)));
        }
        if (method == 'GET' && path == '/posts/held/latest') {
          return handler.resolve(ok({
            'id': 'draft-1',
            'text': 'The bus route to the district hospital was cut last month.',
            'visibility': 'PUBLIC',
            'primaryTopic': 'COMMUNITY',
            'intent': 'ASK',
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

Future<void> _openComposer(WidgetTester tester, String mode) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1200, 4000);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dioProvider.overrideWithValue(_dio(mode)),
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
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('the Facebook Page row on Connected accounts', () {
    Future<void> pumpRow(WidgetTester tester, String mode) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [dioProvider.overrideWithValue(_dio(mode))],
          child: const MaterialApp(home: Scaffold(body: FacebookPageConnection())),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Facebook Page'));
      await tester.pumpAndSettle();
    }

    testWidgets('not yet open: says why, and offers no Connect', (tester) async {
      await pumpRow(tester, 'closed');
      expect(find.text(_reason), findsOneWidget);
      expect(find.text('Connect'), findsNothing);
    });

    testWidgets('an older server that does not say: Connect, as before', (tester) async {
      await pumpRow(tester, 'legacy');
      expect(find.text('Not connected'), findsOneWidget);
      expect(find.text('Connect'), findsOneWidget);
    });
  });

  group('the composer', () {
    testWidgets('not yet open: neither Facebook Page nor Instagram is offered', (tester) async {
      await _openComposer(tester, 'closed');
      expect(find.text('Publish elsewhere'), findsOneWidget);
      expect(find.text('Facebook Page'), findsNothing);
      expect(find.text('Instagram'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('an older server that does not say: both offered, as before', (tester) async {
      await _openComposer(tester, 'legacy');
      expect(find.text('Facebook Page'), findsOneWidget);
      expect(find.text('Instagram'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });

  testWidgets('the announcement editor draws neither row when not open', (tester) async {
    Widget host({required bool offered}) => MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AnnouncementDistribution(
                linkedinConnected: false,
                tiktokConnected: false,
                tiktokEnabled: false,
                initialAura: true,
                initialLinkedin: false,
                initialTiktok: false,
                metaOffered: offered,
                onChanged: ({
                  required bool aura,
                  required bool linkedin,
                  required bool tiktok,
                  required bool facebook,
                  required bool instagram,
                }) {},
              ),
            ),
          ),
        );
    await tester.pumpWidget(host(offered: false));
    expect(find.text('Facebook Page'), findsNothing);
    expect(find.text('Instagram'), findsNothing);
    expect(find.text('LinkedIn'), findsOneWidget);

    await tester.pumpWidget(host(offered: true));
    expect(find.text('Facebook Page'), findsOneWidget);
    expect(find.text('Instagram'), findsOneWidget);
  });
}
