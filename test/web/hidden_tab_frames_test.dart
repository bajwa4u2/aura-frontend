import 'package:aura/core/web/hidden_tab_frames.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

/// A hidden tab gets no animation frames, so a waiting frame is pumped on a
/// timer (2026-09-30: a caller's browser did not join its own call for 43 s).
void main() {
  test('hidden, a frame waiting, scheduler idle: pump', () {
    expect(
      shouldPumpHiddenFrame(pageHidden: true, frameWaiting: true, phase: SchedulerPhase.idle),
      isTrue,
    );
  });

  test('a visible tab keeps the browser\'s own frames', () {
    expect(
      shouldPumpHiddenFrame(pageHidden: false, frameWaiting: true, phase: SchedulerPhase.idle),
      isFalse,
    );
  });

  test('nothing waiting: no work while hidden', () {
    expect(
      shouldPumpHiddenFrame(pageHidden: true, frameWaiting: false, phase: SchedulerPhase.idle),
      isFalse,
    );
  });

  test('never inside a frame already running', () {
    for (final phase in SchedulerPhase.values.where((p) => p != SchedulerPhase.idle)) {
      expect(
        shouldPumpHiddenFrame(pageHidden: true, frameWaiting: true, phase: phase),
        isFalse,
      );
    }
  });

  test('off the web, starting it is harmless', () {
    expect(startHiddenTabFrames, returnsNormally);
  });
}
