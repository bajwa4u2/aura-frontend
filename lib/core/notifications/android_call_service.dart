import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// KEEPS A CALL ALIVE WHEN AURA IS NO LONGER THE APP ON SCREEN.
///
/// ── THE DEFECT ───────────────────────────────────────────────────────────
///
/// Measured on a Pixel, 2026-09-09: HOME was pressed, the transport closed,
/// no replacement was ever created, and for the next four minutes both people
/// were shown a call that had stopped carrying anything — "Connected · 2 ·
/// 02:52" on one side, a frozen last frame on the other.
///
/// From Android 14, an app that is not on screen loses the microphone and the
/// camera unless a foreground service of the matching type is running. Aura
/// ran none: the permissions had been declared, found inert, and removed.
/// `AuraCallService` is the service; this is the door to it.
///
/// ── IT DECIDES NOTHING ───────────────────────────────────────────────────
///
/// Start when a call becomes active, stop when it is over. It holds no call
/// state, and it is never consulted about whether a call exists — a second
/// opinion about that is precisely what this chapter has been removing.
///
/// Best-effort and silent, like [AndroidTelecom] beside it: Android can
/// refuse a background service start, and when it does the call carries on
/// exactly as it does today, without the protection. Nothing branches on the
/// result except diagnostics.
class AndroidCallService {
  AndroidCallService._();

  static final AndroidCallService instance = AndroidCallService._();

  static const MethodChannel _channel =
      MethodChannel('org.auraplatform.app/call_service');

  /// Android only. Everywhere else the channel has no handler and every
  /// method below returns without doing anything.
  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// The session this device believes the service is representing. Kept so a
  /// stop can name its call, and so a second start for the same call is not
  /// sent twice.
  String? _activeSessionId;

  String? get activeSessionId => _activeSessionId;

  /// A call is up. Safe to call repeatedly for the same session.
  Future<bool> start(
    String sessionId, {
    required bool video,
    String title = '',
  }) async {
    if (!isSupported) return false;
    final id = sessionId.trim();
    if (id.isEmpty) return false;
    // A video call that started as audio must restate its type, because the
    // camera is a separate foreground-service type and Android refuses
    // capture under a type that was not declared.
    if (_activeSessionId == id && !video) return true;
    try {
      final ok = await _channel.invokeMethod<bool>('start', <String, dynamic>{
        'sessionId': id,
        'video': video,
        'title': title,
      });
      if (ok == true) _activeSessionId = id;
      return ok == true;
    } catch (e) {
      debugPrint('[call-service] start failed: $e');
      return false;
    }
  }

  /// The call is over — for any reason, from any side.
  ///
  /// An empty [sessionId] means "stop whatever is running", for the teardown
  /// paths that cannot name the call they are ending. A service that outlives
  /// its call holds the microphone, so every terminal path may call this and
  /// none of them needs to know whether another already did.
  Future<bool> stop([String sessionId = '']) async {
    if (!isSupported) return false;
    final id = sessionId.trim();
    if (id.isNotEmpty && _activeSessionId != null && _activeSessionId != id) {
      // A stale stop for a call that already ended must not tear down the one
      // now running.
      return false;
    }
    _activeSessionId = null;
    try {
      final ok = await _channel.invokeMethod<bool>('stop', <String, dynamic>{
        'sessionId': id,
      });
      return ok == true;
    } catch (e) {
      debugPrint('[call-service] stop failed: $e');
      return false;
    }
  }

  /// Whether the native service is running. For diagnostics and tests — never
  /// as a source of truth about whether a call exists.
  Future<bool> isRunning() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('isRunning') == true;
    } catch (_) {
      return false;
    }
  }
}
