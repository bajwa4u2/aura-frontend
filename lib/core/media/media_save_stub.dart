import 'dart:typed_data';

import 'media_save_service.dart';

/// Fallback implementation for platforms with neither `dart:io` nor
/// `dart:html`. No Aura target platform hits this path; it exists only
/// so the conditional import in [MediaSaveService] always resolves.
Future<MediaSaveResult> persistMediaBytes({
  required Uint8List bytes,
  required String filename,
  required String mimeType,
}) async {
  return const MediaSaveResult(
    MediaSaveStatus.failed,
    'Saving media is not supported on this platform.',
  );
}

Future<MediaSaveResult> persistByLink({
  required Uri uri,
  required String filename,
}) async {
  return const MediaSaveResult(
    MediaSaveStatus.failed,
    'Saving media is not supported on this platform.',
  );
}
