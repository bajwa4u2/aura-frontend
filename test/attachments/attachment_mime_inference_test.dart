import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/media/attachment.dart';
import 'package:aura/core/media/media_mime.dart';

/// THE DOCX FAILURE OF 2026-08-20.
///
/// A DOCX attached through Messages failed in production and left **no Media
/// row at all** — the request never reached examination, or even row creation.
///
/// The conversation screen carried its own inline extension ladder covering
/// png, jpg, gif, webp, mp4, webm, mp3 and pdf, with everything else falling
/// through to `application/octet-stream`. The server's allow-list refuses that
/// at presign, before a row exists, which is why the database showed nothing
/// and why a PDF worked while a DOCX did not: `.pdf` happened to be named in
/// the ladder and `.docx` did not.
///
/// `inferMimeFromFileName` already knew every one of these, and its own
/// docstring records that it was extracted to replace exactly such duplicates.
/// That call site had never been migrated.
///
/// These assert the canonical authority covers the whole accepted surface, so
/// the next format added to the allow-list cannot quietly lose its mapping.
void main() {
  group('every accepted document format infers its real type', () {
    const cases = <String, String>{
      'report.pdf': 'application/pdf',
      'notes.doc': 'application/msword',
      'notes.docx':
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'sheet.xls': 'application/vnd.ms-excel',
      'sheet.xlsx':
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'deck.ppt': 'application/vnd.ms-powerpoint',
      'deck.pptx':
          'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'letter.rtf': 'application/rtf',
      'plain.txt': 'text/plain',
      'rows.csv': 'text/csv',
      'bundle.zip': 'application/zip',
    };

    cases.forEach((fileName, expected) {
      test('$fileName is not sent as octet-stream', () {
        final mime = inferMimeFromFileName(fileName);
        expect(mime, expected);
        // The specific failure: anything unmapped became octet-stream and was
        // refused at presign before a Media row existed.
        expect(mime, isNot('application/octet-stream'));
      });
    });

    test('every allowed document MIME is reachable from some extension', () {
      // Guards the direction that actually broke: a format on the allow-list
      // that no filename can produce is unusable in practice, however correct
      // the server is.
      final reachable = <String>{
        for (final name in cases.keys) inferMimeFromFileName(name)!,
      };
      // `application/x-zip-compressed` is a Windows-supplied ALIAS for a ZIP.
      // It is accepted for interoperability when an OS reports it, and no
      // filename produces it, so it is excluded by name rather than by
      // loosening the check.
      const osSuppliedAliases = {'application/x-zip-compressed'};
      final unreachable = kAllowedDocumentMimes
          .where((m) => !reachable.contains(m) && !osSuppliedAliases.contains(m))
          .toList();
      expect(unreachable, isEmpty);
    });
  });

  group('kind derives from the resolved type', () {
    test('documents are DOCUMENT, not IMAGE', () {
      // The size bucket is chosen from `kind`. Sending a document as IMAGE
      // would validate a 25 MB-eligible file against the 10 MB image limit.
      for (final mime in kAllowedDocumentMimes) {
        expect(kindFromMime(mime), AttachmentKind.document, reason: mime);
      }
    });

    test('media families keep their own kinds', () {
      expect(kindFromMime('image/png'), AttachmentKind.image);
      expect(kindFromMime('video/mp4'), AttachmentKind.video);
      expect(kindFromMime('audio/mpeg'), AttachmentKind.audio);
    });
  });

  group('the EICAR test artifact must be nameable', () {
    test('a .txt carrier resolves to an accepted type', () {
      // The malicious-content proof needs the file to REACH examination. Named
      // `eicar.com` it resolves to nothing, is refused at presign as an
      // unsupported type, and never meets the scanner — a refusal at the wrong
      // layer, which proves nothing about malware detection.
      expect(inferMimeFromFileName('eicar.txt'), 'text/plain');
      expect(kAllowedDocumentMimes.contains('text/plain'), isTrue);
      expect(inferMimeFromFileName('eicar.com'), isNull);
    });
  });
}
