// Web implementation using BroadcastChannel and beforeunload.
// Messages are JSON-encoded strings so they survive structured-clone boundaries.
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:convert';

html.BroadcastChannel? _channel;
void Function(Map<String, dynamic>)? _handler;
html.EventListener? _listener;
bool _unloadRegistered = false;

void initPresenceChannel(
  String name,
  void Function(Map<String, dynamic>) onMessage,
) {
  closePresenceChannel();
  _handler = onMessage;

  final channel = html.BroadcastChannel(name);
  _channel = channel;

  _listener = (html.Event event) {
    final msg = event as html.MessageEvent;
    final raw = msg.data;
    Map<String, dynamic>? parsed;
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          parsed = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }
    if (parsed != null) _handler?.call(parsed);
  };
  channel.addEventListener('message', _listener);
}

void postPresenceMessage(Map<String, dynamic> data) {
  _channel?.postMessage(jsonEncode(data));
}

void closePresenceChannel() {
  final l = _listener;
  if (l != null) {
    _channel?.removeEventListener('message', l);
    _listener = null;
  }
  _channel?.close();
  _channel = null;
  _handler = null;
}

void registerWindowUnloadCallback(void Function() callback) {
  if (_unloadRegistered) return;
  _unloadRegistered = true;
  html.window.addEventListener('beforeunload', (_) => callback());
}
