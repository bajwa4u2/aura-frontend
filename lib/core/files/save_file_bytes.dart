/// Saving a file the app produced — the same per-platform path media saving
/// uses (browser download on the web; the system save dialog on Android, iOS
/// and desktop, which needs no storage permission), with its own dialog title.
library;

import 'dart:typed_data';

import '../media/media_save_service.dart';
import '../media/media_save_stub.dart'
    if (dart.library.io) '../media/media_save_io.dart'
    if (dart.library.html) '../media/media_save_web.dart' as platform;

export '../media/media_save_service.dart' show MediaSaveResult, MediaSaveStatus;

Future<MediaSaveResult> saveFileBytes({
  required Uint8List bytes,
  required String filename,
  required String mimeType,
  required String dialogTitle,
}) =>
    platform.persistMediaBytes(
      bytes: bytes,
      filename: filename,
      mimeType: mimeType,
      dialogTitle: dialogTitle,
    );
