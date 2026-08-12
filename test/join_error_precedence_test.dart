import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/realtime/presentation/incoming_live_overlay.dart';

void main() {
  group('joinErrorIsStale — Thread Call Lifecycle Convergence precedence', () {
    // 2026-08-14 — founder-mandated invariant: authoritative JOINED/CONNECTED
    // truth for a session must invalidate stale join-failure presentation
    // for that SAME session, without blindly suppressing a genuinely
    // different failure. This is the exact defect proven live: a Retry/
    // Dismiss banner could persist after the same logical call went on to
    // connect successfully via a later attempt.
    test('a stale error for the now-joined session is suppressed', () {
      expect(
        joinErrorIsStale(
          joinErrorSessionId: 'session-1',
          isJoined: true,
          liveSessionId: 'session-1',
        ),
        isTrue,
      );
    });

    test('an error for a DIFFERENT session is never suppressed, even if joined', () {
      expect(
        joinErrorIsStale(
          joinErrorSessionId: 'session-1',
          isJoined: true,
          liveSessionId: 'session-2',
        ),
        isFalse,
      );
    });

    test('an error is not suppressed while not actually joined', () {
      expect(
        joinErrorIsStale(
          joinErrorSessionId: 'session-1',
          isJoined: false,
          liveSessionId: 'session-1',
        ),
        isFalse,
      );
    });

    test('no error present is trivially not stale', () {
      expect(
        joinErrorIsStale(
          joinErrorSessionId: null,
          isJoined: true,
          liveSessionId: 'session-1',
        ),
        isFalse,
      );
    });

    test('joined with no session id on either side is not treated as a match', () {
      expect(
        joinErrorIsStale(
          joinErrorSessionId: '',
          isJoined: true,
          liveSessionId: null,
        ),
        isFalse,
      );
    });
  });
}
