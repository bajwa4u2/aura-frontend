import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:web/web.dart' as web;

import 'hidden_tab_frames.dart' show shouldPumpHiddenFrame;

Timer? _pump;

void startHiddenTabFrames() {
  if (_pump != null) return;
  _pump = Timer.periodic(const Duration(seconds: 1), (_) {
    final binding = SchedulerBinding.instance;
    if (!shouldPumpHiddenFrame(
      pageHidden: web.document.visibilityState == 'hidden',
      frameWaiting: binding.hasScheduledFrame,
      phase: binding.schedulerPhase,
    )) {
      return;
    }
    binding.scheduleWarmUpFrame();
  });
}
