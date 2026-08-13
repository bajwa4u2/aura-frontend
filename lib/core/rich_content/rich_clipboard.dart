// Item 15 — Rich Paste. Public entry point; resolves to the web
// implementation when compiling for web, the no-op stub everywhere else,
// via Dart's standard conditional-export mechanism (`dart.library.js_interop`
// is only available in web builds).
export 'rich_clipboard_io.dart' if (dart.library.js_interop) 'rich_clipboard_web.dart';
