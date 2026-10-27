import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:aura/features/public/data/public_spaces_registry.dart';
import 'package:aura/features/public/widgets/space_card.dart';

/// The member home's spaces: one row that drifts, and stops when a person is
/// near it (2026-10-26). Finders and scroll offsets, not pixels.
void main() {
  Future<void> pumpStrip(
    WidgetTester tester, {
    bool reduceMotion = false,
    Size size = const Size(1440, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const Scaffold(
          body: Padding(padding: EdgeInsets.all(24), child: PublicSpacesStrip()),
        ),
      ),
      GoRoute(path: '/spaces', builder: (_, __) => const Text('ALL SPACES')),
      GoRoute(path: '/spaces/:slug', builder: (_, s) => Text('SPACE ${s.pathParameters['slug']}')),
    ]);
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
          child: child!,
        ),
      ),
    ));
    await tester.pump();
  }

  double offset(WidgetTester tester) => tester
      .state<ScrollableState>(find.descendant(
        of: find.byKey(const ValueKey('spaces-row')),
        matching: find.byType(Scrollable),
      ))
      .position
      .pixels;

  Future<void> frames(WidgetTester tester, Duration total) async {
    for (var t = Duration.zero; t < total; t += const Duration(milliseconds: 50)) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('the spaces sit in ONE row', (tester) async {
    await pumpStrip(tester);
    final names = [
      for (final s in ProviderContainer().read(publicSpacesProvider)) s.name,
    ];
    final visible = names.where((n) => find.text(n).evaluate().isNotEmpty).toList();
    expect(visible.length, greaterThan(3));
    final rows = {
      for (final n in visible) tester.getTopLeft(find.text(n).first).dy,
    };
    expect(rows, hasLength(1));
    expect(find.text('See all spaces'), findsOneWidget);
  });

  testWidgets('it drifts on its own', (tester) async {
    await pumpStrip(tester);
    final start = offset(tester);
    await frames(tester, const Duration(seconds: 2));
    expect(offset(tester) - start, closeTo(48, 6)); // ~24 px a second
  });

  testWidgets('See all spaces opens the spaces page', (tester) async {
    await pumpStrip(tester);
    await tester.tap(find.text('See all spaces'));
    await tester.pumpAndSettle();
    expect(find.text('ALL SPACES'), findsOneWidget);
  });

  testWidgets('pause holds it still and offers chevrons; play resumes', (tester) async {
    await pumpStrip(tester);
    await tester.tap(find.byTooltip('Pause spaces'));
    await tester.pump();
    expect(find.byTooltip('Play spaces'), findsOneWidget);
    expect(find.byTooltip('Next spaces'), findsOneWidget);
    final held = offset(tester);
    await frames(tester, const Duration(seconds: 2));
    expect(offset(tester), held);

    await tester.tap(find.byTooltip('Next spaces'));
    await tester.pumpAndSettle();
    expect(offset(tester), greaterThan(held));

    await tester.tap(find.byTooltip('Play spaces'));
    await tester.pump();
    final resumed = offset(tester);
    await frames(tester, const Duration(seconds: 1));
    expect(offset(tester), greaterThan(resumed));
  });

  testWidgets('reduced motion: it never moves, chevrons page it', (tester) async {
    await pumpStrip(tester, reduceMotion: true);
    final start = offset(tester);
    await frames(tester, const Duration(seconds: 2));
    expect(offset(tester), start);
    expect(find.byTooltip('Pause spaces'), findsNothing);
    await tester.tap(find.byTooltip('Next spaces'));
    await tester.pump();
    expect(offset(tester), greaterThan(start));
  });

  testWidgets('a pointer over the row stops it; it resumes after leaving', (tester) async {
    await pumpStrip(tester);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.byKey(const ValueKey('spaces-row'))));
    await tester.pump();
    final held = offset(tester);
    await frames(tester, const Duration(seconds: 2));
    expect(offset(tester), held);

    await mouse.moveTo(const Offset(5, 880));
    await frames(tester, const Duration(seconds: 3));
    expect(offset(tester), held); // still within the 4 s grace
    await frames(tester, const Duration(seconds: 2));
    expect(offset(tester), greaterThan(held));
  });

  testWidgets('a space opens its page', (tester) async {
    await pumpStrip(tester);
    await tester.tap(find.text('Technology').first);
    await tester.pumpAndSettle();
    expect(find.text('SPACE technology'), findsOneWidget);
  });
}
