import 'package:flutter/foundation.dart';

/// Lightweight, debug-only runtime tracing.
///
/// This module exists to make runtime regressions reproducible and
/// attributable without adding noisy production logging. Every emit is
/// gated by `kDebugMode` — in release builds the body is dead code that
/// the Dart compiler strips, so the trace cost in shipped artifacts is
/// effectively zero (only the function-call frame remains).
///
/// What it traces (today):
///
///   * `shell.build`      — AppShell rebuild + which shell type was
///                          selected. A burst here means a shell-rebuild
///                          storm.
///   * `router.refresh`   — which auth-chain listener fired the GoRouter
///                          refreshListenable, with the new value. A
///                          burst here drives the shell.build storm
///                          above.
///   * `reconcile.refresh`— RealtimeReconciliationController converged
///                          the paged feeds. Frequency = upstream socket
///                          event frequency.
///   * `error.boundary`   — the global ErrorWidget.builder caught a
///                          widget build failure. The exception summary
///                          is logged here so a contained error is still
///                          visible in the debug console.
///
/// Structured output: every line is prefixed `[trace] <channel>#<n>` so
/// it greps cleanly and the counter makes burst patterns obvious at a
/// glance. Per-channel counters reset on app launch.
///
/// Add a new channel by calling `RuntimeTrace.emit('feature.event', …)`
/// from the callsite. There is no registration step.
class RuntimeTrace {
  RuntimeTrace._();

  static final Map<String, int> _counters = {};

  /// Emit a trace line. No-op in release.
  ///
  /// `data` is rendered as space-separated `key=value` pairs after the
  /// message, so a trace line is grep-friendly:
  ///
  ///     [trace] shell.build#42 chose=MemberShell path=/home
  static void emit(
    String channel,
    String message, {
    Map<String, Object?>? data,
  }) {
    if (!kDebugMode) return;
    final n = (_counters[channel] = (_counters[channel] ?? 0) + 1);
    final extra = (data == null || data.isEmpty)
        ? ''
        : ' ${data.entries.map((e) => '${e.key}=${e.value}').join(' ')}';
    debugPrint('[trace] $channel#$n $message$extra');
  }

  /// Number of times the given channel has emitted in this process.
  /// Useful for assertion-style smoke tests of rebuild quietness.
  static int counter(String channel) => _counters[channel] ?? 0;

  /// Reset all counters. Only meaningful in tests.
  @visibleForTesting
  static void resetForTesting() {
    _counters.clear();
  }
}
