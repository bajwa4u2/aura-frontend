import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:aura/core/link_preview/display_link_preview.dart';
import 'package:aura/core/link_preview/internal_reference_card.dart';
import 'package:aura/core/link_preview/link_preview.dart';
import 'package:aura/core/net/dio_provider.dart';
import 'package:aura/features/posts/presentation/widgets/post_card/post_card_utils.dart';

/// Item 14 — Internal Aura Link / Canonical Reference Hydration.
///
/// Covers: the model parses the backend's `internalReference` shape; the
/// client-side host check used to route display rendering; the bounded
/// card's rendering per outcome (never fabricating title/subtitle/image for
/// non-READY outcomes); and `DisplayLinkPreview`'s branch — external
/// renders immediately from stored fields (no network call, Item 13
/// unchanged), internal always re-resolves live against the current
/// viewer rather than trusting any stored/cached projection.
void main() {
  group('LinkPreview.fromJson internalReference parsing', () {
    test('parses a READY internal reference', () {
      final preview = LinkPreview.fromJson({
        'eligible': true,
        'internal': true,
        'sourceUrl': 'https://app.auraplatform.org/posts/p1',
        'status': 'INTERNAL',
        'internalReference': {
          'outcome': 'READY',
          'kind': 'POST',
          'route': '/posts/p1',
          'title': 'Hello world',
          'subtitle': 'Jane Doe',
          'imageUrl': null,
        },
      });

      expect(preview.internal, isTrue);
      expect(preview.internalReference, isNotNull);
      expect(preview.internalReference!.outcome, 'READY');
      expect(preview.internalReference!.isReady, isTrue);
      expect(preview.internalReference!.kind, 'POST');
      expect(preview.internalReference!.title, 'Hello world');
    });

    test('internalReference is null for an external link', () {
      final preview = LinkPreview.fromJson({
        'eligible': true,
        'internal': false,
        'sourceUrl': 'https://example.com',
        'status': 'READY',
      });

      expect(preview.internal, isFalse);
      expect(preview.internalReference, isNull);
    });

    test('parses a RESTRICTED outcome without fabricating any content fields', () {
      final preview = LinkPreview.fromJson({
        'eligible': true,
        'internal': true,
        'sourceUrl': 'https://app.auraplatform.org/direct/t1',
        'status': 'INTERNAL',
        'internalReference': {
          'outcome': 'RESTRICTED',
          'kind': 'DIRECT_THREAD',
          'route': null,
          'title': null,
          'subtitle': null,
          'imageUrl': null,
        },
      });

      expect(preview.internalReference!.outcome, 'RESTRICTED');
      expect(preview.internalReference!.isReady, isFalse);
      expect(preview.internalReference!.title, isNull);
    });
  });

  group('isInternalAuraUrl', () {
    test('recognizes the workspace host', () {
      expect(isInternalAuraUrl('https://app.auraplatform.org/posts/p1'), isTrue);
    });

    test('recognizes the marketing/share host', () {
      expect(isInternalAuraUrl('https://auraplatform.org/p/p1'), isTrue);
    });

    test('does not treat an external host as internal', () {
      expect(isInternalAuraUrl('https://example.com/posts/p1'), isFalse);
    });

    test('handles an unparseable URL without throwing', () {
      expect(isInternalAuraUrl('not a url'), isFalse);
    });
  });

  group('InternalReferenceCard', () {
    Widget wrap(Widget child) {
      return ProviderScope(
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: '/start',
            routes: [
              GoRoute(path: '/start', builder: (_, __) => Scaffold(body: child)),
              GoRoute(path: '/posts/p1', builder: (_, __) => const Scaffold(body: Text('Post screen'))),
            ],
          ),
        ),
      );
    }

    testWidgets('READY renders the canonical title and subtitle, never the raw URL', (tester) async {
      await tester.pumpWidget(wrap(const InternalReferenceCard(
        sourceUrl: 'https://app.auraplatform.org/posts/p1',
        reference: InternalReferenceResult(
          outcome: 'READY',
          kind: 'POST',
          route: '/posts/p1',
          title: 'Hello world',
          subtitle: 'Jane Doe',
        ),
      )));

      expect(find.text('Hello world'), findsOneWidget);
      expect(find.text('Jane Doe'), findsOneWidget);
    });

    testWidgets('RESTRICTED shows a non-revealing status, no title/subtitle', (tester) async {
      await tester.pumpWidget(wrap(const InternalReferenceCard(
        sourceUrl: 'https://app.auraplatform.org/direct/t1',
        reference: InternalReferenceResult(outcome: 'RESTRICTED', kind: 'DIRECT_THREAD'),
      )));

      expect(find.textContaining('isn\'t available'), findsOneWidget);
    });

    testWidgets('SIGN_IN_REQUIRED shows a sign-in prompt', (tester) async {
      await tester.pumpWidget(wrap(const InternalReferenceCard(
        sourceUrl: 'https://app.auraplatform.org/meetings/m1',
        reference: InternalReferenceResult(outcome: 'SIGN_IN_REQUIRED', kind: 'MEETING'),
      )));

      expect(find.textContaining('Sign in'), findsOneWidget);
    });

    testWidgets('tapping a READY reference navigates to its governed route', (tester) async {
      await tester.pumpWidget(wrap(const InternalReferenceCard(
        sourceUrl: 'https://app.auraplatform.org/posts/p1',
        reference: InternalReferenceResult(
          outcome: 'READY',
          kind: 'POST',
          route: '/posts/p1',
          title: 'Hello world',
        ),
      )));

      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();

      expect(find.text('Post screen'), findsOneWidget);
    });
  });

  group('DisplayLinkPreview', () {
    testWidgets('external link renders immediately from stored fields, no network call', (tester) async {
      var resolveCallCount = 0;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
      dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
        resolveCallCount++;
        handler.resolve(Response(requestOptions: options, statusCode: 200, data: {}));
      }));

      await tester.pumpWidget(ProviderScope(
        overrides: [dioProvider.overrideWithValue(dio)],
        child: const MaterialApp(
          home: Scaffold(
            body: DisplayLinkPreview(
              linkUrl: 'https://example.com/article',
              linkTitle: 'A Great Article',
              linkImageUrl: null,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('A Great Article'), findsOneWidget);
      expect(resolveCallCount, 0);
    });

    testWidgets('internal link re-resolves live against the current viewer', (tester) async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
      dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
        handler.resolve(Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            'data': {
              'eligible': true,
              'internal': true,
              'sourceUrl': 'https://app.auraplatform.org/posts/p1',
              'status': 'INTERNAL',
              'internalReference': {
                'outcome': 'READY',
                'kind': 'POST',
                'route': '/posts/p1',
                'title': 'Freshly resolved title',
              },
            },
          },
        ));
      }));

      await tester.pumpWidget(ProviderScope(
        overrides: [dioProvider.overrideWithValue(dio)],
        child: const MaterialApp(
          home: Scaffold(
            body: DisplayLinkPreview(linkUrl: 'https://app.auraplatform.org/posts/p1'),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Freshly resolved title'), findsOneWidget);
    });
  });
}
