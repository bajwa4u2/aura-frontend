import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// C-1 — THE PROBE THAT SAW THE FAULT AND ONLY WROTE IT DOWN.
///
/// "One-way audio to Android" survived three investigations and a 09-11 hold.
/// It was reproduced live on production on 2026-09-24, on the **Play** build
/// of 1.4.4 (39), with a Bluetooth device connected to the phone:
///
///     13:45:14  bind  server=2 transceivers=4 receiving=2 bound=2
///                     noMid=0 noLine=0 dirUnreadable=0 noTrack=0
///     13:45:14  call audio route changed bt_sco -> speaker
///     13:45:15  kinds=audio=ABSENT video=68898b
///     13:49:42  kinds=audio=ABSENT video=50643560b
///
/// The audio receiver was negotiated and bound CLEANLY, and in the same second
/// the platform moved the call's audio route. Android restarts its audio
/// device on a communication-route change; the inbound audio stream went with
/// it, and nothing renegotiated. Five minutes of a call with perfect video and
/// no sound, recovering only when the OTHER party happened to republish and
/// rebuilt the receiver by accident.
///
/// A control run minutes later with Bluetooth off placed the route change five
/// seconds BEFORE the bind, and audio arrived normally (`first_bytes
/// kind=audio sinceOpenMs=7396`).
///
/// Two repairs, and this file holds the second and more important one:
///
///   1. the route is now settled BEFORE receivers are negotiated (the
///      controller awaits `setSpeakerphoneEnabled` instead of firing it into
///      the same moment as subscribe);
///   2. the transport NOTICES that its audio receiver has died and rebuilds
///      it — because a route change mid-call is not a fault to prevent. It is
///      somebody connecting earbuds, getting into a car, walking away from a
///      headset. Telling people to turn Bluetooth off is not a product.
///
/// `audio=ABSENT` had been computed every three seconds since the instrument
/// was added and acted on by nothing. That is what changed.
void main() {
  final src = File(
    'lib/features/realtime/data/sfu_realtime_transport.dart',
  ).readAsStringSync();

  /// The detection (`_checkAudioReceiverAlive`) and the repair
  /// (`_rebuildReceiversForKind`) — one span, because C-10 generalised the
  /// repair so a stalled VIDEO receiver is rebuilt the same way rather than
  /// condemning the whole transport.
  final recovery = (() {
    final start = src.indexOf('Future<void> _checkAudioReceiverAlive(');
    if (start < 0) throw StateError('the audio receiver recovery is gone');
    final end = src.indexOf('String _kindSummary(', start);
    if (end < 0) throw StateError('could not bound the recovery');
    return src.substring(start, end);
  })();

  group('the liveness probe acts on what it measures', () {
    test('the probe calls the check every tick', () {
      expect(src, contains('unawaited(_checkAudioReceiverAlive(byKind));'),
          reason: 'measuring ABSENT and doing nothing is the original defect');
    });

    test('it only fires when an AUDIO track is actually subscribed', () {
      // A video-only call, or one where nobody has published audio, is not
      // broken. Without this the repair would renegotiate healthy calls.
      expect(recovery, contains("_kindByTrackId[id] == 'audio'"));
      expect(recovery, contains('if (subscribedAudio.isEmpty)'));
    });

    test('a stream that exists but is silent is NOT this fault', () {
      // ABSENT (no inbound stream) and 0b (a stream carrying nothing) have
      // different causes and different repairs. Rebuilding a receiver that
      // exists would be the wrong fix, and the stall probe owns that case.
      expect(recovery, contains("byKind.containsKey('audio')"));
    });

    test('it waits before acting, so a receiver mid-negotiation is safe', () {
      expect(src, contains('_audioAbsentTicksBeforeRecovery = 3'),
          reason: 'the probe runs every 3s; this is about nine seconds');
      expect(recovery, contains('_audioAbsentTicks < _audioAbsentTicksBeforeRecovery'));
    });
  });

  group('the rebuild is the same act the accidental republish performed', () {
    test('it drops the subscription so the next reconcile asks again', () {
      expect(recovery, contains('_subscribed.removeAll(ofKind)'));
    });

    test('it clears the attempt counters it is not responsible for', () {
      // `_subscribeAttempts` bounds a DIFFERENT fault (a publisher race).
      // Spending that budget here would stop the retry that exists for it.
      expect(recovery, contains('_subscribeAttempts.remove(id)'));
    });

    test('it renegotiates', () {
      expect(recovery, contains("refreshRemoteMedia(trigger: 'RECEIVER_REBUILD_"));
    });

    test('it says so, so the next occurrence is legible in the trace', () {
      expect(recovery, contains('op=RECEIVER_REBUILD'));
    });

    test('it forgets the stall counters of the stream that went away', () {
      // Carrying them into the replacement would re-trip the moment the fresh
      // receiver is still warming up.
      expect(recovery, contains('_stallTicksByKind.remove(kind)'));
      expect(recovery, contains('_lastBytesByKind.remove(kind)'));
    });
  });

  group('it is bounded', () {
    test('a fault renegotiation cannot fix does not renegotiate forever', () {
      expect(src, contains('_maxRecoveriesPerKind = 3'));
      expect(recovery, contains('used >= _maxRecoveriesPerKind'));
    });

    test('the budget is PER KIND', () {
      // A camera that keeps stopping must not exhaust the budget audio needs.
      expect(src, contains('_recoveriesByKind'));
    });

    test('it stands down while the transport is closing or already lost', () {
      expect(recovery, contains('if (_closing || _lostReported) return;'));
    });

    test('a failed rebuild cannot break the call', () {
      expect(recovery, contains('} catch (_) {'));
    });
  });

  group('the route is settled before receivers are negotiated', () {
    final controller = File(
      'lib/features/realtime/application/realtime_controller.dart',
    ).readAsStringSync();

    test('the default output is AWAITED, not fired into the same moment', () {
      expect(controller,
          contains('await _mediaService.setSpeakerphoneEnabled(wantsVideo);'));
      expect(controller,
          isNot(contains('unawaited(_mediaService.setSpeakerphoneEnabled(')),
          reason: 'fire-and-forget is what let the route change land in the '
              'same second as the bind');
    });

    test('the measurement that proved it is kept beside the await', () {
      expect(controller, contains('AND IT IS AWAITED, BECAUSE WHEN IT LANDS'));
    });
  });
}
