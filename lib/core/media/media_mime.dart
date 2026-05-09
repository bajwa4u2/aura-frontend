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
