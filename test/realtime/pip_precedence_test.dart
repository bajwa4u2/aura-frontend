import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/realtime/presentation/widgets/floating_call_widget.dart';

/// A PiP MUST NOT PRECEDE THE ROOM IT REPRESENTS.
///
/// **Founder-observed on the receiving end, 2026-08-25:** accepting a call
/// flashed the floating call widget before the room appeared — *"transient pip
/// ... its on receiving end"*. Still present after the 2026-08-22 repair.
///
/// That earlier repair changed *which signal* decides whether the call surface
/// is on screen, from `isCallRoomVisible` (toggled in `initState`, which runs
/// only after the route is built) to the router address (which changes
/// synchronously with navigation). That was right, and it is kept.
///
/// It did not fix the ORDERING. Joining happens before navigation begins: the
/// callee accepts, the session becomes joined, the PiP's resolver starts
/// returning a call, and the PiP renders in the gap before the route changes.
/// On the receiving end that gap is longest, because accepting performs the
/// join and the navigation back to back.
///
/// The rule: a PiP means *"a call is running on some other screen"*. A call
/// whose room has never been shown is not running somewhere else — it is
/// arriving here.
void main() {
  group('the address still decides who owns the screen', () {
    test('a realtime call surface owns it, query string and all', () {
      // The callee lands on /realtime/:id?action=join&returnTo=... — the query
      // must not stop the match.
      expect(
        callSurfaceOwnsTheScreen(
          Uri.parse('/realtime/abc123?action=join&returnTo=%2Fmessages'),
        ),
        isTrue,
      );
    });

    test('a meeting live room owns it', () {
      expect(callSurfaceOwnsTheScreen(Uri.parse('/meetings/m1/live')), isTrue);
    });

    test('ordinary surfaces do not', () {
      for (final path in [
        '/messages',
        '/meetings/m1',
        '/institution/aura/meetings',
        '/home',
      ]) {
        expect(callSurfaceOwnsTheScreen(Uri.parse(path)), isFalse,
            reason: path);
      }
    });
  });

  group('the precedence rule is in the widget', () {
    late String src;

    setUpAll(() {
      src = File(
        'lib/features/realtime/presentation/widgets/floating_call_widget.dart',
      ).readAsStringSync();
    });

    test('the PiP is gated on the room having been shown', () {
      expect(src, contains('_surfaceShown'),
          reason: 'the precedence gate is gone — the PiP can flash before the '
              'room again');
      expect(src, contains('!_surfaceShown.contains(info.sessionId)'),
          reason: 'the gate no longer compares the resolved session');
    });

    test('what gets recorded is the RESOLVED identity, not the path id', () {
      // On /meetings/:id/live the path carries the MEETING id while the PiP
      // compares realtime session ids. Recording the path id would silently
      // suppress the meetings PiP forever — a regression traded for a fix.
      final marker = src.indexOf('final shown = _resolve();');
      expect(marker, greaterThan(-1),
          reason: 'the recorded identity is no longer the resolved one, so the '
              'meetings PiP may never appear again');
      expect(src, contains('_surfaceShown.add(shown.sessionId)'));
    });

    test('leaving is unaffected — the gate only guards arrival', () {
      // By the time somebody minimises, the surface has been shown, so the
      // set already contains the session and the PiP appears immediately.
      // Pinned as a comment invariant so the intent survives refactors.
      expect(src, contains('Leaving is unaffected'),
          reason: 'the rationale that keeps minimise working was removed');
    });
  });
}
