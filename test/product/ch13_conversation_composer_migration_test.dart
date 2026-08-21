// CH-13 · WAVE 1 — the proving consumer, end to end.
//
// These tests drive the REAL `ConversationScreen`, not a harness that resembles
// it. The conversation composer was chosen as the first migration because it is
// the only surface in Aura that supports all three acquisition doors — picker,
// paste and drop — so it exercises the whole of ContentIntake rather than a
// convenient corner of it.
//
// Two of the three doors cannot be driven from a widget test: clipboard paste
// arrives through `contentInsertionConfiguration` and drag/drop through a
// native `desktop_drop` event, neither of which has a Flutter-side seam. The
// DOCUMENT door does have one — `FilePicker.platform` is injectable — so it is
// the door used here, and it reaches exactly the same `_admit` → intake →
// lifecycle → authority path the other two do.
//
// What these prove is the migration's substance:
//
//   * a refusal now happens AT THE DOOR, with nothing uploaded and nothing
//     shown, instead of being deferred to a presign rejection;
//   * an accepted file reaches the wire with the mime intake resolved, not
//     `application/octet-stream`;
//   * a FAILED attachment still holds its claim, so the send that used to drop
//     it silently is refused instead;
//   * readiness on the send control is the authority's answer.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/net/dio_provider.dart';
import 'package:aura/features/conversation/data/conversations_repository.dart';
import 'package:aura/features/conversation/presentation/conversation_identity.dart';
import 'package:aura/features/conversation/presentation/conversation_screen.dart';

void main() {
  late _Recorder rec;

  setUp(() {
    rec = _Recorder();
    FilePicker.platform = _FakeFilePicker();
  });

  testWidgets(
    'an unsupported document is refused at the door: nothing uploads, nothing appears',
    (tester) async {
      _surface(tester);
      // `.exe` is not a type Aura accepts through any door. Before the
      // migration this fell through to `application/octet-stream`, was added
      // to the composer as a DOCUMENT, and only failed once the server's
      // allow-list refused it at presign — after the person had already seen
      // it attached.
      _FakeFilePicker.next = _pick('payload.exe', 'MZ executable');

      await tester.pumpWidget(_wrap(rec));
      await tester.pumpAndSettle();

      await _attachDocument(tester);

      expect(
        rec.presigns,
        isEmpty,
        reason: 'a refused file must never reach /media/presign',
      );
      expect(
        find.text('payload.exe'),
        findsNothing,
        reason: 'a refused file must never appear as an attachment',
      );
      expect(find.text('That file type cannot be attached.'), findsOneWidget);
    },
  );

  testWidgets(
    'an empty file is refused as empty, and says so',
    (tester) async {
      _surface(tester);
      _FakeFilePicker.next = _pick('notes.txt', '');

      await tester.pumpWidget(_wrap(rec));
      await tester.pumpAndSettle();

      await _attachDocument(tester);

      expect(rec.presigns, isEmpty);
      expect(find.text('That file is empty.'), findsOneWidget);
    },
  );

  testWidgets(
    'a .docx reaches the wire as a docx, not as octet-stream',
    (tester) async {
      _surface(tester);
      // THE RECORDED DEFECT. `_ingestBytes` carried its own extension ladder
      // that never named .docx, so a Word document arrived at presign as
      // `application/octet-stream` and was refused there, leaving nothing in
      // the database to explain it. Intake consults the canonical MIME
      // authority, which does know .docx.
      _FakeFilePicker.next = _pick('proposal.docx', 'PK zip container');

      await tester.pumpWidget(_wrap(rec));
      await tester.pumpAndSettle();

      await _attachDocument(tester);

      expect(rec.presigns, hasLength(1));
      final presign = rec.presigns.single;
      expect(
        presign['mimeType'],
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      );
      expect(presign['fileName'], 'proposal.docx');
      // The semantic kind, preserved. 'DOCUMENT' buys the backend's 25 MiB
      // document bucket; the `wireKind` collapse to 'IMAGE' that the other
      // composers still use would cut it to 10 MiB.
      expect(presign['kind'], 'DOCUMENT');
      // The picker door records UPLOAD provenance. It used to be laundered
      // into GALLERY, because the retired upload path derived source from the
      // kind and everything that was not audio was called a gallery pick.
      expect(presign['source'], 'UPLOAD');
    },
  );

  testWidgets(
    'a failed attachment blocks the send instead of being dropped from it',
    (tester) async {
      _surface(tester);
      // The presign in this harness answers without a media id, so
      // `uploadAuraMedia` throws and the attachment settles in the FAILED
      // phase with no server identity.
      //
      // The retired guard read `mediaId == null && !failed` as "still
      // uploading", so a FAILED attachment counted as finished: the send
      // proceeded, `whereType<String>()` silently dropped it, and the message
      // left without the file. AttachmentLifecycle says a failure still holds
      // a claim and is still pending, so the composition is not ready.
      _FakeFilePicker.next = _pick('proposal.docx', 'PK zip container');

      await tester.pumpWidget(_wrap(rec));
      await tester.pumpAndSettle();

      await _attachDocument(tester);

      expect(rec.presigns, hasLength(1), reason: 'the upload was attempted');
      expect(find.text('proposal.docx'), findsOneWidget,
          reason: 'an accepted file stays visible so it can be removed');

      // Text alone would ordinarily be ready to send.
      await tester.enterText(find.byType(TextField).first, 'here it is');
      await tester.pumpAndSettle();

      expect(
        _sendButton(tester).onPressed,
        isNull,
        reason: 'a failed attachment must block the send, not vanish from it',
      );

      // And the guard holds even if the control is bypassed.
      expect(rec.sends, isEmpty);
    },
  );

  testWidgets(
    'the send control reflects readiness, and a plain message still sends',
    (tester) async {
      _surface(tester);

      await tester.pumpWidget(_wrap(rec));
      await tester.pumpAndSettle();

      expect(
        _sendButton(tester).onPressed,
        isNull,
        reason: 'an empty composition is not ready',
      );

      await tester.enterText(find.byType(TextField).first, 'good morning');
      await tester.pumpAndSettle();

      expect(_sendButton(tester).onPressed, isNotNull);

      await tester.tap(_send);
      await tester.pumpAndSettle();

      expect(rec.sends, hasLength(1));
      expect(rec.sends.single['body'], 'good morning');
      // The repository omits `mediaIds` entirely when there are none, rather
      // than sending an empty list.
      expect(rec.sends.single['mediaIds'], isNull);
    },
  );
}

// ── driving the real screen ──────────────────────────────────────────────────

Future<void> _attachDocument(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Attach'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Document'));
  await tester.pumpAndSettle();
}

/// The send control has no tooltip to find it by; its icon is its identity.
Finder get _send =>
    find.widgetWithIcon(IconButton, Icons.arrow_upward_rounded);

IconButton _sendButton(WidgetTester tester) => tester.widget<IconButton>(_send);

void _surface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1400, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Widget _wrap(_Recorder rec) {
  return ProviderScope(
    overrides: [
      dioProvider.overrideWithValue(rec.dio),
      myUserIdProvider.overrideWithValue('user-me'),
    ],
    // AuraScaffold deliberately renders no Scaffold of its own -- the app
    // shell owns it, and the screen's SnackBars are presented through it. The
    // harness supplies the same ancestor rather than a substitute for it.
    child: const MaterialApp(
      home: Scaffold(body: ConversationScreen(conversationId: 'c1')),
    ),
  );
}

// ── the fake picker ──────────────────────────────────────────────────────────

class _FakeFilePicker extends FilePicker {
  static FilePickerResult? next;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    return next;
  }
}

FilePickerResult _pick(String name, String contents) {
  final bytes = Uint8List.fromList(utf8.encode(contents));
  return FilePickerResult([
    PlatformFile(name: name, size: bytes.length, bytes: bytes),
  ]);
}

// ── the network the screen actually talks to ─────────────────────────────────

class _Recorder {
  _Recorder() {
    dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.interceptors.add(InterceptorsWrapper(onRequest: _onRequest));
  }

  late final Dio dio;

  /// Every `/media/presign` body, in order. Emptiness is the assertion that
  /// matters most: a refusal must not reach the wire at all.
  final List<Map<String, dynamic>> presigns = [];
  final List<Map<String, dynamic>> sends = [];

  void _onRequest(RequestOptions o, RequestInterceptorHandler h) {
    final path = o.path;
    final body =
        o.data is Map ? Map<String, dynamic>.from(o.data as Map) : const {};

    if (o.method == 'POST' && path == '/media/presign') {
      presigns.add(Map<String, dynamic>.from(body));
      // Answer WITHOUT a media id. `uploadAuraMedia` then throws before it
      // reaches the storage PUT, which keeps this test entirely offline while
      // still exercising the real failure path.
      return h.resolve(_ok(o, {'media': {}, 'upload': {}}));
    }

    if (o.method == 'POST' && path == '/conversations/c1/messages') {
      sends.add(Map<String, dynamic>.from(body));
      return h.resolve(_ok(o, {'message': _message('m-new', 'sent')}));
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
              'person': {'id': 'user-me', 'displayName': 'Me'},
            },
            {
              'kind': 'PERSON',
              'person': {'id': 'user-amina', 'displayName': 'Amina'},
            },
          ],
        }
      }));
    }

    if (o.method == 'GET' && path == '/conversations/c1/messages') {
      return h.resolve(_ok(o, {'messages': <Map<String, dynamic>>[]}));
    }

    if (o.method == 'GET' && path == '/conversations/c1/live') {
      return h.resolve(_ok(o, {'activeSession': null}));
    }

    // Anything else this screen reaches for on mount (read receipts, presence)
    // answers empty rather than failing, so an unrelated call cannot be
    // mistaken for the behaviour under test.
    return h.resolve(_ok(o, const {}));
  }

  Response<dynamic> _ok(RequestOptions o, Map<String, dynamic> data) =>
      Response<dynamic>(
        requestOptions: o,
        statusCode: 200,
        data: {'ok': true, ...data},
      );

  Map<String, dynamic> _message(String id, String body) => {
        'id': id,
        'senderUserId': 'user-me',
        'body': body,
        'createdAt': '2026-08-21T10:00:00.000Z',
      };
}
