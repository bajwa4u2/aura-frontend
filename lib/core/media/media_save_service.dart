import 'package:http/http.dart' as http;

import 'media_save_stub.dart'
    if (dart.library.io) 'media_save_io.dart'
    if (dart.library.html) 'media_save_web.dart' as platform;

/// Outcome of a [MediaSaveService.save] attempt. Drives the snackbar
/// message and tone surfaced by [MediaSaveButton].
enum MediaSaveStatus {
  /// Bytes were written to a file the user can keep.
  saved,

  /// The user dismissed the save/file dialog.
  cancelled,

  /// Bytes could not be fetched in-app (CORS / network), so the media
  /// was handed to the browser/OS to complete the download.
  openedExternally,

  /// The save failed for a reason the user should be told about.
  failed,
}

/// Result of a save attempt — a [MediaSaveStatus] plus a human-readable
/// message ready to show in a snackbar.
class MediaSaveResult {
  const MediaSaveResult(this.status, this.message);

  final MediaSaveStatus status;
  final String message;

  bool get isSuccess => status == MediaSaveStatus.saved;
}

/// Platform-aware media save / download contract.
///
/// One entry point — [save] — used by every media-capable surface
/// (fullscreen viewer, feed/announcement/institution media frames). The
/// service fetches the media bytes once, then defers the persistence
/// step to a platform implementation:
///
///   * **Web** — bytes become a Blob the browser downloads with the
///     resolved filename. If the fetch is blocked (CORS), the media URL
///     is handed to the browser directly.
///   * **Desktop** — a native "Save file" dialog lets the user pick a
///     destination; the bytes are written there.
///   * **Mobile** — the system document picker (SAF on Android / Files
///     on iOS) receives the bytes; no storage permission is required.
///
/// Callers pass a directly-fetchable URL. Visibility-gated media must be
/// resolved to a signed URL upstream before calling [save].
class MediaSaveService {
  const MediaSaveService();

  /// Network timeout for the byte fetch. Generous enough for large
  /// evidence screenshots on slow links, short enough not to hang.
  static const Duration _fetchTimeout = Duration(seconds: 30);

  /// Fetch [url] and persist it to the device.
  ///
  /// [suggestedFilename] is used verbatim when it already carries a
  /// sensible extension; otherwise an extension is inferred from the
  /// response content-type or the URL.
  Future<MediaSaveResult> save({
    required String url,
    String? suggestedFilename,
  }) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      return const MediaSaveResult(
        MediaSaveStatus.failed,
        'This media is not available to save.',
      );
    }

    var uri = Uri.tryParse(trimmed);
    if (uri != null && !uri.hasScheme) {
      uri = Uri.tryParse('https://$trimmed');
    }
    if (uri == null || !uri.hasScheme) {
      return const MediaSaveResult(
        MediaSaveStatus.failed,
        'This media link is not valid.',
      );
    }

    try {
      final response = await http.get(uri).timeout(_fetchTimeout);
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        final mime = (response.headers['content-type'] ?? '')
            .split(';')
            .first
            .trim()
            .toLowerCase();
        final filename = _resolveFilename(suggestedFilename, uri, mime);
        return platform.persistMediaBytes(
          bytes: response.bodyBytes,
          filename: filename,
          mimeType: mime.isEmpty ? 'application/octet-stream' : mime,
        );
      }
    } catch (_) {
      // Network failure or a cross-origin block — fall through to the
      // direct-link path so the platform can still complete the save.
    }

    final filename = _resolveFilename(suggestedFilename, uri, '');
    return platform.persistByLink(uri: uri, filename: filename);
  }
}

/// Build a safe, extension-bearing filename for a download.
String _resolveFilename(String? suggested, Uri uri, String mime) {
  var base = (suggested ?? '').trim();
  if (base.isEmpty) {
    base = uri.pathSegments.isNotEmpty ? uri.pathSegments.last.trim() : '';
  }
  // Strip any query/fragment that rode along in a path segment.
  base = base.split('?').first.split('#').first.trim();
  if (base.isEmpty) base = 'aura-media';

  if (!_hasKnownExtension(base)) {
    base = '$base.${_extensionForMime(mime)}';
  }

  // Keep only filename-safe characters; collapse the rest to '_'.
  base = base.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
  // Avoid a leading dot (hidden file) or an empty stem.
  if (base.startsWith('.')) base = 'aura-media$base';
  return base;
}

bool _hasKnownExtension(String name) {
  final dot = name.lastIndexOf('.');
  if (dot <= 0 || dot >= name.length - 1) return false;
  final ext = name.substring(dot + 1).toLowerCase();
  return _knownExtensions.contains(ext);
}

const Set<String> _knownExtensions = <String>{
  'jpg', 'jpeg', 'png', 'webp', 'gif', 'heic', 'heif',
  'mp4', 'm4v', 'mov', 'webm',
};

String _extensionForMime(String mime) {
  switch (mime.toLowerCase()) {
    case 'image/jpeg':
      return 'jpg';
    case 'image/png':
      return 'png';
    case 'image/webp':
      return 'webp';
    case 'image/gif':
      return 'gif';
    case 'image/heic':
      return 'heic';
    case 'image/heif':
      return 'heif';
    case 'video/mp4':
      return 'mp4';
    case 'video/quicktime':
      return 'mov';
    case 'video/webm':
      return 'webm';
    default:
      // Discourse media is overwhelmingly photographic; jpg is the
      // safest neutral default when the server gave us nothing.
      return 'jpg';
  }
}
