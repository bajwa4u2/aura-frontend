import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/realtime/data/realtime_media_service.dart';

/// PEER ELIGIBILITY — the layer the first attempt did not test, and the layer
/// that broke production.
///
/// The reverted repair (381c452) used "peer has zero senders" as a proxy for
/// "peer is stale". That predicate is invalid: a newly created ANSWERER also
/// has zero senders, legitimately, right up until `handleRemoteOffer` attaches
/// them. Adding tracks in that window misaligns m-lines and took down both
/// sides of a live meeting.
///
/// The previous test file pinned the kind-selection ARITHMETIC and passed
/// happily while the eligibility rule was wrong. So these tests walk the two
/// real lifecycles state by state and assert the verdict at each step.
void main() {
  /// A settled, healthy peer. Individual tests move one field off this.
  PeerRepairVerdict verdict({
    bool localMediaReady = true,
    bool remoteDescriptionSet = true,
    bool signallingStable = true,
    bool makingOffer = false,
    Set<String> presentKinds = const {'audio', 'video'},
    List<String> localKinds = const ['audio', 'video'],
  }) {
    return evaluatePeerRepair(
      localMediaReady: localMediaReady,
      remoteDescriptionSet: remoteDescriptionSet,
      signallingStable: signallingStable,
      makingOffer: makingOffer,
      presentKinds: presentKinds,
      localKinds: localKinds,
    );
  }

  group('ANSWERER lifecycle — the states the reverted repair destroyed', () {
    test('step 1: fresh answerer, before setRemoteDescription — NOT eligible', () {
      // _ensurePeer(addLocalTracks: false). Zero senders and CORRECT: the
      // tracks are attached two steps later. THIS is the exact state the
      // reverted repair attacked, and why both sides went dark.
      expect(
        verdict(remoteDescriptionSet: false, presentKinds: const {}),
        PeerRepairVerdict.waitRemoteDescription,
      );
    });

    test('step 2: remote offer applied but not yet answered — NOT eligible', () {
      // signalling == have-remote-offer. remoteDescriptionSet is now TRUE, so
      // that guard alone no longer protects this peer — stability does.
      expect(
        verdict(signallingStable: false, presentKinds: const {}),
        PeerRepairVerdict.waitNegotiation,
      );
    });

    test('step 4: answered and stable, senders missing — ELIGIBLE', () {
      // The genuine defect: media was late, _attachLocalTracks attached
      // nothing, and nothing will ever retry it.
      expect(verdict(presentKinds: const {}), PeerRepairVerdict.repair);
    });
  });

  group('OFFERER lifecycle', () {
    test('mid createOffer() — NOT eligible, and stability alone would miss it', () {
      // The subtle one. Between `_makingOffer = true` and
      // setLocalDescription(offer), signalling is STILL stable from the prior
      // negotiation. Guarding on stability alone would wrongly admit this peer,
      // which is why makingOffer is required rather than redundant.
      expect(
        verdict(makingOffer: true, presentKinds: const {}),
        PeerRepairVerdict.waitNegotiation,
      );
      // Proof the guard is load-bearing: identical state minus makingOffer
      // flips the verdict.
      expect(verdict(presentKinds: const {}), PeerRepairVerdict.repair);
    });

    test('offer sent, awaiting answer — NOT eligible', () {
      expect(
        verdict(signallingStable: false, presentKinds: const {}),
        PeerRepairVerdict.waitNegotiation,
      );
    });
  });

  group('media readiness', () {
    test('no local media yet — NOT eligible, nothing to publish', () {
      expect(
        verdict(
          localMediaReady: false,
          presentKinds: const {},
          localKinds: const [],
        ),
        PeerRepairVerdict.waitMedia,
      );
    });

    test('media unready outranks every other signal', () {
      // Repairing without media would renegotiate for nothing.
      expect(
        verdict(localMediaReady: false, presentKinds: const {}),
        PeerRepairVerdict.waitMedia,
      );
    });
  });

  group('a healthy peer is left alone', () {
    test('settled peer already publishing both kinds — NOT eligible', () {
      expect(verdict(), PeerRepairVerdict.healthy);
    });

    test('a repaired peer does not get repaired again — no renegotiation loop', () {
      // The loop guard. After a repair the peer carries the kinds, so the very
      // next sweep must report healthy. If this ever returns `repair`, the
      // heartbeat would re-offer every 10s forever.
      var present = <String>{};
      var v = verdict(presentKinds: present);
      expect(v, PeerRepairVerdict.repair);

      // Simulate the repair having added what was missing.
      present = missingSenderKinds(
        presentKinds: present,
        localKinds: const ['audio', 'video'],
      );
      expect(verdict(presentKinds: present), PeerRepairVerdict.healthy);
      expect(verdict(presentKinds: present), PeerRepairVerdict.healthy);
    });

    test('audio-only peer missing only video — ELIGIBLE for the video alone', () {
      expect(verdict(presentKinds: const {'audio'}), PeerRepairVerdict.repair);
      expect(
        missingSenderKinds(
          presentKinds: const {'audio'},
          localKinds: const ['audio', 'video'],
        ),
        {'video'},
      );
    });

    test('a screen share satisfies video — kind, not identity', () {
      expect(
        verdict(
          presentKinds: const {'audio', 'video'},
          localKinds: const ['audio', 'video'],
        ),
        PeerRepairVerdict.healthy,
      );
    });
  });

  group('kind selection', () {
    test('empty kinds are never added', () {
      expect(
        missingSenderKinds(
          presentKinds: const <String>{},
          localKinds: const ['', 'audio', ''],
        ),
        {'audio'},
      );
    });

    test('duplicate local kinds collapse to one addition', () {
      expect(
        missingSenderKinds(
          presentKinds: const <String>{},
          localKinds: const ['video', 'video'],
        ),
        {'video'},
      );
    });

    test('no local tracks means nothing to add', () {
      expect(
        missingSenderKinds(
          presentKinds: const {'audio'},
          localKinds: const <String>[],
        ),
        isEmpty,
      );
    });
  });
}
