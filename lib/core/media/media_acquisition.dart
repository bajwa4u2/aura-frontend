/// CANONICAL MULTI-MEDIA ACQUISITION.
///
/// Every way media enters a composition converges here:
///
///     gallery / file picker
///     camera / recording
///     drag and drop
///     paste
///       ↓
///     ONE ordered composition
///
/// ## WHY THIS IS ONE FUNCTION AND NOT SEVEN
///
/// Composers previously called `pickImage` or `pickVideo` — both singular —
/// so attaching four photographs meant opening the picker four times. That is
/// not a policy anyone chose; it is the shape the old single-select API left
/// behind, inherited by every surface that copied it.
///
/// `pickMultipleMedia` returns images AND videos from ONE picker, which is why
/// there is no separate "multi-photo" and "multi-video" path here. A person
/// choosing two photographs and a video has made one selection, and splitting
/// it into two architectures would make the composer's job harder to reason
/// about for no benefit to them.
///
/// ## WHAT THIS DOES NOT DO
///
/// It does not decide whether a file is acceptable — `ContentIntake` does, and
/// it refuses at the door rather than letting a refusal surface later as a
/// failed upload. It does not upload. It does not own composition state. It
/// turns a selection into an ORDERED list of intake resolutions and stops.
library;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';

import '../composition/content_intake.dart';
import 'attachment.dart';

/// How many items one acquisition may contribute.
///
/// A deliberate product ceiling rather than an inherited picker default: past
/// this a composition stops reading as a composition and becomes a file
/// listing, and every item costs upload time, memory and a decoder slot in
/// somebody's feed.
const int kMaxComposableMedia = 10;

/// The outcome of one acquisition.
class MediaAcquisition {
  const MediaAcquisition({
    required this.resolutions,
    required this.droppedForLimit,
  });

  /// Intake resolutions IN SELECTION ORDER. Order is author intent from the
  /// first moment, so it is never re-sorted here.
  final List<IntakeResolution> resolutions;

  /// How many the ceiling turned away.
  ///
  /// Reported rather than silently discarded: quietly dropping the fifth of
  /// five chosen photographs is exactly the class of silence this chapter
  /// exists to remove.
  final int droppedForLimit;

  bool get isEmpty => resolutions.isEmpty && droppedForLimit == 0;
}

/// Whether this platform can capture rather than only choose.
///
/// The web has no in-process camera through `image_picker`; a browser file
/// input with `capture` is the OS picker wearing a different hat, and
/// pretending otherwise puts a "Take photo" button in front of somebody who
/// will get a file browser.
bool get supportsCameraCapture => !kIsWeb;

/// Capture ONE photograph.
///
/// THE CLAIM THIS MAKES TRUE. The header above has always said camera
/// converges here, and there was no camera function in this file at all --
/// so every composer reached for `ImagePicker` directly and applied its own
/// intake, its own ceiling and its own idea of what a capture is. The
/// composer's own file called five different picker APIs.
///
/// Capture is singular on purpose: a camera returns one thing at a time, and
/// modelling it as a degenerate multi-select would invent a plural the device
/// never offers.
Future<MediaAcquisition> capturePhoto({
  required int remainingSlots,
  ImagePicker? picker,
}) =>
    _capture(
      remainingSlots: remainingSlots,
      take: (p) => p.pickImage(source: ImageSource.camera),
      picker: picker,
    );

/// Record ONE video.
///
/// [maxDuration] is a product ceiling rather than a device limit: past it a
/// share stops being a moment and becomes an upload the person waits on.
Future<MediaAcquisition> captureVideo({
  required int remainingSlots,
  Duration maxDuration = const Duration(seconds: 60),
  ImagePicker? picker,
}) =>
    _capture(
      remainingSlots: remainingSlots,
      take: (p) => p.pickVideo(source: ImageSource.camera, maxDuration: maxDuration),
      picker: picker,
    );

Future<MediaAcquisition> _capture({
  required int remainingSlots,
  required Future<XFile?> Function(ImagePicker) take,
  ImagePicker? picker,
}) async {
  if (remainingSlots <= 0) {
    return const MediaAcquisition(resolutions: [], droppedForLimit: 0);
  }
  final file = await take(picker ?? ImagePicker());
  // Cancelling the camera is a decision, not a failure. It contributes
  // nothing and says nothing.
  if (file == null) {
    return const MediaAcquisition(resolutions: [], droppedForLimit: 0);
  }
  return resolveAcquired(
    files: [file],
    remainingSlots: remainingSlots,
    // The SOURCE is the one thing capture must not lose. It is what lets a
    // preview offer "Retake" rather than "Remove", and what provenance reads
    // to say this was made here rather than chosen from a library.
    source: AttachmentSource.camera,
  );
}

/// Pick several media items — images, videos, or a mix — in one selection.
///
/// [remainingSlots] is what the composition can still hold, so the ceiling is
/// applied against the WHOLE composition rather than per picker visit.
Future<MediaAcquisition> acquireMultipleMedia({
  required int remainingSlots,
  ImagePicker? picker,
}) async {
  if (remainingSlots <= 0) {
    return const MediaAcquisition(resolutions: [], droppedForLimit: 0);
  }
  final picked = await (picker ?? ImagePicker()).pickMultipleMedia();
  return resolveAcquired(
    files: picked,
    remainingSlots: remainingSlots,
    source: AttachmentSource.gallery,
  );
}

/// Turn already-selected files into ordered intake resolutions.
///
/// Separated from the picker so drag-and-drop, paste and share-to-Aura reach
/// exactly the same intake and ordering rules. The acquisition METHOD must not
/// determine what the composition becomes.
Future<MediaAcquisition> resolveAcquired({
  required List<XFile> files,
  required int remainingSlots,
  required AttachmentSource source,
}) async {
  if (files.isEmpty) {
    return const MediaAcquisition(resolutions: [], droppedForLimit: 0);
  }
  final admitted = files.take(remainingSlots).toList(growable: false);
  final dropped = files.length - admitted.length;

  final out = <IntakeResolution>[];
  for (final f in admitted) {
    out.add(
      await ContentIntake.resolveAndPrepareBytes(
        path: IntakePath.picker,
        bytes: await f.readAsBytes(),
        fileName: f.name,
        // The platform's answer is preferred; intake infers from the name when
        // it declines to say, and refuses when neither answers. It is never
        // guessed from the extension here.
        declaredMimeType: f.mimeType,
        source: source,
      ),
    );
  }
  return MediaAcquisition(resolutions: out, droppedForLimit: dropped);
}

/// What to tell someone when the ceiling turned items away.
String? acquisitionLimitMessage(int dropped) {
  if (dropped <= 0) return null;
  return dropped == 1
      ? 'One item was not added — up to $kMaxComposableMedia can be attached.'
      : '$dropped items were not added — up to $kMaxComposableMedia can be attached.';
}
