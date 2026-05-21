import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'media_save_service.dart';

/// Desktop + mobile media persistence.
///
/// Desktop (Windows/macOS/Linux) — a native "Save file" dialog returns
/// the chosen path and Aura writes the bytes there.
///
/// Mobile (Android/iOS) — the system document picker (Storage Access
/// Framework on Android, Files on iOS) receives the bytes directly, so
/// no runtime storage permission is needed.
Future<MediaSaveResult> persistMediaBytes({
  required Uint8List bytes,
  required String filename,
  required String mimeType,
}) async {
  final isMobile = Platform.isAndroid || Platform.isIOS;

  try {
    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save media',
      fileName: filename,
      // On Android/iOS file_picker writes [bytes] itself. On desktop the
      // platform only returns a destination path — passing bytes there
      // is unnecessary, so it is sent on mobile only and the desktop
      // branch below performs the write.
      bytes: isMobile ? bytes : null,
    );

    if (outputPath == null || outputPath.trim().isEmpty) {
      return const MediaSaveResult(
        MediaSaveStatus.cancelled,
        'Save cancelled.',
      );
    }

    if (!isMobile) {
      // Desktop: file_picker only returns the destination path — the
      // write is ours to perform.
      await File(outputPath).writeAsBytes(bytes, flush: true);
      return const MediaSaveResult(
        MediaSaveStatus.saved,
        'Media saved to your device.',
      );
    }

    return const MediaSaveResult(
      MediaSaveStatus.saved,
      'Media saved to your device.',
    );
  } catch (_) {
    return const MediaSaveResult(
      MediaSaveStatus.failed,
      'Could not save this media. Please try again.',
    );
  }
}

/// Fallback when the bytes could not be fetched in-app: hand the URL to
/// the platform browser, which downloads or displays it for manual save.
Future<MediaSaveResult> persistByLink({
  required Uri uri,
  required String filename,
}) async {
  try {
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (launched) {
      return const MediaSaveResult(
        MediaSaveStatus.openedExternally,
        'Opened in your browser to download.',
      );
    }
  } catch (_) {
    // Fall through to the failure result.
  }
  return const MediaSaveResult(
    MediaSaveStatus.failed,
    'Could not save this media. Please try again.',
  );
}
