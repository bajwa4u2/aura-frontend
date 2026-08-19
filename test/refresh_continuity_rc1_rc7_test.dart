// REFRESH IS NOT NAVIGATION — RC1 and RC7.
//
// Founder contract: reloading on a legitimate destination must reconstruct
// that destination. The shared-cause audit ranked nine root causes beneath
// F059 / F061 / F062 / F063; these are the two widest that can be corrected
// without touching institution routing.
//
// RC1 — web session restore was gated behind a device-local boolean, so a
// browser that could not answer, or that had lost the hint, made Aura state
// "not authenticated" and the router correctly discarded a destination the
// person had every right to keep.
//
// RC7 — the article editor minted a NEW draft on every mount of the id-less
// route and never wrote the draft's identity into the URL, so a reload could
// not reopen the article being written and left an orphan row behind.
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:aura/core/auth/session_hint.dart';
import 'package:aura/core/auth/web_session_restore.dart';
import 'package:aura/core/net/dio_provider.dart';
import 'package:aura/features/articles/presentation/article_editor_screen.dart';

void main() {
  group('RC1 — a hint that cannot be read is not a signed-out user', () {
    WebSessionRestoreDecision decide(SessionHintStatus s, String path) =>
        decideWebSessionRestore(status: s, landingPath: path);

    test('a present hint always restores', () {
      expect(decide(SessionHintStatus.present, '/').attempt, isTrue);
      expect(decide(SessionHintStatus.present, '/conversations/c1').attempt, isTrue);
    });

    test('an UNREADABLE device restores — private browsing is not a sign-out', () {
      // SharedPreferences throws in private mode. Answering "no hint" there
      // turned "I cannot know" into "definitely never signed in".
      final d = decide(SessionHintStatus.unavailable, '/');
      expect(d.attempt, isTrue);
      expect(d.reason, RestoreDecisionReason.hintUnavailable);
    });

    test('no hint on a member destination still restores', () {
      for (final path in const [
        '/conversations/c1',
        '/institution/inst-1/edit-profile',
        '/articles/write/a1',
        '/compose',
      ]) {
        final d = decide(SessionHintStatus.absent, path);
        expect(d.attempt, isTrue, reason: '$path lost its destination');
        expect(d.reason, RestoreDecisionReason.destinationRequiresSession);
      }
    });

    test('no hint on an UNCLASSIFIED route restores — unknown is not public', () {
      // classifyRoute fails closed to MEMBER, so a route nobody remembered to
      // classify costs one speculative refresh, never a lost destination.
      expect(decide(SessionHintStatus.absent, '/some/unlisted/surface').attempt,
          isTrue);
    });

    test('no hint mid-identity-ceremony restores', () {
      // /complete-identity and /verify-pending REQUIRE a session to mean
      // anything. Skipping there strands someone mid-ceremony on reload.
      for (final path in const ['/complete-identity', '/verify-pending']) {
        expect(decide(SessionHintStatus.absent, path).attempt, isTrue,
            reason: '$path needs the session it is completing');
      }
    });

    test('no hint on the router boot path restores', () {
      // /_boot is a moment, not a destination. A reload while it is on screen
      // must not land permanently signed out.
      expect(decide(SessionHintStatus.absent, '/_boot').attempt, isTrue);
    });

    test('THE ONE CASE THAT STILL SKIPS: no hint, public landing page', () {
      // This is what the hint was added for: a fresh tab on a marketing page
      // producing nothing but `401 Missing refresh token` in the console.
      for (final path in const ['/', '/public', '/privacy', '/mission', '/login']) {
        final d = decide(SessionHintStatus.absent, path);
        expect(d.attempt, isFalse, reason: '$path should stay quiet');
        expect(d.reason, RestoreDecisionReason.publicLandingWithoutHint);
      }
    });

    test('the hygiene win is preserved exactly, and nowhere else', () {
      // Every skip in the whole decision space is a public landing without a
      // hint. If that stops being true, the gate has widened again.
      const paths = [
        '/', '/public', '/privacy', '/mission', '/login', '/_boot',
        '/complete-identity', '/conversations/c1', '/unclassified',
      ];
      for (final status in SessionHintStatus.values) {
        for (final path in paths) {
          final d = decide(status, path);
          if (!d.attempt) {
            expect(d.reason, RestoreDecisionReason.publicLandingWithoutHint);
            expect(status, SessionHintStatus.absent);
          }
        }
      }
    });
  });

  group('RC7 — the draft the address bar can find again', () {
    testWidgets('creating a draft writes its identity into the URL',
        (tester) async {
      final calls = <String>[];
      final router = _router();
      await tester.pumpWidget(_app(router, _articlesDio(calls)));
      await tester.pumpAndSettle();

      expect(calls, contains('POST /articles'));
      expect(router.routerDelegate.currentConfiguration.uri.path,
          '/articles/write/draft-1',
          reason: 'A reload of the id-less route minted another draft.');
    });

    testWidgets('opening an existing draft creates nothing', (tester) async {
      final calls = <String>[];
      final router = _router(start: '/articles/write/a9');
      await tester.pumpWidget(_app(router, _articlesDio(calls)));
      await tester.pumpAndSettle();

      expect(calls, contains('GET /articles/mine/a9'));
      expect(calls, isNot(contains('POST /articles')),
          reason: 'This is the reload path — it must resume, not create.');
      expect(router.routerDelegate.currentConfiguration.uri.path,
          '/articles/write/a9');
    });
  });
}

GoRouter _router({String start = '/articles/write'}) {
  // Sibling routes, exactly as router.dart registers them — not nested, so
  // the id-less editor is not mounted on the way to the id-carrying one.
  return GoRouter(
    initialLocation: start,
    routes: [
      GoRoute(
        path: '/articles/write',
        // The real app supplies Material through its shell; AuraScaffold is
        // deliberately a pure page surface.
        builder: (context, state) => const Scaffold(body: ArticleEditorScreen()),
      ),
      GoRoute(
        path: '/articles/write/:articleId',
        builder: (context, state) => Scaffold(
          body: ArticleEditorScreen(articleId: state.pathParameters['articleId']),
        ),
      ),
    ],
  );
}

Widget _app(GoRouter router, Dio dio) => ProviderScope(
      overrides: [dioProvider.overrideWithValue(dio)],
      child: MaterialApp.router(routerConfig: router),
    );

Dio _articlesDio(List<String> calls) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      calls.add('${options.method} ${options.path}');
      final id = options.path.startsWith('/articles/mine/')
          ? options.path.split('/').last
          : 'draft-1';
      return handler.resolve(Response(
        requestOptions: options,
        statusCode: 200,
        data: {
          'data': {
            'article': {
              'id': id,
              'slug': null,
              'title': '',
              'bodyMarkdown': '',
              'coverMediaId': null,
              'status': 'DRAFT',
              'publishedAt': null,
            },
          },
        },
      ));
    },
  ));
  return dio;
}
