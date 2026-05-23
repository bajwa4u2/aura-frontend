import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/diagnostics/runtime_trace.dart';
import '../../correspondence/data/correspondence_live_service.dart';
import '../../feed/data/unified_feed_providers.dart';

/// R3 — Cross-device reconciliation bridge.
///
/// Subscribes to the correspondence socket and, when the backend signals
/// that feed-relevant state changed on another session, performs a
/// **data-preserving** refresh of the two primary paged feeds so this
/// device converges on backend truth.
///
/// ─────────────────────────────────────────────────────────────────────
///   CONTENT-FLASH CONTRACT  (P0 cross-platform regression fix)
/// ─────────────────────────────────────────────────────────────────────
///
/// An earlier version of this controller turned every socket event into a
/// broad `ref.invalidate` pass across the feed, detail, rail, reaction,
/// follow and saves providers. `invalidate` forces every watcher into
/// `AsyncLoading`, and the surfaces that consume those providers render
/// loading as a blank or collapsed state (feed lists clear, the context
/// rail modules `maybeWhen(orElse: SizedBox.shrink())`, detail screens
/// drop to a spinner). Because `socket:connected` fires on the first
/// connection and on every transport reconnect, the app visibly flashed
/// on every surface, on every platform.
///
/// This controller now obeys a strict contract:
///
///   * It NEVER calls `ref.invalidate` on a provider that backs visible
///     content. Convergence happens exclusively through
///     `FeedPagedNotifier.refresh()`, which keeps the items currently on
///     screen and swaps the new page in only once it has loaded.
///   * The two non-family paged feeds are the only providers refreshed.
///     Institution-scoped feeds, detail surfaces, rail modules, reaction
///     / follow / saves state converge on their own next watch or
///     navigation — they are deliberately kept off this path so a socket
///     event can never blank them.
///   * The initial `socket:connected` is ignored. It is the first
///     connection, not a reconnect: every surface is already loading
///     fresh, so there is no missed-event window to close. Only genuine
///     reconnects run the resume-fallback refresh.
///   * Events are debounced (250 ms) so a burst collapses into a single
///     refresh pass, and rapid reconnect cascades are suppressed.
class RealtimeReconciliationController {
  RealtimeReconciliationController(this._ref) {
    _attach();
  }

  final Ref _ref;
  StreamSubscription<CorrespondenceLiveEvent>? _subscription;
  Timer? _debounce;
  bool _sawFirstConnect = false;
  DateTime? _lastReconnectAt;

  void _attach() {
    // Touch the live service so it boots when this controller initialises.
    // ensureConnected() is idempotent and silently no-ops without a token,
    // so attaching this controller never forces an authenticated boot.
    final live = _ref.read(correspondenceLiveServiceProvider);
    unawaited(live.ensureConnected().catchError((_) {}));
    _subscription = live.events.listen(_handle);
  }

  void _handle(CorrespondenceLiveEvent event) {
    switch (event.name) {
      // A genuine cross-device change to feed-relevant state. The payload
      // is only a trigger — the refresh refetches canonical data, so the
      // exact interaction type does not matter here.
      case 'post:interaction.changed':
      case 'follow:state.changed':
      case 'feed:item.changed':
        _scheduleFeedRefresh();
        break;
      case 'socket:connected':
        _onConnect();
        break;
    }
  }

  /// `socket:connected` fires on the first connection AND on every
  /// reconnect. The first connection is not a missed-event window — the
  /// app just booted and every surface is loading fresh — so it is
  /// skipped. Genuine reconnects run the resume-fallback refresh, guarded
  /// against rapid transport-upgrade cascades (2 s is comfortably above
  /// socket.io's transport-upgrade latency and well below any human
  /// reconnect cadence).
  void _onConnect() {
    if (!_sawFirstConnect) {
      _sawFirstConnect = true;
      return;
    }
    final now = DateTime.now();
    if (_lastReconnectAt != null &&
        now.difference(_lastReconnectAt!).inMilliseconds < 2000) {
      return;
    }
    _lastReconnectAt = now;
    _scheduleFeedRefresh();
  }

  void _scheduleFeedRefresh() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      _debounce = null;
      _refreshPagedFeeds();
    });
  }

  /// Data-preserving convergence. `FeedPagedNotifier.refresh()` keeps the
  /// items currently on screen and only swaps in the new page once it has
  /// arrived, so this never blanks a feed the user is reading. Only the
  /// two non-family primary feeds are refreshed — that keeps convergence
  /// off the broad-invalidation path entirely.
  void _refreshPagedFeeds() {
    try {
      _ref.read(globalPublicFeedPagedProvider.notifier).refresh();
      _ref.read(memberHomeFeedPagedProvider.notifier).refresh();
      RuntimeTrace.emit('reconcile.refresh', 'paged feeds');
    } catch (error, stack) {
      // Either provider may not be mounted yet — convergence is
      // best-effort and must never throw out of the socket listener.
      // The failure IS surfaced in the debug trace so a regression in
      // the convergence path is attributable rather than silently lost.
      RuntimeTrace.emit('reconcile.refresh', 'failed',
          data: {'err': '$error'});
      assert(() {
        FlutterError.reportError(FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'realtime reconciliation',
          context: ErrorDescription(
              'while data-preserving refresh of the primary paged feeds'),
        ));
        return true;
      }());
    }
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _debounce?.cancel();
  }
}

/// Eager-listened provider — read once from the app shell so the
/// controller boots, attaches its socket listener, and stays alive for
/// the app's lifetime. Reading is idempotent: the controller is
/// constructed once per ProviderScope.
final realtimeReconciliationProvider =
    Provider<RealtimeReconciliationController>((ref) {
  final controller = RealtimeReconciliationController(ref);
  ref.onDispose(controller.dispose);
  return controller;
});
