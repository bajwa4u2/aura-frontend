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

import '../../core/media/source_origin_scan.dart';

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/media/media_acquisition.dart';

import '../../core/attachments/aura_media_upload.dart';
import '../../core/composition/attachment_lifecycle.dart';
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
    // ONE governed door, reached through the canonical acquisition rather
    // than a private picker. This held its own `ImagePicker` and repeated
    // intake by hand; both already exist in `media_acquisition`, and the
    // private picker cost this surface the Android Photo Picker, so choosing
    // an avatar opened a file browser.
    final resolution = await acquireSingleImage(
      imageQuality: 92,
      picker: _picker,
    );
    if (resolution == null) {
      return const ProfileMediaResult.failed(
        ProfileMediaFailure.cancelled,
        null,
      );
    }
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
    final bytes = picked.bytes ?? const <int>[];
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

    // The editor gets what intake PRODUCED, not what was picked. For ordinary
    // content they are the same object; for a normalized HEIC they are not,
    // and handing the editor the original would decode it a second time on the
    // only platforms that can.
    final cropped = await ProfileMediaEditor.open(
      context,
      imageBytes: picked.bytes ?? Uint8List.fromList(bytes),
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
      fileName: _processedName(picked.fileName ?? fileTag, fileTag),
      // READ BEFORE THE EDIT, because after it there is nothing left to read.
      //
      // The crop re-encodes, which destroys whatever Content Credentials the
      // picked file carried. Losing the credential is correct — its hash
      // describes the ORIGINAL bytes and would be a false claim about these.
      // Forgetting what it SAID is not, and this is the only moment anything
      // can still see it.
      sourceOrigin: scanSourceOrigin(picked.bytes ?? Uint8List.fromList(bytes)),
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
    SourceOriginClaim? sourceOrigin,
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
          // ANCESTRY, carried across the transformation that erased it.
          //
          // Sent as a CLIENT ASSERTION and recorded as one: Aura never saw
          // these original bytes on its own server, and the file it describes
          // no longer exists for anyone to check. That is weaker than a server
          // reading and the model has a place for the distinction, which is
          // better than pretending the two are the same.
          if (sourceOrigin != null)
            'sourceOrigin': sourceOriginWire(sourceOrigin),
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
