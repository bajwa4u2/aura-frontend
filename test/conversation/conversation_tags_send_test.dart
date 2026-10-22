// Messages and governed tags, end to end on the REAL ConversationScreen.
//
// 21 Oct 2026 on a Galaxy S24+: "Testing mentions @ba", pick M S Bajwa (the
// field showed "@bajwawrites"), Send -> refused: the body sent was the typed
// "@ba" while the tag said "@bajwawrites". The composer's body was copied
// only from the field's onChanged, which a pick or an x never fires. Then a
// sent "@bajwawrites" drew as plain text: the bubble matched party NAMES and
// ignored the message's own tag records.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/net/dio_provider.dart';
import 'package:aura/features/conversation/presentation/conversation_identity.dart';
import 'package:aura/features/conversation/presentation/conversation_screen.dart';

void main() {
  late _Recorder rec;
  setUp(() => rec = _Recorder());

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_wrap(rec));
    await tester.pumpAndSettle();
  }

  Future<void> pickAmina(WidgetTester tester) async {
    await tester.showKeyboard(find.byType(TextField).last);
    await tester.enterText(find.byType(TextField).last, 'Testing mentions @am');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    final strip = find.byKey(const ValueKey('tag-suggestion-strip'));
    expect(strip, findsOneWidget);
    await tester.tap(find.descendant(of: strip, matching: find.text('Amina')));
    await tester.pump();
  }

  testWidgets('pick a person, send: the body is the field text and holds the tag',
      (tester) async {
    await open(tester);
    await pickAmina(tester);

    final field = tester.widget<TextField>(find.byType(TextField).last);
    expect(field.controller!.text, startsWith('Testing mentions @amina'));

    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();

    expect(rec.sends, hasLength(1));
    final sent = rec.sends.single;
    expect(sent['body'], 'Testing mentions @amina');
    final tags = (sent['tagReferences'] as List).cast<Map>();
    expect(tags, hasLength(1));
    expect(sent['body'], contains(tags.single['sourceText']));
    // The server resolves a mention by USER ID; a handle here was refused as
    // "Mentioned member not found" (S24+, 21 Oct 2026).
    expect(tags.single['entityId'], 'user-amina');
    expect(tags.single['kind'], 'member');
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('remove the tag with x, send: the body is the field text, no tags',
      (tester) async {
    await open(tester);
    await pickAmina(tester);

    final row = find.byKey(const ValueKey('attached-tag-row'));
    expect(row, findsOneWidget);
    await tester.tap(find.descendant(of: row, matching: find.byIcon(Icons.close_rounded)));
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField).last);
    expect(field.controller!.text, 'Testing mentions ');

    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();

    expect(rec.sends, hasLength(1));
    final sent = rec.sends.single;
    expect(sent['body'], 'Testing mentions');
    final tags = sent['tagReferences'];
    expect(tags == null || (tags as List).isEmpty, isTrue);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('the send control has a name', (tester) async {
    await open(tester);
    expect(find.byTooltip('Send message'), findsOneWidget);
    expect(find.byTooltip('Attach'), findsOneWidget);
    expect(find.byTooltip('Voice note'), findsOneWidget);
  });

  testWidgets('a recorded tag draws as the person\'s name, styled and tappable',
      (tester) async {
    rec.history = [
      {
        'id': 'm1',
        'senderUserId': 'user-amina',
        'body': 'Thanks @bajwawrites for this',
        'createdAt': '2026-10-21T10:00:00.000Z',
        'tagReferences': [
          {
            'kind': 'member',
            'entityId': 'user-b',
            'displayLabel': 'M S Bajwa',
            'sourceText': '@bajwawrites',
            'startOffset': 7,
            'endOffset': 19,
            'identity': {
              'id': 'user-b',
              'type': 'member',
              'displayLabel': 'M S Bajwa',
              'handleOrSlug': 'bajwawrites',
              'route': '/u/bajwawrites',
            },
          },
        ],
      },
    ];
    await open(tester);

    final span = _spanWithText(tester, '@M S Bajwa');
    expect(span, isNotNull, reason: 'the tag draws as the person\'s name');
    expect(span!.style?.fontWeight, FontWeight.w800);
    expect(span.recognizer, isNotNull, reason: 'it opens the person');
    expect(span.mouseCursor, SystemMouseCursors.click);
    expect(_spanWithText(tester, '@bajwawrites'), isNull);
  });

  testWidgets('a message without records still highlights a party by name',
      (tester) async {
    rec.history = [
      {
        'id': 'm1',
        'senderUserId': 'user-amina',
        'body': 'Hello @Amina here',
        'createdAt': '2026-10-21T10:00:00.000Z',
      },
    ];
    await open(tester);

    final span = _spanWithText(tester, '@Amina');
    expect(span, isNotNull);
    expect(span!.style?.fontWeight, FontWeight.w800);
  });
}

/// The rendered TextSpan whose own text is exactly [text], if any.
TextSpan? _spanWithText(WidgetTester tester, String text) {
  TextSpan? hit;
  void visit(InlineSpan s) {
    if (s is TextSpan) {
      if (s.text == text) hit ??= s;
      for (final c in s.children ?? const <InlineSpan>[]) {
        visit(c);
      }
    }
  }

  for (final w in tester.widgetList<RichText>(find.byType(RichText))) {
    visit(w.text);
  }
  for (final e in find.byType(EditableText).evaluate()) {
    final w = e.widget as EditableText;
    final span = w.controller.buildTextSpan(
      context: e,
      style: w.style,
      withComposing: false,
    );
    visit(span);
  }
  return hit;
}

Widget _wrap(_Recorder rec) {
  return ProviderScope(
    overrides: [
      dioProvider.overrideWithValue(rec.dio),
      myUserIdProvider.overrideWithValue('user-me'),
    ],
    child: const MaterialApp(
      home: Scaffold(body: ConversationScreen(conversationId: 'c1')),
    ),
  );
}

class _Recorder {
  _Recorder() {
    dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.interceptors.add(InterceptorsWrapper(onRequest: _onRequest));
  }

  late final Dio dio;
  final List<Map<String, dynamic>> sends = [];
  List<Map<String, dynamic>> history = [];

  void _onRequest(RequestOptions o, RequestInterceptorHandler h) {
    final path = o.path;
    final body =
        o.data is Map ? Map<String, dynamic>.from(o.data as Map) : const {};

    if (o.method == 'POST' && path == '/conversations/c1/messages') {
      sends.add(Map<String, dynamic>.from(body));
      return h.resolve(_ok(o, {
        'message': {
          'id': 'm-new',
          'senderUserId': 'user-me',
          'body': body['body'],
          'createdAt': '2026-10-21T10:01:00.000Z',
        },
      }));
    }
    if (o.method == 'GET' && path == '/conversations/c1') {
      return h.resolve(_ok(o, {
        'conversation': {
          'id': 'c1',
          'name': 'Amina',
          'isDirect': true,
          'unreadCount': 0,
          'archived': false,
          'muted': false,
          'parties': [
            {
              'kind': 'PERSON',
              'person': {'id': 'user-me', 'displayName': 'Me', 'handle': 'me'},
            },
            {
              'kind': 'PERSON',
              'person': {
                'id': 'user-amina',
                'displayName': 'Amina',
                'handle': 'amina',
              },
            },
          ],
        },
      }));
    }
    if (o.method == 'GET' && path == '/conversations/c1/messages') {
      return h.resolve(_ok(o, {'messages': history}));
    }
    if (o.method == 'GET' && path == '/conversations/c1/live') {
      return h.resolve(_ok(o, {'activeSession': null}));
    }
    return h.resolve(_ok(o, const {}));
  }

  Response<dynamic> _ok(RequestOptions o, Map<String, dynamic> data) =>
      Response<dynamic>(
        requestOptions: o,
        statusCode: 200,
        data: {'ok': true, ...data},
      );
}
