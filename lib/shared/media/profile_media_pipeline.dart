/// PROFILE MEDIA PIPELINE — C2 §9 shared primitive.
///
/// One implementation of the mechanic both profile editors duplicated four
/// times each: **pick → validate → crop → upload → URL**.
///
/// ── WHAT IS SHARED, WHAT IS NOT ────────────────────────────────────────────
/// Shared here: the *transport and mechanics* — gallery pick, MIME whitelist,
/// size cap, routing through [ProfileMediaEditor], PNG upload via
/// [uploadAuraMedia] with `editDisclosure`, URL extraction.
///
/// Deliberately NOT shared: what the resulting URL *means*. A person avatar is
/// not an institution logo; person covers save on submit while institution
/// branding auto-persists. Those semantics stay with each caller — this
/// pipeline returns a URL and has no opinion about the domain field it lands
/// in. (`PERSON ≠ INSTITUTION` — the pipeline must never grow a subject flag.)
///
/// The validation rules (MIME whitelist, size caps) existed only on the
/// institution editor; the person editor uploaded unvalidated. Converging the
/// mechanic gives both sides the same protection — a strict improvement with
/// no semantic change.
library;

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/attachments/aura_media_upload.dart';
import '../../core/composition/attachment_lifecycle.dart';
import '../../core/composition/content_intake.dart';
import '../../core/media/attachment.dart';
import 'profile_media_editor.dart';

/// Why a pipeline run produced no URL.
enum ProfileMediaFailure {
  /// The person cancelled the picker or the editor. Not an error.
  cancelled,

  /// The picked file was empty.
  emptyFile,

  /// Not JPEG/PNG/WebP.
  unsupportedType,

  /// Larger than the per-kind cap.
  tooLarge,

  /// Upload failed (network/server).
  uploadFailed,
}

/// Outcome of one pipeline run. Exactly one of [url] / [failure] is set.
class ProfileMediaResult {
  const ProfileMediaResult.success(this.url)
      : failure = null,
        message = null;
  const ProfileMediaResult.failed(this.failure, this.message) : url = null;

  final String? url;
  final ProfileMediaFailure? failure;

  /// Human message for failures worth showing. Cancel carries none.
  final String? message;

  bool get isSuccess => url != null;
  bool get isCancelled => failure == ProfileMediaFailure.cancelled;
}

class ProfileMediaPipeline {
  ProfileMediaPipeline({required this.dio, ImagePicker? picker})
      : _picker = picker ?? ImagePicker();

  final Dio dio;
  final ImagePicker _picker;

  /// Pick from the gallery, validate, crop with [config], upload.
  ///
  /// [maxBytes] is the caller's cap for this media kind (logo vs cover vs
  /// avatar caps are product decisions, not pipeline decisions).
  /// [fileTag] names the processed file (`<base>-<tag>.png`).
  Future<ProfileMediaResult> pickEditUpload(
    BuildContext context, {
    required ProfileMediaEditorConfig config,
    required int maxBytes,
    required String fileTag,
  }) async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
    );
    if (file == null) {
      return const ProfileMediaResult.failed(
        ProfileMediaFailure.cancelled,
        null,
      );
    }

    final bytes = await file.readAsBytes();

    // ONE governed door. This method used to carry its own MIME whitelist and
    // its own `_inferMime`, which is the same private answer every composer
    // had before CH-13 — and it refused a `.heic` or `.gif` with a message
    // naming three formats rather than the canonical vocabulary.
    final resolution = ContentIntake.resolveBytes(
      path: IntakePath.picker,
      bytes: bytes,
      fileName: file.name,
      declaredMimeType: file.mimeType,
      source: AttachmentSource.gallery,
    );
    final picked = resolution.attachment;
    if (picked == null) {
      return ProfileMediaResult.failed(
        resolution.rejection == AttachmentRejection.empty
            ? ProfileMediaFailure.emptyFile
            : resolution.rejection == AttachmentRejection.tooLarge
                ? ProfileMediaFailure.tooLarge
                : ProfileMediaFailure.unsupportedType,
        resolution.rejectionMessage,
      );
    }
    if (picked.kind != AttachmentKind.image) {
      return const ProfileMediaResult.failed(
        ProfileMediaFailure.unsupportedType,
        'A profile image must be an image.',
      );
    }

    // CAPACITY IS ABOUT THE DECODE, NOT THE RESULT.
    //
    // This cap used to be 2 MiB for an avatar and 4 MiB for a cover, applied
    // to the file as PICKED. An ordinary phone photograph is 3–8 MB, so
    // choosing one for an avatar was refused outright — for an image that
    // would be a few dozen kilobytes once cropped. What is stored is the
    // CROPPED output at [config]'s fixed size; the only real constraint is
    // that the editor can decode the original on a phone.
    if (bytes.length > maxBytes) {
      final mb = (maxBytes / (1024 * 1024)).toStringAsFixed(0);
      return ProfileMediaResult.failed(
        ProfileMediaFailure.tooLarge,
        'Image must be $mb MB or smaller.',
      );
    }

    if (!context.mounted) {
      return const ProfileMediaResult.failed(
        ProfileMediaFailure.cancelled,
        null,
      );
    }

    final cropped = await ProfileMediaEditor.open(
      context,
      imageBytes: bytes,
      config: config,
    );
    if (cropped == null) {
      return const ProfileMediaResult.failed(
        ProfileMediaFailure.cancelled,
        null,
      );
    }

    return _upload(
      cropped,
      config: config,
      fileName: _processedName(file.name, fileTag),
    );
  }

  /// Re-edit the current image from its URL (pan/zoom without re-picking).
  Future<ProfileMediaResult> editCurrentUpload(
    BuildContext context, {
    required String imageUrl,
    required ProfileMediaEditorConfig config,
    required String fileTag,
  }) async {
    final url = imageUrl.trim();
    if (url.isEmpty) {
      return const ProfileMediaResult.failed(
        ProfileMediaFailure.cancelled,
        null,
      );
    }

    final cropped = await ProfileMediaEditor.openFromUrl(
      context,
      imageUrl: url,
      config: config,
    );
    if (cropped == null) {
      return const ProfileMediaResult.failed(
        ProfileMediaFailure.cancelled,
        null,
      );
    }

    return _upload(cropped, config: config, fileName: '$fileTag-edit.png');
  }

  Future<ProfileMediaResult> _upload(
    Uint8List bytes, {
    required ProfileMediaEditorConfig config,
    required String fileName,
  }) async {
    try {
      final result = await uploadAuraMedia(
        dio: dio,
        bytes: bytes,
        fileName: fileName,
        mimeType: 'image/png',
        kind: 'IMAGE',
        source: 'UPLOAD',
        width: config.outputWidth,
        height: config.outputHeight,
        metadataPatch: <String, dynamic>{
          'width': config.outputWidth,
          'height': config.outputHeight,
          'editDisclosure': true,
        },
      );
      final url = result.url.trim();
      if (url.isEmpty) {
        return const ProfileMediaResult.failed(
          ProfileMediaFailure.uploadFailed,
          'Uploaded image URL missing.',
        );
      }
      return ProfileMediaResult.success(url);
    } catch (_) {
      return const ProfileMediaResult.failed(
        ProfileMediaFailure.uploadFailed,
        'Could not upload image.',
      );
    }
  }

  static String _processedName(String original, String tag) {
    final base = original.contains('.')
        ? original.substring(0, original.lastIndexOf('.'))
        : original;
    return '$base-$tag.png';
  }

  // `_inferMime` used to live here — a fourth private extension ladder that
  // defaulted anything it did not recognise to `image/jpeg`. Intake resolves
  // the type from the canonical authority and refuses rather than guessing.
}

/// The one http(s)-URL rule both editors need. It was implemented only on the
/// institution editor; person links/website submitted unvalidated.
String? httpUrlValidator(String? value) {
  final v = (value ?? '').trim();
  if (v.isEmpty) return null;
  final uri = Uri.tryParse(v);
  if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
    return 'Enter a valid URL (http:// or https://)';
  }
  return null;
}
