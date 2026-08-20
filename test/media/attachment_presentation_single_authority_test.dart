// RICH-CONTENT DOCTRINE — ONE PRESENTATION RESOLVER, NOT ONE PER DESTINATION.
//
// Founder direction: "Support extensible content handlers/resolvers rather
// than allowing destination-specific MIME/category switches to become the
// architecture." And: "Conversation is a proving/reference surface, not the
// owner of the capability."
//
// The product had THREE answers to one question — "what is this file, and how
// should it be presented?":
//
//   1. kindFromMime -> AttachmentKind — coarse, four kinds, everything
//      non-media collapsing into `document`;
//   2. a private substring-matching switch inside the Correspondence document
//      surface (`lower.contains('spreadsheet')` and friends);
//   3. attachmentKindFrom -> AttachmentPresentationKind — the canonical one.
//
// Three switches drift. The Correspondence one had no ARCHIVE kind at all, so
// a zip fell through to a generic "File" with a document icon and an Open
// action nothing could honour.
//
// This gate keeps presentation resolution single-sited. It does NOT forbid
// kindFromMime: that answers a DIFFERENT question — which allow-list applies
// at acquisition — and the two stages of the lifecycle keep their own
// vocabularies deliberately.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/media/aura_attachment_card.dart';

/// The canonical resolver's home.
const String kResolver = 'lib/core/media/aura_attachment_card.dart';

/// Destinations that present attachments.
///
/// The correspondence thread tile was removed from this list when CO-RC-C7-005
/// Phase 5 retired that runtime (2026-08-20). One destination remains, and that
/// is the point of the retirement rather than a weakening of this gate: there
/// is now one attachment presentation surface in the product, so the rule this
/// file enforces has one place left to be broken.
const List<String> kDestinations = [
  'lib/features/conversation/presentation/conversation_screen.dart',
];

/// Substring-matching on a MIME to decide PRESENTATION. This is the shape a
/// private switch takes when it re-grows in a destination.
final _privateMimeSwitch = RegExp(
  r"\.contains\(\s*'(?:spreadsheet|presentation|powerpoint|excel|wordprocessingml|msword|zip)'",
);

List<File> _libFiles() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList();

String _rel(File f) => f.path.replaceAll('\\', '/');

void main() {
  group('one presentation resolver', () {
    test('no destination re-implements MIME-to-presentation dispatch', () {
      final offenders = <String>[];
      for (final f in _libFiles()) {
        final path = _rel(f);
        if (path == kResolver) continue;
        final lines = f.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (line.trimLeft().startsWith('//') || line.trimLeft().startsWith('///')) continue;
          if (_privateMimeSwitch.hasMatch(line)) {
            offenders.add('$path:${i + 1}  ${line.trim()}');
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: '\n[RICH CONTENT] A destination is deciding presentation from '
            'a MIME substring:\n${offenders.map((o) => '  $o').join('\n')}\n\n'
            'Use attachmentKindFrom(). Three switches for one question is how '
            'destination-specific dispatch becomes the architecture.\n',
      );
    });

    test('every attachment destination consumes the canonical resolver', () {
      for (final d in kDestinations) {
        final src = File(d).readAsStringSync();
        expect(src.contains('attachmentKindFrom'), isTrue,
            reason: '$d presents attachments but does not consume the '
                'canonical presentation resolver.');
      }
    });

    test('no destination shows a person a raw MIME string', () {
      // A person should never read
      // `application/vnd.openxmlformats-officedocument.presentationml.presentation`
      // to learn they were sent a slide deck.
      for (final d in kDestinations) {
        final lines = File(d).readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final l = lines[i];
          if (l.trimLeft().startsWith('//')) continue;
          expect(RegExp(r'if \(mimeType\.isNotEmpty\) mimeType,').hasMatch(l), isFalse,
              reason: '$d:${i + 1} renders the raw mime as product copy.');
        }
      }
    });
  });

  group('the resolver covers what the MIME matrix permits', () {
    test('every permitted attachment class resolves to a distinct kind', () {
      // The canonical matrix has IMAGE, VIDEO, AUDIO, DOCUMENT and ARCHIVE
      // classes. A resolver that collapses any of them re-creates the defect.
      final kinds = <AttachmentPresentationKind>{
        attachmentKindFrom(mimeType: 'image/png'),
        attachmentKindFrom(mimeType: 'video/mp4'),
        attachmentKindFrom(mimeType: 'audio/mpeg'),
        attachmentKindFrom(mimeType: 'application/pdf'),
        attachmentKindFrom(mimeType: 'application/zip'),
      };
      expect(kinds.length, 5,
          reason: 'Each permitted class must be distinguishable.');
    });

    test('an archive is never presented as a document', () {
      // The specific gap the Correspondence switch had.
      expect(attachmentKindFrom(mimeType: 'application/zip'),
          AttachmentPresentationKind.archive);
      expect(attachmentKindFrom(mimeType: 'application/x-zip-compressed'),
          AttachmentPresentationKind.archive);
    });
  });
}
