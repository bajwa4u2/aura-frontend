import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A LIVE MEETING TAKES THE SCREEN.
///
/// Founder, looking at a real three-party meeting on the rebuilt stage
/// (2026-09-24): *"still three headers above meeting surface tiles eating
/// vertical space"*. The stage composition was right; the meeting was simply
/// wrapped in the app's chrome — the global AURA bar, then the institution
/// bar, then its own header — costing about a quarter of the window before a
/// single face.
///
/// Calls already obeyed the rule: `/realtime/:sessionId` sits OUTSIDE the
/// `ShellRoute` and suppresses chrome once you are in a session. Meetings were
/// the exception. This holds the correction, because a route is one careless
/// paste away from moving back inside and the cost is invisible until somebody
/// is in a real meeting.
void main() {
  final src = File('lib/router.dart').readAsStringSync();
  final lines = src.split('\n');

  /// Routes nested in the ShellRoute are indented deeper than top-level ones.
  /// Indentation is the structure here, so it is what gets asserted.
  int indentOf(String path) {
    final i = lines.indexWhere((l) => l.contains("path: '$path'"));
    expect(i, greaterThan(-1), reason: '$path is gone from the router');
    // Walk back to the GoRoute( that owns this path.
    for (var j = i; j >= 0; j--) {
      if (lines[j].trimRight().endsWith('GoRoute(')) {
        return lines[j].length - lines[j].trimLeft().length;
      }
    }
    fail('no GoRoute( found above $path');
  }

  test('the call route is immersive — the precedent being followed', () {
    // If this ever changes, the comparison below is measuring nothing.
    expect(indentOf('/realtime/:sessionId'), 6);
  });

  test('a live meeting sits outside the shell, like a call', () {
    expect(indentOf('/meetings/:meetingId/live'), 6,
        reason: 'the member live room is wrapped in app chrome again');
    expect(indentOf('/institution/:institutionId/meetings/:meetingId/live'), 6,
        reason: 'the institution live room is wrapped in app chrome again');
  });

  test('the meeting RECORD stays inside the shell', () {
    // Entering is immersive; reading about a meeting is ordinary navigation
    // and must keep the app's hierarchy. The same distinction the Live
    // directory had to learn.
    expect(indentOf('/institution/:institutionId/meetings/:meetingId'), 10,
        reason: 'the meeting record lost the app hierarchy');
  });

  test('the correction is explained where it lives', () {
    expect(src, contains('A LIVE MEETING IS A SESSION'),
        reason: 'the reason was removed, so the next person will undo it');
  });
}
