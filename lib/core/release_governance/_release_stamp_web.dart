// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

/// Reads the build stamp of the release currently being served.
///
/// `flutter_bootstrap.js` carries a `serviceWorkerVersion` that changes with
/// every build, and it is served `no-cache`, so this genuinely reflects what
/// is deployed rather than what this tab loaded. A cache-busting query is
/// added anyway: `no-cache` means revalidate, and an intermediary that
/// misbehaves would otherwise make the check silently useless.
Future<String?> readReleaseStamp() async {
  try {
    final url =
        'flutter_bootstrap.js?stamp=${DateTime.now().millisecondsSinceEpoch}';
    final text = await html.HttpRequest.getString(url);
    final match =
        RegExp(r'serviceWorkerVersion:\s*"([^"]+)"').firstMatch(text);
    return match?.group(1);
  } catch (_) {
    // Offline, blocked, or the file moved. Silence is correct: a failed check
    // must never be read as "a new release exists".
    return null;
  }
}
