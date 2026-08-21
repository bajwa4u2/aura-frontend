// CONTENT NORMALIZATION — a governed presentation representation.
//
// Some formats Aura should ACCEPT cannot be rendered by the consumers Aura has
// to serve. HEIC forced the issue: it is what an iPhone produces, and roughly
// 85% of browsers cannot display it. Refusing it is not an answer — it is an
// ordinary modern photograph. Storing it unchanged is not an answer either,
// because most viewers would see nothing.
//
// So Aura normalizes: it produces a representation every consumer can render,
// and keeps the truth about what actually arrived.
//
// ─────────────────────────────────────────────────────────────────────────────
// WHAT THIS DELIBERATELY KEEPS APART
//
//   ORIGINAL IDENTITY      what the person actually chose — image/heic
//   DETECTED TYPE          resolved from the BYTES, never from the name
//   NORMALIZED FORM        genuinely re-encoded bytes, not a relabelling
//   PRESENTATION FORMAT    what is stored and served — image/jpeg
//
// It never renames HEIC bytes to JPEG. The bytes are decoded and re-encoded,
// so the result really is a JPEG, and `originalMimeType` records what it was
// before — provenance rather than erasure.
// ─────────────────────────────────────────────────────────────────────────────
//
// HOW IT DECODES, AND WHY THAT IS THE CEILING
//
// Decoding goes through `ui.instantiateImageCodec`, which is the PLATFORM's
// codec. That is a deliberate choice and it is also the limit of what is
// possible here:
//
//   * iOS / macOS  — decodes HEIC through ImageIO.
//   * Android 28+  — decodes HEIC through the platform ImageDecoder.
//   * Android < 28, Linux, Web — cannot. `instantiateImageCodec` throws and
//     this returns null, so intake refuses TRUTHFULLY instead of storing
//     something no one can see.
//
// There is no Dart HEIC decoder to fall back to and there will not be one: the
// `image` package's maintainer has consolidated every HEIC request and states
// the only acceptable route is a from-scratch Dart rewrite, because libheif is
// LGPL and `image` is MIT. A universal client-side answer is therefore not
// available, and the remaining gap — web and old Android — closes with a
// SERVER-side derivative, not with a different client package.
//
// Encoding uses `package:image`, already a direct dependency. JPEG rather than
// PNG on purpose: `dart:ui` can only emit PNG, and a 12 MP photograph as PNG is
// tens of megabytes. Sending that over mobile data in place of a 2 MB original
// would be a worse product than the one being fixed.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image/image.dart' as img;

/// Formats Aura accepts from a person but must not serve unchanged.
///
/// Membership here is about what CONSUMERS can render, not about what Aura can
/// store. A format leaves this set the day it is broadly renderable.
const Set<String> kNormalizableImageMimes = <String>{
  'image/heic',
  'image/heif',
};

/// The result of taking content in and making it presentable.
class NormalizedContent {
  const NormalizedContent({
    required this.bytes,
    required this.mimeType,
    required this.originalMimeType,
    required this.fileName,
  });

  /// The bytes to store and serve.
  final Uint8List bytes;

  /// What [bytes] now genuinely are.
  final String mimeType;

  /// What the person actually chose. Kept even when nothing changed, so a
  /// caller never has to ask whether the field means anything.
  final String originalMimeType;

  /// A name that matches the bytes. Renaming `photo.heic` to `photo.jpg` is
  /// truthful here precisely BECAUSE the bytes were re-encoded — the same
  /// rename without the re-encode would be the lie this exists to avoid.
  final String? fileName;

  bool get wasNormalized => mimeType != originalMimeType;
}

class ContentNormalizer {
  const ContentNormalizer._();

  /// Quality for the derived representation. High enough that a photograph is
  /// not visibly degraded, low enough that the derivative is smaller than the
  /// HEIC it replaces.
  static const int _jpegQuality = 92;

  static bool needsNormalization(String? mimeType) =>
      kNormalizableImageMimes.contains((mimeType ?? '').trim().toLowerCase());

  /// Produce a presentable representation.
  ///
  /// Returns the content unchanged when nothing needs doing, and NULL when the
  /// content needs normalizing but this device cannot decode it — the caller
  /// must then refuse, because the alternative is storing something the
  /// recipient cannot open.
  static Future<NormalizedContent?> normalize({
    required Uint8List bytes,
    required String mimeType,
    String? fileName,
  }) async {
    if (!needsNormalization(mimeType)) {
      return NormalizedContent(
        bytes: bytes,
        mimeType: mimeType,
        originalMimeType: mimeType,
        fileName: fileName,
      );
    }

    ui.Image? decoded;
    ui.Codec? codec;
    try {
      codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      decoded = frame.image;

      final raw = await decoded.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (raw == null) return null;

      final rebuilt = img.Image.fromBytes(
        width: decoded.width,
        height: decoded.height,
        bytes: raw.buffer,
        numChannels: 4,
      );
      final jpeg = img.encodeJpg(rebuilt, quality: _jpegQuality);

      return NormalizedContent(
        bytes: Uint8List.fromList(jpeg),
        mimeType: 'image/jpeg',
        originalMimeType: mimeType.trim().toLowerCase(),
        fileName: _renamed(fileName),
      );
    } catch (_) {
      // This platform has no decoder for it. Refusing is the honest outcome;
      // the caller says so rather than storing an image nobody can render.
      return null;
    } finally {
      decoded?.dispose();
      codec?.dispose();
    }
  }

  /// `photo.heic` becomes `photo.jpg`, because the bytes really did change.
  static String? _renamed(String? fileName) {
    final name = (fileName ?? '').trim();
    if (name.isEmpty) return null;
    final dot = name.lastIndexOf('.');
    final base = dot > 0 ? name.substring(0, dot) : name;
    return '$base.jpg';
  }
}
