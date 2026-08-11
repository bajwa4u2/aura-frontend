import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:aura/core/net/dio_provider.dart';
import 'package:aura/features/institutions/announcements/institution_announcement_composer.dart';

/// Compose Link Intelligence / OG Preview -- Phase 1 (Announcement
/// extension). Mounts the real, full `InstitutionAnnouncementComposer` --
/// not a minimal harness -- proving Institution Announcements reuse the
/// identical shared `ComposeLinkDetector`/`LinkPreviewService`/
/// `LinkPreviewCard` mechanism already certified for member and institution
/// post compose, rather than a third divergent implementation. Exercised
/// via "Save draft" -- publish routes through the Communication Integrity
/// review sheet (a separate, unrelated flow this test doesn't need to
/// drive) but shares the exact same `_save()`/payload wiring underneath.
void main() {
  testWidgets(
    'announcement compose: pasting a URL resolves a preview and the saved payload carries it',
    (tester) async {
      _useLargeSurface(tester);
      final saved = <Map<String, dynamic>>[];
      final resolveCalls = <String>[];
      final dio = _announcementComposeDio(saved: saved, resolveCalls: resolveCalls);

      await tester.pumpWidget(_wrap(dio));
      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(1), 'A short summary.');
      await tester.enterText(
        fields.at(2),
        'Read more at https://example.com/notice',
      );
      await tester.pump(const Duration(milliseconds: 600)); // detector debounce
      await tester.pumpAndSettle();

      expect(resolveCalls, contains('https://example.com/notice'));
      expect(find.text('Official Notice'), findsOneWidget);

      await tester.ensureVisible(find.text('Save draft'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save draft'));
      await tester.pumpAndSettle();

      expect(saved, isNotEmpty);
      final sent = saved.last;
      expect(sent['linkPreviewId'], 'lp-ann-1');
      expect(sent['linkSourceUrl'], 'https://example.com/notice');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets(
    'announcement compose: removing the pasted URL clears the preview and the payload',
    (tester) async {
      _useLargeSurface(tester);
      final saved = <Map<String, dynamic>>[];
      final resolveCalls = <String>[];
      final dio = _announcementComposeDio(saved: saved, resolveCalls: resolveCalls);

      await tester.pumpWidget(_wrap(dio));
      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(1), 'A short summary.');
      await tester.enterText(fields.at(2), 'see https://example.com/notice');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(find.text('Official Notice'), findsOneWidget);

      await tester.enterText(fields.at(2), 'no link anymore, just text');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(find.text('Official Notice'), findsNothing);

      await tester.ensureVisible(find.text('Save draft'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save draft'));
      await tester.pumpAndSettle();

      expect(saved, isNotEmpty);
      expect(saved.last['linkPreviewId'], isNull);
      expect(saved.last['linkSourceUrl'], isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets(
    'announcement compose: an existing announcement with a link preview hydrates the card immediately on edit',
    (tester) async {
      _useLargeSurface(tester);
      final dio = _announcementComposeDio(saved: [], resolveCalls: []);

      await tester.pumpWidget(
        _wrap(
          dio,
          announcementId: 'ann-1',
          initialData: const {
            'title': 'Existing announcement',
            'summary': 'Existing summary',
            'bodyMarkdown': 'Existing body text',
            'kind': 'GENERAL',
            'audience': 'PUBLIC',
            'linkUrl': 'https://example.com/already-attached',
            'linkTitle': 'Already Attached Link',
          },
        ),
      );
      await tester.pumpAndSettle();

      // Rendered from the announcement's own already-resolved fields -- no
      // resolve() call needed for this to appear.
      expect(find.text('Already Attached Link'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}

void _useLargeSurface(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1400, 1600);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Widget _wrap(
  Dio dio, {
  String? announcementId,
  Map<String, dynamic>? initialData,
}) {
  return ProviderScope(
    overrides: [dioProvider.overrideWithValue(dio)],
    child: MaterialApp.router(
      routerConfig: GoRouter(
        initialLocation: '/institution/inst-1/announcements',
        routes: [
          GoRoute(
            path: '/institution/inst-1/announcements',
            builder: (context, state) => const SizedBox.shrink(),
            routes: [
              GoRoute(
                path: 'compose',
                builder: (context, state) => Scaffold(
                  body: InstitutionAnnouncementComposer(
                    institutionId: 'inst-1',
                    announcementId: announcementId,
                    initialData: initialData,
                  ),
                ),
              ),
            ],
          ),
        ],
        redirect: (context, state) => state.uri.path == '/institution/inst-1/announcements'
            ? '/institution/inst-1/announcements/compose'
            : null,
      ),
    ),
  );
}

Dio _announcementComposeDio({
  required List<Map<String, dynamic>> saved,
  required List<String> resolveCalls,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final path = options.path;
        final method = options.method;

        if (method == 'POST' && path == '/link-previews/resolve') {
          final url = (options.data as Map)['url'] as String;
          resolveCalls.add(url);
          return handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'data': {
                  'eligible': true,
                  'internal': false,
                  'sourceUrl': url,
                  'canonicalUrl': url,
                  'linkPreviewId': 'lp-ann-1',
                  'status': 'READY',
                  'title': 'Official Notice',
                  'description': 'Details of this official notice.',
                  'siteName': 'example.com',
                  'imageUrl': null,
                  'faviconUrl': null,
                },
              },
            ),
          );
        }

        if (method == 'POST' && path == '/institutions/inst-1/announcements') {
          final data = Map<String, dynamic>.from(options.data as Map);
          saved.add(data);
          return handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'ok': true,
                'item': {
                  'id': 'ann-1',
                  'slug': 'a-slug',
                  'title': data['title'],
                  'summary': data['summary'],
                  'excerpt': data['excerpt'],
                  'bodyMarkdown': data['bodyMarkdown'],
                  'kind': data['kind'],
                  'audience': data['audience'],
                  'status': 'DRAFT',
                  'pinned': false,
                  'media': <dynamic>[],
                },
              },
            ),
          );
        }

        if (method == 'PATCH' &&
            path.startsWith('/institutions/inst-1/announcements/')) {
          final data = Map<String, dynamic>.from(options.data as Map);
          saved.add(data);
          return handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'ok': true,
                'item': {
                  'id': 'ann-1',
                  'slug': 'a-slug',
                  'title': data['title'] ?? 'Existing announcement',
                  'summary': data['summary'] ?? 'Existing summary',
                  'excerpt': data['excerpt'] ?? 'Existing summary',
                  'bodyMarkdown': data['bodyMarkdown'] ?? 'Existing body text',
                  'kind': 'GENERAL',
                  'audience': 'PUBLIC',
                  'status': 'DRAFT',
                  'pinned': false,
                  'media': <dynamic>[],
                },
              },
            ),
          );
        }

        return handler.resolve(
          Response(
            requestOptions: options,
            statusCode: 404,
            data: 'unhandled ${options.method} $path',
          ),
        );
      },
    ),
  );
  return dio;
}
