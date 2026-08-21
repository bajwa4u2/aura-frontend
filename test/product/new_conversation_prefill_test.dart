// `/messages/new` PREFILL.
//
// A profile's "Invite to space" pushes `/messages/new` carrying that person's
// `handle`, `name` and `userId`. The route built `const NewConversationPicker()`
// and discarded all three, so the picker opened on an empty search box and the
// person had to search for whoever they had just been reading about.
//
// The prefill is a SEARCH prefill, not an auto-open. This screen's canon is
// "choose a person → the conversation opens", and choosing is exactly the step
// an auto-open would skip.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/net/dio_provider.dart';
import 'package:aura/features/conversation/presentation/new_conversation_picker.dart';

void main() {
  testWidgets('a prefilled handle searches immediately and finds the person',
      (tester) async {
    final queries = <String>[];
    await tester.pumpWidget(_wrap(_dio(queries), initialQuery: 'amina'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'amina'), findsOneWidget);
    expect(queries, contains('amina'),
        reason: 'the prefill must actually run the search, not just fill a box');
    expect(find.text('Amina Rahman'), findsOneWidget);
  });

  testWidgets('no prefill leaves the picker exactly as it was',
      (tester) async {
    final queries = <String>[];
    await tester.pumpWidget(_wrap(_dio(queries)));
    await tester.pumpAndSettle();

    expect(queries, isEmpty, reason: 'an empty picker must not search');
    expect(find.text('Amina Rahman'), findsNothing);
  });

  testWidgets('a blank prefill is treated as no prefill', (tester) async {
    // The route passes null rather than an empty string, but the widget must
    // not search on whitespace if one ever reaches it.
    final queries = <String>[];
    await tester.pumpWidget(_wrap(_dio(queries), initialQuery: '   '));
    await tester.pumpAndSettle();

    expect(queries, isEmpty);
  });
}

Widget _wrap(Dio dio, {String? initialQuery}) {
  return ProviderScope(
    overrides: [dioProvider.overrideWithValue(dio)],
    child: MaterialApp(
      home: Scaffold(body: NewConversationPicker(initialQuery: initialQuery)),
    ),
  );
}

Dio _dio(List<String> queries) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
  dio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
    if (o.path.startsWith('/search')) {
      final q = (o.queryParameters['q'] ?? '').toString();
      queries.add(q);
      return h.resolve(Response<dynamic>(
        requestOptions: o,
        statusCode: 200,
        data: {
          'ok': true,
          'users': [
            {
              'id': 'user-amina',
              'displayName': 'Amina Rahman',
              'handle': 'amina',
            }
          ],
        },
      ));
    }
    return h.resolve(Response<dynamic>(
      requestOptions: o,
      statusCode: 200,
      data: const {'ok': true},
    ));
  }));
  return dio;
}
