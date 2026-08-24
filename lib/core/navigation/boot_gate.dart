import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session_bootstrap.dart';
import '../product/product_state.dart';
import '../product/product_state_view.dart';

/// BOOT IS MACHINERY, NOT A DESTINATION.
///
/// FOUNDER CONTRACT: a canonical Aura link shared outside Aura must return the
/// person to the exact intended destination. Aura must not expose an avoidable
/// intermediate experience or move anyone backward merely because the
/// application cold-started.
///
/// ─────────────────────────────────────────────────────────────────────────
/// WHAT WAS WRONG
/// ─────────────────────────────────────────────────────────────────────────
///
/// While the session was being restored, the router NAVIGATED to
/// `/_boot?redirect=<destination>`. That is a real navigation, and it had
/// three costs that a loading state does not:
///
///   * the address bar showed `/_boot?redirect=/articles/...` instead of the
///     article the person had opened — Aura's own machinery displacing the
///     destination as the visible identity of the page;
///   * `_boot` entered browser history, so Back went to a transit page;
///   * a reload during restore re-entered `_boot` rather than the destination.
///
/// Restoring a session is not going somewhere. The person is already where
/// they asked to be; Aura is simply not ready to draw it yet.
///
/// ─────────────────────────────────────────────────────────────────────────
/// WHAT THIS DOES INSTEAD
/// ─────────────────────────────────────────────────────────────────────────
///
/// The router now stays put during bootstrap and this gate renders in place.
/// The URL never changes, nothing enters history, and refresh returns to the
/// same location because the location was never left.
///
/// It renders the boot state INSTEAD of the routed child rather than on top of
/// it. That matters: a widget that is not in the tree never mounts, so the
/// destination's providers do not fire requests while authentication is still
/// being restored — which is the real reason the old code navigated away
/// rather than simply overlaying a spinner.
///
/// This is the same lifecycle that governs deep-link entry, refresh and
/// release restoration. There is deliberately no second mechanism for any of
/// them: they are one capability — reach the intended location once Aura is
/// ready — and the destination is the URL itself rather than a parameter
/// carried alongside it.
class BootGate extends ConsumerStatefulWidget {
  const BootGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<BootGate> createState() => _BootGateState();
}

class _BootGateState extends ConsumerState<BootGate> {
  /// Long enough that a slow-but-working cold load is never interrupted,
  /// short enough that a hang does not become an indefinite spinner.
  static const Duration _deadline = Duration(seconds: 12);

  Timer? _timer;
  bool _overdue = false;

  void _arm() {
    _timer?.cancel();
    _timer = Timer(_deadline, () {
      if (mounted) setState(() => _overdue = true);
    });
  }

  void _disarm() {
    _timer?.cancel();
    _timer = null;
    if (_overdue && mounted) setState(() => _overdue = false);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _retry() {
    setState(() => _overdue = false);
    _arm();
    ref.invalidate(sessionBootstrapProvider);
  }

  @override
  Widget build(BuildContext context) {
    final bootstrap = ref.watch(sessionBootstrapProvider);
    final restoring = bootstrap.isLoading;

    if (!restoring) {
      // Cancel the deadline the moment restoration settles, so a later
      // rebuild cannot surface a stale "taking too long" state.
      if (_timer != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _disarm();
        });
      }
      return widget.child;
    }

    if (_timer == null && !_overdue) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _timer == null) _arm();
      });
    }

    if (!_overdue) {
      return const Scaffold(body: AuraProductState(state: ProductState.loading));
    }

    return Scaffold(
      body: AuraProductState(
        state: ProductState.unavailable,
        headline: 'Still restoring your session',
        // Truthful: the destination is the URL, which has not been touched, so
        // retrying genuinely resumes rather than starting over somewhere else.
        detail:
            'This is taking longer than expected. Your place has been kept — '
            'try again to pick up where you left off.',
        onRecover: _retry,
      ),
    );
  }
}
