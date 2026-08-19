// F011 — ATTACHMENT PRESENTATION TRUTH.
//
// The defect: every attachment that was not an image, a voice note or a video
// rendered as a grey pill reading the literal word "Attachment" — no name, no
// type, no size, no action. A PDF, a spreadsheet, a deck and a zip were
// indistinguishable from each other and from a failure state.
//
// The backend already knew what each file was; content truth resolves the real
// type from the bytes. F011 is the presentation half: the resolved kind must
// be presented honestly, with the actions appropriate to that kind.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/media/aura_attachment_card.dart';

void main() {
  group('F011 — kind resolves from the RESOLVED mime, not a claim', () {
    test('distinguishes every document family the MIME matrix permits', () {
      // The coarse canonical kind cannot do this: a PDF and a zip are both
      // OTHER. That collapse is precisely why one pill served them all.
      expect(attachmentKindFrom(mimeType: 'application/pdf'),
          AttachmentPresentationKind.pdf);
      expect(
          attachmentKindFrom(
              mimeType:
                  'application/vnd.openxmlformats-officedocument.wordprocessingml.document'),
          AttachmentPresentationKind.document);
      expect(
          attachmentKindFrom(
              mimeType:
                  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'),
          AttachmentPresentationKind.spreadsheet);
      expect(
          attachmentKindFrom(
              mimeType:
                  'application/vnd.openxmlformats-officedocument.presentationml.presentation'),
          AttachmentPresentationKind.presentation);
      expect(attachmentKindFrom(mimeType: 'application/zip'),
          AttachmentPresentationKind.archive);
      expect(attachmentKindFrom(mimeType: 'text/csv'),
          AttachmentPresentationKind.text);
    });

    test('the MIME wins over the coarse canonical kind', () {
      // Content truth may have CORRECTED a mislabelled file. The corrected
      // mime is the truth; deferring to the coarse enum would undo it.
      expect(
        attachmentKindFrom(mimeType: 'application/pdf', canonicalKind: 'OTHER'),
        AttachmentPresentationKind.pdf,
      );
    });

    test('falls back to the coarse kind only when the mime says nothing', () {
      expect(attachmentKindFrom(mimeType: null, canonicalKind: 'IMAGE'),
          AttachmentPresentationKind.image);
      expect(attachmentKindFrom(mimeType: '', canonicalKind: 'AUDIO'),
          AttachmentPresentationKind.audio);
    });

    test('an unrecognised type is "File", never a confident wrong label', () {
      final k = attachmentKindFrom(mimeType: 'application/x-unknown-thing');
      expect(k, AttachmentPresentationKind.unknown);
      // "File" states that we do not recognise the kind. "Attachment" stated
      // nothing at all.
      expect(k.label, 'File');
    });
  });

  group('F011 — the action offered must be honest', () {
    test('an archive offers Download, not Open', () {
      // Nothing in-app can open a zip. Offering "Open" would be a false offer.
      expect(AttachmentPresentationKind.archive.actionLabel, 'Download');
      expect(AttachmentPresentationKind.unknown.actionLabel, 'Download');
    });

    test('a document offers Open', () {
      expect(AttachmentPresentationKind.pdf.actionLabel, 'Open');
      expect(AttachmentPresentationKind.spreadsheet.actionLabel, 'Open');
    });
  });

  group('F011 — size is stated or omitted, never faked', () {
    test('formats real sizes readably', () {
      expect(humanFileSize(900), '900 B');
      expect(humanFileSize(2048), '2.0 KB');
      expect(humanFileSize(5 * 1024 * 1024), '5.0 MB');
    });

    test('returns null when the size is unknown rather than printing 0 B', () {
      expect(humanFileSize(null), isNull);
      expect(humanFileSize(0), isNull);
      expect(humanFileSize(-1), isNull);
    });
  });

  group('F011 — the card carries real identity', () {
    Future<void> pump(WidgetTester tester, Widget child) =>
        tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));

    testWidgets('shows the file name, kind and size', (tester) async {
      await pump(
        tester,
        AuraAttachmentCard(
          kind: AttachmentPresentationKind.pdf,
          fileName: 'Q3-board-pack.pdf',
          sizeBytes: 2 * 1024 * 1024,
          onOpen: () {},
        ),
      );
      expect(find.text('Q3-board-pack.pdf'), findsOneWidget);
      expect(find.textContaining('PDF document'), findsOneWidget);
      expect(find.textContaining('2.0 MB'), findsOneWidget);
      expect(find.text('Open'), findsOneWidget);
      // The word that used to be the entire experience must be gone.
      expect(find.text('Attachment'), findsNothing);
    });

    testWidgets('the card is tappable and opens', (tester) async {
      var opened = false;
      await pump(
        tester,
        AuraAttachmentCard(
          kind: AttachmentPresentationKind.pdf,
          fileName: 'notes.pdf',
          onOpen: () => opened = true,
        ),
      );
      await tester.tap(find.byType(AuraAttachmentCard));
      await tester.pump();
      expect(opened, isTrue, reason: 'the old chip had no tap target at all');
    });

    testWidgets('falls back to the kind when a name is genuinely absent',
        (tester) async {
      await pump(
        tester,
        const AuraAttachmentCard(
          kind: AttachmentPresentationKind.spreadsheet,
          fileName: '',
        ),
      );
      expect(find.text('Spreadsheet'), findsWidgets);
    });

    testWidgets('offers NO action when the file cannot be opened',
        (tester) async {
      // A button that does nothing is worse than no button.
      await pump(
        tester,
        const AuraAttachmentCard(
          kind: AttachmentPresentationKind.pdf,
          fileName: 'gone.pdf',
        ),
      );
      expect(find.text('Open'), findsNothing);
    });

    testWidgets('states unavailability instead of offering a failing action',
        (tester) async {
      await pump(
        tester,
        AuraAttachmentCard(
          kind: AttachmentPresentationKind.pdf,
          fileName: 'gone.pdf',
          sizeBytes: 1024,
          onOpen: () {},
          unavailableReason: 'Unavailable',
        ),
      );
      expect(find.textContaining('Unavailable'), findsOneWidget);
      expect(find.text('Open'), findsNothing);
      // Identity survives the failure — the person still knows what is missing.
      expect(find.text('gone.pdf'), findsOneWidget);
    });
  });
}
