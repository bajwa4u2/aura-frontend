import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/realtime/presentation/incoming_live_overlay.dart';

/// C-5 — AN ADDRESS IS NOT A CALL.
///
/// Founder-observed, Film A capture 10: after the far end hung up, the web room
/// sat at *"Connecting… · 0 participants"* on a session that would never join,
/// **and the next incoming call was suppressed**. No ring, no card, nothing.
///
/// The cause was a suppression rule that read the address: anybody on
/// `/realtime/...` was assumed to be in a call and was never interrupted. The
/// one state where that is false — stranded on a dead room — is precisely the
/// state where the next call most needs to arrive.
///
/// The same mistake had already been found and repaired for the state-based
/// version of this test, one rule below it in the same function. This holds the
/// address-based one, because the "obvious" simplification back to
/// `path.contains('/realtime') → suppress` is one careless edit away and its
/// cost is a call that silently never rings.
void main() {
  group('off a call surface, nothing is suppressed', () {
    test('an ordinary route lets the card through', () {
      expect(
        callSurfaceSuppressesIncoming(
          currentPath: '/messages/c/abc',
          isJoined: false,
          incomingSessionId: 'sess-1',
        ),
        isFalse,
      );
    });

    test('even while joined elsewhere, a non-call route still rings', () {
      // The PiP represents the running call; a ringing card can coexist.
      expect(
        callSurfaceSuppressesIncoming(
          currentPath: '/home',
          isJoined: true,
          incomingSessionId: 'sess-2',
        ),
        isFalse,
      );
    });
  });

  group('on a call surface, a REAL call suppresses', () {
    for (final path in [
      '/realtime/sess-1',
      '/meetings/m1/live/',
      '/activity',
    ]) {
      test('joined, at $path — do not interrupt', () {
        expect(
          callSurfaceSuppressesIncoming(
            currentPath: path,
            isJoined: true,
            incomingSessionId: 'other-session',
          ),
          isTrue,
        );
      });
    }
  });

  group('on a call surface with NO call, the next call rings', () {
    test('THE DEFECT: stranded on a dead room, a new call is not suppressed',
        () {
      // "Connecting… · 0 participants" — the address says /realtime, the
      // controller is joined to nothing, and somebody is calling.
      expect(
        callSurfaceSuppressesIncoming(
          currentPath: '/realtime/dead-session',
          isJoined: false,
          incomingSessionId: 'a-brand-new-session',
        ),
        isFalse,
        reason: 'this is the exact state the founder was stranded in',
      );
    });

    test('a query string does not rescue the old behaviour', () {
      expect(
        callSurfaceSuppressesIncoming(
          currentPath: '/realtime/dead-session?action=join&returnTo=%2Fhome',
          isJoined: false,
          incomingSessionId: 'a-brand-new-session',
        ),
        isFalse,
      );
    });
  });

  group('the accept transition is not re-interrupted', () {
    test('navigated to the ringing session but not yet joined', () {
      // Accepting navigates first and joins a moment later. In that window the
      // client is on a call surface and not joined — the shape the repair
      // deliberately still suppresses, or the card it came from flashes back.
      expect(
        callSurfaceSuppressesIncoming(
          currentPath: '/realtime/sess-9?action=join',
          isJoined: false,
          incomingSessionId: 'sess-9',
        ),
        isTrue,
      );
    });

    test('a DIFFERENT session at that address is still allowed through', () {
      expect(
        callSurfaceSuppressesIncoming(
          currentPath: '/realtime/sess-9',
          isJoined: false,
          incomingSessionId: 'sess-10',
        ),
        isFalse,
      );
    });

    test('an empty or absent incoming session id suppresses nothing', () {
      for (final id in [null, '', '   ']) {
        expect(
          callSurfaceSuppressesIncoming(
            currentPath: '/realtime/sess-9',
            isJoined: false,
            incomingSessionId: id,
          ),
          isFalse,
          reason: 'id=$id',
        );
      }
    });
  });
}
