import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// END REACHES THE SERVER.
///
/// 2026-10-24: End from the live ribbon read `ref` after its confirmation
/// dialog, by which time the card had been rebuilt and its State disposed. It
/// threw "Cannot use ref after the widget was disposed" and the meeting ran on
/// until the stranded sweep ended it. Everything an exit needs from `ref` is
/// taken before the first await.
void main() {
  String slice(String path, String from, String to) {
    final src = File(path).readAsStringSync();
    final start = src.indexOf(from);
    return src.substring(start, src.indexOf(to, start));
  }

  test('the ribbon takes what it needs before asking', () {
    final body = slice(
      'lib/features/realtime/presentation/widgets/floating_call_widget.dart',
      'Future<void> _endOrLeaveMeeting(',
      'Future<void> _endCallFromPip(',
    );
    final afterDialog = body.substring(body.indexOf('showAdaptiveDialog'));
    expect(afterDialog, isNot(contains('ref.')));
    expect(body.indexOf('final meetings = ref.read(meetingsRepositoryProvider);'),
        lessThan(body.indexOf('showAdaptiveDialog')));
  });

  test('the room ends the meeting without reading ref after an await', () {
    final body = slice(
      'lib/features/meetings/presentation/meeting_live_room_screen.dart',
      'Future<void> _endMeeting(',
      'Future<void> _toggleScreenShare(',
    );
    final afterEnd = body.substring(body.indexOf('await meetings.endMeeting('));
    expect(afterEnd, isNot(contains('ref.')));
  });

  test('the room does not use ref in dispose', () {
    final src = File(
      'lib/features/meetings/presentation/meeting_live_room_screen.dart',
    ).readAsStringSync();
    final cls = src.indexOf('class _MeetingLiveRoomScreenState');
    final start = src.indexOf('  void dispose() {', cls);
    final body = src.substring(start, src.indexOf('super.dispose();', start));
    expect(body, isNot(contains('ref.')));
  });

  // 2026-10-24: a disposed earlier mount cleared visibility after the live
  // mount set it, and the reconnect rejoin (gated on it) never ran.
  test('only the room on screen clears call-room visibility', () {
    final src = File(
      'lib/features/meetings/presentation/meeting_live_room_screen.dart',
    ).readAsStringSync();
    final cls = src.indexOf('class _MeetingLiveRoomScreenState');
    final start = src.indexOf('  void dispose() {', cls);
    final body = src.substring(start, src.indexOf('super.dispose();', start));
    final guard = body.indexOf('if (identical(_visibleRoom, this))');
    expect(guard, greaterThan(0));
    expect(body.indexOf('setCallRoomVisible(false)'), greaterThan(guard));
    expect(src, contains('_visibleRoom = this;'));
  });
}
