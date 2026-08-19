// RC9 — ONCE PER APP LOAD IS NOT ONCE FOR ALL TIME.
//
// `_bootstrapDone` is module state, so it survived provider invalidation. A
// sibling tab signing in published a login event, this tab invalidated
// `sessionBootstrapProvider` in response — and the rebuilt provider returned
// on its FIRST LINE because the flag was still set. The invalidation was a
// no-op, and the comment at the call site ("the bootstrap on the next
// provider read will pick it up") described something that could not happen.
//
// The latch is still right for what it was for: one speculative
// `/auth/refresh` per app load, not one per widget rebuild. What it must not
// do is outlive an AUTHORITATIVE session change.
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/auth/session_bootstrap.dart';

void main() {
  setUp(() => debugSetSessionBootstrapDone(false));
  tearDown(() => debugSetSessionBootstrapDone(false));

  group('RC9 — initialisation stays once, reconstruction stays repeatable', () {
    test('a completed bootstrap does not run again on its own', () {
      // The property the latch exists for: no speculative refresh per widget
      // rebuild, per provider read, or per route change.
      debugSetSessionBootstrapDone(true);
      expect(debugSessionBootstrapWouldRun(), isFalse);
    });

    test('an authoritative session change lets it run again', () {
      debugSetSessionBootstrapDone(true);
      resetSessionBootstrap();
      expect(debugSessionBootstrapWouldRun(), isTrue,
          reason: 'Without this, invalidating the provider is cosmetic.');
    });

    test('the reset is idempotent — duplicate events do not stack', () {
      // Browsers can deliver the same broadcast more than once, and a person
      // can sign in and out repeatedly. Neither may accumulate state.
      debugSetSessionBootstrapDone(true);
      for (var i = 0; i < 5; i++) {
        resetSessionBootstrap();
      }
      expect(debugSessionBootstrapWouldRun(), isTrue);
    });

    test('resetting an already-idle bootstrap changes nothing', () {
      expect(debugSessionBootstrapWouldRun(), isTrue);
      resetSessionBootstrap();
      expect(debugSessionBootstrapWouldRun(), isTrue);
    });

    test('a later completion latches again — no permanent open door', () {
      // Reset PERMITS one reconstruction; it does not disable the guard
      // forever, or every subsequent read would re-ask the network.
      resetSessionBootstrap();
      expect(debugSessionBootstrapWouldRun(), isTrue);
      debugSetSessionBootstrapDone(true);
      expect(debugSessionBootstrapWouldRun(), isFalse);
    });

    test('the reset itself performs NO network work and asks nothing', () {
      // It is a trigger, not an authority: it only permits the question to be
      // asked again. The answer still comes from /auth/refresh and the
      // canonical session authorities, with the RC1 rules deciding whether
      // asking is warranted at all. A pure state flip cannot need a
      // container, a Dio or a token store — and this test passes without any
      // of them, which is the proof.
      debugSetSessionBootstrapDone(true);
      resetSessionBootstrap();
      expect(debugSessionBootstrapWouldRun(), isTrue);
    });
  });
}
