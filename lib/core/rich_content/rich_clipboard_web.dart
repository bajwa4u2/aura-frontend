/// Item 15 — Rich Paste, web implementation.
///
/// Flutter's built-in `Clipboard.getData` only ever reads the
/// `text/plain` clipboard flavor on every platform, including web -- there
/// is no first-party Flutter API for the `text/html` flavor a browser
/// populates when copying formatted content (an article, a rich email).
/// This uses the browser's own async Clipboard API (`navigator.clipboard`,
/// already exposed via the existing `package:web` dependency, no new
/// package added) to read that flavor directly.
///
/// Requires a secure context (https, which every deployed Aura host is)
/// and is gated by the Clipboard-Read permission, which the browser
/// resolves implicitly for a paste triggered by a user gesture (Ctrl+V,
/// the context-menu Paste item) -- exactly the situation this is invoked
/// from (see `rich_paste_action.dart`'s `PasteTextIntent` override).
library;

import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<String?> readClipboardHtml() async {
  try {
    final clipboard = web.window.navigator.clipboard;
    final items = await clipboard.read().toDart;
    for (final item in items.toDart) {
      final types = item.types.toDart.map((t) => t.toDart).toList();
      if (!types.contains('text/html')) continue;
      final blob = await item.getType('text/html').toDart;
      final text = await blob.text().toDart;
      final html = text.toDart;
      if (html.trim().isNotEmpty) return html;
    }
  } catch (_) {
    // Permission denied, unsupported browser, empty clipboard, or any
    // other clipboard-API failure -- the caller falls back to Flutter's
    // normal plain-text paste, exactly today's existing behavior. Never
    // block or corrupt a paste because the rich-read attempt failed.
  }
  return null;
}
