import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

/// Canonical media-kind enum used everywhere in the app.
///
/// Replaces the per-composer enums:
///   * `ComposeAttachmentType` (post composer; image/video only)
///   * `ThreadAttachmentKind` (thread composer; image/video/audio/document)
///   * the string-typed kind in `_AnnouncementEditorMediaAttachment` ("IMAGE"/"VIDEO")
///
/// `audio` and `document` are first-class even on surfaces that don't ship
/// them today — keeping the enum closed to the four Aura supports avoids
/// the thread composer's habit of forcing audio into a generic "document"
/// branch when the parent surface doesn't render it.
enum AttachmentKind { image, video, audio, document }

/// Where the attachment originated. The wire format expects an upper-case
/// string (CAMERA/GALLERY/UPLOAD/RECORDING/PASTE) — see [wireSource].
enum AttachmentSource { camera, gallery, upload, recording, paste }

/// One canonical attachment model.
///
/// Replaces:
///   * `ComposeAttachment` (lib/features/posts/presentation/compose/compose_models.dart)
///   * `_DraftAttachment`  (lib/features/correspondence/presentation/thread/thread_composer.dart)
///   * `_AnnouncementEditorMediaAttachment` (lib/features/announcements/presentation/announcement_editor_screen.dart)
///
/// Mutable on purpose — composers heavily rely on field-level mutation
/// (e.g. `att.uploading = true`, `att.error = …`) and converting all five
/// surfaces to copy-with would balloon this consolidation pass. The
/// invariant we DO enforce is: only `localId` and `kind` are required at
/// construction; everything else is populated as the upload progresses.
///
/// Caption text on multi-image post composers is intentionally NOT stored
/// here as a `TextEditingController` — that was the old `ComposeAttachment`
/// pattern and it coupled UI state to data. The composer keeps a parallel
/// `Map<String, TextEditingController>` keyed by [localId] and writes the
/// final string into [caption] right before send. See
/// `compose_screen.dart` for the parallel-map wiring.
class Attachment {
  Attachment({
    required this.localId,
    required this.kind,
    this.source = AttachmentSource.upload,
    this.file,
    this.bytes,
    this.fileName,
    this.mimeType,
    this.sizeBytes,
    this.width,
    this.height,
    this.durationMs,
    this.mediaId,
    this.url,
    this.thumbUrl,
    this.storageKey,
    this.uploading = false,
    this.uploadProgress,
    this.attachedToDraft = false,
    this.error,
    this.caption,
  });

  /// Stable client-side id. Generated at pick-time; survives across
  /// rebuild/re-render. Different from [mediaId] which is server-issued.
  final String localId;

  final AttachmentKind kind;
  final AttachmentSource source;

  /// Pre-upload local representations. At least one of [file] / [bytes]
  /// will be populated for surfaces that show a local preview before the
  /// upload completes. After upload completes both can be cleared to free
  /// memory; rendering switches to [url].
  XFile? file;
  Uint8List? bytes;

  /// File metadata. Populated either client-side (pickers fill these in)
  /// or server-side (the `/media/:id/confirm` response refines them).
  String? fileName;
  String? mimeType;
  int? sizeBytes;
  int? width;
  int? height;

  /// Duration in milliseconds. Wire format expects seconds — see
  /// [toMessagePayload]. Internally we keep ms because pickers and
  /// `video_player` report ms.
  int? durationMs;

  /// Server-issued identifiers, populated after `POST /media/presign` +
  /// `POST /media/:id/confirm` succeed.
  String? mediaId;
  String? url;
  String? thumbUrl;
  String? storageKey;

  /// Live upload progress.
  bool uploading;

  /// 0.0 .. 1.0. Null when the surface doesn't track per-byte progress.
  double? uploadProgress;

  /// Last upload error, if any. Null on success or when not yet attempted.
  String? error;

  /// Compose-specific. True once the attachment is wired into the active
  /// post draft (vs. picked-but-not-yet-attached). Other surfaces leave
  /// this at the default `false`.
  bool attachedToDraft;

  /// Optional per-attachment caption (post carousel uses this; messages
  /// and announcements ignore). String form, not TextEditingController —
  /// see class doc.
  String? caption;

  bool get isImage => kind == AttachmentKind.image;
  bool get isVideo => kind == AttachmentKind.video;
  bool get isAudio => kind == AttachmentKind.audio;
  bool get isDocument => kind == AttachmentKind.document;
  bool get isUploaded => (mediaId ?? '').trim().isNotEmpty;

  /// Wire format used by the direct-message / thread message endpoint.
  /// Backend DTO: `{ storageKey, fileName, mimeType, sizeBytes, width?, height?, durationSec? }`.
  /// Note seconds, not ms.
  Map<String, dynamic> toMessagePayload() {
    final payload = <String, dynamic>{
      'storageKey': storageKey ?? '',
      'fileName': fileName ?? file?.name ?? '',
      'mimeType': mimeType ?? '',
      'sizeBytes': sizeBytes ?? 0,
    };
    if (width != null) payload['width'] = width;
    if (height != null) payload['height'] = height;
    if (durationMs != null) payload['durationSec'] = (durationMs! / 1000).round();
    return payload;
  }
}

/// Wire string for [AttachmentKind] — backend `MediaType` enum is
/// upper-case (IMAGE / VIDEO / AUDIO). Documents historically rode the
/// IMAGE channel on the messages backend; the thread composer used to
/// force `'IMAGE'` for documents — preserved here so behaviour is
/// identical.
String wireKind(AttachmentKind kind) {
  switch (kind) {
    case AttachmentKind.image:
      return 'IMAGE';
    case AttachmentKind.video:
      return 'VIDEO';
    case AttachmentKind.audio:
      return 'AUDIO';
    case AttachmentKind.document:
      return 'IMAGE';
  }
}

/// Wire string for [AttachmentSource] — backend `MediaSource` enum.
String wireSource(AttachmentSource source) {
  switch (source) {
    case AttachmentSource.camera:
      return 'CAMERA';
    case AttachmentSource.gallery:
      return 'GALLERY';
    case AttachmentSource.upload:
      return 'UPLOAD';
    case AttachmentSource.recording:
      return 'RECORDING';
    case AttachmentSource.paste:
      return 'PASTE';
  }
}

/// User-facing label for the kind. Used by composers in tooltips and
/// "Image/Video/Audio/Document" pickers — extracted from the four
/// surface-local copies of `_attachmentKindLabel`.
String attachmentKindLabel(AttachmentKind kind) {
  switch (kind) {
    case AttachmentKind.image:
      return 'Image';
    case AttachmentKind.video:
      return 'Video';
    case AttachmentKind.audio:
      return 'Audio';
    case AttachmentKind.document:
      return 'Document';
  }
}
