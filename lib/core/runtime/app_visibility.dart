import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// App-wide foreground/background signal exposed as a Riverpod provider.
///
/// Drives polling budgets across the app: any controller that opts into
/// visibility-gated polling reads `appForegroundedProvider` and pauses
/// timers when the app is backgrounded. On Flutter for web,
/// `AppLifecycleState.hidden` is the most reliable signal that a tab has
/// been switched away from; we treat both `hidden` and `paused` as "not
/// foregrounded" so the budget tightens regardless of platform.
///
/// This provider must be installed once at app start (we do this from
/// `AuraApp.initState`) so the binding observer is registered before any
/// background polling subscribes.
class AppVisibilityNotifier extends StateNotifier<bool>
    with WidgetsBindingObserver {
  AppVisibilityNotifier() : super(true) {
    WidgetsBinding.instance.addObserver(this);
    // Seed from the binding's current lifecycle state so a controller that
    // subscribes mid-session doesn't briefly think the app is foregrounded
    // when in fact it isn't.
    final current = WidgetsBinding.instance.lifecycleState;
    if (current != null) {
      state = _isForegrounded(current);
    }
  }

  static bool _isForegrounded(AppLifecycleState s) {
    return s == AppLifecycleState.resumed;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final next = _isForegrounded(state);
    if (this.state != next) this.state = next;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

final appForegroundedProvider =
    StateNotifierProvider<AppVisibilityNotifier, bool>((ref) {
  return AppVisibilityNotifier();
});
