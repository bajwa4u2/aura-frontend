import 'package:aura/core/net/dio_provider.dart';
import 'package:aura/features/auth/presentation/restore_account_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// RESTORE A DELETED ACCOUNT (founder decision 2026-10-21).
///
/// Email → code → "Your account is back". The screen never says whether an
/// email has a deleted account: it repeats the server's single answer.
void main() {
  const startAnswer =
      'If a deleted account with this email can still be restored, we have sent a code to it. The code expires in 15 minutes.';

  Dio fakeDio({
    required List<RequestOptions> calls,
    int completeStatus = 200,
    String? completeMessage,
  }) {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          calls.add(options);
          if (options.path == '/auth/account-restore/start') {
            return handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: {'ok': true, 'message': startAnswer},
            ));
          }
          if (options.path == '/auth/account-restore/complete') {
            if (completeStatus == 200) {
              return handler.resolve(Response(
                requestOptions: options,
                statusCode: 200,
                data: {'ok': true, 'message': 'Your account is back. Sign in to continue.'},
              ));
            }
            return handler.reject(DioException(
              requestOptions: options,
              response: Response(
                requestOptions: options,
                statusCode: completeStatus,
                data: {
                  'ok': false,
                  'error': {'message': completeMessage ?? 'Refused.'},
                },
              ),
            ));
          }
          return handler.resolve(Response(requestOptions: options, statusCode: 404));
        },
      ),
    );
    return dio;
  }

  Future<void> pump(WidgetTester tester, Dio dio, {Size size = const Size(390, 844)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/restore-account',
      routes: [
        GoRoute(
          path: '/restore-account',
          // The app's shell supplies the Scaffold AuraScaffold paints into.
          builder: (_, __) => const Scaffold(
            body: RestoreAccountScreen(email: 'person@example.com'),
          ),
        ),
        GoRoute(path: '/login', builder: (_, __) => const Text('SIGN IN SCREEN')),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [dioProvider.overrideWithValue(dio)],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('email, then code, then the account is back', (tester) async {
    final calls = <RequestOptions>[];
    await pump(tester, fakeDio(calls: calls));

    expect(find.text('Restore a deleted account'), findsOneWidget);
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();

    expect(calls.single.data, {'email': 'person@example.com'});
    expect(find.text(startAnswer), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Code from the email'), '123456');
    await tester.tap(find.text('Restore account'));
    await tester.pumpAndSettle();

    expect(calls.last.path, '/auth/account-restore/complete');
    expect(calls.last.data, {'email': 'person@example.com', 'code': '123456'});
    expect(find.text('Your account is back'), findsOneWidget);
    expect(find.textContaining('needs connecting again'), findsOneWidget);

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('SIGN IN SCREEN'), findsOneWidget);
  });

  testWidgets('a refused code shows the server sentence and keeps the form', (tester) async {
    final calls = <RequestOptions>[];
    await pump(
      tester,
      fakeDio(
        calls: calls,
        completeStatus: 400,
        completeMessage: 'That code is not right, or it has expired. Ask for a new code and try again.',
      ),
    );
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Code from the email'), '654321');
    await tester.tap(find.text('Restore account'));
    await tester.pumpAndSettle();

    expect(find.textContaining('That code is not right'), findsOneWidget);
    expect(find.text('Restore account'), findsOneWidget);
    expect(find.text('Send a new code'), findsOneWidget);
  });

  testWidgets('says plainly when the email now belongs to another account', (tester) async {
    final calls = <RequestOptions>[];
    await pump(
      tester,
      fakeDio(
        calls: calls,
        completeStatus: 409,
        completeMessage: 'This email now belongs to another Aura account, so the deleted account cannot be restored with it. Sign in to that account instead.',
      ),
    );
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Code from the email'), '111222');
    await tester.tap(find.text('Restore account'));
    await tester.pumpAndSettle();

    expect(find.textContaining('now belongs to another Aura account'), findsOneWidget);
  });

  testWidgets('asks for six digits before calling the server', (tester) async {
    final calls = <RequestOptions>[];
    await pump(tester, fakeDio(calls: calls));
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Code from the email'), '12');
    await tester.tap(find.text('Restore account'));
    await tester.pumpAndSettle();

    expect(find.text('Enter the 6-digit code from the email.'), findsOneWidget);
    expect(calls.where((c) => c.path.endsWith('/complete')), isEmpty);
  });

  testWidgets('fits a small phone and a wide window without overflow', (tester) async {
    // 360 is the narrowest common phone. The test font draws every glyph a full
    // em wide, so it is stricter than any real font at the same width.
    for (final size in const [Size(360, 640), Size(1440, 900)]) {
      final calls = <RequestOptions>[];
      await pump(tester, fakeDio(calls: calls), size: size);
      await tester.tap(find.text('Send code'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
