import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// THE ANDROID HALF OF NATIVE CALL LIFECYCLE.
///
/// Deliberately the same shape as [IosCallKit] — report started, report
/// connected, report ended, hear back when the system acts — because the
/// existing call code already reports those four things and this must be
/// reportable from the SAME places rather than from new ones. A second set of
/// call sites would be a second lifecycle to keep correct.
///
/// ── IT IS NOT A RINGING SURFACE ──────────────────────────────────────────
///
/// These are SELF-MANAGED calls: Android draws no incoming-call screen for
/// them, the app does. `IncomingCallPresenter` remains exactly what a person
/// sees, unchanged and still certified. What registering with Telecom buys is
/// everything underneath — audio focus, Bluetooth and wired routing, and
/// concurrency with the dialer — done the way the system does it for every
/// other call on the device.
///
/// ── NOTHING BRANCHES ON WHETHER IT WORKED ────────────────────────────────
///
/// Every method is best-effort and silent. Telecom can refuse a call, the
/// device can be too old, and a future policy could withhold it; in all three
/// cases the Aura call behaves exactly as it did before this file existed. The
/// return value says whether the OS will show the call in its own surfaces,
/// and that is the only thing it may be read for.
class AndroidTelecom {
  AndroidTelecom._();

  static final AndroidTelecom instance = AndroidTelecom._();

  static const MethodChannel _channel =
      MethodChannel('org.auraplatform.app/telecom');

  bool _started = false;

  /// The system answered — a Bluetooth headset button, a car, a wearable.
  ///
  /// Carried to the app rather than acted on here. Founder ruling 2026-08-14:
  /// answering must reach the same accept path a foreground call gets, and
  /// nothing may join on the recipient's behalf behind it.
  Future<void> Function(String sessionId)? onAnswer;

  /// The system disconnected the call — a cellular call took priority, or the
  /// person ended it from a system surface.
  Future<void> Function(String sessionId)? onDisconnect;

  /// The call was put on hold, or taken off it. A held Aura call must go quiet
  /// rather than carry on into a conversation the person is no longer in.
  Future<void> Function(String sessionId, bool active)? onHoldChanged;

  /// Android only. Everywhere else the channel has no handler, and every
  /// method below returns without doing anything.
  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Calls THIS device placed, by session id.
  ///
  /// THE CALLER ENDED ITS OWN CALL THE MOMENT IT WAS ANSWERED. Root-caused
  /// 2026-09-25 from an iPhone's system log (TestFlight 1.5.0 (40), iPhone
  /// calling a Pixel): the Pixel accepted, the session's `participant.accepted`
  /// reached the caller, the incoming-call bridge projected it as "stop
  /// ringing", and its terminal choke point reported the system call ended.
  /// The system call id is derived from the session id in BOTH directions, so
  /// what it ended was the call this phone had placed:
  ///
  ///   05:34:35.854  Provider was asked to report that call ... ended ... reason 2
  ///   05:34:35.854  callservicesd: Setting disconnected reason to remote hangup
  ///   05:34:35.941  AudioToolboxServerHandleInterruption Stop Now ... Runner
  ///
  /// On iOS CallKit tore down the audio session: video carried on, audio died both
  /// ways, and an audio-only call looked as if it never connected. Present
  /// since outgoing calls were first reported (5ffed711, 1.4.2).
  ///
  /// A ring can only end on a phone that rang. [reportRingEnded] consults this
  /// set; [reportEnded] — the call really ending — does not, and retires it.
  final Set<String> _placed = <String>{};

  /// Whether this device placed [sessionId]. For tests and diagnostics.
  @visibleForTesting
  bool placedHere(String sessionId) => _placed.contains(sessionId.trim());

  @visibleForTesting
  void resetPlacedForTest() => _placed.clear();

  Future<void> start() async {
    if (!isSupported || _started) return;
    _started = true;
    _channel.setMethodCallHandler(_dispatch);
  }

  Future<dynamic> _dispatch(MethodCall call) async {
    final args = call.arguments;
    final sessionId =
        args is Map ? (args['sessionId'] ?? '').toString().trim() : '';
    if (sessionId.isEmpty) return null;

    switch (call.method) {
      case 'onAnswer':
        await onAnswer?.call(sessionId);
      case 'onDisconnect':
        await onDisconnect?.call(sessionId);
      case 'onSetActive':
        await onHoldChanged?.call(sessionId, true);
      case 'onSetInactive':
        await onHoldChanged?.call(sessionId, false);
    }
    return null;
  }

  /// Whether Aura may participate in the system call stack right now.
  ///
  /// Asked of the native policy rather than decided here. Today it answers
  /// yes on any Android 8.0+ device — there is no known Android restriction
  /// and none has been invented — but the question is asked so that if one is
  /// ever established, every caller already honours it.
  Future<bool> isAvailable() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// A call is ringing. Registers it with Telecom so the system knows a call
  /// is in progress before the person has answered it.
  Future<bool> reportIncoming(
    String sessionId, {
    required String displayName,
    required bool video,
  }) =>
      _report('reportIncoming', sessionId, displayName, video);

  /// A call Aura is PLACING. Without this an outgoing call participates in no
  /// audio-routing decision and has no relationship to a cellular call
  /// arriving during it.
  Future<bool> reportOutgoing(
    String sessionId, {
    required String displayName,
    required bool video,
  }) {
    if (isSupported && sessionId.trim().isNotEmpty) {
      _placed.add(sessionId.trim());
    }
    return _report('reportOutgoing', sessionId, displayName, video);
  }

  Future<bool> _report(
    String method,
    String sessionId,
    String displayName,
    bool video,
  ) async {
    if (!isSupported || sessionId.trim().isEmpty) return false;
    try {
      final ok = await _channel.invokeMethod<bool>(method, {
        'sessionId': sessionId,
        'displayName': displayName,
        'video': video,
      });
      return ok ?? false;
    } catch (e) {
      debugPrint('[telecom] $method failed: $e');
      return false;
    }
  }

  /// Media is up. Moves the system call out of "connecting", which is what
  /// gives an entry a real duration rather than none.
  Future<void> reportConnected(String sessionId) async {
    if (!isSupported || sessionId.trim().isEmpty) return;
    try {
      await _channel.invokeMethod<void>('reportConnected', {
        'sessionId': sessionId,
      });
    } catch (e) {
      debugPrint('[telecom] reportConnected failed: $e');
    }
  }

  /// The call is over, with a truthful reason.
  ///
  /// The reason is carried because system call history is user-visible: a call
  /// answered on another device must not be recorded as declined, and one that
  /// expired must not be recorded as ended by the caller. Where Aura genuinely
  /// cannot tell the difference the honest default is a plain local
  /// disconnect, and nothing invents it.
  Future<void> reportEnded(String sessionId, {required String reason}) async {
    if (!isSupported || sessionId.trim().isEmpty) return;
    _placed.remove(sessionId.trim());
    try {
      await _channel.invokeMethod<void>('reportEnded', {
        'sessionId': sessionId,
        'reason': reason,
      });
    } catch (e) {
      debugPrint('[telecom] reportEnded failed: $e');
    }
  }

  /// A RING is over. Ends the system call only if this device was ringing for
  /// it — never a call it placed. See [_placed].
  Future<void> reportRingEnded(String sessionId, {required String reason}) async {
    if (_placed.contains(sessionId.trim())) {
      debugPrint('[telecom] ring-clear ignored for a call placed here '
          'session=$sessionId reason=$reason');
      return;
    }
    await reportEnded(sessionId, reason: reason);
  }
}
