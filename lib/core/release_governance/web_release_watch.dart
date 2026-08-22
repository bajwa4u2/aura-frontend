import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '_release_stamp_stub.dart'
    if (dart.library.html) '_release_stamp_web.dart';

/// RELEASE IS NOT NAVIGATION.
///
/// A running web client had no way to learn that a new release existed. The
/// service worker only acts when the browser happens to fetch it, and the
/// compatibility gate only fires when an operator flips a per-distribution
/// flag — so an ordinary deploy reached a long-lived tab as "one stale load,
/// then it heals", which is a description of an accident rather than a
/// product behaviour.
///
/// This watches the build stamp Flutter already emits.
/// `flutter_bootstrap.js` carries a `serviceWorkerVersion` that changes with
/// every build, and nginx already serves that file `no-cache`, so the running
/// client can simply ask. No backend change, no operator action, no new
/// deployment artefact.
///
/// WHAT IT DELIBERATELY DOES NOT DO
/// --------------------------------
/// Reload by itself. Someone may be part-way through composing an article, and
/// a reload that arrives unannounced is indistinguishable from a crash. It
/// reports availability; the person chooses. When they do choose, the reload
/// preserves the current URL — the location was never the thing being
/// replaced.
class WebReleaseWatch extends StateNotifier<bool> {
  WebReleaseWatch() : super(false) {
    if (!kIsWeb) return;
    _start();
  }

  static const Duration _interval = Duration(minutes: 5);

  Timer? _timer;
  String? _initialStamp;

  Future<void> _start() async {
    _initialStamp = await readReleaseStamp();
    // Without a baseline there is nothing to compare against, and guessing
    // that any later read means "new release" would nag on every network
    // hiccup.
    if (_initialStamp == null || _initialStamp!.isEmpty) return;
    _timer = Timer.periodic(_interval, (_) => check());
  }

  /// Compares the live build stamp against the one this client started with.
  Future<void> check() async {
    if (state) return; // already reported; nothing changes by saying it twice
    final current = await readReleaseStamp();
    if (current == null || current.isEmpty) return; // offline, or blocked
    if (_initialStamp != null && current != _initialStamp) state = true;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// True once a release newer than the running client is live.
final webReleaseAvailableProvider =
    StateNotifierProvider<WebReleaseWatch, bool>((ref) => WebReleaseWatch());
