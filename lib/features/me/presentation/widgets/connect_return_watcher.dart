import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// The connect/start address for a platform, saying where the member is.
///
/// The installed app sends the member to the platform's consent page in the
/// system browser, and the platform's return lands there too — not in the app.
/// `client=app` asks Aura to answer that return with a page that sends the
/// member back to the app, instead of the web app's Me page. The web keeps
/// today's address exactly.
String connectStartPath(String path, {bool? isWeb}) =>
    (isWeb ?? kIsWeb) ? path : '$path?client=app';

/// THE MEMBER COMING BACK FROM A PLATFORM'S CONSENT PAGE (2026-10-21).
///
/// On the installed app, Connect opens the system browser and nothing tells
/// the app when the member has approved. The one dependable signal is the app
/// coming back to the front, so after a connect is started the watcher is
/// [arm]ed, and the first return to the front afterwards re-reads the
/// connection — once per connect attempt.
///
/// "Coming back" means a `resumed` that follows the app having left the front
/// (inactive, hidden or paused) after arming. A resume that the launch itself
/// did not cause is not a return.
class ConnectReturnWatcher with WidgetsBindingObserver {
  ConnectReturnWatcher({bool? isWeb}) : _isWeb = isWeb ?? kIsWeb;

  final bool _isWeb;
  Future<void> Function()? _onReturn;
  bool _left = false;
  bool _attached = false;

  bool get isArmed => _onReturn != null;

  /// Waits for the member's next return to the app, then runs [onReturn].
  /// On the web the platform returns to the Me page itself; nothing to watch.
  void arm(Future<void> Function() onReturn) {
    if (_isWeb) return;
    _onReturn = onReturn;
    _left = false;
    if (!_attached) {
      WidgetsBinding.instance.addObserver(this);
      _attached = true;
    }
  }

  void dispose() {
    _onReturn = null;
    if (_attached) {
      WidgetsBinding.instance.removeObserver(this);
      _attached = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final onReturn = _onReturn;
    if (onReturn == null) return;
    if (state == AppLifecycleState.resumed) {
      if (!_left) return;
      _onReturn = null;
      _left = false;
      onReturn();
    } else {
      _left = true;
    }
  }
}
