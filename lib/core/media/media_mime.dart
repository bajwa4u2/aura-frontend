import 'dart:typed_data';

import 'attachment.dart';

/// Canonical MIME utilities. Replaces the four duplicate `_inferMime`
/// implementations and the two MIME allow-lists scattered across:
///   * lib/features/posts/presentation/compose_screen.dart:343
///   * lib/features/institutions/posts/institution_post_composer_screen.dart:113, 597
///   * lib/features/correspondence/presentation/thread/thread_composer.dart:407, 881
///   * lib/features/announcements/presentation/announcement_editor_screen.dart:181
///
/// The allow-lists below are the frontend mirror of the backend allowlist
/// in `aura-backend/src/media/media.service.ts::allowedMime()`. Backend
/// is authoritative — frontend rejection is purely UX (so users see a
/// clear error before the upload attempt). If backend tightens or
/// loosens, update here in lockstep.

/// Common image MIME types. SVG is intentionally absent — backend
/// rejects it across five separate gates as a P0-7 security measure.
const Set<String> kAllowedImageMimes = <String>{
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/gif',
};

const Set<String> kAllowedVideoMimes = <String>{
  'video/mp4',
  'video/quicktime',
  'video/webm',
};

const Set<String> kAllowedAudioMimes = <String>{
  'audio/mpeg',
  'audio/mp4',
  'audio/aac',
  'audio/ogg',
  'audio/webm',
  'audio/wav',
  'audio/x-wav',
  'audio/flac',
  // 2026-08-21 — the backend's canonical matrix has accepted these three all
  // along; only this mirror refused them. A browser reporting `audio/mp3` for
  // an MP3, or `audio/m4a` for an M4A, was turned away at the client for
  // naming the same bytes differently.
  'audio/mp3',
  'audio/m4a',
  'audio/x-aac',
};

const Set<String> kAllowedDocumentMimes = <String>{
  'application/pdf',
  'application/msword',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'application/vnd.ms-excel',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'application/vnd.ms-powerpoint',
  'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  'application/rtf',
  'text/plain',
  'text/csv',
  'application/zip',
  'application/x-zip-compressed',
};

/// Detect a MIME type from the CONTENT itself.
///
/// The strongest evidence there is. A filename is what something was CALLED
/// and a declared mime is what a caller CLAIMED; the bytes are the thing.
///
/// This exists because both weaker sources are provably wrong in the field.
/// `image_picker` on Android re-encodes a picked HEIC to JPEG when a quality
/// or size constraint is set — and KEEPS THE ORIGINAL FILENAME. The result is
/// `photo.heic` containing perfectly good JPEG bytes. Resolving that by
/// extension refuses a file Aura fully supports, and does it for a reason the
/// person cannot possibly guess.
///
/// Returns null when the signature is not one Aura recognises, so the caller
/// can fall back to weaker evidence rather than treating "unknown" as "wrong".
String? sniffMimeFromBytes(Uint8List? bytes) {
  final b = bytes;
  if (b == null || b.length < 12) return null;

  bool at(int offset, List<int> sig) {
    if (offset + sig.length > b.length) return false;
    for (var i = 0; i < sig.length; i++) {
      if (b[offset + i] != sig[i]) return false;
    }
    return true;
  }

  // ── images ──
  if (at(0, [0xFF, 0xD8, 0xFF])) return 'image/jpeg';
  if (at(0, [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) return 'image/png';
  if (at(0, [0x47, 0x49, 0x46, 0x38])) return 'image/gif';
  // RIFF....WEBP / WAVE share a container header, so the sub-type decides.
  if (at(0, [0x52, 0x49, 0x46, 0x46])) {
    if (at(8, [0x57, 0x45, 0x42, 0x50])) return 'image/webp';
    if (at(8, [0x57, 0x41, 0x56, 0x45])) return 'audio/wav';
    return null;
  }

  // ── ISO base media (ftyp at offset 4): heic/heif, mp4, m4a ──
  if (at(4, [0x66, 0x74, 0x79, 0x70])) {
    final brand = String.fromCharCodes(b.sublist(8, 12)).toLowerCase();
    switch (brand) {
      case 'heic':
      case 'heix':
      case 'heim':
      case 'heis':
        return 'image/heic';
      case 'mif1':
      case 'msf1':
        return 'image/heif';
      case 'qt  ':
        return 'video/quicktime';
      case 'm4a ':
        return 'audio/mp4';
      default:
        // THE BRAND DOES NOT SAY WHETHER THERE IS A PICTURE.
        //
        // This returned `video/mp4` for every brand it did not recognise, and
        // that turned Aura's own voice notes into videos. Android records them
        // with `MediaRecorder` as AAC in an MPEG-4 container, which is stamped
        // `isom` or `mp42` — never `m4a `. The recorder declared `audio/mp4`
        // honestly, the sniffer overruled it to `video/mp4` because bytes
        // outrank a declaration, and the message then rendered as a video
        // card. Founder-observed on a Pixel, 2026-09-04.
        //
        // The rule was right and the reading was too shallow. `isom` says the
        // file is ISO base media; it says nothing about its tracks. So this
        // reads the tracks.
        return _isoBaseMediaTrackMime(b);
    }
  }

  // ── audio ──
  if (at(0, [0x49, 0x44, 0x33])) return 'audio/mpeg'; // ID3-tagged MP3
  if (at(0, [0xFF, 0xFB]) || at(0, [0xFF, 0xF3]) || at(0, [0xFF, 0xF2])) {
    return 'audio/mpeg';
  }
  if (at(0, [0x66, 0x4C, 0x61, 0x43])) return 'audio/flac';
  if (at(0, [0x4F, 0x67, 0x67, 0x53])) return 'audio/ogg';

  // ── documents / containers ──
  if (at(0, [0x25, 0x50, 0x44, 0x46])) return 'application/pdf';
  // PK.. is every OOXML document as well as a plain zip. The container alone
  // cannot tell docx from xlsx from zip, so this deliberately does NOT answer
  // — the filename is the better evidence for WHICH zip this is, and the
  // caller falls through to it.
  if (at(0, [0x50, 0x4B, 0x03, 0x04])) return null;

  return null;
}

/// WHAT AN ISO BASE MEDIA FILE ACTUALLY CONTAINS.
///
/// `isom`, `mp42`, `avc1` and friends are container brands, and a container
/// brand is not a content type: the same brand covers a film and a voice note.
/// Deciding from the brand alone is how Aura's own voice notes became videos.
///
/// So this reads the track handlers, which is where the answer actually lives.
/// Every track carries an `hdlr` box, and its handler type is `vide` for
/// picture and `soun` for sound:
///
///     [size 4][ 'hdlr' ][version+flags 4][pre_defined 4][handler_type 4]
///
/// A file with any video track is a video, whatever else it also has. A file
/// with sound and no picture is audio. And when neither handler can be found —
/// a truncated buffer, or an `moov` that is not in the bytes we were given —
/// this answers NULL rather than guessing, so the caller falls through to the
/// declared type and the filename. Refusing to answer is the honest outcome;
/// asserting "video" is what caused the defect.
String? _isoBaseMediaTrackMime(Uint8List b) {
  const hdlr = [0x68, 0x64, 0x6C, 0x72]; // 'hdlr'
  var sawSound = false;

  for (var i = 0; i + 16 <= b.length; i++) {
    if (b[i] != hdlr[0] ||
        b[i + 1] != hdlr[1] ||
        b[i + 2] != hdlr[2] ||
        b[i + 3] != hdlr[3]) {
      continue;
    }
    // handler_type sits 12 bytes past the start of the 'hdlr' name.
    final at = i + 12;
    if (at + 4 > b.length) break;
    final handler = String.fromCharCodes(b.sublist(at, at + 4));
    // A picture anywhere settles it — a video with an audio track is a video.
    if (handler == 'vide') return 'video/mp4';
    if (handler == 'soun') sawSound = true;
  }

  if (sawSound) return 'audio/mp4';
  return null;
}

/// Infer a MIME type from a file name's extension. Returns `null` when
/// the extension is unknown — callers that need a fallback should pick
/// `application/octet-stream` themselves.
///
/// Extracted from four duplicate `_inferMime` implementations. Slightly
/// broader coverage than any of them individually (none of the four
/// covered audio + documents in one function).
String? inferMimeFromFileName(String? fileName) {
  if (fileName == null) return null;
  final lower = fileName.trim().toLowerCase();
  if (lower.isEmpty) return null;

  final dot = lower.lastIndexOf('.');
  if (dot < 0 || dot >= lower.length - 1) return null;
  final ext = lower.substring(dot + 1);

  switch (ext) {
    // images
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    case 'webp':
      return 'image/webp';
    case 'gif':
      return 'image/gif';
    case 'heic':
      return 'image/heic';
    case 'heif':
      return 'image/heif';

    // videos
    case 'mp4':
    case 'm4v':
      return 'video/mp4';
    case 'mov':
      return 'video/quicktime';
    case 'webm':
      return 'video/webm';

    // audio
    case 'mp3':
      return 'audio/mpeg';
    case 'm4a':
      return 'audio/mp4';
    case 'aac':
      return 'audio/aac';
    case 'ogg':
    case 'oga':
      return 'audio/ogg';
    case 'wav':
      return 'audio/wav';
    case 'flac':
      return 'audio/flac';

    // documents
    case 'pdf':
      return 'application/pdf';
    case 'doc':
      return 'application/msword';
    case 'docx':
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    case 'xls':
      return 'application/vnd.ms-excel';
    case 'xlsx':
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    case 'ppt':
      return 'application/vnd.ms-powerpoint';
    case 'pptx':
      return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    case 'rtf':
      return 'application/rtf';
    case 'txt':
      return 'text/plain';
    case 'csv':
      return 'text/csv';
    case 'zip':
      return 'application/zip';
    default:
      return null;
  }
}

/// Resolve which [AttachmentKind] this MIME belongs to. Replaces the
/// `kindFromMime` in `thread_utils.dart`. Unknown MIMEs route to
/// `document` (matches the old behaviour).
AttachmentKind kindFromMime(String mime) {
  final lower = mime.toLowerCase();
  if (lower.startsWith('image/')) return AttachmentKind.image;
  if (lower.startsWith('video/')) return AttachmentKind.video;
  if (lower.startsWith('audio/')) return AttachmentKind.audio;
  if (kAllowedDocumentMimes.contains(lower)) return AttachmentKind.document;
  if (lower.startsWith('application/') || lower.startsWith('text/')) {
    return AttachmentKind.document;
  }
  return AttachmentKind.document;
}

/// Whether [mime] is allow-listed for the given [kind]. The thread
/// composer used to inline four separate sets and validate against them
/// individually; this single predicate replaces that logic.
bool isMimeAllowedFor(AttachmentKind kind, String mime) {
  final lower = mime.toLowerCase();
  switch (kind) {
    case AttachmentKind.image:
      return kAllowedImageMimes.contains(lower);
    case AttachmentKind.video:
      return kAllowedVideoMimes.contains(lower);
    case AttachmentKind.audio:
      return kAllowedAudioMimes.contains(lower);
    case AttachmentKind.document:
      return kAllowedDocumentMimes.contains(lower);
  }
}

/// Whether [mime] is allow-listed at all. Used by surfaces that accept
/// "any media" without pre-classifying (e.g. paste-from-clipboard).
bool isAnyMimeAllowed(String mime) {
  final kind = kindFromMime(mime);
  return isMimeAllowedFor(kind, mime);
}
