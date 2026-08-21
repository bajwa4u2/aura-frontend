// CH-13 · CO-RC-C5-012 — CONTENT INTAKE & RESOLUTION.
//
// One governed door for everything a person can put into a composer, whether it
// arrived from a picker, a paste or a drop. §12 froze the rule that intake
// preserves richness and never INVENTS it, and the D7 rule that a caller's
// claim about what something is confers no authority.
//
// Today the three entry paths are three different answers. A picker fills in a
// mime from the platform, a paste fills in whatever the clipboard said, and a
// drop — with zero implementations — has no answer at all. Each composer then
// re-derives kind from mime in its own way. The consequence is not theoretical:
// the same PNG can enter as `image/png` from one door and `application/
// octet-stream` from another, and only one of those is accepted.
//
// So this resolves intake ONCE, before any composer sees it, and returns a
// verdict rather than a mutated object. A verdict can be tested; a mutation has
// to be observed.
//
// What this deliberately does NOT do: guess. Where the evidence is absent the
// resolution says so and the attachment is refused, because manufacturing a
// type is exactly how a file becomes trusted for being named confidently — the
// defect F127 already recorded at the server door.

import 'dart:typed_data';

import 'package:image_picker/image_picker.dart' show XFile;

import '../media/attachment.dart';
import '../media/media_capacity.dart';
import '../media/media_mime.dart';
import 'attachment_lifecycle.dart';

/// How content arrived. Distinct from [AttachmentSource] on purpose: source is
/// a wire field the server records, intake path is a client-side fact about
/// which door was used and what evidence that door can be trusted to supply.
enum IntakePath { picker, paste, drop }

/// The outcome of resolving one piece of incoming content.
///
/// Either an accepted attachment or a refusal with a reason. Never both, and
/// never a half-populated object that a composer has to interrogate.
class IntakeResolution {
  const IntakeResolution._({
    required this.path,
    this.attachment,
    this.rejection,
    this.rejectedKind,
  });

  const IntakeResolution.accepted({
    required IntakePath path,
    required Attachment attachment,
  }) : this._(path: path, attachment: attachment);

  /// [kind] is supplied when the content resolved far enough to have one —
  /// a file refused for CAPACITY has a perfectly good class, and the message
  /// needs it to name the ceiling. A file refused for type does not.
  const IntakeResolution.rejected({
    required IntakePath path,
    required AttachmentRejection rejection,
    AttachmentKind? kind,
  }) : this._(path: path, rejection: rejection, rejectedKind: kind);

  final IntakePath path;
  final Attachment? attachment;
  final AttachmentRejection? rejection;

  /// Set only on a refusal that got far enough to classify the content.
  final AttachmentKind? rejectedKind;

  /// The class the content resolved to, whether or not it was accepted.
  AttachmentKind? get kind => attachment?.kind ?? rejectedKind;

  /// The refusal, already worded, with the ceiling filled in where it applies.
  String? get rejectionMessage => rejection == null
      ? null
      : AttachmentLifecycle.rejectionMessage(rejection!, kind: kind);

  bool get isAccepted => attachment != null;

  /// The phase this resolution produces, so a caller never has to decide.
  AttachmentPhase get phase => isAccepted
      ? AttachmentLifecycle.phaseOf(attachment!)
      : AttachmentPhase.rejected;
}

/// The intake authority.
class ContentIntake {
  const ContentIntake._();

  /// Resolve bytes that arrived from any door.
  ///
  /// [declaredMimeType] is EVIDENCE, not authority — it is what the platform or
  /// the clipboard claimed. When it is absent or useless the filename is
  /// consulted, and when neither answers the content is refused rather than
  /// defaulted. `application/octet-stream` is treated as absent for exactly
  /// this reason: it is the type a source emits when it does not know, and
  /// accepting it would let "unknown" pass as "fine".
  static IntakeResolution resolveBytes({
    required IntakePath path,
    required Uint8List bytes,
    String? fileName,
    String? declaredMimeType,
    AttachmentSource? source,
    String? localId,
  }) {
    if (bytes.isEmpty) {
      return IntakeResolution.rejected(
        path: path,
        rejection: AttachmentRejection.empty,
      );
    }

    final mime = _resolveMime(declaredMimeType, fileName);
    if (mime == null || !isAnyMimeAllowed(mime)) {
      return IntakeResolution.rejected(
        path: path,
        rejection: AttachmentRejection.unsupportedType,
      );
    }

    final kind = kindFromMime(mime);
    if (!isMimeAllowedFor(kind, mime)) {
      // The resolved kind and the resolved mime disagree. Nothing downstream
      // can repair that, and choosing one of them would be inventing richness.
      return IntakeResolution.rejected(
        path: path,
        rejection: AttachmentRejection.kindMismatch,
      );
    }

    // Capacity is judged HERE, once, against the canonical per-class ceiling.
    // It used to be judged by whichever private constant the receiving composer
    // happened to declare, so the same file was accepted on one surface and
    // refused on another.
    if (bytes.length > MediaCapacity.maxBytesFor(kind)) {
      return IntakeResolution.rejected(
        path: path,
        rejection: AttachmentRejection.tooLarge,
        kind: kind,
      );
    }

    return IntakeResolution.accepted(
      path: path,
      attachment: Attachment(
        localId: localId ?? _localId(path, fileName, bytes.length),
        kind: kind,
        source: source ?? _sourceFor(path),
        bytes: bytes,
        fileName: fileName,
        mimeType: mime,
        sizeBytes: bytes.length,
      ),
    );
  }

  /// Resolve a platform file. Same rules; the file simply carries better
  /// evidence, and better evidence does not earn different treatment.
  static IntakeResolution resolveFile({
    required IntakePath path,
    required XFile file,
    int? sizeBytes,
    String? declaredMimeType,
    AttachmentSource? source,
    String? localId,
  }) {
    final name = file.name.trim().isEmpty ? null : file.name;
    final mime = _resolveMime(declaredMimeType ?? file.mimeType, name);
    if (mime == null || !isAnyMimeAllowed(mime)) {
      return IntakeResolution.rejected(
        path: path,
        rejection: AttachmentRejection.unsupportedType,
      );
    }

    final kind = kindFromMime(mime);
    if (!isMimeAllowedFor(kind, mime)) {
      return IntakeResolution.rejected(
        path: path,
        rejection: AttachmentRejection.kindMismatch,
      );
    }

    if (sizeBytes != null && sizeBytes <= 0) {
      return IntakeResolution.rejected(
        path: path,
        rejection: AttachmentRejection.empty,
      );
    }

    if (sizeBytes != null && sizeBytes > MediaCapacity.maxBytesFor(kind)) {
      return IntakeResolution.rejected(
        path: path,
        rejection: AttachmentRejection.tooLarge,
        kind: kind,
      );
    }

    return IntakeResolution.accepted(
      path: path,
      attachment: Attachment(
        localId: localId ?? _localId(path, name, sizeBytes ?? 0),
        kind: kind,
        source: source ?? _sourceFor(path),
        file: file,
        fileName: name,
        mimeType: mime,
        sizeBytes: sizeBytes,
      ),
    );
  }

  /// Resolve many at once, preserving order. Refusals are RETURNED, never
  /// dropped — a file that silently fails to attach is the worst outcome
  /// available, because the person believes it is there.
  static List<IntakeResolution> resolveAllBytes({
    required IntakePath path,
    required List<({Uint8List bytes, String? fileName, String? mimeType})> items,
  }) {
    return <IntakeResolution>[
      for (final item in items)
        resolveBytes(
          path: path,
          bytes: item.bytes,
          fileName: item.fileName,
          declaredMimeType: item.mimeType,
        ),
    ];
  }

  /// `octet-stream` means "the source did not know". Treating it as a real type
  /// is how an unknown file becomes an accepted one.
  static String? _resolveMime(String? declared, String? fileName) {
    final claimed = (declared ?? '').trim().toLowerCase();
    if (claimed.isNotEmpty &&
        claimed != 'application/octet-stream' &&
        claimed != 'binary/octet-stream') {
      return claimed;
    }
    final inferred = inferMimeFromFileName(fileName);
    if (inferred != null && inferred.trim().isNotEmpty) {
      return inferred.trim().toLowerCase();
    }
    return null;
  }

  static AttachmentSource _sourceFor(IntakePath path) {
    switch (path) {
      case IntakePath.paste:
        return AttachmentSource.paste;
      case IntakePath.picker:
      case IntakePath.drop:
        return AttachmentSource.upload;
    }
  }

  /// Stable enough to key a widget and unique enough not to collide within one
  /// composition. Not a security identifier and never sent to the server.
  static int _seq = 0;
  static String _localId(IntakePath path, String? fileName, int size) {
    _seq += 1;
    final name = (fileName ?? 'item').replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '');
    return '${path.name}-$size-$_seq-$name';
  }
}
