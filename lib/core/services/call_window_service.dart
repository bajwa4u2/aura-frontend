import 'package:flutter_riverpod/flutter_riverpod.dart';

import '_call_window_stub.dart'
    if (dart.library.html) '_call_window_web.dart';

final callWindowServiceProvider = Provider<CallWindowService>((ref) {
  return CallWindowService();
});

/// Manages the lifecycle of the dedicated call popup window.
///
/// On web: opens a named popup (`aura_call`) to `/realtime/:sessionId`
/// so the full call surface appears outside the messages tab. Re-opening
/// the same session focuses the existing window rather than spawning a new one.
///
/// On non-web (mobile/desktop): all operations are no-ops — the caller
/// navigates within the app via `context.go()` instead.
class CallWindowService {
  String? _sessionId;

  String? get activeSessionId => _sessionId;

  /// Whether the call popup is currently open.
  /// Always false on non-web platforms.
  bool get isWindowOpen => webWindowIsOpen();

  /// Opens (or re-focuses) the popup for [sessionId].
  /// If a popup for a different session is open, the existing window is
  /// reused by navigating it to the new session URL.
  void openCall(String sessionId) {
    _sessionId = sessionId;
    webWindowOpen('/realtime/$sessionId?action=join');
  }

  /// Brings the call popup to the foreground.
  void focusCall() => webWindowFocus();

  /// Programmatically closes the popup (call ended from within the app).
  void closeCall() {
    webWindowClose();
    _sessionId = null;
  }

  /// Call this when the session ends so the window reference is cleared.
  void onCallEnded() => closeCall();
}
