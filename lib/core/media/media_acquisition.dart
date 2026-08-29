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
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

import '../composition/content_intake.dart';
import 'attachment.dart';

/// How many items one acquisition may contribute.
///
/// A deliberate product ceiling rather than an inherited picker default: past
/// this a composition stops reading as a composition and becomes a file
/// listing, and every item costs upload time, memory and a decoder slot in
/// somebody's feed.
///
/// This is the ACQUISITION ceiling, not the publication rule. Destinations
/// have their own limits and they are not the same number — see
/// [kMaxMemberPostMedia].
const int kMaxComposableMedia = 10;

/// What a MEMBER POST accepts — mirroring `MAX_MEMBER_POST_ATTACHMENTS` in
/// `posts.service.ts`, which is the rule. Founder raised it from five to ten
/// on 2026-08-29 ("make atleast 10 man"); five was the stricter surface for
/// no stated reason while institution posts already allowed ten.
///
/// The client used to carry only the ceiling above, so it accepted a sixth
/// item, UPLOADED it, and discovered the rule at publish. Founder, 2026-08-29:
/// five photographs from the library, then a recorded video clip. Every
/// upload succeeded, every item reached READY on the server, and the post
/// could never be published — the whole cost landing on the person, who
/// filmed something and waited for it to upload before being refused.
///
/// A limit the client does not know is a limit the client will let somebody
/// break. Institution posts are deliberately NOT this number: their own
/// authority allows ten, so they keep using the ceiling. Each surface honours
/// the rule that actually governs it.
const int kMaxMemberPostMedia = 10;

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

/// USE THE PHOTO PICKER, NOT THE FILE BROWSER.
///
/// THE DEFECT THIS CLOSES, reproduced on a Pixel 9a 2026-08-29. Tapping
/// Library opened `com.android.documentsui.picker.PickActivity` -- a FILE
/// MANAGER, offering "Search this device", Images/Audio/Videos/Documents
/// chips, and a Recent files list whose only entry was a `ui.xml`. Somebody
/// looking for a photograph was shown an XML document. It read as "the
/// library doesn't load anything", and nothing was broken: it was the wrong
/// picker.
///
/// `image_picker_android` defaults `useAndroidPhotoPicker` to FALSE, so every
/// call in the app fell back to the legacy `ACTION_OPEN_DOCUMENT` intent
/// instead of Android's Photo Picker. That default is a plugin decision made
/// for compatibility, and it silently costs every surface that picks media --
/// Compose as much as Share.
///
/// Armed HERE, at every entry point of this module, and NOWHERE ELSE.
///
/// It was briefly armed at app startup too, while the composers still built
/// their own pickers -- a compensation for the bypasses rather than a fix for
/// them. Those are retired now: every acquisition in the app comes through
/// this file, so the guarantee lives with the thing it guards instead of in a
/// boot-time side effect that no reader would connect to a file browser
/// appearing three screens away.
///
/// Idempotent and Android-only by construction: on other platforms the
/// instance is not `ImagePickerAndroid` and this does nothing.
void ensureAndroidPhotoPicker() {
  if (kIsWeb) return;
  final platform = ImagePickerPlatform.instance;
  if (platform is ImagePickerAndroid) {
    platform.useAndroidPhotoPicker = true;
  }
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
  ensureAndroidPhotoPicker();
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
  ensureAndroidPhotoPicker();
  final picked = await (picker ?? ImagePicker()).pickMultipleMedia();
  return resolveAcquired(
    files: picked,
    remainingSlots: remainingSlots,
    source: AttachmentSource.gallery,
  );
}

/// Choose exactly ONE image.
///
/// WHY A SINGULAR FUNCTION EXISTS ALONGSIDE THE PLURAL ONE. An avatar, an
/// article cover and an inline illustration are each ONE SLOT, not a
/// composition of one -- the person is replacing a specific thing, and
/// offering multi-select there would let them pick four images for a space
/// that holds one and then silently discard three.
///
/// Its absence is why three surfaces still reached for `ImagePicker`
/// directly: the module had no shape for the thing they actually needed, so
/// they went around it, and every one of them inherited the legacy file
/// browser as a result. A canonical module that does not cover the real cases
/// does not get used; it gets bypassed.
/// [imageQuality] re-encodes before the file ever reaches intake. An avatar
/// does not need a 12-megapixel original, and the person should not pay to
/// upload one; it is left null everywhere the ORIGINAL is the point.
Future<IntakeResolution?> acquireSingleImage({
  int? imageQuality,
  ImagePicker? picker,
}) async {
  ensureAndroidPhotoPicker();
  final file = await (picker ?? ImagePicker()).pickImage(
    source: ImageSource.gallery,
    imageQuality: imageQuality,
  );
  if (file == null) return null;
  final acquired = await resolveAcquired(
    files: [file],
    remainingSlots: 1,
    source: AttachmentSource.gallery,
  );
  return acquired.resolutions.isEmpty ? null : acquired.resolutions.first;
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
    final resolution = await ContentIntake.resolveAndPrepareBytes(
      path: IntakePath.picker,
      bytes: await f.readAsBytes(),
      fileName: f.name,
      // The platform's answer is preferred; intake infers from the name when
      // it declines to say, and refuses when neither answers. It is never
      // guessed from the extension here.
      declaredMimeType: f.mimeType,
      source: source,
    );
    // KEEP THE LOCAL ORIGIN. Intake works in bytes, which is right for
    // deciding what something IS -- but the file is the only thing that can
    // still be asked what a VIDEO is: duration, dimensions and rotation come
    // from decoding the file, not from a byte array. Dropping it here would
    // have left every module-acquired video unmeasurable, and any caller that
    // uploads from `attachment.file` silently doing nothing at all.
    resolution.attachment?.file = f;
    out.add(resolution);
  }
  return MediaAcquisition(resolutions: out, droppedForLimit: dropped);
}

/// What to tell someone when the ceiling turned items away.
///
/// [limit] is the DESTINATION's rule, not this file's ceiling: a member post
/// takes five and an institution post takes ten, so a message that quoted one
/// constant would be wrong on one of them. Callers state their own.
String? acquisitionLimitMessage(int dropped, {int limit = kMaxComposableMedia}) {
  if (dropped <= 0) return null;
  return dropped == 1
      ? 'One item was not added — up to $limit can be attached.'
      : '$dropped items were not added — up to $limit can be attached.';
}
