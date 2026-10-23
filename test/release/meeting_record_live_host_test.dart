import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// THE MEETING RECORD DURING A LIVE MEETING, 2026-10-23.
///
/// The Pixel kept the record open overnight and Enter room sent it to the
/// session that had ended; the host saved a recording mid-meeting and could
/// not see it until the meeting ended.
void main() {
  final record = const LineSplitter()
      .convert(File('lib/features/meetings/presentation/meeting_detail_screen.dart')
          .readAsStringSync())
      .map((l) {
        final i = l.indexOf('//');
        return i < 0 ? l : l.substring(0, i);
      })
      .join('\n');

  test('Enter room asks the server for the current session', () {
    final enter = record.substring(
      record.indexOf('Future<void> _enterRoom('),
      record.indexOf('Future<void> _startMeeting('),
    );
    expect(enter, contains('ref.refresh(meetingProvider(meeting.id).future)'));
    expect(enter.indexOf('ref.refresh('),
        lessThan(enter.indexOf('context.push(')));
  });

  test('the host sees the recording in any state of the meeting', () {
    final aftermath = record.substring(
      record.indexOf('final aftermath = <Widget>['),
      record.indexOf('Widget header()'),
    );
    expect(aftermath, contains('] else if (isHost) ...['));
    expect(
      aftermath.substring(aftermath.indexOf('] else if (isHost)')),
      contains('recording()'),
    );
  });
}
