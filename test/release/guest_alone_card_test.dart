import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A GUEST LEFT ALONE IS NOT A HOST WAITING, 2026-10-24.
///
/// The host dropped and the guest stayed; the guest was shown "You are the
/// first one here" and an Invite button they cannot use.
void main() {
  test('the ready card is the host\'s alone', () {
    final src =
        File('lib/features/meetings/presentation/meeting_live_room_screen.dart')
            .readAsStringSync();
    final at = src.indexOf('state.participants.length <= 1 &&');
    final guard = src.substring(at - 120, at);
    expect(guard, contains('_isHost &&'));
  });
}
