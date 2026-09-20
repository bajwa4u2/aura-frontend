import 'dart:math' as math;

/// WHAT A PERSON SEES WHILE THEY ARE SPEAKING.
///
/// A voice note gave no sign it was working: one boolean turned the mic icon
/// red, the hint read "Recording…", and nothing moved (founder, 2026-09-19 —
/// "recording voice message is deadlike not showing recording time"). A
/// recorder that shows no elapsed time cannot be trusted to be recording, and
/// a person cannot judge how long a message has become.
///
/// These two functions are the whole of the arithmetic, kept pure so they can
/// be tested without a microphone.

/// `m:ss` under an hour, `h:mm:ss` beyond it.
///
/// Minutes are not zero-padded and seconds always are, which is how every
/// clock a person already reads behaves. A negative duration — a clock skew,
/// a stop that lands a millisecond early — shows zero rather than a minus
/// sign: it is a length, and lengths do not run backwards.
String formatRecordingElapsed(Duration elapsed) {
  final total = elapsed.isNegative ? 0 : elapsed.inSeconds;
  final seconds = total % 60;
  final minutes = (total ~/ 60) % 60;
  final hours = total ~/ 3600;
  final ss = seconds.toString().padLeft(2, '0');
  if (hours == 0) return '$minutes:$ss';
  return '$hours:${minutes.toString().padLeft(2, '0')}:$ss';
}

/// The quietest level worth drawing, in dBFS. Below this a room is silent
/// enough that a meter should sit at rest rather than twitch at noise.
const double kRecordingFloorDbfs = -45.0;

/// A dBFS reading as a 0..1 bar height.
///
/// `record` reports amplitude in dBFS on every platform Aura ships: 0 is the
/// loudest the hardware can encode and the scale runs negative. The meter is
/// therefore a MEASUREMENT, not decoration — it is drawn only because there
/// is a real number behind it, and it must not exaggerate one: a value above
/// 0 or below the floor is clamped rather than scaled into a lie.
double normalizeRecordingLevel(double dbfs) {
  if (dbfs.isNaN || dbfs.isInfinite) return 0;
  final clamped = math.max(kRecordingFloorDbfs, math.min(0.0, dbfs));
  return (clamped - kRecordingFloorDbfs) / -kRecordingFloorDbfs;
}
