/// Cross-tab auth event channel.
///
/// Web only. Calling tabs publish small string events (`logout`, `login`) and
/// other open tabs of the same origin receive them via BroadcastChannel /
/// localStorage. Native platforms get a no-op stub — there is only one
/// "tab" and no sync is needed.
///
/// Receivers MUST keep their own auth-clearing logic alongside the
/// subscription. This module only routes events; the main app decides
/// what `logout` means (clear tokens, invalidate providers, etc.).
library;

import '_auth_broadcast_stub.dart'
    if (dart.library.html) '_auth_broadcast_web.dart';

class AuthBroadcast {
  AuthBroadcast._();

  /// Event type token sent when the user explicitly signs out in this tab.
  /// Other tabs treat this as "drop the local session immediately."
  static const String typeLogout = 'logout';

  /// Event type token sent when the user signs in. Other tabs may use this
  /// to trigger a silent /auth/me re-read so the UI catches up without a
  /// reload. Currently consumed only as an opt-in trigger.
  static const String typeLogin = 'login';

  /// Subscribe to remote auth events. The handler receives the event type
  /// string ([typeLogout] / [typeLogin]). Idempotent — calling twice
  /// replaces the listener.
  static void start({required void Function(String type) onMessage}) {
    initAuthBroadcast(onMessage);
  }

  /// Publish a logout event so every other tab clears local state.
  static void publishLogout() {
    publishAuthEvent(typeLogout);
  }

  /// Publish a login event. Other tabs may reread auth state silently.
  static void publishLogin() {
    publishAuthEvent(typeLogin);
  }

  /// Tear down listeners and channels. Called from app dispose for
  /// completeness — browsers also clean up on tab close.
  static void dispose() {
    closeAuthBroadcast();
  }
}
