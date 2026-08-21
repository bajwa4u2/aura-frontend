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

  /// Parsed whole during examination, so bounded by the examiner's buffer.
  static const int image = 32 * 1024 * 1024;

  /// Examined by streaming (malware) and by header window (container sanity),
  /// so it is not bounded by the examiner's buffer. This is the product's
  /// accepted envelope and the number the malware-coherence invariant is
  /// measured against.
  static const int video = 150 * 1024 * 1024;

  /// Container sanity reads a header window, but audio still routes through
  /// the whole-file examiners for structural checks, so it takes the buffer
  /// bound rather than the streaming one.
  static const int audio = 32 * 1024 * 1024;

  /// Parsed whole during examination — a document examiner cannot answer from
  /// a header window.
  static const int document = 32 * 1024 * 1024;

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
