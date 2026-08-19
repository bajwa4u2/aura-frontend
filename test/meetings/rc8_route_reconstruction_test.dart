// RC8 — the routes themselves, driven through the REAL router.
//
// These assert the two behaviours that were actually broken: a booking URL
// opened cold must reach the right booking (not a page for nobody), and a
// reschedule link from an email must reach the reschedule flow (not a cancel
// screen with an empty token).
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:aura/core/net/dio_provider.dart';
import 'package:aura/features/meetings/presentation/booking_confirm_screen.dart';
import 'package:aura/features/meetings/presentation/booking_cancel_screen.dart';
import 'package:aura/features/meetings/presentation/booking_reschedule_screen.dart';
import 'package:aura/features/meetings/presentation/booking_route_entry.dart';
import 'package:aura/features/meetings/presentation/slot_picker_screen.dart';

Map<String, dynamic> _profile(String slug) => {
      'id': 'prof-1',
      'name': 'Founder',
      'slug': slug,
      'meetingTitle': 'Founder conversation',
      'durationOptions': [30, 60],
      'defaultDuration': 30,
      'bufferBefore': 0,
      'bufferAfter': 0,
      'minimumNotice': 60,
      'maximumAdvance': 43200,
      'timezone': 'UTC',
      'isActive': true,
      'windows': <dynamic>[],
      'overrides': <dynamic>[],
    };

Dio _bookingDio({
  List<String>? calls,
  bool bookingFound = true,
  bool reschedulable = true,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      calls?.add('${options.method} ${options.path}');
      Response<dynamic> ok(dynamic data) =>
          Response(requestOptions: options, statusCode: 200, data: {'data': data});

      if (options.path.startsWith('/book/reschedule/')) {
        if (!bookingFound) {
          return handler.reject(DioException(
            requestOptions: options,
            response: Response(requestOptions: options, statusCode: 404),
            type: DioExceptionType.badResponse,
          ));
        }
        return handler.resolve(ok({
          'status': reschedulable ? 'CONFIRMED' : 'CANCELLED',
          'scheduledAt': '2026-09-01T10:00:00.000Z',
          'durationMinutes': 30,
          'timezone': 'UTC',
          'meetingTitle': 'Founder conversation',
          'profileSlug': 'founder',
          'institutionSlug': null,
          'reschedulable': reschedulable,
        }));
      }
      if (options.path.startsWith('/book/')) {
        return handler.resolve(ok(_profile(options.path.split('/').last)));
      }
      return handler.resolve(ok(<String, dynamic>{}));
    },
  ));
  return dio;
}

Widget _app(Dio dio, String location) => ProviderScope(
      overrides: [dioProvider.overrideWithValue(dio)],
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: location,
          routes: [
            GoRoute(
              path: '/meet/:slug/book',
              // The real app routes every screen inside a shell that
              // provides Material; the harness reproduces that ancestor
              // rather than changing a screen to suit a test.
              builder: (context, state) => Scaffold(
                body: BookingRouteEntry(
                  slug: state.pathParameters['slug'] ?? '',
                  slot: slotFromQuery(state.uri.queryParameters),
                  durationMinutes:
                      int.tryParse(state.uri.queryParameters['duration'] ?? ''),
                ),
              ),
            ),
            GoRoute(
              path: '/meet/reschedule/:token',
              builder: (context, state) => Scaffold(
                body: RescheduleRouteEntry(
                  token: state.pathParameters['token'] ?? '',
                ),
              ),
            ),
          ],
        ),
      ),
    );

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

void main() {
  testWidgets('a booking URL opened cold reaches the RIGHT booking',
      (tester) async {
    final calls = <String>[];
    await tester.pumpWidget(_app(
      _bookingDio(calls: calls),
      '/meet/founder/book?start=2026-09-01T10%3A00%3A00.000Z&duration=30',
    ));
    await _settle(tester);

    expect(calls, contains('GET /book/founder'),
        reason: 'The slug in the path is who the booking is with.');
    expect(find.byType(BookingConfirmScreen), findsOneWidget);
  });

  testWidgets('a booking URL with no slot offers the picker, not nothing',
      (tester) async {
    await tester.pumpWidget(_app(_bookingDio(), '/meet/founder/book'));
    await _settle(tester);

    // Before: PublicBookingScreen(slug: '') — a booking page for nobody.
    expect(find.byType(SlotPickerScreen), findsOneWidget);
  });

  testWidgets('a reschedule link from an email reaches the reschedule flow',
      (tester) async {
    final calls = <String>[];
    await tester.pumpWidget(
        _app(_bookingDio(calls: calls), '/meet/reschedule/tok-123'));
    await _settle(tester);

    expect(calls, contains('GET /book/reschedule/tok-123'));
    expect(find.byType(BookingRescheduleScreen), findsOneWidget);
    expect(find.byType(BookingCancelScreen), findsNothing,
        reason: 'It used to land on CANCEL with the token thrown away.');
  });

  testWidgets('a cancelled booking is told plainly, not offered a reschedule',
      (tester) async {
    // Authority stays with the booking, not with the link that carried it.
    await tester.pumpWidget(
        _app(_bookingDio(reschedulable: false), '/meet/reschedule/tok-123'));
    await _settle(tester);

    expect(find.byType(BookingRescheduleScreen), findsNothing);
    expect(find.textContaining('no longer be rescheduled'), findsOneWidget);
  });

  testWidgets('an unknown token is honest, and reveals nothing', (tester) async {
    await tester.pumpWidget(
        _app(_bookingDio(bookingFound: false), '/meet/reschedule/nope'));
    await _settle(tester);

    expect(find.byType(BookingRescheduleScreen), findsNothing);
    expect(find.textContaining('could not be found'), findsOneWidget);
  });

  testWidgets('an empty token asks for the email link again', (tester) async {
    await tester.pumpWidget(_app(_bookingDio(), '/meet/reschedule/ '));
    await _settle(tester);

    expect(find.textContaining('incomplete'), findsOneWidget);
  });
}
