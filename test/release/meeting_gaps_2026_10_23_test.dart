import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Gaps found certifying a guest meeting, 2026-10-23.
void main() {
  test('a code sent moments ago opens the code entry, not an error', () {
    final src = File('lib/features/meetings/presentation/pre_join_screen.dart')
        .readAsStringSync();
    final send = src.substring(
      src.indexOf('Future<void> _sendOtp('),
      src.indexOf('Future<void> _verifyOtp('),
    );
    expect(send, contains("error.code == 'CODE_RECENTLY_SENT'"));
    expect(
      send.indexOf("_otpSentTo = 'your invited email'", send.indexOf('CODE_RECENTLY_SENT')),
      greaterThan(0),
    );
  });

  test('a live instant meeting can be edited without a booked time', () {
    final src = File('lib/features/meetings/presentation/meeting_detail_screen.dart')
        .readAsStringSync();
    expect(src, contains('if (scheduledAt == null && meeting.sessionId == null) {'));
    expect(src, contains('scheduledAt?.toUtc().toIso8601String(),'));
  });
}
