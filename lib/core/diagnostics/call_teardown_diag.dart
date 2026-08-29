/// BOUNDED RELEASE DIAGNOSTIC — CALL TEARDOWN / SHELL REACTIVATION.
///
/// WHY THIS EXISTS AND WHEN IT LEAVES.
///
/// Ending a call on Android produces, in a RELEASE build:
///
///     Null check operator used on a null value
///     #0  StatefulElement.state
///     #1  StatefulElement.activate
///     #2  Element._activateRecursively
///
/// Every frame is framework. There is no `package:aura` frame, because the
/// failure is inside element REACTIVATION rather than in app code that called
/// something -- the signature of a GlobalKey being reparented onto a State
/// that is already gone. That tells us the class of defect and nothing about
/// the owner, and the app has three app-lifetime GlobalKeys that could each
/// produce it.
///
/// `RuntimeTrace` cannot answer this: it is `if (!kDebugMode) return`, so a
/// release build traces nothing and the absence is not evidence. This module
/// is the minimum needed to attribute THIS defect in a release binary, and it
/// is deliberately not a general "enable debug logging in release" switch:
///
///   * its own compile-time gate, independent of `kDebugMode`;
///   * only the channels needed for this attribution;
///   * a bounded ring buffer, so the crash can be read together with what
///     immediately preceded it -- the ordering IS the evidence here.
///
/// It carries no user content, no tokens, no message bodies. Identities are
/// `identityHashCode`, which says only "same object or not".
///
/// DELETE THIS FILE once the owner is attributed and repaired.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Stamped into the first trace line so the log itself proves which binary
/// produced it. Bump when the instrumentation changes.
const String kAuraDiagMarker = 'AURA-DIAG-CALLTEARDOWN-1';

/// Compile-time gate. Off unless built with:
///
///     flutter build apk --release --dart-define=AURA_DIAG_CALL_TEARDOWN=true
///
/// A normal release build strips every emit below as dead code, exactly as
/// `RuntimeTrace` is stripped today.
const bool kAuraDiagCallTeardown =
    bool.fromEnvironment('AURA_DIAG_CALL_TEARDOWN');

/// The three app-lifetime GlobalKeys, named so a trace line attributes itself
/// instead of saying "scaffold key" three different ways.
class DiagKeyLabel {
  DiagKeyLabel._();

  static const memberShellScaffold = 'MEMBER_SHELL_PRIMARY_SCAFFOLD_KEY';
  static const institutionShellScaffold = 'MEMBER_SHELL_INSTITUTION_SCAFFOLD_KEY';
  static const notificationMessenger = 'NOTIFICATION_SCAFFOLD_MESSENGER_KEY';
}

/// Release-visible diagnostic for the call-teardown reactivation failure.
class CallDiag {
  CallDiag._();

  static const int _ringLimit = 60;
  static final List<String> _ring = <String>[];
  static int _seq = 0;
  static bool _stamped = false;

  static bool get enabled => kAuraDiagCallTeardown || kDebugMode;

  /// Identity of an object as a short stable token. Says only whether two
  /// observations are the same instance -- never any of its contents.
  static String id(Object? o) =>
      o == null ? 'null' : identityHashCode(o).toRadixString(16);

  /// Emit one diagnostic event, and retain it for the crash dump.
  static void emit(String channel, String message, {Map<String, Object?>? data}) {
    if (!enabled) return;
    if (!_stamped) {
      _stamped = true;
      debugPrint('[auradiag] marker=$kAuraDiagMarker');
    }
    final n = ++_seq;
    final extra = (data == null || data.isEmpty)
        ? ''
        : ' ${data.entries.map((e) => '${e.key}=${e.value}').join(' ')}';
    final line = '[auradiag] $channel#$n $message$extra';
    _ring.add(line);
    if (_ring.length > _ringLimit) _ring.removeAt(0);
    debugPrint(line);
  }

  /// Report what a GlobalKey is currently BOUND to.
  ///
  /// This is the load-bearing observation. The key itself is a singleton, so
  /// its own identity never changes and proves nothing; what discriminates a
  /// reparent is whether the STATE and ELEMENT behind it change identity, or
  /// are still attached when a second holder appears.
  static void keyBinding(String label, GlobalKey key, String at) {
    if (!enabled) return;
    Object? state;
    Object? ctx;
    try {
      state = key.currentState;
      ctx = key.currentContext;
    } catch (e) {
      // Reading currentState during an unstable tree can itself throw; that
      // is an observation, not a failure of the diagnostic.
      emit('key.binding', label, data: {'at': at, 'read_error': e.runtimeType});
      return;
    }
    emit('key.binding', label, data: {
      'at': at,
      'key': id(key),
      'state': id(state),
      'element': id(ctx),
      'mounted': ctx is Element ? ctx.mounted : 'n/a',
    });
  }

  /// The retained tail, oldest first. Printed beside the crash so the two are
  /// read together rather than correlated by timestamp across a noisy buffer.
  static List<String> recent() => List<String>.unmodifiable(_ring);

  /// Dump the tail under a header that greps as one block.
  static void dumpRecent(String reason) {
    if (!enabled) return;
    debugPrint('[auradiag] ---- RECENT (${_ring.length}) reason=$reason ----');
    for (final line in _ring) {
      debugPrint('[auradiag] | $line');
    }
    debugPrint('[auradiag] ---- END RECENT ----');
  }
}
