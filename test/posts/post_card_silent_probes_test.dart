import 'package:aura/core/errors/report_silently.dart';
import 'package:aura/core/net/dio_provider.dart';
import 'package:aura/features/feed/domain/post.dart';
import 'package:aura/features/posts/presentation/widgets/post_card.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// PostCard reads optional fields that not every post model carries. A
/// missing field is normal and stays silent; it must not flood the crash
/// reporter on every render (the empty catches it replaced hid everything).
void main() {
  testWidgets('a normal post renders without a single silent report',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final reports = <String>[];
    ReportSilentlySink.sink = (e, st, context) => reports.add(context);
    addTearDown(() => ReportSilentlySink.sink = (_, __, ___) {});

    final dio = Dio(BaseOptions(baseUrl: 'https://api.test/v1'));
    dio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
      h.resolve(Response(
          requestOptions: o, statusCode: 200, data: {'ok': true, 'data': {}}));
    }));

    final post = Post.fromJson({
      'id': 'p1',
      'text': 'Hello Aura',
      'createdAt': DateTime(2026, 10, 21).toIso8601String(),
      'author': {'id': 'u1', 'handle': 'amina', 'displayName': 'Amina'},
    });

    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [dioProvider.overrideWithValue(dio)],
      child: MaterialApp.router(
        routerConfig: GoRouter(routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => Scaffold(
              body: SingleChildScrollView(child: PostCard(post: post)),
            ),
          ),
        ]),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('Hello Aura'), findsWidgets);
    expect(reports.where((r) => r.startsWith('postCard.')), isEmpty);
  });
}
