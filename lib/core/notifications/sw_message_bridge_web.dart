import 'dart:js_interop';

import 'package:web/web.dart';

EventListener? _listener;

/// Listens for `{ type: 'AURA_NAVIGATE', deeplink: '...' }` messages posted
/// by the service worker when `client.navigate()` is unavailable (Safari).
void listenForSwNavigate(void Function(String deeplink) onNavigate) {
  stopSwNavigateListener();

  void handle(Event event) {
    try {
      final e = event as MessageEvent;
      final raw = e.data.dartify();
      if (raw is! Map) return;
      if (raw['type'] != 'AURA_NAVIGATE') return;
      final deeplink = (raw['deeplink'] ?? '').toString().trim();
      if (deeplink.isNotEmpty) onNavigate(deeplink);
    } catch (_) {}
  }

  final jsHandler = handle.toJS;
  _listener = jsHandler;

  try {
    window.navigator.serviceWorker.addEventListener('message', jsHandler);
  } catch (_) {}
}

void stopSwNavigateListener() {
  final l = _listener;
  if (l == null) return;
  try {
    window.navigator.serviceWorker.removeEventListener('message', l);
  } catch (_) {}
  _listener = null;
}
