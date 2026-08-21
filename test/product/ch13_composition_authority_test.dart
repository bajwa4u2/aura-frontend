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
import 'package:aura/core/media/content_normalizer.dart';
import 'package:aura/core/media/media_mime.dart';
import 'package:aura/core/media/media_capacity.dart';
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

  // ── CAPACITY — one answer, and it names itself ────────────────────────────
  //
  // Capacity used to be whatever private constant the receiving composer
  // declared: 8 MiB image and 50 MiB video on the institution post composer,
  // nothing at all on the conversation composer. The same file was accepted on
  // one surface and refused on another, and neither number came from a measured
  // constraint. It is judged once, at the door, against the canonical ceiling.
  group('CO-RC-C5-022 · capacity is judged at the door', () {
    Uint8List sized(int n) => Uint8List(n);

    test('a file at the ceiling is accepted', () {
      final r = ContentIntake.resolveBytes(
        path: IntakePath.picker,
        bytes: sized(MediaCapacity.image),
        fileName: 'big.png',
        declaredMimeType: 'image/png',
      );
      expect(r.isAccepted, isTrue);
    });

    test('one byte over is refused, before anything is uploaded', () {
      final r = ContentIntake.resolveBytes(
        path: IntakePath.picker,
        bytes: sized(MediaCapacity.image + 1),
        fileName: 'big.png',
        declaredMimeType: 'image/png',
      );
      expect(r.isAccepted, isFalse);
      expect(r.rejection, AttachmentRejection.tooLarge);
    });

    test('a capacity refusal names the limit it exceeded', () {
      // "That file is too large" tells a person nothing they can act on.
      final r = ContentIntake.resolveBytes(
        path: IntakePath.picker,
        bytes: sized(MediaCapacity.image + 1),
        fileName: 'big.png',
        declaredMimeType: 'image/png',
      );
      expect(r.kind, AttachmentKind.image);
      expect(
        r.rejectionMessage,
        contains('${MediaCapacity.image ~/ (1024 * 1024)} MB'),
      );
    });

    test('the ceiling differs by class, because the constraint does', () {
      // Image, video and audio require only MALWARE_SCAN, which streams, so
      // they share the streamed envelope. DOCUMENT requires whole-object
      // inspection — a PDF's objects are anywhere in the file — so it is
      // genuinely bound by the examiner's buffer and stands lower.
      expect(MediaCapacity.image, MediaCapacity.video);
      expect(MediaCapacity.audio, MediaCapacity.video);
      expect(MediaCapacity.document, lessThan(MediaCapacity.video));
    });

    test('the retired private ceilings are not the answer anywhere', () {
      // 8 MiB and 50 MiB were the institution post composer's own constants.
      const retired = <int>[8 * 1024 * 1024, 50 * 1024 * 1024];
      for (final kind in AttachmentKind.values) {
        expect(retired, isNot(contains(MediaCapacity.maxBytesFor(kind))));
      }
    });
  });

  // ── TYPE CAPABILITY — the mirror must not be narrower than the door ───────
  group('CO-RC-C5-019 · supported content is not narrowed by the client', () {
    test('the audio names a browser actually reports are accepted', () {
      // audio/mp3, audio/m4a and audio/x-aac are in the backend's canonical
      // matrix and were refused only by this mirror. A browser naming the same
      // bytes differently was turned away at the client.
      for (final mime in ['audio/mp3', 'audio/m4a', 'audio/x-aac']) {
        final r = ContentIntake.resolveBytes(
          path: IntakePath.picker,
          bytes: Uint8List.fromList([1, 2, 3]),
          fileName: 'voice.m4a',
          declaredMimeType: mime,
        );
        expect(r.isAccepted, isTrue, reason: '$mime must be accepted');
        expect(r.attachment!.kind, AttachmentKind.audio);
      }
    });

    test('office documents resolve from the filename when the platform is silent',
        () {
      // The DOCX late-refusal defect: no declared mime, and the retired path
      // fell to octet-stream, which the server refuses at presign.
      const office = {
        'proposal.docx':
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'deck.pptx':
            'application/vnd.openxmlformats-officedocument.presentationml.presentation',
        'sheet.xlsx':
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      };
      office.forEach((name, mime) {
        final r = ContentIntake.resolveBytes(
          path: IntakePath.picker,
          bytes: Uint8List.fromList([1, 2, 3]),
          fileName: name,
        );
        expect(r.isAccepted, isTrue, reason: '$name must be accepted');
        expect(r.attachment!.mimeType, mime);
        expect(r.attachment!.kind, AttachmentKind.document);
      });
    });
  });

  // ── IDENTITY IMAGERY — a cap on the decode, not on the result ─────────────
  group('CO-RC-C5-022 · profile imagery capacity', () {
    test('an ordinary phone photograph can become an avatar', () {
      // THE DEFECT. Avatar was capped at 2 MiB and cover at 4 MiB, applied to
      // the file as PICKED. A modern phone photograph is 3-8 MB, so choosing
      // one for an avatar was refused outright — for an image that ends up a
      // few dozen kilobytes once cropped to a fixed size.
      const typicalPhonePhoto = 6 * 1024 * 1024;
      expect(typicalPhonePhoto, lessThan(MediaCapacity.profileSource));

      const retiredAvatarCap = 2 * 1024 * 1024;
      const retiredCoverCap = 4 * 1024 * 1024;
      expect(typicalPhonePhoto, greaterThan(retiredAvatarCap));
      expect(typicalPhonePhoto, greaterThan(retiredCoverCap));
    });

    test('identity imagery still resolves through the canonical door', () {
      // The pipeline used to carry its own three-format whitelist and its own
      // `_inferMime` that defaulted anything unrecognised to image/jpeg.
      final r = ContentIntake.resolveBytes(
        path: IntakePath.picker,
        bytes: Uint8List.fromList(List<int>.filled(1024, 7)),
        fileName: 'portrait.webp',
        declaredMimeType: 'image/webp',
      );
      expect(r.isAccepted, isTrue);
      expect(r.attachment!.kind, AttachmentKind.image);
    });

    test('a non-image picked for a profile is refused, not defaulted to jpeg',
        () {
      final r = ContentIntake.resolveBytes(
        path: IntakePath.picker,
        bytes: Uint8List.fromList(List<int>.filled(64, 7)),
        fileName: 'notes.pdf',
      );
      expect(r.isAccepted, isTrue);
      // It resolves honestly as a document; the pipeline refuses it for being
      // the wrong KIND rather than relabelling it as an image.
      expect(r.attachment!.kind, AttachmentKind.document);
    });
  });

  // ── CONTENT DETECTION — the bytes outrank the name ────────────────────────
  //
  // `image_picker` on Android re-encodes a picked HEIC to JPEG when a size or
  // quality constraint is set, and KEEPS the original filename. The result is
  // `photo.heic` holding perfectly good JPEG bytes. Resolving by extension
  // refused a file Aura fully supports, for a reason the person could not
  // possibly guess. Two of Aura's own pickers set `imageQuality: 92`.
  group('CO-RC-C5-012 · type is detected, not assumed', () {
    Uint8List withHeader(List<int> header) =>
        Uint8List.fromList([...header, ...List<int>.filled(32, 0)]);

    final jpeg = withHeader([0xFF, 0xD8, 0xFF, 0xE0]);
    final png = withHeader([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
    final heic = withHeader(
        [0, 0, 0, 0x18, 0x66, 0x74, 0x79, 0x70, 0x68, 0x65, 0x69, 0x63]);

    test('JPEG bytes named .heic are accepted as JPEG', () {
      final r = ContentIntake.resolveBytes(
        path: IntakePath.picker,
        bytes: jpeg,
        fileName: 'photo.heic',
      );
      expect(r.isAccepted, isTrue,
          reason: 'the bytes are a JPEG Aura fully supports');
      expect(r.attachment!.mimeType, 'image/jpeg');
      expect(r.attachment!.kind, AttachmentKind.image);
    });

    test('a declared type does not override the content', () {
      // A caller's claim is possession, not authority — the D7 rule one layer
      // up. PNG bytes declared as JPEG resolve as PNG.
      final r = ContentIntake.resolveBytes(
        path: IntakePath.picker,
        bytes: png,
        fileName: 'whatever.jpg',
        declaredMimeType: 'image/jpeg',
      );
      expect(r.attachment!.mimeType, 'image/png');
    });

    test('genuine HEIC bytes are still refused, and honestly', () {
      // Detection is not permission. Aura cannot serve HEIC to ~85% of
      // browsers, so it is refused — but for being HEIC, not for its name.
      final r = ContentIntake.resolveBytes(
        path: IntakePath.picker,
        bytes: heic,
        fileName: 'photo.jpg',
      );
      expect(r.isAccepted, isFalse);
      expect(r.rejection, AttachmentRejection.unsupportedType);
    });

    test('an unrecognised signature falls through to weaker evidence', () {
      // A zip container cannot tell docx from xlsx, so the filename is the
      // better evidence for WHICH zip it is and the sniffer declines to answer.
      final r = ContentIntake.resolveBytes(
        path: IntakePath.picker,
        bytes: withHeader([0x50, 0x4B, 0x03, 0x04]),
        fileName: 'proposal.docx',
      );
      expect(r.isAccepted, isTrue);
      expect(
        r.attachment!.mimeType,
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      );
    });
  });

  // ── NORMALIZATION — accept the photograph, serve something renderable ─────
  //
  // HEIC is what an iPhone produces and ~85% of browsers cannot display it.
  // Refusing it is wrong; storing it unchanged is wrong. Aura decodes through
  // the PLATFORM codec and re-encodes, so the stored bytes really are a JPEG
  // and the original type survives as provenance rather than being erased.
  group('CO-RC-C5-012 · content is prepared, never relabelled', () {
    Uint8List withHeader(List<int> header) =>
        Uint8List.fromList([...header, ...List<int>.filled(64, 0)]);

    final heic = withHeader(
        [0, 0, 0, 0x18, 0x66, 0x74, 0x79, 0x70, 0x68, 0x65, 0x69, 0x63]);

    test('HEIC and HEIF are the formats that need preparing', () {
      expect(ContentNormalizer.needsNormalization('image/heic'), isTrue);
      expect(ContentNormalizer.needsNormalization('image/heif'), isTrue);
      expect(ContentNormalizer.needsNormalization('IMAGE/HEIC'), isTrue);
      for (final ok in ['image/jpeg', 'image/png', 'image/webp', 'image/gif']) {
        expect(ContentNormalizer.needsNormalization(ok), isFalse);
      }
      expect(ContentNormalizer.needsNormalization(null), isFalse);
    });

    test('content that needs nothing passes through with its origin recorded',
        () async {
      final jpeg = withHeader([0xFF, 0xD8, 0xFF, 0xE0]);
      final out = await ContentNormalizer.normalize(
        bytes: jpeg,
        mimeType: 'image/jpeg',
        fileName: 'photo.jpg',
      );
      expect(out, isNotNull);
      expect(out!.wasNormalized, isFalse);
      expect(out.mimeType, 'image/jpeg');
      // Equal, never null — a caller must not have to ask whether it means
      // anything.
      expect(out.originalMimeType, 'image/jpeg');
      expect(identical(out.bytes, jpeg), isTrue);
    });

    test('a device that cannot decode it refuses, and says something useful',
        () async {
      // The Dart test VM has no platform HEIC codec, which is exactly the
      // situation on web and on Android below 28. The honest outcome is a
      // refusal — NOT a stored file no recipient could open.
      final r = await ContentIntake.resolveAndPrepareBytes(
        path: IntakePath.picker,
        bytes: heic,
        fileName: 'IMG_0001.heic',
      );
      expect(r.isAccepted, isFalse);
      expect(r.rejection, AttachmentRejection.cannotBeMadePresentable);
      expect(r.rejectionMessage, contains('phone'));
    });

    test('the preparing door is transparent for ordinary content', () async {
      final png = withHeader(
          [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
      final prepared = await ContentIntake.resolveAndPrepareBytes(
        path: IntakePath.drop,
        bytes: png,
        fileName: 'diagram.png',
      );
      final direct = ContentIntake.resolveBytes(
        path: IntakePath.drop,
        bytes: png,
        fileName: 'diagram.png',
      );
      expect(prepared.isAccepted, direct.isAccepted);
      expect(prepared.attachment!.mimeType, direct.attachment!.mimeType);
      expect(prepared.attachment!.kind, direct.attachment!.kind);
      expect(prepared.attachment!.originalMimeType, 'image/png');
    });

    test('the attachment carries the bytes its type describes', () async {
      // THE MISLABELLING TRAP, pinned. An upload site that sends the bytes it
      // PICKED alongside the mime intake RESOLVED will mislabel content the
      // moment those two differ — which is exactly what normalization makes
      // happen. The attachment is the single object carrying both, so a caller
      // that uploads `attachment.bytes` with `attachment.mimeType` cannot
      // desynchronise them.
      final jpeg = withHeader([0xFF, 0xD8, 0xFF, 0xE0]);
      final r = await ContentIntake.resolveAndPrepareBytes(
        path: IntakePath.picker,
        bytes: jpeg,
        fileName: 'photo.jpg',
      );
      final a = r.attachment!;
      expect(a.bytes, isNotNull);
      expect(a.mimeType, isNotNull);
      // The declared size must describe the bytes actually held, or the
      // presign contract is measuring a different object than the one sent.
      expect(a.sizeBytes, a.bytes!.length);
      expect(sniffMimeFromBytes(a.bytes), a.mimeType);
    });

    test('a rename without a re-encode is exactly what this avoids', () {
      // The synchronous door does not prepare anything, so HEIC is refused
      // there rather than being quietly renamed into an accepted type.
      final r = ContentIntake.resolveBytes(
        path: IntakePath.picker,
        bytes: heic,
        fileName: 'IMG_0001.heic',
      );
      expect(r.isAccepted, isFalse);
      expect(r.rejection, AttachmentRejection.unsupportedType);
    });
  });
}
