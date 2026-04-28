import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart';

import 'web_push_types.dart';

export 'web_push_types.dart';

/// Web Push subscription service for browser targets.
///
/// Uses the service worker at [_swPath] registered at [_swScope] — a path
/// that does not overlap with Flutter's root-scope service worker, preventing
/// caching conflicts while still receiving push events for this origin.
class WebPushService {
  const WebPushService._();

  static const _swPath = '/push/sw.js';
  static const _swScope = '/push/';

  // ── Support / permission ──────────────────────────────────────────────────

  static bool get isSupported {
    try {
      window.navigator.serviceWorker;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Returns `'granted'`, `'denied'`, `'default'`, or `'unavailable'`.
  static String get permission {
    try {
      return Notification.permission;
    } catch (_) {
      return 'unavailable';
    }
  }

  // ── Service worker registration ───────────────────────────────────────────

  static Future<ServiceWorkerRegistration?> _getOrRegisterSW() async {
    try {
      final container = window.navigator.serviceWorker;
      // Check for an existing registration at the push scope first.
      final existing = await container.getRegistration(_swScope).toDart;
      if (existing != null) return existing;
      // Not yet registered — register and return the ServiceWorkerRegistration
      // directly from the promise rather than calling getRegistration() again,
      // which avoids a race between installation and the lookup.
      final reg = await container.register(_swPath.toJS).toDart;
      return reg;
    } catch (_) {
      return null;
    }
  }

  // ── Subscription ──────────────────────────────────────────────────────────

  /// Returns an existing subscription silently without requesting permission.
  static Future<WebPushResult?> getExistingSubscription() async {
    try {
      final reg = await _getOrRegisterSW();
      if (reg == null) return null;
      final sub = await reg.pushManager.getSubscription().toDart;
      if (sub == null) return null;
      return _extractResult(sub);
    } catch (_) {
      return null;
    }
  }

  /// Requests browser notification permission. Returns `'granted'`, `'denied'`,
  /// or `'default'`. Does NOT subscribe — call [subscribe] afterward.
  static Future<String> requestPermission() async {
    try {
      final result = await Notification.requestPermission().toDart;
      return result.toDart;
    } catch (_) {
      return 'denied';
    }
  }

  /// Subscribes to push using [vapidPublicKey] (base64url-encoded VAPID public
  /// key). Returns null if permission is denied or subscription fails.
  static Future<WebPushResult?> subscribe(String vapidPublicKey) async {
    if (vapidPublicKey.isEmpty) return null;
    try {
      final reg = await _getOrRegisterSW();
      if (reg == null) return null;

      final keyBytes = _urlBase64Decode(vapidPublicKey);
      final options = PushSubscriptionOptionsInit(
        userVisibleOnly: true,
        applicationServerKey: keyBytes.toJS,
      );

      final sub = await reg.pushManager.subscribe(options).toDart;
      return _extractResult(sub);
    } catch (_) {
      return null;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static WebPushResult _extractResult(PushSubscription sub) {
    final endpoint = sub.endpoint;
    final p256dhBuf = sub.getKey('p256dh');
    final authBuf = sub.getKey('auth');
    return WebPushResult(
      endpoint: endpoint,
      p256dh: p256dhBuf != null ? _bufferToBase64Url(p256dhBuf) : null,
      auth: authBuf != null ? _bufferToBase64Url(authBuf) : null,
    );
  }

  static String _bufferToBase64Url(JSArrayBuffer buffer) {
    final bytes = buffer.toDart.asUint8List();
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  static Uint8List _urlBase64Decode(String input) {
    final normalized = input.replaceAll('-', '+').replaceAll('_', '/');
    final padded = normalized.padRight((normalized.length + 3) & ~3, '=');
    return base64Decode(padded);
  }
}
