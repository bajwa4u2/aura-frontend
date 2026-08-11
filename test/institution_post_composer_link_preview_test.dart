import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:aura/core/auth/session_providers.dart';
import 'package:aura/core/institutions/institution_access_provider.dart';
import 'package:aura/core/net/dio_provider.dart';
import 'package:aura/features/institutions/domain/institution_post.dart';
import 'package:aura/features/institutions/posts/institution_post_composer_screen.dart';

/// Compose Link Intelligence / OG Preview -- Phase 1.
///
/// Mounts the real, full `InstitutionPostComposerScreen` -- not a minimal
/// harness -- and drives an actual paste-a-URL-and-save flow through it,
/// proving institution compose produces the same class of preview as
/// member compose via the identical shared `ComposeLinkDetector`/
/// `LinkPreviewService`/`LinkPreviewCard`. Uses the edit-mode entry point
/// (`widget.initial` pre-set with a primary topic already selected) so the
/// test exercises the link-preview payload wiring without also having to
/// drive the (unrelated) topic-picker UI -- `_localValidationError`
/// requires a primary topic before save is enabled either way, and
/// create-mode and edit-mode share the exact same `_payload()`.
void main() {
  testWidgets(
    'institution compose: pasting a URL resolves a preview and the saved payload carries it',
    (tester) async {
      _useLargeSurface(tester);
      final saved = <Map<String, dynamic>>[];
      final resolveCalls = <String>[];
      final dio = _institutionComposeDio(saved: saved, resolveCalls: resolveCalls);

      await tester.pumpWidget(_wrap(dio, initial: _editableInitial()));
      await tester.pumpAndSettle();

      final bodyField = find.byType(TextField).at(1); // title field is .first
      await tester.enterText(bodyField, 'check this out https://example.com/report');
      await tester.pump(const Duration(milliseconds: 600)); // detector debounce
      await tester.pumpAndSettle();

      expect(resolveCalls, contains('https://example.com/report'));
      expect(find.text('Quarterly Report'), findsOneWidget);

      await tester.ensureVisible(find.text('Save changes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(saved, isNotEmpty);
      final sent = saved.last;
      expect(sent['linkPreviewId'], 'lp-inst-1');
      expect(sent['linkSourceUrl'], 'https://example.com/report');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets(
    'institution compose: removing the pasted URL clears the preview and the payload',
    (tester) async {
      _useLargeSurface(tester);
      final saved = <Map<String, dynamic>>[];
      final resolveCalls = <String>[];
      final dio = _institutionComposeDio(saved: saved, resolveCalls: resolveCalls);

      await tester.pumpWidget(_wrap(dio, initial: _editableInitial()));
      await tester.pumpAndSettle();

      final bodyField = find.byType(TextField).at(1);
      await tester.enterText(bodyField, 'see https://example.com/report');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(find.text('Quarterly Report'), findsOneWidget);

      await tester.enterText(bodyField, 'no link anymore');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(find.text('Quarterly Report'), findsNothing);

      await tester.ensureVisible(find.text('Save changes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(saved, isNotEmpty);
      expect(saved.last['linkPreviewId'], isNull);
      expect(saved.last['linkSourceUrl'], isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets(
    'institution compose: an existing post with a link preview hydrates the card immediately on edit',
    (tester) async {
      _useLargeSurface(tester);
      final dio = _institutionComposeDio(saved: [], resolveCalls: []);

      const initial = InstitutionPost(
        id: 'ip1',
        institutionId: 'inst-1',
        authorUserId: 'user-1',
        title: 'Existing post',
        body: 'Existing body text',
        visibility: InstitutionPostVisibility.publicAll,
        distribution: InstitutionPostDistribution.globalEligible,
        status: InstitutionPostStatus.draft,
        primaryTopic: 'TECHNOLOGY',
        linkUrl: 'https://example.com/already-attached',
        linkTitle: 'Already Attached Link',
      );

      await tester.pumpWidget(_wrap(dio, initial: initial));
      await tester.pumpAndSettle();

      // Rendered from the post's own already-resolved fields -- no
      // resolve() call needed for this to appear.
      expect(find.text('Already Attached Link'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}

InstitutionPost _editableInitial() {
  return const InstitutionPost(
    id: 'ip1',
    institutionId: 'inst-1',
    authorUserId: 'user-1',
    title: 'Existing post',
    body: 'Existing body text',
    visibility: InstitutionPostVisibility.publicAll,
    distribution: InstitutionPostDistribution.globalEligible,
    status: InstitutionPostStatus.draft,
    primaryTopic: 'TECHNOLOGY',
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

Widget _wrap(Dio dio, {required InstitutionPost initial}) {
  return ProviderScope(
    overrides: [
      dioProvider.overrideWithValue(dio),
      authMeDataProvider.overrideWith(
        (ref) async => {
          'id': 'user-1',
          'accountType': 'PUBLIC',
          'identityBaselineComplete': true,
        },
      ),
      institutionIdentityProvider.overrideWithValue(
        const InstitutionIdentity(
          id: 'inst-1',
          name: 'Test Institution',
          slug: 'test-institution',
          isAuthorizedSpeaker: true,
          capabilities: {'PUBLISH_OFFICIAL'},
          role: 'OWNER',
        ),
      ),
    ],
    child: MaterialApp.router(
      routerConfig: GoRouter(
        initialLocation: '/institution/inst-1/posts',
        routes: [
          GoRoute(
            path: '/institution/inst-1/posts',
            builder: (context, state) => const SizedBox.shrink(),
            routes: [
              GoRoute(
                path: 'edit',
                builder: (context, state) => Material(
                  child: InstitutionPostComposerScreen(
                    institutionId: 'inst-1',
                    postId: initial.id,
                    initial: initial,
                  ),
                ),
              ),
            ],
          ),
        ],
        redirect: (context, state) =>
            state.uri.path == '/institution/inst-1/posts'
            ? '/institution/inst-1/posts/edit'
            : null,
      ),
    ),
  );
}

Dio _institutionComposeDio({
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
                  'linkPreviewId': 'lp-inst-1',
                  'status': 'READY',
                  'title': 'Quarterly Report',
                  'description': 'Full breakdown of Q3 results.',
                  'siteName': 'example.com',
                  'imageUrl': null,
                  'faviconUrl': null,
                },
              },
            ),
          );
        }

        if (method == 'PATCH' && path == '/institutions/inst-1/posts/ip1') {
          saved.add(Map<String, dynamic>.from(options.data as Map));
          return handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'data': {
                  'id': 'ip1',
                  'institutionId': 'inst-1',
                  'authorUserId': 'user-1',
                  'title': options.data['title'],
                  'body': options.data['body'],
                  'visibility': 'PUBLIC',
                  'distribution': 'GLOBAL_ELIGIBLE',
                  'status': 'DRAFT',
                },
              },
            ),
          );
        }

        return handler.resolve(
          Response(requestOptions: options, statusCode: 404, data: 'unhandled ${options.method} $path'),
        );
      },
    ),
  );
  return dio;
}
