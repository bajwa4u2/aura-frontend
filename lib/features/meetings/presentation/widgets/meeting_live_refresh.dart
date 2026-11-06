import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/runtime/app_visibility.dart';
import '../../application/meetings_provider.dart';

/// THE MEETING PAGE FOLLOWS THE MEETING (6 Nov 2026).
///
/// The page loaded once and then stood still: a meeting that started,
/// was cancelled or was moved kept showing what it was when the page opened,
/// until the person left and came back.
///
/// It now re-reads the meeting, quietly and in place, when:
///  * the realtime `meeting.state_changed` event names this meeting (the same
///    event the Meetings list listens to);
///  * the app comes back to the foreground;
///  * [pollEvery] passes while the page is on screen. The server sends
///    `meeting.state_changed` only to people already in the room, and not at
///    all for a cancel or a reschedule, so the event alone does not reach
///    someone reading this page.
///
/// Only while this page is the route on top: when the live room is open over
/// it, the room owns the meeting and is left alone.
///
/// The re-read never puts a spinner over the page (founder rule: a refresh
/// keeps the place). The page reads the meeting with skipLoadingOnReload.
class MeetingLiveRefresh extends ConsumerStatefulWidget {
  const MeetingLiveRefresh({
    super.key,
    required this.meetingId,
    required this.child,
    this.pollEvery = const Duration(seconds: 60),
  });

  final String meetingId;
  final Widget child;
  final Duration pollEvery;

  @override
  ConsumerState<MeetingLiveRefresh> createState() => _MeetingLiveRefreshState();
}

class _MeetingLiveRefreshState extends ConsumerState<MeetingLiveRefresh> {
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(widget.pollEvery, (_) {
      if (ref.read(appForegroundedProvider)) _refresh();
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _refresh() {
    if (!mounted || !_onTop()) return;
    ref.invalidate(meetingProvider(widget.meetingId));
  }

  /// True when this page is the top route of EVERY navigator above it. The
  /// live room and dialogs open on the root navigator, while this page sits
  /// in the shell's nested one, where it stays "current" underneath them.
  bool _onTop() {
    BuildContext? at = context;
    while (at != null) {
      final route = ModalRoute.of(at);
      if (route == null) return true;
      if (!route.isCurrent) return false;
      at = route.navigator?.context;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(meetingStateChangedEventProvider, (_, next) {
      next.whenData((event) {
        if (event.meetingId == widget.meetingId) _refresh();
      });
    });
    ref.listen<bool>(appForegroundedProvider, (previous, next) {
      if (previous == false && next) _refresh();
    });
    return widget.child;
  }
}
