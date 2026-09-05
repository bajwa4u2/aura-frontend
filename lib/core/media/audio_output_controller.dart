import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'audio_output.dart';
import 'audio_output_stub.dart'
    if (dart.library.io) 'audio_output_io.dart'
    if (dart.library.js_interop) 'audio_output_web.dart';

/// THE LIVE ANSWER TO "WHERE IS THIS CALL BEING HEARD?"
///
/// Holds no policy and no memory of intent. It asks the platform what exists
/// and what is current, offers a selection, and asks again afterwards.
///
/// ── WHY IT POLLS ─────────────────────────────────────────────────────────
///
/// Routes change without the app doing anything: a headset connects, a headset
/// disconnects, the system moves the call. Android exposes no callback for the
/// communication device through the plugin, so the only honest way to keep the
/// displayed route true is to keep asking.
///
/// Three seconds, and only while a call is on screen. It is a read of local
/// device state — no network, no server, nothing written anywhere.
///
/// ── RECOVERY ─────────────────────────────────────────────────────────────
///
/// When the route in use disappears — Bluetooth dropped, headset unplugged —
/// the platform normally re-routes on its own, and the poll simply shows where
/// it went. When it does not, and the call is left pointing at a route that no
/// longer exists, this asks for the best route that DOES exist rather than
/// leaving the call inaudible. That is not a priority policy: it is refusing to
/// leave a call bound to nothing, which is the exact failure this whole control
/// was built for.
class AudioOutputController extends StateNotifier<AudioOutputState> {
  AudioOutputController(this._authority)
      : super(AudioOutputState(isSupported: _authority.isSupported));

  final AudioOutputAuthority _authority;
  Timer? _poll;
  bool _reading = false;

  /// The last route the platform actually confirmed. Only used to tell "this
  /// call had an output and lost it" apart from "this call has not chosen one
  /// yet" — never as a substitute for asking.
  AudioOutputRoute? _lastKnown;

  static const Duration _interval = Duration(seconds: 3);

  /// Begin watching. Safe to call repeatedly; the call surface does on rebuild.
  void start() {
    if (!_authority.isSupported || _poll != null) return;
    unawaited(refresh());
    _poll = Timer.periodic(_interval, (_) => unawaited(refresh()));
  }

  void stop() {
    _poll?.cancel();
    _poll = null;
  }

  /// Re-read both questions from the platform.
  Future<void> refresh() async {
    if (!_authority.isSupported || _reading || !mounted) return;
    _reading = true;
    try {
      final routes = await _authority.available();
      final current = await _authority.current();
      if (!mounted) return;

      // ── A ROUTE THAT NO LONGER EXISTS ─────────────────────────────────
      //
      // The platform has usually already moved the audio by the time this is
      // noticed, in which case `current` is simply the new route and there is
      // nothing to do. This handles the case where it has not.
      //
      // Two shapes, and the second is the one that actually bit. When a route
      // goes away a platform may keep naming it, or may name NOTHING at all —
      // the device that produced this control reported exactly the latter:
      // `preferredCommunicationDevice: null` for forty seconds while media
      // arrived and nobody could hear it.
      //
      // Deliberately conditional on having KNOWN a route before. A null before
      // any route has been established is a call that has not chosen yet, and
      // choosing for it here would be inventing the default-routing policy this
      // control is explicitly not allowed to own.
      final knewARoute = _lastKnown != null;
      final gone = current == null
          ? knewARoute && routes.isNotEmpty
          : routes.isNotEmpty && !routes.any((r) => r.id == current.id);
      if (current != null) _lastKnown = current;

      state = state.copyWith(
        routes: routes,
        current: current,
        clearCurrent: current == null,
        isSupported: true,
      );

      if (gone) {
        final fallback = _fallbackFrom(routes);
        if (fallback != null) await select(fallback);
      }
    } catch (_) {
      // A read that failed is not evidence that routing broke. The last known
      // state stands until a read succeeds.
    } finally {
      _reading = false;
    }
  }

  /// Ask for [route], then show what the platform is actually on.
  ///
  /// The returned route is rendered, never the requested one. A request that
  /// was refused or substituted must be visible as such.
  Future<void> select(AudioOutputRoute route) async {
    if (!_authority.isSupported || !mounted) return;
    state = state.copyWith(isSwitching: true);
    try {
      final settled = await _authority.select(route);
      if (!mounted) return;
      final routes = await _authority.available();
      if (!mounted) return;
      state = state.copyWith(
        routes: routes,
        current: settled,
        clearCurrent: settled == null,
        isSwitching: false,
      );
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(isSwitching: false);
      // Re-read rather than assume the failure left things unchanged.
      unawaited(refresh());
    }
  }

  /// The most reasonable route among those that still exist.
  ///
  /// Used only to rescue a call whose route has vanished. A wired headset or a
  /// Bluetooth device someone is wearing is a better guess than the speaker,
  /// and the earpiece is where a phone call belongs by default — the same
  /// default the call itself already applies, not a new one invented here.
  AudioOutputRoute? _fallbackFrom(List<AudioOutputRoute> routes) {
    if (routes.isEmpty) return null;
    for (final kind in const [
      AudioOutputKind.wiredHeadset,
      AudioOutputKind.bluetooth,
      AudioOutputKind.earpiece,
      AudioOutputKind.speaker,
    ]) {
      for (final route in routes) {
        if (route.kind == kind) return route;
      }
    }
    return routes.first;
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

/// The platform's audio-output authority for this build.
final audioOutputAuthorityProvider = Provider<AudioOutputAuthority>(
  (ref) => platformAudioOutputAuthority,
);

final audioOutputControllerProvider =
    StateNotifierProvider<AudioOutputController, AudioOutputState>((ref) {
  final controller =
      AudioOutputController(ref.watch(audioOutputAuthorityProvider));
  ref.onDispose(controller.stop);
  return controller;
});
