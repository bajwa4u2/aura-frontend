import 'package:flutter/scheduler.dart';

import 'hidden_tab_frames_stub.dart'
    if (dart.library.js_interop) 'hidden_tab_frames_web.dart'
    as platform;

/// A HIDDEN TAB STILL GETS ITS FRAMES.
///
/// Flutter web draws on the browser's animation frames, and Chrome sends a
/// hidden or covered tab none. Everything in Aura that waits for a frame then
/// simply stops: navigating to a screen, a post-frame callback, a widget that
/// starts work when it is built. Calls were the casualty. A caller who placed
/// a call and turned to their phone left a browser that did not join its own
/// call for 43 seconds, and joined only when something forced a frame
/// (2026-09-30, traced in the page: the join request went out the instant a
/// screenshot drew one).
///
/// While the page is hidden and a frame is waiting, this runs that frame on a
/// timer, the path Flutter uses for its warm-up frame and which needs no
/// animation clock. At most once a second, and never while the tab is visible,
/// where the browser's own frames are the right ones. Off the web, nothing.
void startHiddenTabFrames() => platform.startHiddenTabFrames();

/// Pure: should a frame be pumped now? Separated so the rule can be tested.
bool shouldPumpHiddenFrame({
  required bool pageHidden,
  required bool frameWaiting,
  required SchedulerPhase phase,
}) => pageHidden && frameWaiting && phase == SchedulerPhase.idle;
