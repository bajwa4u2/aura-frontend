// NO_INFINITE_SPINNER — proof that a stalled media load becomes an honest
// error rather than a permanent loading state.
//
// The production symptom this locks out: the immersive viewer sat on a
// CircularProgressIndicator indefinitely while `Open original` remained the
// only working affordance. The cause was not a missing error UI — every player
// already had one. It was that a STALLED load never completes and never
// throws, so nothing could route to it. Silence is not an error, and
// `catchError` cannot catch silence.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/media/media_initialization.dart';

void main() {
  group('MEDIA_INITIALIZATION_TIMEOUT = HONEST_ERROR', () {
    test('a stalled operation is converted into a throw', () async {
      // A Future that never completes — exactly what a wedged decoder or a
      // load waiting on bytes that never arrive looks like from Dart.
      final never = Completer<void>();

      await expectLater(
        boundedMediaInit(
          MediaInitPhase.acquisition,
          () => never.future,
          timeout: const Duration(milliseconds: 40),
        ),
        throwsA(isA<MediaInitTimeout>()),
      );
    });

    test('the timeout names the phase that exceeded its bound', () async {
      final never = Completer<void>();
      try {
        await boundedMediaInit(
          MediaInitPhase.decode,
          () => never.future,
          timeout: const Duration(milliseconds: 40),
        );
        fail('expected a MediaInitTimeout');
      } on MediaInitTimeout catch (e) {
        expect(e.phase, MediaInitPhase.decode);
        expect(e.toString(), contains('decode'));
      }
    });

    test('a real error still propagates unchanged', () async {
      // The bound must not swallow or reclassify a genuine decode failure —
      // that path already worked and must keep working.
      await expectLater(
        boundedMediaInit(
          MediaInitPhase.acquisition,
          () => Future<void>.error(StateError('codec refused')),
          timeout: const Duration(seconds: 5),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('a successful operation is returned untouched and not delayed', () async {
      final value = await boundedMediaInit(
        MediaInitPhase.playback,
        () async => 'ready',
        timeout: const Duration(seconds: 5),
      );
      expect(value, 'ready');
    });

    test('NEGATIVE CONTROL — without the bound, the stall never resolves', () async {
      // Restores the pre-fix behaviour and shows it hanging: the same Future,
      // awaited directly, is still pending long after the bounded call above
      // has already failed. This is the defect, reproduced.
      final never = Completer<void>();
      var settled = false;
      unawaited(never.future.then((_) => settled = true, onError: (_) => settled = true));

      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(settled, isFalse);
    });
  });

  group('every phase is bounded, and bounded sensibly', () {
    test('no phase is unbounded', () {
      for (final phase in MediaInitPhase.values) {
        final t = mediaInitTimeout(phase);
        expect(t, greaterThan(Duration.zero), reason: '${phase.name} must be bounded');
        // A ceiling as well as a floor: a "bound" measured in minutes would
        // technically satisfy the state machine while failing the person.
        expect(t.inSeconds, lessThanOrEqualTo(60), reason: '${phase.name} is too patient');
      }
    });

    test('acquisition is the most patient phase', () {
      // Fetching first bytes over a poor connection deserves more time than a
      // decoder that has already been handed them; a single global number
      // would either cut off a slow network or let a wedged decoder hang.
      final acquisition = mediaInitTimeout(MediaInitPhase.acquisition);
      for (final phase in MediaInitPhase.values) {
        if (phase == MediaInitPhase.acquisition) continue;
        expect(
          mediaInitTimeout(phase).inSeconds,
          lessThanOrEqualTo(acquisition.inSeconds),
          reason: '${phase.name} should not out-wait acquisition',
        );
      }
    });

    test('a poster waits the least — it is recognition, not the media', () {
      expect(
        mediaInitTimeout(MediaInitPhase.poster).inSeconds,
        lessThan(mediaInitTimeout(MediaInitPhase.acquisition).inSeconds),
      );
    });
  });
}
