import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// ANSWERING A CALL MUST NEVER REPORT IT ENDED.
///
/// On 2026-08-30 an iPhone rang correctly, answered correctly, joined the
/// session, bound media and rendered the caller's video — and then left the
/// call five seconds later. Backend trace, session cmtf7np66...:
///
///   02:49:18  join ACTIVE, participants=2
///   02:49:21  bound=2, remote video attached
///   02:49:23  roster 2 -> 1, [stage:session_not_active], transport closed
///
/// The cause was that every path which cleared the ringing card funnelled
/// through the bridge's terminal choke point, and that choke point reports the
/// CallKit call ended. On iOS that ends the system call, deactivates the audio
/// session, and removes a backgrounded app's reason to keep running. The join
/// had already succeeded, so nothing in the join path looked wrong.
///
/// None of this is observable from a unit test: `IosCallKit` is inert off-iOS,
/// so the bug runs green everywhere except a physical iPhone. What IS
/// observable is the wiring, so the wiring is what gets pinned here.
String _read(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: 'missing source file: $path');
  return file.readAsStringSync();
}

/// Comments are stripped before matching. The repaired call sites are
/// documented with comments that necessarily NAME the forbidden calls, and a
/// guard that read prose would fail on the explanation of the very defect it
/// exists to prevent.
String _code(String source) => const LineSplitter()
    .convert(source)
    .map((line) {
      final idx = line.indexOf('//');
      return idx < 0 ? line : line.substring(0, idx);
    })
    .join(' ');

/// The code between two anchors — robust where brace-counting is not.
String _between(String source, String start, String end) {
  final a = source.indexOf(start);
  expect(a, greaterThanOrEqualTo(0), reason: 'anchor not found: $start');
  final b = source.indexOf(end, a + start.length);
  expect(b, greaterThan(a), reason: 'closing anchor not found: $end');
  return _code(source.substring(a, b));
}

void main() {
  const bridgePath = 'lib/features/updates/incoming_call_bridge.dart';
  const controllerPath =
      'lib/features/realtime/application/thread_call_lifecycle_controller.dart';
  const overlayPath =
      'lib/features/realtime/presentation/incoming_live_overlay.dart';

  test('the accepted-clear path never reports a call ended', () {
    final body = _between(
      _read(bridgePath),
      'void clearAccepted(',
      'void removeAccepted(',
    );
    expect(
      body.contains('reportEnded'),
      isFalse,
      reason: 'clearAccepted() exists precisely so accepting a call does not '
          'end it. Reporting ended here reinstates the original defect.',
    );
  });

  test('accepting an incoming call does not route through the terminal clear',
      () {
    final body = _between(
      _read(controllerPath),
      'Future<void> acceptIncomingCall(',
      'Future<void> joinThreadCallSession(',
    );
    expect(
      body.contains('clearAccepted('),
      isTrue,
      reason: 'accept must clear presentation without terminating.',
    );
    expect(
      body.contains('removeBySession('),
      isFalse,
      reason: 'removeBySession() reports the CallKit call ended — on the '
          'accept path that ends the call being accepted.',
    );
  });

  test('a successful join does not report itself terminal', () {
    final block =
        _between(_read(controllerPath), '.join(sessionId)', '.catchError');
    expect(block.contains('clearAccepted('), isTrue);
    expect(
      block.contains('removeBySession('),
      isFalse,
      reason: 'this fires on every join that succeeds — caller, callee and '
          'route alike — so a terminal report here ends every connected call.',
    );
  });

  test('the in-app accept button does not report the call declined', () {
    // Scoped to the success branch only. The later remove(id) in the
    // invite-expired branch is correct: that call genuinely is over.
    final block = _between(
      _read(overlayPath),
      '.acceptIncomingCall(item);',
      'if (id.isNotEmpty)',
    );
    expect(block.contains('removeAccepted('), isTrue);
    expect(
      RegExp(r'notifier\)\.remove\(id\)').hasMatch(block),
      isFalse,
      reason: 'remove(id) reports reason "declined" to CallKit. On the accept '
          'button that both ended the call and mislabelled it in the system '
          'call log.',
    );
  });
}
