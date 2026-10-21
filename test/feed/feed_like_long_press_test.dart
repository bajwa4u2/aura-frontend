import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:aura/core/auth/session_providers.dart';
import 'package:aura/core/institutions/institution_access_provider.dart';
import 'package:aura/features/feed/presentation/feed_interaction_bar.dart';
import 'package:aura/features/posts/data/reactions_repository.dart';

/// Holding Like on a feed card used to like the post (S24+, 21 Oct 2026): with
/// no long-press handler, a held finger counted as a tap. Now a hold shows what
/// the button does and does nothing else. A signed-out tap goes to sign-in,
/// which is how these tests see whether the button acted.
void main() {
  Future<List<String>> pump(WidgetTester tester) async {
    final visited = <String>[];
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(
            body: Center(
              child: FeedInteractionBar(target: PostReactionTarget('p1')),
            ),
          ),
        ),
        GoRoute(
          path: '/login',
          builder: (_, state) {
            visited.add(state.uri.path);
            return const Text('sign in');
          },
        ),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        isAuthedProvider.overrideWithValue(false),
        institutionIdentityProvider.overrideWithValue(null),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
    return visited;
  }

  testWidgets('holding Like does not act, on every platform', (tester) async {
    final visited = await pump(tester);

    await tester.longPress(find.text('Like'));
    await tester.pumpAndSettle();
    expect(visited, isEmpty);
  }, variant: TargetPlatformVariant.all());

  testWidgets('a tap on Like still acts', (tester) async {
    final visited = await pump(tester);
    await tester.tap(find.text('Like'));
    await tester.pumpAndSettle();
    expect(visited, ['/login']);
  });

  testWidgets('the hold says what the button does', (tester) async {
    await pump(tester);
    expect(find.byTooltip('Like this post'), findsOneWidget);
  });
}
