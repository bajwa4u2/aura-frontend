import 'package:flutter/widgets.dart';

/// WHAT THE APP WAS DOING WHEN THE CALL ARRIVED.
///
/// ── THE DEFECT THIS EXISTS FOR ────────────────────────────────────────────
///
/// Production, session …8gdacp, 2026-09-16: the ring pushes went out at
/// 04:23:22 and this device recorded its presentation at 04:24:48 — 85
/// seconds later, 67 seconds after the caller had already cancelled. The
/// presentation acknowledgement said `ESTABLISHED` and nothing else, so the
/// 85 seconds could not be attributed: a push that took a minute to be
/// delivered and a push delivered instantly to an app that took a minute to
/// draw are the same row.
///
/// Forty-four acknowledgements exist and every one of them says ESTABLISHED,
/// which is the other half of the same blindness.
///
/// This records the one fact the server cannot observe and the device knows
/// for certain: whether the app was already open, was in the background, or
/// was started by the call itself.
///
/// ── WHY IT IS CARRIED IN `detail` ─────────────────────────────────────────
///
/// The presentation endpoint validates its body against a DTO with
/// `forbidNonWhitelisted`, so a new top-level field would be REJECTED by the
/// deployed server and the acknowledgement — the thing being repaired — would
/// be lost entirely. `detail` is already the free-text provenance field on
/// that route ("in-app incoming call surface rendered"), so the state travels
/// there, in a form a reader and a parser can both use, until the server
/// carries a first-class column for it. When it does, [describe] is the one
/// line that changes.
enum CallAppState {
  /// The process was started by the call itself.
  cold,

  /// Running, but not on screen — backgrounded or locked.
  background,

  /// Already open in front of the person.
  foreground,

  /// Genuinely not determinable. Never guessed at.
  unknown,
}

extension CallAppStateWire on CallAppState {
  String get wire => switch (this) {
        CallAppState.cold => 'cold',
        CallAppState.background => 'background',
        CallAppState.foreground => 'foreground',
        CallAppState.unknown => 'unknown',
      };
}

/// The app's own answer about itself.
///
/// Deliberately a tiny singleton rather than a provider: the question is asked
/// from a push handler that can run before any Riverpod container exists, and
/// an answer that is unavailable on the cold path is useless for the defect it
/// was built to explain.
class CallPresentationContext {
  CallPresentationContext._();

  static final CallPresentationContext instance = CallPresentationContext._();

  /// When this process began. Used only to separate "the call started the
  /// app" from "the app was already running, in the background".
  final DateTime _startedAt = DateTime.now();

  /// How soon after process start a presentation still counts as cold.
  ///
  /// A push that cold-starts the app reaches presentation within seconds; an
  /// app a person opened a minute ago and backgrounded does not. The window is
  /// deliberately generous — misreading a warm start as cold would be a wrong
  /// fact, so the boundary sits where the two populations do not overlap.
  static const Duration _coldWindow = Duration(seconds: 12);

  /// Last lifecycle state Flutter reported. Null until the binding delivers
  /// one, which on a cold start is genuinely later than the first push.
  AppLifecycleState? _lifecycle;

  void noteLifecycle(AppLifecycleState state) => _lifecycle = state;

  /// The state to report, decided from process age and lifecycle — never
  /// inferred from whether a call happened to work.
  CallAppState get state {
    final sinceStart = DateTime.now().difference(_startedAt);
    if (sinceStart < _coldWindow) return CallAppState.cold;
    final lifecycle = _lifecycle;
    if (lifecycle == null) return CallAppState.unknown;
    return switch (lifecycle) {
      AppLifecycleState.resumed => CallAppState.foreground,
      AppLifecycleState.inactive ||
      AppLifecycleState.paused ||
      AppLifecycleState.hidden ||
      AppLifecycleState.detached =>
        CallAppState.background,
    };
  }

  /// `detail` for a presentation report: what was drawn, and what the app was
  /// doing when it drew it.
  ///
  /// Bounded to the route's 300-character limit by construction — the caller's
  /// own description is trimmed, never the state, because the state is the
  /// part that cannot be reconstructed later.
  String describe(String what) {
    final suffix = ' [app=${state.wire}]';
    final room = 300 - suffix.length;
    final trimmed = what.length > room ? what.substring(0, room) : what;
    return '$trimmed$suffix';
  }
}
