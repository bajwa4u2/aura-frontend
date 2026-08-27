/// STORED MEDIA — the resolution layer of Aura's stored-media authority.
///
/// ## THE LAYERS, AND WHY THEY ARE SEPARATE
///
///     STORED MEDIA RESOLUTION   this file
///       media type / metadata / poster / playable source / state
///            |
///     INLINE PRESENTATION       aura_stored_media.dart
///       poster / play affordance / inline playback / loading / error
///            |
///     FULL VIEWER               aura_media_viewer.dart
///
/// The defect that forced the split was a category error: a thumbnail was
/// treated as the domain model. `CanonicalMediaThumb` — an adapter whose whole
/// job is "put this media in a frame" — was the nearest thing the product had
/// to a stored-media authority, so anything it did not know how to do became a
/// per-surface improvisation. Video was the case that exposed it, but the
/// shape of the mistake was general.
///
/// A poster is ONE PRESENTATION CAPABILITY of a stored object. It is not what
/// the object is. So this layer answers what the media IS and what is known
/// about it, and knows nothing about widgets; the presentation layer decides
/// what that should look like; the viewer owns fullscreen. A surface that
/// wants a picture consumes the stack, and does not reason about MP4s.
///
/// ## IDENTITY IS PRESERVED, NOT REPLACED
///
/// A preview never stands in for the object. Every stored media keeps its
/// storage identity, mime, filename, duration, dimensions, provenance and
/// visibility policy, so a surface can always fall back to naming the thing
/// truthfully when it cannot show it. Poster is presentation metadata carried
/// ALONGSIDE that identity — never in place of it.
library;

import 'dart:typed_data';

import 'aura_attachment_card.dart';

/// Where a stored object is in its lifecycle, as far as presentation cares.
///
/// This is deliberately coarse. The product has richer server-side states, but
/// a surface only ever needs to know whether it can show the thing, should
/// wait, or must say it cannot.
enum StoredMediaState {
  /// Fetchable and presentable now.
  ready,

  /// Chosen locally, not yet uploaded. Compose surfaces live here.
  local,

  /// Uploading or awaiting server processing.
  pending,

  /// Known to exist but not presentable — deleted, expired, denied, or failed.
  unavailable,
}

/// A stored media object, resolved into everything presentation needs.
///
/// Constructed by adapters from each surface's own payload ([fromParts] and
/// the named adapters below), so surfaces keep their wire models and the
/// presentation layer sees exactly one shape.
class StoredMedia {
  const StoredMedia({
    required this.mediaId,
    required this.kind,
    this.state = StoredMediaState.ready,
    this.isPublic = false,
    this.sourceUrl,
    this.posterUrl,
    this.localBytes,
    this.localPath,
    this.fileName,
    this.mimeType,
    this.caption,
    this.width,
    this.height,
    this.durationMs,
    this.sizeBytes,
  });

  /// Canonical `Media.id`. Empty for media that exists only locally.
  final String mediaId;

  /// What this object IS, resolved by the canonical mime-first rule.
  final AttachmentPresentationKind kind;

  final StoredMediaState state;

  /// PUBLIC visibility. Anything else needs a freshly signed URL, which the
  /// presentation layer resolves through `MediaUrlResolver`.
  final bool isPublic;

  /// The original object: playable video, full-size image, downloadable file.
  /// Never a derivative, never a poster.
  final String? sourceUrl;

  /// Presentation metadata: a server-produced picture OF the object.
  ///
  /// Null for every video the product stores today — the backend's derivative
  /// pipeline accepts image mimes only. Consumers must not care: the
  /// presentation layer produces a picture by whatever means the platform
  /// allows, and this is simply the cheapest one when it exists.
  final String? posterUrl;

  /// Pre-upload bytes, for compose surfaces.
  final Uint8List? localBytes;

  /// Pre-upload file path, for platforms that hand back a path rather than
  /// bytes. Large video is routinely too big to hold in memory.
  final String? localPath;

  final String? fileName;
  final String? mimeType;
  final String? caption;
  final int? width;
  final int? height;

  /// MILLISECONDS (F133), as the rest of the product carries duration.
  final int? durationMs;

  final int? sizeBytes;

  bool get isImage => kind == AttachmentPresentationKind.image;
  bool get isVideo => kind == AttachmentPresentationKind.video;
  bool get isAudio => kind == AttachmentPresentationKind.audio;

  bool get hasPoster => (posterUrl ?? '').trim().isNotEmpty;
  bool get hasSource => (sourceUrl ?? '').trim().isNotEmpty;
  bool get hasLocalBytes => (localBytes?.isNotEmpty ?? false);
  bool get hasLocalPath => (localPath ?? '').trim().isNotEmpty;

  /// Whether anything at all can be reached for this object.
  bool get isReachable =>
      state != StoredMediaState.unavailable &&
      (hasSource || hasLocalBytes || hasLocalPath || mediaId.trim().isNotEmpty);

  /// Aspect ratio from real intrinsic dimensions, or null when unknown.
  /// Never guessed here — a surface that needs a default chooses its own.
  double? get aspectRatio {
    final w = width;
    final h = height;
    if (w == null || h == null || w <= 0 || h <= 0) return null;
    return w / h;
  }

  StoredMedia copyWith({
    StoredMediaState? state,
    String? sourceUrl,
    String? posterUrl,
  }) =>
      StoredMedia(
        mediaId: mediaId,
        kind: kind,
        state: state ?? this.state,
        isPublic: isPublic,
        sourceUrl: sourceUrl ?? this.sourceUrl,
        posterUrl: posterUrl ?? this.posterUrl,
        localBytes: localBytes,
        localPath: localPath,
        fileName: fileName,
        mimeType: mimeType,
        caption: caption,
        width: width,
        height: height,
        durationMs: durationMs,
        sizeBytes: sizeBytes,
      );

  /// Canonical constructor from loose parts.
  ///
  /// KIND RESOLUTION IS NOT REPEATED HERE. `attachmentKindFrom` already owns
  /// the mime-first rule, including the case where a document rides the IMAGE
  /// channel on the wire. Re-deriving it would create a second answer to a
  /// question the product has already settled.
  factory StoredMedia.fromParts({
    String mediaId = '',
    String? mimeType,
    String? declaredKind,
    bool isPublic = false,
    String? sourceUrl,
    String? posterUrl,
    Uint8List? localBytes,
    String? localPath,
    String? fileName,
    String? caption,
    int? width,
    int? height,
    int? durationMs,
    int? sizeBytes,
    StoredMediaState state = StoredMediaState.ready,
  }) {
    return StoredMedia(
      mediaId: mediaId.trim(),
      kind: attachmentKindFrom(
        mimeType: mimeType,
        canonicalKind: declaredKind,
      ),
      state: state,
      isPublic: isPublic,
      sourceUrl: sourceUrl,
      // An empty string is not a poster. Normalising here keeps every
      // consumer from having to trim before deciding.
      posterUrl: (posterUrl ?? '').trim().isEmpty ? null : posterUrl!.trim(),
      localBytes: localBytes,
      localPath: localPath,
      fileName: fileName,
      mimeType: mimeType,
      caption: caption,
      width: width,
      height: height,
      durationMs: durationMs,
      sizeBytes: sizeBytes,
    );
  }
}
