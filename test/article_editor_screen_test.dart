// F025 + F026 — driven through the REAL `ArticleEditorScreen`.
//
// Not a minimal harness: the actual screen, the actual `ArticlesRepository`,
// the actual draft-load and autosave wiring. A test that reimplements the
// surface it is meant to certify proves nothing about the surface.
//
// F025 — "Article image insertion shows raw markdown to the author instead of
// a rendered image." The author now writes and SEES at once: the body markdown
// is rendered live, by the same publication renderer that will publish it.
//
// F026 — "Pasting a title into the article editor oversizes it." A pasted
// title arrives normalised in shape, and its size follows its length.
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:aura/core/net/dio_provider.dart';
import 'package:aura/core/ui/publication/aura_publication_markdown.dart';
import 'package:aura/core/ui/publication/aura_publication_title.dart';
import 'package:aura/features/articles/presentation/article_editor_screen.dart';

const _imageMarkdown = '![image](https://cdn.example.test/photo.png)';

void main() {
  testWidgets('F025 — the inserted image renders while writing, on a wide view',
      (tester) async {
    _surface(tester, const Size(1400, 1400));
    await tester.pumpWidget(_app(_articleDio(body: 'Opening line.\n\n$_imageMarkdown')));
    await tester.pumpAndSettle();

    // The source is still markdown — that is what a markdown editor is, and
    // the durability of the written URL belongs to F121, not here.
    expect(find.text('Opening line.\n\n$_imageMarkdown'), findsOneWidget);

    // ...and the author simultaneously sees it RENDERED, by the shared
    // publication renderer, without leaving writing mode. This pairing is
    // exactly what F025 reported missing.
    expect(find.byType(AuraPublicationMarkdown), findsOneWidget);
    expect(find.byType(Image), findsWidgets);
  });

  testWidgets('F025 — the rendered half updates as the author types',
      (tester) async {
    _surface(tester, const Size(1400, 1400));
    await tester.pumpWidget(_app(_articleDio(body: '')));
    await tester.pumpAndSettle();

    await tester.enterText(_bodyField, '## A heading the author just typed');
    await tester.pump();

    expect(find.text('A heading the author just typed'), findsOneWidget,
        reason: 'A preview that only updates on a toggle is not live.');
  });

  testWidgets('F025 — the preview is a pane, not a mode, when there is room',
      (tester) async {
    _surface(tester, const Size(1400, 1400));
    await tester.pumpWidget(_app(_articleDio(body: 'text')));
    await tester.pumpAndSettle();

    expect(find.text('Preview'), findsNothing,
        reason: 'A toggle to something already on screen is dead chrome.');
  });

  testWidgets('F025 — a narrow view keeps the toggle and renders on demand',
      (tester) async {
    _surface(tester, const Size(560, 1000));
    await tester.pumpWidget(_app(_articleDio(body: '## Narrow heading')));
    await tester.pumpAndSettle();

    expect(find.byType(AuraPublicationMarkdown), findsNothing);
    await tester.tap(find.text('Preview'));
    await tester.pumpAndSettle();

    expect(find.byType(AuraPublicationMarkdown), findsOneWidget);
    expect(find.text('Narrow heading'), findsOneWidget);
  });

  testWidgets('F026 — a pasted multi-line title arrives as one line',
      (tester) async {
    _surface(tester, const Size(1400, 1400));
    final saved = <Map<String, dynamic>>[];
    await tester.pumpWidget(_app(_articleDio(body: '', saved: saved)));
    await tester.pumpAndSettle();

    await tester.enterText(
        _titleField, 'The Institution\nOperating\nLayer');
    await tester.pump();

    final field = tester.widget<TextField>(_titleField);
    expect(field.controller!.text, 'The Institution Operating Layer',
        reason: 'Three pasted lines consumed the whole title box.');
  });

  testWidgets('F026 — a long pasted title is rendered smaller, not clipped',
      (tester) async {
    _surface(tester, const Size(1400, 1400));
    await tester.pumpWidget(_app(_articleDio(body: '', title: 'Short')));
    await tester.pumpAndSettle();

    final short = tester.widget<TextField>(_titleField).style!.fontSize!;

    final long = List.generate(24, (i) => 'word$i').join(' ');
    await tester.enterText(_titleField, long);
    await tester.pump();

    final big = tester.widget<TextField>(_titleField).style!.fontSize!;
    expect(big, lessThan(short),
        reason: 'A 40px fixed field is precisely how the title oversized.');
  });

  testWidgets('F026 — the editor and its preview show one title, one size',
      (tester) async {
    _surface(tester, const Size(1400, 1400));
    final long = List.generate(24, (i) => 'word$i').join(' ');
    await tester.pumpWidget(_app(_articleDio(body: 'body', title: long)));
    await tester.pumpAndSettle();

    final fieldSize = tester.widget<TextField>(_titleField).style!.fontSize!;
    final previewSize = tester
        .widget<Text>(find.descendant(
          of: find.byType(AuraPublicationTitle),
          matching: find.text(long),
        ))
        .style!
        .fontSize!;

    expect(previewSize, fieldSize,
        reason: 'One authority, or the title changes size on publish.');
  });
}

Finder get _titleField => find.byType(TextField).first;
Finder get _bodyField => find.byType(TextField).at(1);

void _surface(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Widget _app(Dio dio) {
  return ProviderScope(
    overrides: [dioProvider.overrideWithValue(dio)],
    child: MaterialApp.router(
      routerConfig: GoRouter(
        initialLocation: '/articles/write/a1',
        routes: [
          GoRoute(
            path: '/articles/write/:id',
            // The real app routes every screen inside a shell that provides
            // Material/Scaffold; AuraScaffold is deliberately a pure page
            // surface. The harness reproduces that ancestor rather than
            // changing the screen to suit a test.
            builder: (context, state) => Scaffold(
              body: ArticleEditorScreen(articleId: state.pathParameters['id']),
            ),
          ),
          GoRoute(
            path: '/create',
            builder: (context, state) => const SizedBox.shrink(),
          ),
        ],
      ),
    ),
  );
}

/// The real repository talking to a canned transport — the screen's own
/// load/save path is exercised, only the network is replaced.
Dio _articleDio({
  required String body,
  String title = '',
  List<Map<String, dynamic>>? saved,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      if (options.method == 'GET' && options.path == '/articles/mine/a1') {
        return handler.resolve(Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            'data': {
              'article': {
                'id': 'a1',
                'slug': null,
                'title': title,
                'bodyMarkdown': body,
                'coverMediaId': null,
                'status': 'DRAFT',
                'publishedAt': null,
              },
            },
          },
        ));
      }
      if (options.method == 'PATCH' && options.path == '/articles/a1') {
        saved?.add(Map<String, dynamic>.from(options.data as Map));
        return handler.resolve(
            Response(requestOptions: options, statusCode: 200, data: {'data': {}}));
      }
      return handler.resolve(
          Response(requestOptions: options, statusCode: 200, data: {'data': {}}));
    },
  ));
  return dio;
}
