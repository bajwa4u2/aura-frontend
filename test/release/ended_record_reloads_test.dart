import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// THE RECORD AFTER AN END, 2026-10-25.
///
/// Ending from the corner card went to the record already on screen, which
/// did not reload, and it went on saying "This meeting is live".
void main() {
  test('ending or leaving from the card reloads the record', () {
    final src = File('lib/features/realtime/presentation/widgets/floating_call_widget.dart')
        .readAsStringSync();
    final exit = src.substring(src.indexOf('Future<void> _endOrLeaveMeeting('));
    final go = exit.indexOf('router.go(recordPath);');
    expect(exit.substring(0, go), contains('container.invalidate(meetingProvider(meetingId))'));
  });

  test('ending or leaving from the room reloads the record', () {
    final src = File('lib/features/meetings/presentation/meeting_live_room_screen.dart')
        .readAsStringSync();
    for (final fn in ['Future<void> _endMeeting(', 'Future<void> _leaveMeeting(']) {
      final body = src.substring(src.indexOf(fn));
      final go = body.indexOf('context.go(_workspacePath);');
      expect(body.substring(0, go), contains('container.invalidate(meetingProvider(widget.meetingId));'),
          reason: fn);
    }
  });
}
