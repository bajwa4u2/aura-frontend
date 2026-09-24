import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/realtime/data/sfu_realtime_transport.dart';

/// C-9 — A SENDER IS NOT ITS CURRENT TRACK.
///
/// `_replaceSource` found the sender to publish on with
/// `sender.track?.kind != kind`. A sender whose track has been CLEARED reports
/// a null track, therefore a null kind, therefore matches nothing — and stays
/// unmatchable for the rest of the call.
///
/// Clearing is not an exotic state. Stopping a screen share while no camera is
/// running calls `replaceVideoSource(null)` and does exactly this. From that
/// moment every share and every camera start logged `REPLACE_NO_SENDER`,
/// published nothing at all, and left the interface saying it was sharing —
/// the far end seeing nothing while the sharer believed they were sharing.
///
/// A sender's kind is fixed when its m-line is created and never changes, so
/// it is recorded there and read back here.
void main() {
  group('the rule', () {
    test('THE DEFECT: a cleared track no longer hides its sender', () {
      expect(
        senderPublishesKind(
          kind: 'video',
          trackKind: null, // replaceTrack(null) — the share was stopped
          recordedKind: 'video',
        ),
        isTrue,
        reason: 'this is the exact state that made a share reach nobody',
      );
    });

    test('a recorded kind that does not match is still refused', () {
      expect(
        senderPublishesKind(
          kind: 'video',
          trackKind: null,
          recordedKind: 'audio',
        ),
        isFalse,
        reason: 'publishing video down the audio m-line would be worse than '
            'the defect',
      );
    });

    test('the recorded kind wins over a stale track kind', () {
      // A sender mid-replacement can briefly carry the outgoing track. What it
      // was created to publish is the stable answer.
      expect(
        senderPublishesKind(
          kind: 'video',
          trackKind: 'audio',
          recordedKind: 'video',
        ),
        isTrue,
      );
    });

    test('without a record it falls back to the behaviour that shipped', () {
      // Senders this transport did not create, and platforms that will not
      // surface a sender id, must keep working exactly as before.
      expect(
        senderPublishesKind(kind: 'video', trackKind: 'video', recordedKind: null),
        isTrue,
      );
      expect(
        senderPublishesKind(kind: 'video', trackKind: 'audio', recordedKind: null),
        isFalse,
      );
      expect(
        senderPublishesKind(kind: 'video', trackKind: null, recordedKind: null),
        isFalse,
        reason: 'with nothing recorded there is no way to know, and guessing '
            'is what would publish down the wrong line',
      );
    });

    test('an empty record is treated as no record, not as a match', () {
      expect(
        senderPublishesKind(kind: 'video', trackKind: 'video', recordedKind: ''),
        isTrue,
      );
      expect(
        senderPublishesKind(kind: 'video', trackKind: null, recordedKind: ''),
        isFalse,
      );
    });
  });

  group('the wiring', () {
    final src = File(
      'lib/features/realtime/data/sfu_realtime_transport.dart',
    ).readAsStringSync();

    test('the kind is recorded when the sending m-line is created', () {
      expect(src, contains('_kindBySenderId[transceiver.sender.senderId]'));
    });

    test('only SendOnly lines are recorded', () {
      // A recvonly line's sender genuinely cannot publish. Recording it would
      // turn an honest REPLACE_NO_SENDER — which tells the caller to publish
      // and renegotiate — into a silent replace onto a line that sends
      // nothing.
      final open = src.substring(
        src.indexOf('Future<void> _open({'),
        src.indexOf('final offer = await pc.createOffer();'),
      );
      final recordAt = open.indexOf('_kindBySenderId[');
      final sendOnlyAt = open.lastIndexOf('TransceiverDirection.SendOnly', recordAt);
      final recvOnlyAt = open.lastIndexOf('TransceiverDirection.RecvOnly', recordAt);
      expect(recordAt, greaterThan(-1));
      expect(sendOnlyAt, greaterThan(recvOnlyAt),
          reason: 'the record must sit under the SendOnly branch');
    });

    test('the replace path no longer matches on the live track alone', () {
      final replace = src.substring(src.indexOf('Future<void> _replaceSource('));
      expect(replace, contains('senderPublishesKind('));
      expect(replace, isNot(contains('if (sender.track?.kind != kind) continue;')),
          reason: 'this is the line that made a cleared sender unmatchable');
    });

    test('REPLACE_NO_SENDER still exists for the case it was written for', () {
      // An audio-only join trying to share, or a camera that was denied at
      // attach, has no sending m-line at all. That must still be reported so
      // the caller publishes and renegotiates rather than failing silently.
      expect(src, contains("op=REPLACE_NO_SENDER kind="));
    });
  });
}
