import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/runtime/app_visibility.dart';

/// Default cadence for admin-screen refreshes that opt into the coordinator's
/// shared tick. Long enough that a passive admin session does not hammer the
/// backend; short enough that an operator watching a live counter sees it
/// move within a minute. Individual subscriptions can override but should
/// honor the minimum below.
const Duration kAdminTickInterval = Duration(seconds: 60);

/// Floor on per-subscription cadence. Anything shorter is a feature-team
/// request that needs to be discussed in docs/admin-runtime-governance.md
/// before being added — not silently allowed.
const Duration kMinAdminTickInterval = Duration(seconds: 30);

/// Snapshot of coordinator state. Exposed as the StateNotifier value so
/// widgets can `ref.watch(...)` and react (e.g. show a "polling paused"
/// indicator while the tab is hidden).
@immutable
class AdminRuntimeState {
  const AdminRuntimeState({
    required this.shellMounted,
    required this.foregrounded,
    required this.tickCount,
    required this.lastTickAt,
  });

  /// True while the AdminShell widget is in the tree. Becomes false on
  /// route changes that pop the admin shell entirely.
  final bool shellMounted;

  /// True while the OS reports the app is in the foreground. On web this
  /// flips to false when the tab is hidden.
  final bool foregrounded;

  /// Monotonically incremented every time the coordinator fires its tick.
  /// Useful for debug overlays and for any subscriber that wants to
  /// `ref.watch` a single integer rather than the whole state.
  final int tickCount;

  /// Wall-clock of the most recent tick. null before the first.
  final DateTime? lastTickAt;

  /// Derived: should the coordinator and any subscribed handler be polling
  /// right now? Both inputs must be true. Backgrounded tabs and unmounted
  /// shells produce ZERO admin polling.
  bool get shouldPoll => shellMounted && foregrounded;

  AdminRuntimeState copyWith({
    bool? shellMounted,
    bool? foregrounded,
    int? tickCount,
    DateTime? lastTickAt,
  }) {
    return AdminRuntimeState(
      shellMounted: shellMounted ?? this.shellMounted,
      foregrounded: foregrounded ?? this.foregrounded,
      tickCount: tickCount ?? this.tickCount,
      lastTickAt: lastTickAt ?? this.lastTickAt,
    );
  }

  static const initial = AdminRuntimeState(
    shellMounted: false,
    foregrounded: true,
    tickCount: 0,
    lastTickAt: null,
  );
}

typedef AdminRefreshHandler = Future<void> Function();

/// Single source of truth for admin-workspace polling. Owns:
///
///   * shell-mount lifecycle  (set by AdminShell.initState/dispose)
///   * app visibility lifecycle  (read from appForegroundedProvider)
///   * a coalesced tick stream  (Timer.periodic, paused when not should-poll)
///   * a registry of refresh handlers keyed by name
///
/// Any admin screen that needs periodic refresh should:
///
///   1. Read `adminRuntimeCoordinatorProvider.notifier`
///   2. Call `subscribe(name, handler)` in `initState` (or via `ref.listen`).
///   3. Return the dispose callback in `dispose`.
///
/// The coordinator never fires a handler when `state.shouldPoll` is false.
/// Subscribing duplicate names is a no-op (later registrations replace the
/// earlier one), which is the simplest way to dedupe across hot reload and
/// rebuilds.
class AdminRuntimeCoordinator extends StateNotifier<AdminRuntimeState> {
  AdminRuntimeCoordinator(this._ref) : super(AdminRuntimeState.initial) {
    // Seed with the current visibility, then keep tracking. We read
    // appForegroundedProvider with `ref.listen` so the notifier rebuild
    // doesn't get caught in a stale value loop.
    final initial = _ref.read(appForegroundedProvider);
    state = state.copyWith(foregrounded: initial);
    _ref.listen<bool>(
      appForegroundedProvider,
      (_, next) {
        state = state.copyWith(foregrounded: next);
        _evaluateTimer();
      },
      fireImmediately: false,
    );
  }

  final Ref _ref;
  Timer? _timer;
  bool _disposed = false;
  final Map<String, AdminRefreshHandler> _handlers = <String, AdminRefreshHandler>{};

  // ── shell lifecycle (called by AdminShell only) ───────────────────────────

  void markShellMounted() {
    if (_disposed) return;
    if (state.shellMounted) return;
    state = state.copyWith(shellMounted: true);
    _evaluateTimer();
  }

  void markShellUnmounted() {
    if (_disposed) return;
    if (!state.shellMounted) return;
    state = state.copyWith(shellMounted: false);
    _evaluateTimer();
    // Do NOT clear handlers — a sub-screen may still be mounted and waiting
    // for its own dispose to unsubscribe. Handlers that survive shell
    // unmount simply will not fire (the timer is paused).
  }

  // ── handler registry ──────────────────────────────────────────────────────

  /// Register a refresh callback. Returns a disposer; the caller MUST invoke
  /// it on widget dispose to prevent leaks. If `name` is already registered
  /// the previous handler is replaced (dedup).
  VoidCallback subscribe(String name, AdminRefreshHandler handler) {
    if (_disposed) return () {};
    _handlers[name] = handler;
    return () => _unsubscribe(name, handler);
  }

  void _unsubscribe(String name, AdminRefreshHandler handler) {
    final existing = _handlers[name];
    if (existing == handler) _handlers.remove(name);
  }

  /// Fire all subscribed handlers concurrently (best-effort). A single
  /// failed handler does not affect the others. Returns when every handler
  /// has settled.
  Future<void> refreshAll() async {
    if (_handlers.isEmpty) return;
    final snapshot = _handlers.values.toList(growable: false);
    await Future.wait(
      snapshot.map((handler) async {
        try {
          await handler();
        } catch (error, stack) {
          if (kDebugMode) {
            debugPrint('AdminRuntimeCoordinator: handler failed: $error\n$stack');
          }
        }
      }),
    );
  }

  // ── timer plumbing ────────────────────────────────────────────────────────

  void _evaluateTimer() {
    if (_disposed) return;
    if (state.shouldPoll) {
      _timer ??= Timer.periodic(kAdminTickInterval, (_) => _onTick());
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  Future<void> _onTick() async {
    if (_disposed || !state.shouldPoll) return;
    state = state.copyWith(
      tickCount: state.tickCount + 1,
      lastTickAt: DateTime.now(),
    );
    await refreshAll();
  }

  /// Force a tick now (used by manual "Refresh" buttons). Honors shouldPoll
  /// so a paused coordinator still won't fire — operators see "Refresh
  /// disabled while tab is hidden" instead of accidental traffic.
  Future<void> refreshNow() => _onTick();

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    _handlers.clear();
    super.dispose();
  }
}

final adminRuntimeCoordinatorProvider =
    StateNotifierProvider<AdminRuntimeCoordinator, AdminRuntimeState>((ref) {
  return AdminRuntimeCoordinator(ref);
});
