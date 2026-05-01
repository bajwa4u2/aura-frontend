import 'package:flutter_riverpod/flutter_riverpod.dart';

final callWindowServiceProvider = Provider<CallWindowService>((ref) {
  return CallWindowService();
});

/// Popup call window removed. All methods are no-ops.
/// Calls now route entirely via /realtime/:sessionId within the app.
class CallWindowService {
  String? get activeSessionId => null;
  bool get isWindowOpen => false;
  void openCall(String sessionId) {}
  void focusCall() {}
  void closeCall() {}
  void onCallEnded() {}
  void closeCurrentWindow() {}
}
