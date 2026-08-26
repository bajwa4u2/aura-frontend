import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// THE SILENT ANSWERER — one-way media, fixed and pinned.
///
/// **Founder-observed live, 2026-08-25, Pixel ↔ browser:** a connected
/// two-party video call in which the callee saw nothing at all while the caller
/// saw them perfectly. Confirmed by the founder in the moment: *"callee not
/// having remote video"*.
///
/// ## The root cause
///
/// `handleRemoteOffer` is the answerer path. It attaches local tracks AFTER
/// `setRemoteDescription` — correct, because attaching before misaligns
/// m-lines — and does it exactly once, guarded by `isNewPeer`. If the offer
/// arrives while `getUserMedia` is still resolving, `_localStream` is null,
/// `_attachLocalTracks` attached nothing, and `createAnswer` produced
/// **recvonly** m-lines. The peer reaches Connected and is permanently dark and
/// silent to the far side.
///
/// It cannot recover afterwards: `setCameraEnabled` only flips `track.enabled`
/// on tracks that already exist, and `replaceTrack` needs a sender to replace.
/// That is why toggling the camera did nothing and only leaving and rejoining
/// helped.
///
/// ## Why this test is structural
///
/// The defect is an ORDERING property inside one method, across a real
/// `RTCPeerConnection` that cannot be constructed in a widget test. The repo
/// already proves architectural invariants this way. This test was
/// **negative-controlled**: removing the wait makes it fail.
///
/// ## Why it must not be deleted again
///
/// A previous repair (`381c452`) was reverted by `a77b62e`, which also deleted
/// its 237-line regression test, and a second attempt (`9815742`) was reverted
/// by `4420602`. `main` then carried neither repair nor test, and the defect
/// stayed live for four days until a real two-party call surfaced it again.
/// If this fix is ever reverted, delete this test deliberately — do not let it
/// go quietly with the code.
void main() {
  late String attach;

  setUpAll(() {
    final src = File(
      'lib/features/realtime/data/realtime_media_service.dart',
    ).readAsStringSync();

    final begin = src.indexOf('Future<void> _attachLocalTracks(');
    expect(begin, greaterThan(-1),
        reason: '_attachLocalTracks was renamed; re-establish this invariant '
            'against whatever replaced it rather than deleting the test');
    final end = src.indexOf('Future<RTCPeerConnection> _ensurePeer(', begin);
    expect(end, greaterThan(begin));
    attach = src.substring(begin, end);
  });

  test('it waits for an in-flight acquisition before giving up', () {
    expect(attach, contains('_mediaAcquisition'),
        reason: 'the answerer no longer waits for media that is still being '
            'acquired, so a well-timed offer produces recvonly again');
    expect(attach, contains('await inflight'),
        reason: 'the in-flight future is read but never awaited');
  });

  test('the wait happens BEFORE the null check that abandons the attach', () {
    final wait = attach.indexOf('await inflight');
    final bail = attach.indexOf("attach: NO local stream");
    expect(wait, greaterThan(-1));
    expect(bail, greaterThan(-1),
        reason: 'the honest "nothing to send" path was removed; a refused '
            'device must still be able to join receive-only');
    expect(wait, lessThan(bail),
        reason: 'THE REGRESSION THIS PREVENTS: the answerer concludes it has '
            'no media while getUserMedia is still resolving, answers '
            'recvonly, and is permanently dark to the far side');
  });

  test('a genuinely absent device still returns rather than hanging', () {
    // Waiting must be conditional on there BEING something to wait for.
    // Someone who refused their camera must still join, receive-only.
    expect(attach, contains('_localStream == null && inflight != null'),
        reason: 'the wait is unconditional, so a refused device would block '
            'the answer instead of joining receive-only');
  });

  test('the offer path still attaches only for a new peer', () {
    // Renegotiation offers arrive on peers that already carry their tracks;
    // re-attaching would duplicate senders.
    final src = File(
      'lib/features/realtime/data/realtime_media_service.dart',
    ).readAsStringSync();
    final offer = src.indexOf('_remoteDescriptionSet.add(peerKey)');
    final guarded = src.indexOf('if (isNewPeer)', offer);
    expect(guarded, greaterThan(offer),
        reason: 'the isNewPeer guard on the answerer attach is gone');
  });
}
