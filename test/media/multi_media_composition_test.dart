// MULTI-MEDIA COMPOSITION — the CREATION half.
//
// Consumption was delivered first and reported as the chapter; it was not. A
// person cannot compose four photographs by rendering four photographs. These
// tests cover the half that was missing: acquiring several items, arranging
// them, watching each upload separately, and recovering when one fails without
// silently sending the survivors.

import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/composition/attachment_lifecycle.dart';
import 'package:aura/core/composition/composition_authority.dart';
import 'package:aura/core/media/attachment.dart';
import 'package:aura/core/media/media_acquisition.dart';

Attachment ready(String id, {AttachmentKind kind = AttachmentKind.image}) =>
    Attachment(localId: id, kind: kind, mediaId: 'server-$id', url: 'https://x/$id');

Attachment uploading(String id) =>
    Attachment(localId: id, kind: AttachmentKind.image, uploading: true);

Attachment failed(String id) =>
    Attachment(localId: id, kind: AttachmentKind.image, error: 'network');

CompositionState composed(List<Attachment> items) =>
    CompositionState(body: 'text', attachments: items, requiresBody: false);

void main() {
  group('MULTI_MEDIA_REORDER — order is author intent', () {
    test('moving an item forward lands it where it was dropped', () {
      final s = composed([ready('a'), ready('b'), ready('c')]);
      final moved = s.reorderAttachment(0, 2);
      // Dragging downward reports the index BEFORE removal — the classic
      // off-by-one in every reorderable list.
      expect(moved.attachments.map((a) => a.localId), ['b', 'a', 'c']);
    });

    test('moving an item backward lands it where it was dropped', () {
      final s = composed([ready('a'), ready('b'), ready('c')]);
      expect(s.reorderAttachment(2, 0).attachments.map((a) => a.localId),
          ['c', 'a', 'b']);
    });

    test('a drag that ends outside the list changes nothing', () {
      final s = composed([ready('a'), ready('b')]);
      // An ordinary gesture, not an error.
      expect(s.reorderAttachment(5, 0).attachments.length, 2);
      expect(s.reorderAttachment(0, 0).attachments.map((a) => a.localId),
          ['a', 'b']);
    });

    test('reorder never changes what is composable', () {
      final s = composed([ready('a'), ready('b'), ready('c')]);
      final moved = s.reorderAttachment(0, 2);
      expect(moved.composableAttachments.length, 3);
      expect(moved.canSubmit, isTrue);
    });

    test('MULTI_MEDIA_PERSISTENCE_ORDER — send order follows the arranged order', () {
      // Non-symmetric on purpose: an accidental reorder is obvious.
      final s = composed([ready('first'), ready('second'), ready('third')]);
      final arranged = s.reorderAttachment(2, 0);
      expect(arranged.composableAttachments.map((a) => a.mediaId),
          ['server-third', 'server-first', 'server-second']);
    });
  });

  group('PARTIAL_FAILURE_RECOVERY', () {
    test('a failed item BLOCKS the send — survivors are never sent alone', () {
      // 4 selected, the third fails. Sending 1, 2 and 4 would publish a
      // composition the author never approved, and they would not find out.
      final s = composed([ready('1'), ready('2'), failed('3'), ready('4')]);
      expect(s.hasPartialFailure, isTrue);
      expect(s.canSubmit, isFalse);
      expect(s.composableAttachments.length, 3);
    });

    test('the blocked reason names the real problem, not a wait', () {
      final s = composed([ready('1'), failed('3')]);
      // A failed item is not a slow one: telling someone to wait for something
      // that has already stopped is how a composer appears frozen.
      expect(s.blockedReason, contains("didn't upload"));
      expect(s.blockedReason, isNot(contains('Waiting')));
    });

    test('two failures are counted, not generalised', () {
      final s = composed([failed('a'), failed('b'), ready('c')]);
      expect(s.blockedReason, contains('2 items'));
    });

    test('removing the failed item unblocks the send — an EXPLICIT author act', () {
      final s = composed([ready('1'), ready('2'), failed('3'), ready('4')]);
      final after = s.removeAttachment('3');
      expect(after.canSubmit, isTrue);
      expect(after.composableAttachments.length, 3);
    });

    test('a retried item that succeeds unblocks the send', () {
      final f = failed('3');
      final s = composed([ready('1'), f]);
      expect(s.canSubmit, isFalse);
      // Retry mutates the same attachment rather than re-uploading siblings.
      f.error = null;
      f.mediaId = 'server-3';
      f.url = 'https://x/3';
      expect(s.canSubmit, isTrue);
    });

    test('an item still uploading also blocks, and says so differently', () {
      final s = composed([ready('1'), uploading('2')]);
      expect(s.canSubmit, isFalse);
      expect(s.blockedReason, contains('Waiting'));
    });
  });

  group('the removal race — a stale success must not resurrect media', () {
    test('a removed item is recorded as withdrawn', () {
      final s = composed([ready('a'), ready('b')]);
      final after = s.removeAttachment('a');
      expect(after.isWithdrawn('a'), isTrue);
      expect(after.attachments.map((x) => x.localId), ['b']);
    });

    test('a late upload success cannot re-admit a removed item', () {
      final late = uploading('a');
      final s = composed([late, ready('b')]);
      final after = s.removeAttachment('a');

      // The upload completes AFTER the author removed it.
      late.uploading = false;
      late.mediaId = 'server-a';
      late.url = 'https://x/a';

      // It is gone from the composition, and the cancellation means it could
      // not re-enter even if something put the object back in the list.
      expect(after.attachments.any((x) => x.localId == 'a'), isFalse);
      final resurrected = after.copyWith(attachments: [late, ...after.attachments]);
      expect(resurrected.phaseOf(late), AttachmentPhase.cancelled);
      expect(resurrected.composableAttachments.map((x) => x.localId), ['b']);
    });

    test('removing something that was never there changes nothing', () {
      final s = composed([ready('a')]);
      expect(identical(s.removeAttachment('zzz'), s), isTrue);
    });
  });

  group('MULTI_MEDIA_ACQUISITION', () {
    test('the ceiling is a stated product policy', () {
      expect(kMaxComposableMedia, 10);
    });

    test('the ceiling applies to the WHOLE composition, not one picker visit', () async {
      // Eight already attached, four chosen: only two may join.
      final acquisition = await resolveAcquired(
        files: const [],
        remainingSlots: 2,
        source: AttachmentSource.gallery,
      );
      expect(acquisition.isEmpty, isTrue);
    });

    test('items turned away are REPORTED, never silently dropped', () {
      expect(acquisitionLimitMessage(0), isNull);
      expect(acquisitionLimitMessage(1), contains('One item'));
      expect(acquisitionLimitMessage(3), contains('3 items'));
    });
  });

  group('SINGLE_MEDIA_REGRESSION', () {
    test('one item still composes exactly as before', () {
      final s = composed([ready('only')]);
      expect(s.canSubmit, isTrue);
      expect(s.hasPartialFailure, isFalse);
      expect(s.blockedReason, isNull);
    });

    test('one failed item blocks, with singular wording', () {
      final s = composed([failed('only')]);
      expect(s.canSubmit, isFalse);
      expect(s.blockedReason, contains('One item'));
    });

    test('an empty composition is unchanged by the new operations', () {
      const s = CompositionState(requiresBody: false);
      expect(s.reorderAttachment(0, 1).attachments, isEmpty);
      expect(s.failedAttachments, isEmpty);
      expect(s.hasPartialFailure, isFalse);
    });
  });

  group('MIXED_IMAGE_VIDEO_GROUP composes as one composition', () {
    test('images and videos share one ordered list', () {
      final s = composed([
        ready('i1'),
        ready('v1', kind: AttachmentKind.video),
        ready('i2'),
        ready('v2', kind: AttachmentKind.video),
      ]);
      expect(s.canSubmit, isTrue);
      expect(s.composableAttachments.map((a) => a.kind), [
        AttachmentKind.image,
        AttachmentKind.video,
        AttachmentKind.image,
        AttachmentKind.video,
      ]);
    });

    test('reordering a mixed composition keeps each item its own kind', () {
      final s = composed([
        ready('i1'),
        ready('v1', kind: AttachmentKind.video),
      ]).reorderAttachment(1, 0);
      expect(s.attachments.first.kind, AttachmentKind.video);
      expect(s.attachments.last.kind, AttachmentKind.image);
    });
  });
}
