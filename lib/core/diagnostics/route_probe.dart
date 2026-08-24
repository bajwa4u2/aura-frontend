import 'package:flutter/foundation.dart';

/// TEMPORARY ROUTE-BOUNDARY PROBE.
///
/// `RuntimeTrace` is compiled out in release (`if (!kDebugMode) return`), and
/// the failure under investigation only appears in the deployed release web
/// client — so the existing facility cannot see it. This one emits regardless
/// of build mode, carries a monotonic sequence number so a single chronology
/// can be read off the console, and exists only for the institution
/// route-boundary measurement. It comes out with the fix.
class RouteProbe {
  RouteProbe._();

  static int _seq = 0;

  /// How many times institution access resolution has STARTED and FINISHED.
  /// Rendered into the waiting state so a stalled single run is
  /// distinguishable from restart churn without a console.
  static int accessRuns = 0;
  static int accessDone = 0;

  static void emit(String what, [Map<String, Object?>? data]) {
    final n = ++_seq;
    final extra = (data == null || data.isEmpty)
        ? ''
        : ' ${data.entries.map((e) => '${e.key}=${e.value}').join(' ')}';
    debugPrint('RP#$n $what$extra');
  }
}
