import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'media_save_service.dart';

/// Web media persistence.
///
/// Fetched bytes become an in-memory Blob that the browser downloads
/// with the resolved filename via a hidden `<a download>` element. This
/// works for cross-origin media (R2/uploads host) because the bytes are
/// already local by the time the anchor is clicked.
Future<MediaSaveResult> persistMediaBytes({
  required Uint8List bytes,
  required String filename,
  required String mimeType,
}) async {
  try {
    final blob = web.Blob(
      <web.BlobPart>[bytes.toJS].toJS,
      web.BlobPropertyBag(type: mimeType),
    );
    final objectUrl = web.URL.createObjectURL(blob);
    _clickDownloadAnchor(href: objectUrl, filename: filename);
    // Keep the object URL alive long enough for the download to start,
    // then release it so the bytes can be garbage-collected.
    Future<void>.delayed(
      const Duration(minutes: 1),
      () => web.URL.revokeObjectURL(objectUrl),
    );
    return const MediaSaveResult(
      MediaSaveStatus.saved,
      'Media downloaded.',
    );
  } catch (_) {
    return const MediaSaveResult(
      MediaSaveStatus.failed,
      'Could not download this media. Please try again.',
    );
  }
}

/// Fallback when the bytes could not be fetched in-app (a CORS block on
/// the media host): point the browser straight at the URL. Same-origin
/// media downloads; cross-origin media opens for a manual save.
Future<MediaSaveResult> persistByLink({
  required Uri uri,
  required String filename,
}) async {
  try {
    _clickDownloadAnchor(
      href: uri.toString(),
      filename: filename,
      newTab: true,
    );
    return const MediaSaveResult(
      MediaSaveStatus.openedExternally,
      'Opening download in your browser…',
    );
  } catch (_) {
    return const MediaSaveResult(
      MediaSaveStatus.failed,
      'Could not download this media. Please try again.',
    );
  }
}

void _clickDownloadAnchor({
  required String href,
  required String filename,
  bool newTab = false,
}) {
  final anchor = web.HTMLAnchorElement()
    ..href = href
    ..download = filename;
  if (newTab) anchor.target = '_blank';
  anchor.style.display = 'none';
  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
}
