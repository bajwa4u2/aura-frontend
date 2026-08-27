// F125 / F011 — CONVERSATION ATTACHMENTS ARE WIRED TO THE CANONICAL SURFACES.
//
// F125, verbatim: "Conversation images have no viewer and no save: not
// tappable, no fullscreen, no save affordance — while every other surface
// routes through AuraMediaViewer/MediaSaveService."
//
// That is the whole defect: Conversation was the one surface that opted out.
// The fix is not a bespoke viewer for Conversation — it is routing Conversation
// into the same canonical viewer everything else already uses, which brings
// fullscreen and save with it.
//
// These are source assertions because the alternative proves less: a widget
// test could show that a tap handler exists, but only reading the call site
// shows it reaches the CANONICAL viewer rather than a second one built here.
// A second viewer would satisfy a behavioural test and reintroduce the defect.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String kConversation =
    'lib/features/conversation/presentation/conversation_screen.dart';

String _attachmentRenderer() {
  final src = File(kConversation).readAsStringSync();
  final start = src.indexOf('class _ConversationAttachment');
  expect(start, isNot(-1), reason: 'the conversation attachment renderer must exist');

  // The end of the renderer is simply the next top-level declaration.
  //
  // This used to be pinned to `class _MediaPlayback` — the private inline
  // player that lived directly below. That player has been RETIRED: inline
  // video is now the shared stored-media authority's job, and Conversation
  // consumes it like every other surface. Pinning the bound to a neighbour
  // made these assertions fail for a reason that had nothing to do with what
  // they assert, so the bound now follows the file's structure instead.
  final match = RegExp(r'^(class|final|enum|mixin|extension|typedef|abstract)\s',
          multiLine: true)
      .allMatches(src, start)
      .firstWhere((m) => m.start > start,
          orElse: () => throw StateError('no declaration follows the renderer'));
  final end = match.start;
  expect(end, greaterThan(start),
      reason: 'could not bound the attachment renderer');
  return src.substring(start, end);
}

void main() {
  group('F125 — images reach the canonical viewer, not a local one', () {
    test('the renderer opens showAuraMediaViewer', () {
      final src = _attachmentRenderer();
      expect(src.contains('showAuraMediaViewer'), isTrue,
          reason: 'Conversation was the one surface that opted out of the '
              'canonical viewer. Routing back into it is the fix.');
    });

    test('images are tappable', () {
      final src = _attachmentRenderer();
      expect(RegExp(r'onTap:').hasMatch(src), isTrue,
          reason: 'F125: "not tappable" was the first of the three missing '
              'affordances.');
    });

    test('it passes the canonical mediaId so gated media resolves a fresh URL', () {
      final src = _attachmentRenderer();
      expect(RegExp(r'mediaId:\s*media\.mediaId').hasMatch(src), isTrue,
          reason: 'Without the media id the viewer cannot resolve a signed URL '
              'for gated media, and save would fail on exactly the files that '
              'need it most.');
    });

    test('it does NOT build a second viewer inside Conversation', () {
      // The defect was Conversation being special. A local fullscreen route
      // would pass a behavioural test and recreate it.
      final src = _attachmentRenderer();
      for (final forbidden in const [
        'Navigator.push',
        'showDialog(',
        'InteractiveViewer(',
      ]) {
        expect(src.contains(forbidden), isFalse,
            reason: 'Conversation must consume the canonical viewer, not '
                'reimplement one ($forbidden).');
      }
    });
  });

  group('F011 — the generic pill is gone', () {
    test('the renderer no longer emits a bare "Attachment" label', () {
      final src = _attachmentRenderer();
      expect(src.contains("_fileChip('Attachment')"), isFalse,
          reason: 'A PDF, a spreadsheet, a deck and a zip were once '
              'indistinguishable from each other and from failure.');
    });

    test('it renders the kind-aware card instead', () {
      final src = _attachmentRenderer();
      expect(src.contains('AuraAttachmentCard'), isTrue);
      expect(src.contains('attachmentKindFrom'), isTrue);
    });

    test('the card is given the file identity the backend now sends', () {
      final src = _attachmentRenderer();
      expect(src.contains('media.fileName'), isTrue);
      expect(src.contains('media.fileSizeBytes'), isTrue);
    });

    test('non-renderable kinds get an open action', () {
      final src = _attachmentRenderer();
      expect(src.contains('openAuraAttachment'), isTrue,
          reason: 'The old chip had no action at all.');
    });

    test('the unavailable state keeps identity instead of degrading', () {
      final src = _attachmentRenderer();
      expect(src.contains('unavailableReason'), isTrue,
          reason: 'Failure used the SAME chip as a document, so a person could '
              'not tell a missing file from a supported one.');
    });
  });
}
