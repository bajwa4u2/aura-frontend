import 'package:flutter_test/flutter_test.dart';
import 'package:aura/features/realtime/data/sfu_realtime_transport.dart';

/// A TRACK WE COULD NOT ATTACH IS NOT A TRACK WE ARE RECEIVING.
///
/// Observed live on 2026-09-08. A call between the founder and Mrs Bajwa: she
/// subscribed and saw him; he subscribed, got `empty_track_error`, retried, got
/// `invalid_session_description`, and sat on "connecting" for the whole call
/// while she saw him perfectly.
///
/// The server half of that is fixed where the offer is now returned rather than
/// thrown away. The client half lived here, in one line:
///
///     _subscribed.addAll(fresh);
///
/// `fresh` is every track we ASKED for. A track the provider refused — because
/// the publisher had not created it at the provider yet, a race measured in
/// seconds — was recorded as subscribed anyway. And `fresh` is computed by
/// excluding `_subscribed`, so the retry that would have succeeded a moment
/// later was never sent. A two-second race became permanent.
///
/// The rule that fixes it: a binding without a `mid` names no m-line, so there
/// is no transceiver to attach and nothing can arrive on it. It is a refusal
/// wearing the shape of a result.
void main() {
  Map<String, dynamic> binding(String trackId, Object? mid) =>
      {'trackId': trackId, 'participantId': 'p', 'trackType': 'AUDIO', 'mid': mid};

  group('what counts as subscribed', () {
    test('a binding with a real mid counts', () {
      expect(boundTrackIds([binding('t1', '2')]), {'t1'});
    });

    test('a binding with a null mid does not', () {
      expect(boundTrackIds([binding('t1', null)]), isEmpty);
    });

    test('mid zero counts — it is a real m-line', () {
      // The trap in every falsiness-based version of this check. Cloudflare
      // names m-line zero routinely, and treating '0' as "no mid" would drop
      // the first track of every call.
      expect(boundTrackIds([binding('t1', '0')]), {'t1'});
      expect(boundTrackIds([binding('t1', 0)]), {'t1'});
    });

    test('the literal string "null" does not count', () {
      // Interpolation of a null through a JSON boundary produces this, and it
      // is not an m-line.
      expect(boundTrackIds([binding('t1', 'null')]), isEmpty);
    });

    test('a mixed response keeps only the tracks that bound', () {
      final bound = boundTrackIds([
        binding('audio', '2'),
        binding('video', null),
      ]);
      expect(bound, {'audio'});
    });
  });

  group('the retry gate this feeds', () {
    // The decision the transport makes with that set: what to ask for next
    // time. Asserted as arithmetic on the same rule, because the defect was
    // never in the request — it was in what got remembered afterwards.
    test('a refused track is asked for again; a bound one is not', () {
      final subscribed = <String>{};
      final requested = ['audio', 'video'];

      // First reconcile: video refused.
      final firstBound = boundTrackIds([
        binding('audio', '2'),
        binding('video', null),
      ]);
      subscribed.addAll(requested.where(firstBound.contains));

      final nextFresh =
          requested.where((id) => !subscribed.contains(id)).toList();
      expect(nextFresh, ['video'],
          reason: 'the refused track must be retried, the bound one must not');

      // Second reconcile: the publication has landed.
      final secondBound = boundTrackIds([binding('video', '4')]);
      subscribed.addAll(nextFresh.where(secondBound.contains));
      expect(subscribed, {'audio', 'video'});
      expect(requested.where((id) => !subscribed.contains(id)), isEmpty,
          reason: 'once everything is bound the loop goes quiet');
    });

    test('the old rule would have retried nothing', () {
      // Preserved as the counter-example: this is precisely what shipped, and
      // why the founder's client never recovered on its own.
      final subscribed = <String>{};
      final requested = ['audio', 'video'];
      subscribed.addAll(requested); // the unconditional addAll
      expect(requested.where((id) => !subscribed.contains(id)), isEmpty,
          reason: 'the refused track is never asked for again');
    });
  });
}
