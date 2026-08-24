/// TEMPORARY COLD-ENTRY PROBE.
///
/// Console output is not a usable channel here: `RuntimeTrace` is compiled out
/// in release (`if (!kDebugMode) return`) and `debugPrint` proved unreliable
/// for burst output in the deployed web build. What IS reliable is rendering
/// the probe into the waiting state itself, so a screenshot names the stage.
///
/// Every wait point on the institution cold-entry path carries a distinct
/// label; this holds the counters the authority stage reports. Removed once
/// the stall is localised.
class RouteProbe {
  RouteProbe._();

  /// Institution access resolutions STARTED and FINISHED this app session.
  /// runs>done while waiting means a resolution is in flight; runs==done while
  /// still waiting means the stall is downstream of the authority.
  static int accessRuns = 0;
  static int accessDone = 0;

  /// Whether the producer latch currently holds an established answer.
  static bool authorityLatched = false;
}
