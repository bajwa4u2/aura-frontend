import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A CALL MAY NOT READ "CONNECTED" WHILE ITS MEDIA IS BEING REBUILT.
///
/// 2026-09-16, session …ycs9j: the callee's transport closed and its
/// replacement arrived 13 seconds later, with the screen saying Connected the
/// whole way. 2026-09-09: a frozen call read "Connected · 2 · 02:52" for four
/// minutes while +0 frames arrived. Both times the product claimed a state the
/// media did not support, and neither person could tell.
///
/// The status line is assembled in one place with no fall-through, so this is
/// a test of that ORDER: a connection failure outranks everything, a rebuilding
/// transport outranks the call's own phase, and only then does the shared
/// projection speak. Checked at source level because `_CallStage` is private
/// and rendering it needs the whole realtime graph — the same precedent
/// `call_media_truth_test.dart` sets for this screen.
void main() {
  final src = File('lib/features/realtime/presentation/realtime_room_screen.dart')
      .readAsStringSync();

  int at(String needle) {
    final i = src.indexOf(needle);
    expect(i, greaterThan(-1), reason: 'not found: $needle');
    return i;
  }

  test('a rebuilding transport is said out loud, not hidden behind Connected', () {
    final recovering = at("statusLabel = 'Reconnecting…';");
    final connected = at("statusLabel = 'Connected';");
    expect(recovering, lessThan(connected),
        reason: 'recovery must be decided before the phase label');
  });

  test('a connection failure still outranks recovery', () {
    expect(at("statusLabel = 'Not connected';"), lessThan(at("statusLabel = 'Reconnecting…';")));
  });

  test('the recovery fact comes from the controller, not from this screen', () {
    // No second opinion: the screen renders `state.mediaRecovering`, it does
    // not decide when a transport is in trouble.
    expect(src.contains('mediaRecovering: state.mediaRecovering'), isTrue);
    expect(src.contains('} else if (mediaRecovering) {'), isTrue);
  });
}
