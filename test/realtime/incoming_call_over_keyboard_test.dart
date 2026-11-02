import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A RINGING CALL IS NEVER UNDER THE KEYBOARD.
///
/// 2026-11-02, S24: a call rang while the keyboard was open in a
/// conversation, and the keyboard covered Accept and Decline.
void main() {
  final overlay = File(
    'lib/features/realtime/presentation/incoming_live_overlay.dart',
  ).readAsStringSync();

  test('the ringing card closes the keyboard when it appears', () {
    final start = overlay.indexOf('class _IncomingCallCardState');
    final init = overlay.substring(start, overlay.indexOf('void dispose()', start));
    expect(init, contains('FocusManager.instance.primaryFocus?.unfocus();'));
  });

  test('and sits above the keyboard while it is still on screen', () {
    expect(overlay, contains('MediaQuery.viewInsetsOf(context).bottom'));
  });
}
