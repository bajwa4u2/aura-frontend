// Web implementation. Two transports, both fire in *other* tabs only:
//   - BroadcastChannel (preferred): clean message passing, no polling.
//   - localStorage 'storage' event (fallback): always supported.
// We use both so private-mode browsers without BroadcastChannel still sync.
//
// Messages are JSON-encoded with a `type` field. The receiver normalizes
// to a single string token (`logout` / `login`) and hands it to the
// caller-provided dispatcher; no business logic lives here.

// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:convert';

const String _channelName = 'aura_auth_broadcast';
const String _storageKey = 'aura_auth_broadcast_event';

html.BroadcastChannel? _channel;
html.EventListener? _channelListener;
html.EventListener? _storageListener;
void Function(String type)? _handler;

void initAuthBroadcast(void Function(String type) onMessage) {
  closeAuthBroadcast();
  _handler = onMessage;

  // BroadcastChannel transport.
  try {
    final channel = html.BroadcastChannel(_channelName);
    _channelListener = (html.Event event) {
      final msg = event as html.MessageEvent;
      _dispatch(msg.data);
    };
    channel.addEventListener('message', _channelListener);
    _channel = channel;
  } catch (_) {
    // Older browsers / private modes may not expose BroadcastChannel.
    _channel = null;
  }

  // Storage-event fallback. Storage events fire only in OTHER tabs sharing
  // the same origin, which is exactly the cross-tab semantics we want.
  _storageListener = (html.Event event) {
    if (event is! html.StorageEvent) return;
    if (event.key != _storageKey) return;
    _dispatch(event.newValue);
  };
  html.window.addEventListener('storage', _storageListener);
}

void publishAuthEvent(String type) {
  final payload = jsonEncode({
    'type': type,
    'ts': DateTime.now().millisecondsSinceEpoch,
    // A nonce prevents storage-event coalescing when the same type fires
    // twice in quick succession (browsers skip duplicate writes).
    'nonce': '${DateTime.now().microsecondsSinceEpoch}',
  });
  try {
    _channel?.postMessage(payload);
  } catch (_) {
    // ignore — storage path will still fire
  }
  try {
    html.window.localStorage[_storageKey] = payload;
  } catch (_) {
    // private-browsing localStorage may throw; nothing more to do.
  }
}

void closeAuthBroadcast() {
  final cl = _channelListener;
  if (cl != null) {
    try {
      _channel?.removeEventListener('message', cl);
    } catch (_) {}
    _channelListener = null;
  }
  try {
    _channel?.close();
  } catch (_) {}
  _channel = null;

  final sl = _storageListener;
  if (sl != null) {
    try {
      html.window.removeEventListener('storage', sl);
    } catch (_) {}
    _storageListener = null;
  }

  _handler = null;
}

void _dispatch(dynamic raw) {
  if (raw == null) return;
  String? text;
  if (raw is String) {
    text = raw;
  } else {
    text = raw.toString();
  }
  if (text.isEmpty) return;
  try {
    final decoded = jsonDecode(text);
    if (decoded is Map) {
      final type = (decoded['type'] ?? '').toString().trim();
      if (type.isEmpty) return;
      _handler?.call(type);
    }
  } catch (_) {
    // malformed payload — drop silently
  }
}
