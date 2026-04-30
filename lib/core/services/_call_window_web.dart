// Web-specific implementation using dart:html window APIs.
// Opened under the named target 'aura_call' so re-open always reuses
// the same tab rather than creating duplicates.
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

// Stored as dynamic so we can call .focus() which exists on Window
// (the actual runtime type) but not on the declared WindowBase type.
dynamic _callWindow;

bool webWindowIsOpen() {
  final w = _callWindow;
  if (w == null) return false;
  // ignore: avoid_dynamic_calls
  return !(w.closed as bool? ?? true);
}

void webWindowOpen(String url) {
  if (webWindowIsOpen()) {
    webWindowFocus();
    return;
  }
  _callWindow = html.window.open(
    url,
    'aura_call',
    'width=1280,height=800,resizable=yes,toolbar=no,menubar=no,scrollbars=no',
  );
}

void webWindowFocus() {
  // ignore: avoid_dynamic_calls
  _callWindow?.focus();
}

void webWindowClose() {
  if (webWindowIsOpen()) {
    // ignore: avoid_dynamic_calls
    _callWindow?.close();
  }
  _callWindow = null;
}
