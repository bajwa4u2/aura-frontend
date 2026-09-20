import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The Windows push channel, and an honest account of when there isn't one.
///
/// A WNS channel URI is issued by the OS to a **packaged** application — it is
/// a property of the MSIX identity, not of the executable. A debug run or a
/// bare `Release\aura.exe` has no identity, so there is no channel to get, and
/// this returns null rather than pretending. That distinction matters: "no
/// channel because unpackaged" is a development condition, while "no channel
/// from the installed app" would be a real defect, and collapsing the two would
/// hide the second behind the first.
class WindowsPushChannel {
  const WindowsPushChannel({required this.uri, this.expiresAt});

  final String uri;
  final DateTime? expiresAt;

  /// The OS retires channels. Re-registering while a good margin remains is
  /// cheaper than discovering expiry from a 410 on the next incoming call —
  /// which would be discovered by a call that failed to ring.
  bool get nearingExpiry {
    final at = expiresAt;
    if (at == null) return false;
    return at.difference(DateTime.now().toUtc()) < const Duration(days: 2);
  }
}

class WindowsPushService {
  static const MethodChannel _channel =
      MethodChannel('org.auraplatform.app/wns');

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  /// Ask the OS for this install's channel. Null means no channel is available
  /// here, with the reason logged — never an exception into the caller, because
  /// device registration must not fail wholesale over one platform's transport.
  static Future<WindowsPushChannel?> createChannel() async {
    if (!isSupported) return null;
    try {
      final result =
          await _channel.invokeMapMethod<String, dynamic>('createChannel');
      final uri = (result?['channelUri'] as String?)?.trim() ?? '';
      if (uri.isEmpty) return null;

      DateTime? expires;
      final raw = result?['expiresAt'];
      if (raw is int && raw > 0) {
        expires = DateTime.fromMillisecondsSinceEpoch(raw * 1000, isUtc: true);
      }
      return WindowsPushChannel(uri: uri, expiresAt: expires);
    } on PlatformException catch (e) {
      // WNS_UNAVAILABLE is the expected answer when running unpackaged.
      debugPrint('WindowsPushService.createChannel unavailable: ${e.code}');
      return null;
    } catch (e) {
      debugPrint('WindowsPushService.createChannel failed: $e');
      return null;
    }
  }

  /// Call payloads as they arrive, whether Aura was open or was started by the
  /// push.
  ///
  /// Broadcast because the app root listens for the lifetime of the process;
  /// there is exactly one producer, the native receiver.
  static final StreamController<Map<String, dynamic>> _calls =
      StreamController<Map<String, dynamic>>.broadcast();

  static Stream<Map<String, dynamic>> get callPushes => _calls.stream;

  static bool _listening = false;

  /// Begin receiving. Safe to call more than once.
  ///
  /// Three things happen here and they are deliberately in one place: the
  /// handler for pushes that arrive while Aura is open, the registration that
  /// lets Windows start Aura for a push when it is closed, and the collection
  /// of a payload recorded by that background task before Dart existed.
  static Future<void> start() async {
    if (!isSupported || _listening) return;
    _listening = true;

    _channel.setMethodCallHandler((call) async {
      if (call.method != 'onCallPush') return null;
      final payload = _decode(call.arguments);
      if (payload != null) _calls.add(payload);
      return null;
    });

    // A machine that refuses this still rings while Aura is open. The answer
    // is logged rather than thrown for that reason.
    try {
      final registered =
          await _channel.invokeMethod<bool>('registerBackgroundTask');
      if (registered != true) {
        debugPrint(
          'WindowsPushService: background call delivery not registered; '
          'calls will ring only while Aura is open.',
        );
      }
    } catch (e) {
      debugPrint('WindowsPushService.registerBackgroundTask failed: $e');
    }

    // COLD START. The call arrived before this process existed — the push is
    // what started it — so it is waiting in the package's local folder rather
    // than on the stream above.
    await drainPending();
  }

  /// Collect a call recorded while Aura was closed, if there is one.
  static Future<void> drainPending() async {
    if (!isSupported) return;
    try {
      final pending = await _channel.invokeMethod<String>('takePendingCallPush');
      final payload = _decode(pending);
      if (payload != null) _calls.add(payload);
    } catch (e) {
      debugPrint('WindowsPushService.takePendingCallPush failed: $e');
    }
  }

  /// The raw body the server sent, as a map.
  ///
  /// The WNS adapter sends `{type, title, body, data:{…}}` — the same shape the
  /// call projection authority already reads, `data` nested and all — so this
  /// decodes and hands it over without reshaping it into a third dialect.
  static Map<String, dynamic>? _decode(Object? raw) {
    if (raw is! String) return null;
    final text = raw.trim();
    if (text.isEmpty) return null;
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (e) {
      debugPrint('WindowsPushService: unreadable call payload ($e)');
    }
    return null;
  }
}
