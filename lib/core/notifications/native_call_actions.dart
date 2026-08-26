import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/services.dart';

/// What a person did to a natively-presented incoming call.
///
/// Since 2026-08-25 an incoming Android call is drawn by the app itself
/// (`IncomingCallPresenter`) rather than by the Firebase SDK. That is what
/// makes it a call — full-screen, un-swipeable, ringing for the invite's whole
/// window — but it also means `FirebaseMessaging.onMessageOpenedApp` no longer
/// fires for it: that stream only reports taps on SDK-drawn notifications.
/// This channel carries the act across in its place.
enum NativeCallAction {
  /// The Answer control on the call notification. An unambiguous, explicit
  /// accept.
  answer,

  /// The Decline control. Equally explicit, and the opposite.
  decline,

  /// The notification body, or the full-screen call surface. NOT an answer —
  /// founder ruling 2026-08-14: this must offer the same Accept/Decline choice
  /// a foreground call gets, never join on the recipient's behalf.
  open,
}

class NativeCallActionEvent {
  const NativeCallActionEvent({
    required this.action,
    required this.sessionId,
    required this.data,
  });

  final NativeCallAction action;
  final String sessionId;

  /// The original call push, so the incoming-call bridge can render the same
  /// card it would have rendered for a socket-delivered ring.
  final Map<String, dynamic> data;

  @override
  String toString() =>
      'NativeCallActionEvent(${action.name}, session=$sessionId, keys=${data.keys.length})';
}

/// Bridges native incoming-call acts into Dart.
///
/// Two delivery paths, because the engine may or may not exist when the person
/// acts:
///
/// * **warm** — `MainActivity` invokes `onCallAction` and [onAction] fires;
/// * **cold** — the act is held natively and drained by [consumePending] once
///   Dart is running. Without this, answering a call from a killed app would
///   open an app that had forgotten the call.
class NativeCallActions {
  NativeCallActions._();

  static final NativeCallActions instance = NativeCallActions._();

  static const MethodChannel _channel = MethodChannel(
    'org.auraplatform.app/notifications',
  );

  void Function(NativeCallActionEvent event)? onAction;

  bool get _supported => !kIsWeb && Platform.isAndroid;

  bool _listening = false;

  void listen() {
    if (!_supported || _listening) return;
    _listening = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'onCallAction') return null;
      final event = _parse(call.arguments);
      if (event != null) {
        debugPrint('[native-call] warm action: $event');
        // The warm path has the act, so retire the native fallback slot.
        // Without this BOTH paths deliver: measured 2026-08-25, one answer
        // arrived warm at t+1ms and again from the pending drain at t+225ms.
        // The overlay's once-only guard absorbed it, but a duplicate delivery
        // that only a downstream guard makes harmless is still a duplicate.
        unawaited(_channel.invokeMethod<dynamic>('consumePendingCallAction'));
        onAction?.call(event);
      }
      return null;
    });
  }

  /// Drains an act that happened before Dart could hear it. Returns at most
  /// once per act — the native side clears it on read, which is what stops an
  /// answered call from being answered again on the next resume.
  Future<NativeCallActionEvent?> consumePending() async {
    if (!_supported) return null;
    try {
      final raw = await _channel.invokeMethod<dynamic>('consumePendingCallAction');
      final event = _parse(raw);
      if (event != null) debugPrint('[native-call] drained pending action: $event');
      return event;
    } catch (error) {
      debugPrint('[native-call] consumePendingCallAction failed: $error');
      return null;
    }
  }

  /// Drains a pending act and dispatches it to [onAction].
  ///
  /// Called from two places on purpose: once after the first frame (cold
  /// start, where the act happened before Dart existed) and again on every
  /// resume (the act can land while the engine is detached). Draining twice is
  /// safe — the native side clears the slot on read.
  Future<void> drainPending() async {
    final event = await consumePending();
    if (event == null) return;
    onAction?.call(event);
  }

  /// Whether Android will actually let a call present full-screen.
  ///
  /// Android 14 stopped granting `USE_FULL_SCREEN_INTENT` to every app that
  /// asks. Reported rather than assumed, so "the call presented as a call" and
  /// "Android degraded it to a heads-up notification" are distinguishable
  /// facts instead of one hopeful claim.
  Future<bool> canPresentFullScreen() async {
    if (!_supported) return false;
    try {
      return await _channel.invokeMethod<bool>('canUseFullScreenIntent') ?? false;
    } catch (error) {
      debugPrint('[native-call] canUseFullScreenIntent failed: $error');
      return false;
    }
  }

  NativeCallActionEvent? _parse(dynamic raw) {
    if (raw is! Map) return null;
    final action = switch ((raw['action'] ?? '').toString().trim()) {
      'answer' => NativeCallAction.answer,
      'decline' => NativeCallAction.decline,
      'open' => NativeCallAction.open,
      _ => null,
    };
    if (action == null) return null;

    final data = <String, dynamic>{};
    final rawData = raw['data'];
    if (rawData is Map) {
      for (final entry in rawData.entries) {
        data[entry.key.toString()] = entry.value;
      }
    }
    return NativeCallActionEvent(
      action: action,
      sessionId: (raw['sessionId'] ?? '').toString().trim(),
      data: data,
    );
  }
}
