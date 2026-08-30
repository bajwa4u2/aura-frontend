import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// THE IOS HALF OF CALL ARRIVAL — AND ONLY THE PRESENTATION HALF.
///
/// Native `AppDelegate.swift` owns the two things only iOS can do: receive a
/// PushKit VoIP push, and put a real incoming-call screen on the lock screen
/// through CallKit. Everything about whether a call *exists* stays where it
/// already lives — the Aura backend's session and invite lifecycle. This class
/// is the seam between them, and it is deliberately thin: it forwards user
/// intent inwards and backend truth outwards, and decides nothing itself.
///
/// The seam runs in one direction for each concern:
///
///   native → Dart   a VoIP token appeared or rotated; the user answered;
///                   the user declined; the system refused the call
///   Dart → native   this session is over — because the backend said so, not
///                   because a screen was dismissed
class IosCallKit {
  IosCallKit._();

  static final IosCallKit instance = IosCallKit._();

  static const MethodChannel _channel =
      MethodChannel('org.auraplatform.app/callkit');

  bool _started = false;

  /// Called with a PushKit VoIP token whenever one is issued or rotated.
  ///
  /// THIS IS NOT THE FCM TOKEN. It is a separate credential from a separate
  /// registry with its own lifetime, and overloading the two was the specific
  /// mistake this design avoids: an FCM token registered as VoIP silently
  /// receives nothing, because APNs routes VoIP pushes on a different topic.
  Future<void> Function(String token)? onVoipToken;

  /// The VoIP token was invalidated by iOS. The backend row should be
  /// deactivated rather than left to fail delivery forever.
  Future<void> Function()? onVoipTokenInvalidated;

  /// The person answered on the CallKit screen. The implementation must join
  /// the Aura session, and MUST call [reportEnded] with `failed` if the join
  /// does not succeed — otherwise the system call UI sits there connected to
  /// nothing.
  Future<void> Function(String sessionId)? onAnswer;

  /// The person declined, or ended a call that had been answered. The backend
  /// decline/leave is what makes it true; CallKit has already dismissed.
  Future<void> Function(String sessionId)? onEnd;

  /// iOS accepted the push but refused to present the call — Do Not Disturb, a
  /// blocked caller, or a call that had already ended. Worth surfacing so the
  /// invite is not left pending in the UI on a device that will never ring.
  Future<void> Function(String sessionId, String reason)? onRejectedBySystem;

  /// A VoIP push arrived and a call screen is now up.
  ///
  /// THIS IS THE RECONCILIATION SEAM, AND IT WAS NEVER CONNECTED. Presentation
  /// has already happened natively, but Aura's own incoming-call state only
  /// ever learned about a call from the socket. When the VoIP push was the
  /// thing that arrived — which is the whole point of PushKit — CallKit and
  /// the app held two unrelated opinions about whether a call existed: the
  /// phone rang and nothing in Aura knew it.
  ///
  /// The full native payload is handed over, not just an id, because the VoIP
  /// dictionary already carries the caller's identity and the invite's expiry.
  /// Anything less would force the app to re-derive what the push already
  /// said.
  Future<void> Function(Map<String, dynamic> payload)? onIncomingCall;

  bool get isSupported => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// Bind the channel and drain anything native queued while Dart was still
  /// booting. A VoIP push routinely beats the Flutter engine on a cold start —
  /// the call screen is already visible before `main()` has finished — so the
  /// native side buffers and this is what releases it.
  Future<void> start() async {
    if (!isSupported || _started) return;
    _started = true;
    _channel.setMethodCallHandler(_dispatch);
    try {
      await _channel.invokeMethod<void>('ready');
    } catch (e) {
      debugPrint('[callkit] ready failed: $e');
    }
  }

  /// Tell CallKit a session is over, with a truthful reason.
  ///
  /// Every caller of this is a BACKEND fact: answered on another device,
  /// caller ended it, the invite expired, the join failed. None of them is a
  /// UI event. This is the method that stops a phone ringing at a call that
  /// no longer exists, and the reason is carried through so the system call
  /// log does not describe a missed call as a declined one.
  Future<void> reportEnded(String sessionId, {required String reason}) async {
    if (!isSupported || sessionId.isEmpty) return;
    try {
      await _channel.invokeMethod<bool>('endCall', {
        'sessionId': sessionId,
        'reason': reason,
      });
    } catch (e) {
      debugPrint('[callkit] endCall failed: $e');
    }
  }

  /// The media path is up after an answer. Moves the system call UI out of
  /// "connecting" so the timer reflects the real call.
  Future<void> reportConnected(String sessionId) async {
    if (!isSupported || sessionId.isEmpty) return;
    try {
      await _channel.invokeMethod<bool>('callConnected', {'sessionId': sessionId});
    } catch (e) {
      debugPrint('[callkit] callConnected failed: $e');
    }
  }

  Future<String?> currentVoipToken() async {
    if (!isSupported) return null;
    try {
      return await _channel.invokeMethod<String>('voipToken');
    } catch (_) {
      return null;
    }
  }

  Future<dynamic> _dispatch(MethodCall call) async {
    if (call.method != 'onCallEvent') return null;
    final args = (call.arguments as Map?)?.cast<String, dynamic>() ?? const {};
    final event = (args['event'] as String?) ?? '';
    final sessionId = (args['sessionId'] as String?) ?? '';

    switch (event) {
      case 'voipToken':
        final token = (args['token'] as String?) ?? '';
        if (token.isNotEmpty) await onVoipToken?.call(token);
        break;
      case 'voipTokenInvalidated':
        await onVoipTokenInvalidated?.call();
        break;
      case 'incomingCall':
        await onIncomingCall?.call(args);
        break;
      case 'answer':
        await onAnswer?.call(sessionId);
        break;
      case 'end':
        await onEnd?.call(sessionId);
        break;
      case 'callRejectedBySystem':
        await onRejectedBySystem?.call(
          sessionId,
          (args['reason'] as String?) ?? 'rejected',
        );
        break;
      default:
        break;
    }
    return null;
  }
}
