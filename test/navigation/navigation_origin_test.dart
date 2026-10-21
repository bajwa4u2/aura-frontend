import 'package:aura/app/shell/member_shell.dart';
import 'package:aura/core/navigation/navigation_authority.dart';
import 'package:aura/core/navigation/navigation_origin.dart';
import 'package:aura/core/net/dio_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// THE ORIGIN TAB (founder decision 2026-10-21): a detail page keeps the tab
/// it was opened from highlighted; with no origin, the content's own home.
void main() {
  setUp(NavigationOrigin.reset);

  group('origin resolution', () {
    test('a primary route highlights itself and becomes the origin', () {
      expect(NavigationOrigin.selectedFor('/messages'),
          PrimaryDestination.messages);
      expect(NavigationOrigin.last, PrimaryDestination.messages);
    });

    test('a detail route highlights where it was opened from', () {
      NavigationOrigin.selectedFor('/discover');
      expect(NavigationOrigin.selectedFor('/posts/p1'),
          PrimaryDestination.discover);
      expect(NavigationOrigin.selectedFor('/u/amina'),
          PrimaryDestination.discover);
      NavigationOrigin.selectedFor('/messages');
      expect(NavigationOrigin.selectedFor('/posts/p1'),
          PrimaryDestination.messages);
      expect(NavigationOrigin.selectedFor('/me/edit'),
          PrimaryDestination.messages);
      expect(NavigationOrigin.selectedFor('/meetings/m1'),
          PrimaryDestination.messages);
    });

    test('Create is an action, never an origin', () {
      NavigationOrigin.selectedFor('/home');
      expect(NavigationOrigin.selectedFor('/compose'),
          PrimaryDestination.create);
      // What Create made is shown where it belongs, not under Create.
      expect(NavigationOrigin.selectedFor('/posts/p1'),
          PrimaryDestination.home);
    });

    test('with no origin, the content decides (cold start, shared link)', () {
      final cases = <String, PrimaryDestination?>{
        '/posts/p1': PrimaryDestination.home,
        '/p/abc': PrimaryDestination.home,
        '/announcements/a1': PrimaryDestination.home,
        '/articles/my-article': PrimaryDestination.home,
        '/thread/t1': PrimaryDestination.home,
        '/direct/d1': PrimaryDestination.messages,
        '/messages/c/c1': PrimaryDestination.messages,
        '/u/amina': PrimaryDestination.discover,
        '/author/amina': PrimaryDestination.discover,
        '/institutions/acme': PrimaryDestination.discover,
        '/spaces/town-hall': PrimaryDestination.discover,
        // Personal depth and meetings belong to no primary.
        '/me': null,
        '/security': null,
        '/meetings/m1': null,
      };
      cases.forEach((path, expected) {
        NavigationOrigin.reset();
        expect(NavigationOrigin.selectedFor(path), expected, reason: path);
      });
    });
  });

  group('member shell', () {
    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues(const {});
    });

    Dio offline() {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test/v1'));
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (o, h) => h.reject(
          DioException(requestOptions: o, type: DioExceptionType.connectionError),
        ),
      ));
      return dio;
    }

    Widget page(String name) => ListView(
          key: ValueKey('page-$name'),
          children: [
            for (var i = 0; i < 80; i++)
              SizedBox(height: 60, child: Text('$name row $i')),
          ],
        );

    Future<GoRouter> pumpShell(WidgetTester tester, Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final router = GoRouter(
        initialLocation: '/discover',
        routes: [
          ShellRoute(
            builder: (_, __, child) => MemberShell(child: child),
            routes: [
              for (final p in ['/home', '/messages', '/discover', '/create'])
                GoRoute(path: p, builder: (_, __) => page(p)),
              GoRoute(path: '/posts/:id', builder: (_, __) => page('post')),
            ],
          ),
        ],
      );
      await tester.pumpWidget(ProviderScope(
        overrides: [dioProvider.overrideWithValue(offline())],
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pump(const Duration(milliseconds: 200));
      return router;
    }

    // A selected tab draws its filled icon (rail and bottom bar alike).
    const filled = {
      'Home': Icons.home_rounded,
      'Messages': Icons.mail_rounded,
      'Discover': Icons.explore_rounded,
    };
    bool isSelected(WidgetTester tester, String label) =>
        find.byIcon(filled[label]!).evaluate().isNotEmpty;

    for (final entry in {
      'phone (bottom navigation)': const Size(390, 844),
      'desktop (rail)': const Size(1400, 900),
    }.entries) {
      testWidgets('${entry.key}: a detail page keeps its origin highlighted',
          (tester) async {
        final router = await pumpShell(tester, entry.value);
        expect(isSelected(tester, 'Discover'), isTrue);

        router.go('/posts/p1');
        await tester.pump(const Duration(milliseconds: 200));
        expect(isSelected(tester, 'Discover'), isTrue);
        expect(isSelected(tester, 'Home'), isFalse);

        // Tapping the highlighted tab returns to that tab's root.
        await tester.tap(find.text('Discover').first);
        await tester.pump(const Duration(milliseconds: 200));
        expect(router.routerDelegate.currentConfiguration.uri.path, '/discover');
      });
    }

    testWidgets('re-selecting the current tab scrolls its page to the top',
        (tester) async {
      await pumpShell(tester, const Size(390, 844));
      final list = find.byKey(const ValueKey('page-/discover'));
      await tester.drag(list, const Offset(0, -1500));
      await tester.pump();
      final scrollable = tester.state<ScrollableState>(
        find.descendant(of: list, matching: find.byType(Scrollable)).first,
      );
      expect(scrollable.position.pixels, greaterThan(0));

      await tester.tap(find.text('Discover').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(scrollable.position.pixels, 0);
    });
  });
}
