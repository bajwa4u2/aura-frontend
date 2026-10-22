import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:aura/core/product/product_language.dart';
import 'package:aura/features/meetings/application/meetings_provider.dart';
import 'package:aura/features/meetings/presentation/pre_join_screen.dart';

/// "Meeting not found" only when the meeting is not found (founder-approved
/// correction, 22 Oct 2026). Offline or a server failure says it could not
/// reach Aura and offers to try again, instead of blaming the meeting code.
void main() {
  Future<void> pump(WidgetTester tester, Object error) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/meetings/join/abc-defg-hij',
      routes: [
        GoRoute(
          path: '/meetings/join/:code',
          builder: (_, s) =>
              PreJoinScreen(meetingCode: s.pathParameters['code']!),
        ),
        GoRoute(path: '/meetings/join', builder: (_, __) => const SizedBox()),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          meetingEntryResolutionProvider.overrideWith((ref, key) async {
            throw error;
          }),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  DioException withStatus(int code) {
    final req = RequestOptions(path: '/meetings/resolve');
    return DioException(
      requestOptions: req,
      type: DioExceptionType.badResponse,
      response: Response(requestOptions: req, statusCode: code),
    );
  }

  testWidgets('a 404 says the meeting was not found', (tester) async {
    await pump(tester, withStatus(404));
    expect(find.text('Meeting not found'), findsOneWidget);
    expect(find.text('Enter a meeting code'), findsOneWidget);
    expect(find.text("Couldn't reach Aura"), findsNothing);
  });

  testWidgets('no connection says Aura could not be reached, with Try again',
      (tester) async {
    await pump(
      tester,
      DioException(
        requestOptions: RequestOptions(path: '/meetings/resolve'),
        type: DioExceptionType.connectionError,
      ),
    );
    expect(find.text("Couldn't reach Aura"), findsOneWidget);
    expect(find.text(ProductLabels.of(ProductAction.retry)), findsOneWidget);
    expect(find.text('Meeting not found'), findsNothing);
  });

  testWidgets('a server failure is not "not found" either', (tester) async {
    await pump(tester, withStatus(503));
    expect(find.text("Couldn't reach Aura"), findsOneWidget);
    expect(find.text('Meeting not found'), findsNothing);
  });
}
