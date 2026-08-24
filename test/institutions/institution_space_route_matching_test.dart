import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// WHICH ROUTE ANSWERS `/institution/:addr/spaces/:space`?
///
/// Measured in production on 2026-08-24: on a direct load of the Space detail
/// address, `InstitutionRouteScope.build` ran — but the Space detail route's
/// own builder never did. Both cannot be true of the same route, so something
/// other than the detail route was answering the address.
///
/// This asks go_router the question directly, with the same two sibling paths
/// the app registers, so the answer is about ROUTE MATCHING and nothing else.
void main() {
  testWidgets('a sibling list route must not answer the detail address',
      (tester) async {
    final answered = <String>[];

    final router = GoRouter(
      initialLocation: '/institution/aura-platform-llc/spaces/my-space',
      routes: [
        GoRoute(
          path: '/institution/:institutionId/spaces',
          builder: (_, __) {
            answered.add('list');
            return const Text('list');
          },
        ),
        GoRoute(
          path: '/institution/:institutionId/spaces/:spaceAddress',
          builder: (_, state) {
            answered.add('detail:${state.pathParameters['spaceAddress']}');
            return const Text('detail');
          },
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(answered, ['detail:my-space'],
        reason: 'the three-segment address belongs to the detail route');
    expect(find.text('detail'), findsOneWidget);
  });

  testWidgets('the list address still reaches the list route', (tester) async {
    final answered = <String>[];
    final router = GoRouter(
      initialLocation: '/institution/aura-platform-llc/spaces',
      routes: [
        GoRoute(
          path: '/institution/:institutionId/spaces',
          builder: (_, __) {
            answered.add('list');
            return const Text('list');
          },
        ),
        GoRoute(
          path: '/institution/:institutionId/spaces/:spaceAddress',
          builder: (_, __) {
            answered.add('detail');
            return const Text('detail');
          },
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(answered, ['list']);
  });
}
