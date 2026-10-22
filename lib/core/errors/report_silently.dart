import 'package:flutter/foundation.dart';

/// A failure the app recovers from without telling the person, but that must
/// not vanish: an empty `catch` hides a defect from everyone, including us.
///
/// [reportSilently] prints in debug builds and hands the failure to
/// [ReportSilentlySink.sink], which the crash reporter installs at start-up.
/// It never throws and never shows anything to the person.
typedef SilentFailureSink =
    void Function(Object error, StackTrace? stack, String context);

class ReportSilentlySink {
  ReportSilentlySink._();

  /// Installed by the client error reporter; a no-op until then.
  static SilentFailureSink sink = (_, __, ___) {};
}

void reportSilently(Object error, StackTrace? stack, String context) {
  try {
    debugPrint('[silent] $context: ${error.runtimeType}');
    ReportSilentlySink.sink(error, stack, context);
  } catch (_) {
    // Reporting must never become a second failure.
  }
}
