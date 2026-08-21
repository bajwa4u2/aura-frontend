// CH-13 WAVE 1 — the six VALIDATION_OR_GATE_ONLY obligations, as proof.
//
// CO-RC-C5-018 backend contracts · CO-RC-C5-021 drafts and draft data ·
// CO-RC-C5-022 proven validation · CO-RC-C5-023 accessibility behaviour ·
// CO-RC-C5-024 legitimate context differences · CO-RC-C5-025 working media
// rendering.
//
// These ship WITH the authority they protect — there is no standalone
// enforcement chapter. Each group below names the obligation it discharges and
// seeds the failure it exists to catch, because a gate that has never failed is
// a gate nobody has tested.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/composition/attachment_lifecycle.dart';
import 'package:aura/core/composition/composition_authority.dart';
import 'package:aura/core/composition/content_intake.dart';
import 'package:aura/core/content_policy/content_length_policy.dart';
import 'package:aura/core/media/attachment.dart';
import 'package:image_picker/image_picker.dart' show XFile;

Attachment _att({
  String id = 'a1',
  AttachmentKind kind = AttachmentKind.image,
  String? mediaId,
  bool uploading = false,
  String? error,
  Uint8List? bytes,
}) {
  return Attachment(
    localId: id,
    kind: kind,
    mediaId: mediaId,
    uploading: uploading,
    error: error,
    bytes: bytes,
  );
}

final _png = Uint8List.fromList(<int>[0x89, 0x50, 0x4E, 0x47, 1, 2, 3]);

void main() {
  // ── CO-RC-C5-022 — PROVEN VALIDATION ──────────────────────────────────────
  group('CO-RC-C5-022 · validation is proven, not asserted', () {
    test('an unknown type is refused rather than defaulted', () {
      final r = ContentIntake.resolveBytes(
        path: IntakePath.paste,
        bytes: _png,
        fileName: 'mystery.zzz',
        declaredMimeType: null,
      );
      expect(r.isAccepted, isFalse);
      expect(r.rejection, AttachmentRejection.unsupportedType);
    });

    test('octet-stream is treated as ABSENT evidence, not as a type', () {
      // The whole point: a source that says octet-stream is saying "I do not
      // know". Accepting it lets unknown pass as fine — the F127 shape.
      final r = ContentIntake.resolveBytes(
        path: IntakePath.picker,
        bytes: _png,
        fileName: 'photo.png',
        declaredMimeType: 'application/octet-stream',
      );
      expect(r.isAccepted, isTrue, reason: 'the filename still carries evidence');
      expect(r.attachment!.mimeType, 'image/png');
    });

    test('octet-stream with NO filename evidence is refused', () {
      final r = ContentIntake.resolveBytes(
        path: IntakePath.drop,
        bytes: _png,
        fileName: null,
        declaredMimeType: 'application/octet-stream',
      );
      expect(r.isAccepted, isFalse);
      expect(r.rejection, AttachmentRejection.unsupportedType);
    });

    test('empty bytes are refused before any type question is asked', () {
      final r = ContentIntake.resolveBytes(
        path: IntakePath.picker,
        bytes: Uint8List(0),
        fileName: 'photo.png',
        declaredMimeType: 'image/png',
      );
      expect(r.rejection, AttachmentRejection.empty);
    });

    test('over-length blocks submission', () {
      final state = CompositionState(
        body: 'x' * (ContentLengthPolicy.message + 1),
        maxLength: ContentLengthPolicy.message,
      );
      expect(state.isOverLength, isTrue);
      expect(state.canSubmit, isFalse);
    });

    test('length is measured in grapheme clusters, as TextField measures it', () {
      // A family emoji is one character to a person and several code units to
      // Dart. Measuring differently from the field the person types into is how
      // a composer refuses text that looks well within the limit.
      const family = '\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}';
      final state = CompositionState(body: family * 3, maxLength: 3);
      expect(state.isOverLength, isFalse);
      expect(CompositionState(body: family * 4, maxLength: 3).isOverLength, isTrue);
    });
  });

  // ── CO-RC-C5-011 — the lifecycle itself ───────────────────────────────────
  group('CO-RC-C5-011 · phase is DERIVED, so it cannot drift', () {
    test('server identity — not a cleared flag — is what makes it ready', () {
      // The defect this exists to stop: `uploading == false` proves the attempt
      // STOPPED, never that it succeeded.
      expect(
        AttachmentLifecycle.phaseOf(_att(uploading: false)),
        isNot(AttachmentPhase.ready),
      );
      expect(
        AttachmentLifecycle.phaseOf(_att(mediaId: 'm1')),
        AttachmentPhase.ready,
      );
    });

    test('a stale error beside real identity does not un-ready it', () {
      expect(
        AttachmentLifecycle.phaseOf(_att(mediaId: 'm1', error: 'timeout')),
        AttachmentPhase.ready,
      );
    });

    test('failure is retryable; refusal never is', () {
      expect(AttachmentLifecycle.isRetryable(AttachmentPhase.failed), isTrue);
      expect(AttachmentLifecycle.isRetryable(AttachmentPhase.rejected), isFalse);
    });

    test('only ready is composable', () {
      for (final phase in AttachmentPhase.values) {
        expect(
          AttachmentLifecycle.isComposable(phase),
          phase == AttachmentPhase.ready,
          reason: '$phase must not be sendable unless it is ready',
        );
      }
    });

    test('terminal-by-refusal and terminal-by-intent hold no claim', () {
      expect(AttachmentLifecycle.holdsClaim(AttachmentPhase.rejected), isFalse);
      expect(AttachmentLifecycle.holdsClaim(AttachmentPhase.cancelled), isFalse);
      expect(AttachmentLifecycle.holdsClaim(AttachmentPhase.failed), isTrue);
    });
  });

  // ── CO-RC-C5-010 — readiness, one derivation ──────────────────────────────
  group('CO-RC-C5-010 · readiness is decided once', () {
    test('an in-flight attachment blocks send', () {
      final state = CompositionState(
        body: 'hello',
        attachments: <Attachment>[_att(uploading: true)],
      );
      expect(state.canSubmit, isFalse);
      expect(state.blockedReason, contains('attachments'));
    });

    test('a REJECTED attachment does not block send forever', () {
      // The mirror defect: a refusal left in the list disabling Send for good.
      final state = CompositionState(
        body: 'hello',
        attachments: <Attachment>[_att(id: 'bad')],
        rejections: <String, AttachmentRejection>{
          'bad': AttachmentRejection.unsupportedType,
        },
      );
      expect(state.canSubmit, isTrue);
      expect(state.liveAttachments, isEmpty);
    });

    test('an attachment-only composition is sendable', () {
      final state = CompositionState(
        attachments: <Attachment>[_att(mediaId: 'm1')],
      );
      expect(state.canSubmit, isTrue);
    });

    test('submitting blocks a second submit', () {
      const state = CompositionState(body: 'hi', isSubmitting: true);
      expect(state.canSubmit, isFalse);
    });

    test('an empty composition is not sendable', () {
      expect(const CompositionState().canSubmit, isFalse);
      expect(const CompositionState(body: '   ').canSubmit, isFalse);
    });
  });

  // ── CO-RC-C5-024 — LEGITIMATE CONTEXT DIFFERENCES ─────────────────────────
  group('CO-RC-C5-024 · context differences are expressed, not hard-coded', () {
    test('a body-less surface may submit with no text', () {
      final voice = CompositionState(
        requiresBody: false,
        attachments: <Attachment>[
          _att(kind: AttachmentKind.audio, mediaId: 'm1'),
        ],
      );
      expect(voice.canSubmit, isTrue);
    });

    test('surfaces carry their own limit rather than a shared constant', () {
      const post = CompositionState(body: 'x', maxLength: ContentLengthPolicy.post);
      const msg = CompositionState(body: 'x', maxLength: ContentLengthPolicy.message);
      expect(post.maxLength, isNot(msg.maxLength));
    });
  });

  // ── CO-RC-C5-021 — DRAFTS AND DRAFT DATA (and CO-RC-C5-007) ───────────────
  group('CO-RC-C5-021 · drafts, and the claim CO-RC-C5-007 turns on', () {
    test('dirtiness is derived from saved-vs-current, never from a flag', () {
      const fresh = CompositionState();
      expect(fresh.isDirty, isFalse);

      const typed = CompositionState(body: 'hello');
      expect(typed.isDirty, isTrue, reason: 'never saved, has content');

      const saved = CompositionState(body: 'hello', savedBody: 'hello');
      expect(saved.isDirty, isFalse);

      const edited = CompositionState(body: 'hello!', savedBody: 'hello');
      expect(edited.isDirty, isTrue);
    });

    test('autosave never writes underneath a submit', () {
      const policy = AutosavePolicy();
      const submitting = CompositionState(body: 'hi', isSubmitting: true);
      expect(policy.shouldSave(submitting), isFalse);
      expect(policy.shouldSave(const CompositionState(body: 'hi')), isTrue);
    });

    test('CLIENT-ONLY recoverable media is REPORTED, not silently tolerated', () {
      // CO-RC-C5-007. The backend refuses to reclaim anything a reference
      // covers; a client-only draft asserts no reference, so its uploaded media
      // is reclaimable. The authority names that rather than hiding it.
      final unprotected = CompositionState(
        body: 'draft',
        attachments: <Attachment>[_att(mediaId: 'm1')],
        draftClaim: DraftClaim.clientOnly,
      );
      expect(unprotected.hasUnprotectedRecoverableMedia, isTrue);

      final held = unprotected.copyWith(draftClaim: DraftClaim.serverHeld);
      expect(held.hasUnprotectedRecoverableMedia, isFalse);
    });

    test('a client-only draft with no uploaded media has nothing at risk', () {
      final local = CompositionState(
        attachments: <Attachment>[_att(bytes: _png)],
        draftClaim: DraftClaim.clientOnly,
      );
      expect(local.hasUnprotectedRecoverableMedia, isFalse);
    });
  });

  // ── CO-RC-C5-023 — ACCESSIBILITY BEHAVIOUR ────────────────────────────────
  group('CO-RC-C5-023 · every blocked state can explain itself', () {
    test('a blocked composition always has a reason to announce', () {
      final blocked = <CompositionState>[
        const CompositionState(),
        const CompositionState(body: 'hi', isSubmitting: true),
        CompositionState(body: 'x' * (ContentLengthPolicy.message + 1)),
        CompositionState(
          body: 'hi',
          attachments: <Attachment>[_att(uploading: true)],
        ),
      ];
      for (final state in blocked) {
        expect(state.canSubmit, isFalse);
        expect(
          state.blockedReason,
          isNotNull,
          reason: 'a control disabled with no stated reason is unusable '
              'without sight of it',
        );
      }
    });

    test('a ready composition offers no reason, because there is none', () {
      expect(const CompositionState(body: 'hi').blockedReason, isNull);
    });

    test('every refusal has product-language text', () {
      for (final rejection in AttachmentRejection.values) {
        final message = AttachmentLifecycle.rejectionMessage(rejection);
        expect(message.trim(), isNotEmpty);
        expect(message, isNot(contains('MIME')));
        expect(message, isNot(contains('octet')));
      }
    });
  });

  // ── CO-RC-C5-018 / CO-RC-C5-025 — contracts and rendering ─────────────────
  group('CO-RC-C5-018 · what reaches the backend contract', () {
    test('intake resolves the fields the presign contract requires', () {
      final r = ContentIntake.resolveFile(
        path: IntakePath.picker,
        file: XFile('holiday.jpg'),
        sizeBytes: 4096,
      );
      expect(r.isAccepted, isTrue);
      final a = r.attachment!;
      expect(a.mimeType, 'image/jpeg');
      expect(a.kind, AttachmentKind.image);
      expect(a.sizeBytes, 4096);
      expect(a.fileName, 'holiday.jpg');
    });

    test('paste is recorded as its own source, not laundered into upload', () {
      final r = ContentIntake.resolveBytes(
        path: IntakePath.paste,
        bytes: _png,
        fileName: 'pasted.png',
        declaredMimeType: 'image/png',
      );
      expect(r.attachment!.source, AttachmentSource.paste);
    });
  });

  group('CO-RC-C5-025 · media rendering has what it needs', () {
    test('an accepted attachment can be previewed before any upload', () {
      final r = ContentIntake.resolveBytes(
        path: IntakePath.drop,
        bytes: _png,
        fileName: 'dropped.png',
        declaredMimeType: 'image/png',
      );
      expect(r.phase, AttachmentPhase.preview);
      expect(r.attachment!.bytes, isNotNull);
    });

    test('a resolution never returns a half-populated attachment', () {
      final bad = ContentIntake.resolveBytes(
        path: IntakePath.drop,
        bytes: _png,
        fileName: 'x.zzz',
      );
      expect(bad.attachment, isNull);
      expect(bad.rejection, isNotNull);
    });
  });
}
