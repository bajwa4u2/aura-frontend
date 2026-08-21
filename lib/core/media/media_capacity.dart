// CANONICAL MEDIA CAPACITY.
//
// One answer to "how large may this be", for every surface.
//
// Before this file, capacity was whatever each composer happened to declare.
// The institution post composer capped images at 8 MiB and video at 50 MiB in
// two private constants; the conversation composer declared nothing at all and
// let the server refuse; the profile surfaces each carried their own pair. None
// of those numbers came from a measured constraint. They were round numbers
// chosen at different times, and the product's real capacity was whichever of
// them the person happened to meet first.
//
// ─────────────────────────────────────────────────────────────────────────────
// WHERE THESE NUMBERS COME FROM
//
// Aura uploads bytes DIRECTLY to object storage through a presigned PUT. They
// never traverse the API process, so the API's 1 MiB JSON body limit does not
// bound media and never did. The binding constraint is not transport — it is
// EXAMINATION, and the founder has already frozen the rule that governs it:
//
//   *if Aura accepts an object, Aura's required safety examination must be
//   CAPABLE of examining it.*
//
// The backend expresses that as two numbers. `MAX_EXAMINABLE_BYTES` (32 MiB) is
// how much an examiner will hold in memory at once — it bounds every capability
// that must parse a whole file, which is images and documents. Malware scanning
// and container sanity STREAM, so they are bounded instead by the scanner's own
// envelope, which is what allows video to stand higher.
//
// So: 32 MiB for the classes that must be parsed whole, and the existing video
// ceiling for the class that is examined by streaming. Each ceiling is a real
// constraint rather than a habit, and each is stated below with its reason.
// ─────────────────────────────────────────────────────────────────────────────
//
// These MIRROR `aura-backend/src/media/media.service.ts::maxBytesFor`. The
// backend remains authoritative — a client-side refusal exists so a person is
// told before a large upload is attempted, never to define policy. If the
// backend moves, this moves with it.

import 'attachment.dart';

/// Per-class byte ceilings.
class MediaCapacity {
  const MediaCapacity._();

  /// The streamed-examination envelope: what the malware scanner vouches for.
  ///
  /// Image, video and audio all live here. Reading `examination-policy.ts`
  /// rather than assuming: MALWARE_SCAN is the ONLY required capability for
  /// these three classes, and it streams to clamd window by window.
  /// STRUCTURAL_VALIDATION answers from a header window, and
  /// MEDIA_DECODE_VALIDATION is optional — above the examiner's buffer it
  /// reports UNAVAILABLE, an honest absence rather than a pass it did not earn.
  /// The 32 MiB buffer therefore does not bind them.
  static const int _streamedEnvelope = 150 * 1024 * 1024;

  static const int image = _streamedEnvelope;
  static const int video = _streamedEnvelope;
  static const int audio = _streamedEnvelope;

  /// DOCUMENT is different in kind. `DOCUMENT_INSPECTION` and
  /// `STRUCTURAL_VALIDATION` are both REQUIRED for it, and a PDF's objects are
  /// anywhere in the file, so the examiner must hold the whole object. This
  /// ceiling is architectural: raising it would accept documents Aura cannot
  /// inspect. Archives are bounded the same way — their directory is at the
  /// END — and the frontend models them as documents.
  static const int document = 32 * 1024 * 1024;

  /// The largest image the ON-DEVICE crop editor will decode.
  ///
  /// Identity imagery is a different problem from an attachment. The picked
  /// file is never what gets stored — it is decoded, cropped to a fixed output
  /// size and re-encoded, so the stored object is small regardless of what was
  /// picked. The only real constraint is that the editor must hold the decoded
  /// original in memory on a phone.
  ///
  /// The caps this replaced were 2 MiB for an avatar and 4 MiB for a cover,
  /// applied to the PRE-CROP file. An ordinary modern phone photograph is 3–8
  /// MB, so picking one for an avatar was refused outright — for an image that
  /// would have been a few dozen kilobytes once cropped. That is precisely a
  /// ceiling impoverishing ordinary use, and it is why this is measured
  /// against decode feasibility rather than against the stored result.
  static const int profileSource = 32 * 1024 * 1024;

  static int maxBytesFor(AttachmentKind kind) {
    switch (kind) {
      case AttachmentKind.image:
        return image;
      case AttachmentKind.video:
        return video;
      case AttachmentKind.audio:
        return audio;
      case AttachmentKind.document:
        return document;
    }
  }

  /// Whole megabytes, for a refusal a person can act on. Deliberately not
  /// "8.0 MB" — a limit reads as a limit, not as a measurement.
  static String describeLimit(AttachmentKind kind) =>
      '${maxBytesFor(kind) ~/ (1024 * 1024)} MB';
}
