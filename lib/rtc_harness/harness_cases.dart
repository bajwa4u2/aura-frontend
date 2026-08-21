// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
// CONTROLLER-LEVEL NEGOTIATION CERTIFICATION HARNESS — the cases.
//
// NOT PRODUCT. Each case joins a fresh pair of REAL RealtimeControllers,
// injures zero, one or both of them through a path production actually takes,
// and then only watches. Nothing here calls repair, sends an offer, or picks a
// winner; every offer in every trail was decided by the product.

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'harness_plane.dart';
import 'main.dart';

typedef CaseBody = Future<void> Function(CaseResult result);

class HarnessCase {
  const HarnessCase(this.id, this.title, this.body);
  final String id;
  final String title;
  final CaseBody body;
}

// ── Shared moves ────────────────────────────────────────────────────────────

/// Bring the pair up with the newcomer's acquisition stalled, so it answers the
/// existing peer's offer with a null local stream. [newcomerIsPolite] decides
/// which side of the politeness rule the injured participant lands on, which is
/// the whole difference between cases B and C.
///
/// Returns once the injury is REAL — the newcomer has media but no senders, and
/// the far side's negotiated directions say so. A case that cannot prove its
/// own precondition is reported as invalid rather than passed.
Future<World> silentNewcomer({
  required CaseResult result,
  required bool newcomerIsPolite,
  required String caseId,
  Duration stall = const Duration(seconds: 7),
}) async {
  // FIRST is the existing peer / offerer. Politeness is by socket id, so making
  // the newcomer polite means making FIRST impolite.
  final world = await World.create(
    firstIsPolite: !newcomerIsPolite,
    caseId: caseId,
  );
  world.second.media
    ..injury = MediaInjury.stallAcquisition
    ..stall = stall;

  result.note(
    'FIRST=${world.first.socketId} (polite=${world.first.politeAgainst(world.second)}), '
    'SECOND=${world.second.socketId} (polite=${world.second.politeAgainst(world.first)}); '
    'the SILENT side is SECOND, the newcomer/answerer',
  );

  await bringUp(world);
  // Wait past the stall so the injured side HAS media and is therefore a
  // genuinely stale peer rather than a transitional one.
  await waitUntil(
    () async => world.second.controller.state.isMediaReady,
    timeout: stall + const Duration(seconds: 20),
  );
  await hold(const Duration(seconds: 2));
  await result.checkpoint('injured', world);
  return world;
}

/// Did the injury this case depends on actually occur? Read from both ends:
/// the injured side publishes nothing, and the far side's NEGOTIATED direction
/// agrees that nothing is coming. One end alone could be a local artefact.
Future<bool> confirmOneWaySilence(World world, {required bool secondIsSilent}) async {
  final silent = secondIsSilent ? world.second : world.first;
  final healthy = secondIsSilent ? world.first : world.second;
  final silentProbe = await silent.probe(healthy);
  final healthyProbe = await healthy.probe(silent);
  return silentProbe.mediaReady &&
      silentProbe.senderKinds.isEmpty &&
      healthyProbe.senderKinds.isNotEmpty &&
      healthyProbe.remoteSilent;
}

/// Grade a recovery window: who offered, how often, and did the call end up
/// genuinely two-way.
Future<void> gradeRecovery(
  CaseResult result,
  World world, {
  required int windowStartMs,
}) async {
  final firstOffers = world.hub.offersFrom(world.first.socketId, afterMs: windowStartMs);
  final secondOffers = world.hub.offersFrom(world.second.socketId, afterMs: windowStartMs);
  final counts = trailCounts();

  result.checks.addAll(<String, dynamic>{
    'windowStartMs': windowStartMs,
    'recoveryOffers.FIRST': firstOffers,
    'recoveryOffers.SECOND': secondOffers,
    'recoveryOffers.total': firstOffers + secondOffers,
    'bothSidesOfferedInWindow': firstOffers > 0 && secondOffers > 0,
    'firstIsPolite': world.first.politeAgainst(world.second),
    'secondIsPolite': world.second.politeAgainst(world.first),
    'fullyDuplex': await bothSidesFullyDuplex(world),
    'joinState.FIRST': world.first.controller.state.joinState.name,
    'joinState.SECOND': world.second.controller.state.joinState.name,
    'error.FIRST': world.first.controller.state.errorMessage,
    'error.SECOND': world.second.controller.state.errorMessage,
    'joinStateTimeline': world.joinStateTimeline,
    'heldOffersStillParked': world.hub.heldOfferCount,
    'heldAnswersStillParked': world.hub.heldAnswerCount,
    ...counts,
  });
}

// ── Cases ───────────────────────────────────────────────────────────────────

final List<HarnessCase> kCases = <HarnessCase>[
  HarnessCase('A', 'healthy normal join', (result) async {
    final world = await World.create(firstIsPolite: true, caseId: 'A');
    try {
      await bringUp(world);
      final duplex = await waitUntil(
        () => bothSidesFullyDuplex(world),
        timeout: const Duration(seconds: 25),
      );
      await result.checkpoint('settled', world);
      final settledMs = Trail.clock.elapsedMilliseconds;

      // Two full heartbeats with nothing wrong. A design that offers here is
      // creating traffic — and glare risk — out of a healthy room.
      await hold(kHeartbeat * 2 + const Duration(seconds: 3));
      await result.checkpoint('after-2-heartbeats', world);

      result.checks['reachedDuplex'] = duplex;
      result.checks['offersAfterSettle.FIRST'] =
          world.hub.offersFrom(world.first.socketId, afterMs: settledMs);
      result.checks['offersAfterSettle.SECOND'] =
          world.hub.offersFrom(world.second.socketId, afterMs: settledMs);
      await gradeRecovery(result, world, windowStartMs: settledMs);
      result.frames = world.hub.sdpFrames();
    } finally {
      await world.teardown();
    }
  }),

  HarnessCase('B', 'only the IMPOLITE side is silent', (result) async {
    final world = await silentNewcomer(
      result: result,
      newcomerIsPolite: false,
      caseId: 'B',
    );
    try {
      result.checks['injuryReproduced'] =
          await confirmOneWaySilence(world, secondIsSilent: true);
      final windowStart = Trail.clock.elapsedMilliseconds;

      // Three heartbeats. One is enough for a design that repairs on the beat;
      // three distinguishes "repaired once" from "repairs forever".
      await hold(kHeartbeat * 3 + const Duration(seconds: 4));
      await result.checkpoint('after-3-heartbeats', world);
      await gradeRecovery(result, world, windowStartMs: windowStart);
      result.frames = world.hub.sdpFrames();
    } finally {
      await world.teardown();
    }
  }),

  HarnessCase('C', 'only the POLITE side is silent', (result) async {
    final world = await silentNewcomer(
      result: result,
      newcomerIsPolite: true,
      caseId: 'C',
    );
    try {
      result.checks['injuryReproduced'] =
          await confirmOneWaySilence(world, secondIsSilent: true);
      final windowStart = Trail.clock.elapsedMilliseconds;

      // The crux case. If the designated initiator is the OTHER side, this is
      // where a one-authority design either recovers or is proven insufficient.
      await hold(kHeartbeat * 3 + const Duration(seconds: 4));
      await result.checkpoint('after-3-heartbeats', world);
      await gradeRecovery(result, world, windowStartMs: windowStart);

      // What does the healthy, designated initiator actually KNOW? Recorded
      // whether or not the design used it, because question 2 of the brief is
      // "what exact evidence does the impolite side possess".
      final impolite = world.first.politeAgainst(world.second)
          ? world.second
          : world.first;
      final other = identical(impolite, world.first) ? world.second : world.first;
      final probe = await impolite.probe(other);
      final rosterPeer = other.controller.state.participants;
      result.checks['observability.initiatorIsFirst'] = identical(impolite, world.first);
      result.checks['observability.transceiverDirections'] =
          probe.transceiverDirections;
      result.checks['observability.remoteSilentByDirection'] = probe.remoteSilent;
      result.checks['observability.receiverKinds'] = probe.receiverKinds;
      result.checks['observability.remoteVideoLive'] = probe.remoteVideoLive;
      result.checks['observability.remoteAudioLive'] = probe.remoteAudioLive;
      result.checks['observability.rosterClaimsFromFarSide'] = rosterPeer
          .map((p) => <String, dynamic>{
                'userId': p.userId,
                'audioOn': p.audioOn,
                'videoOn': p.videoOn,
              })
          .toList();
      result.frames = world.hub.sdpFrames();
    } finally {
      await world.teardown();
    }
  }),

  HarnessCase('D', 'symmetric silence, offers RELEASED TOGETHER', (result) async {
    await _symmetricSilence(result, caseId: 'D', collide: true);
  }),

  HarnessCase('D2', 'symmetric silence, offers delivered normally', (result) async {
    // The contrast case. Identical injury, identical design, no delivery
    // control. If D fails and D2 passes, the failure is the COLLISION and not
    // the repair itself.
    await _symmetricSilence(result, caseId: 'D2', collide: false);
  }),

  HarnessCase('E', 'answer withheld until the real 8s watchdog fires', (result) async {
    // One side holds a genuine repair offer in flight; its answer is parked at
    // the wire so the REAL 8s watchdog becomes eligible on its own schedule.
    // Nothing is advanced, faked or invoked by hand — the question is only
    // whether the watchdog then acts as a SECOND offer authority for a recovery
    // that already has one.
    final world = await silentNewcomer(
      result: result,
      newcomerIsPolite: false,
      caseId: 'E',
    );
    try {
      result.checks['injuryReproduced'] =
          await confirmOneWaySilence(world, secondIsSilent: true);
      final windowStart = Trail.clock.elapsedMilliseconds;

      // Park every answer from here on. The silent side's beat-driven repair
      // offer will therefore go unanswered.
      world.hub.holdAnswers = true;
      result.note('answers parked at the wire; waiting for a real repair offer');

      final sawRepairOffer = await waitUntil(
        () async => world.hub.offersFrom(world.second.socketId,
                afterMs: windowStart) >
            0,
        timeout: const Duration(seconds: 45),
      );
      result.checks['repairOfferObserved'] = sawRepairOffer;
      final offerAt = Trail.clock.elapsedMilliseconds;

      // The real watchdog is 8s from the offer. Wait past it, then past a
      // heartbeat, so watchdog and beat both get their chance.
      await hold(kWatchdog + const Duration(seconds: 3));
      await result.checkpoint('after-watchdog-window', world);
      result.checks['offersDuringWatchdogWindow.SECOND'] =
          world.hub.offersFrom(world.second.socketId, afterMs: offerAt);
      result.checks['offersDuringWatchdogWindow.FIRST'] =
          world.hub.offersFrom(world.first.socketId, afterMs: offerAt);
      result.checks['heldAnswersAtWatchdog'] = world.hub.heldAnswerCount;

      // Now let every parked answer through at once — a late answer arriving
      // after a re-offer is the stale-answer condition the product claims to
      // absorb.
      world.hub.holdAnswers = false;
      world.hub.releaseHeldAnswers();
      await hold(const Duration(seconds: 6));
      await result.checkpoint('after-stale-answer-release', world);

      await hold(kHeartbeat * 2 + const Duration(seconds: 3));
      await result.checkpoint('after-2-more-heartbeats', world);
      await gradeRecovery(result, world, windowStartMs: windowStart);
      result.checks['offerTimeline'] = world.hub.frames
          .where((f) =>
              f['event'] == 'session:offer' && (f['at'] as int) >= windowStart)
          .toList();
      result.frames = world.hub.sdpFrames();
    } finally {
      world.hub.holdAnswers = false;
      await world.teardown();
    }
  }),

  HarnessCase('E2', "repair offer vs the far side Retry, released together",
      (result) async {
    // The cross-authority collision. One side's beat-driven repair offer and the
    // other side's retryMedia() offer are both genuine, both controller-decided,
    // and both parked until they can be released into each other. This is the
    // collision two users can produce without any timer coincidence: one side
    // repairs while the other taps Retry.
    final world = await silentNewcomer(
      result: result,
      newcomerIsPolite: false,
      caseId: 'E2',
    );
    try {
      final windowStart = Trail.clock.elapsedMilliseconds;
      world.hub.holdOffers = true;
      result.note('offers parked; waiting for a real repair offer to appear');

      final sawRepair = await waitUntil(
        () async => world.hub.heldOfferSenders.contains(world.second.socketId),
        timeout: const Duration(seconds: 45),
      );
      result.checks['repairOfferHeld'] = sawRepair;

      // The far side's user taps Retry. Its offer is parked next to the repair
      // offer rather than racing it.
      result.note('FIRST taps Retry while the repair offer is in flight');
      unawaited(world.first.controller.retryMedia());
      final sawRetry = await waitUntil(
        () async => world.hub.heldOfferSenders.contains(world.first.socketId),
        timeout: const Duration(seconds: 20),
      );
      result.checks['retryOfferHeld'] = sawRetry;
      result.checks['heldOffersBeforeRelease'] = world.hub.heldOfferCount;

      world.hub.holdOffers = false;
      world.hub.releaseHeldOffers();
      result.note('both offers released together');

      await hold(kWatchdog + const Duration(seconds: 4));
      await result.checkpoint('after-collision-and-watchdog', world);
      await hold(kHeartbeat * 2 + const Duration(seconds: 3));
      await result.checkpoint('after-2-more-heartbeats', world);
      await gradeRecovery(result, world, windowStartMs: windowStart);
      result.frames = world.hub.sdpFrames();
    } finally {
      world.hub.holdOffers = false;
      await world.teardown();
    }
  }),

  HarnessCase('F', 'simultaneous negotiation / glare', (result) async {
    final world = await World.create(firstIsPolite: true, caseId: 'F');
    try {
      await bringUp(world);
      await waitUntil(() => bothSidesFullyDuplex(world),
          timeout: const Duration(seconds: 25));
      await result.checkpoint('settled', world);
      final windowStart = Trail.clock.elapsedMilliseconds;

      // retryMedia() is a SHIPPED public entry point that renegotiates on
      // 'track-change'. Calling it on both sides at once is the product's own
      // symmetric offer authority — glare here is not a harness construction,
      // it is a state two users can reach by both tapping Retry.
      result.note('simultaneous retryMedia() on both sides — product glare path');
      await Future.wait(<Future<void>>[
        world.first.controller.retryMedia(),
        world.second.controller.retryMedia(),
      ]);
      await hold(const Duration(seconds: 8));
      await result.checkpoint('after-glare', world);
      await hold(kHeartbeat + const Duration(seconds: 3));
      await result.checkpoint('after-glare-plus-beat', world);
      await gradeRecovery(result, world, windowStartMs: windowStart);
      result.frames = world.hub.sdpFrames();
    } finally {
      await world.teardown();
    }
  }),

  HarnessCase('G', 'fresh answerer / acquisition transitional state', (result) async {
    final world = await World.create(firstIsPolite: true, caseId: 'G');
    try {
      world.second.media
        ..injury = MediaInjury.stallAcquisition
        ..stall = const Duration(seconds: 22);

      await bringUp(world);
      // Sample ACROSS two heartbeats while the newcomer is still transitional.
      // 381c452 shipped a design that repaired peers in exactly this window; a
      // rig that never looks here cannot catch that class of mistake.
      final samples = <Map<String, dynamic>>[];
      for (var i = 0; i < 4; i++) {
        await hold(const Duration(seconds: 5));
        final probe = await world.second.probe(world.first);
        samples.add(<String, dynamic>{
          'atMs': Trail.clock.elapsedMilliseconds,
          'mediaReady': probe.mediaReady,
          'senderKinds': probe.senderKinds,
          'signalling': probe.signalling,
        });
      }
      result.checks['transitionalSamples'] = samples;
      result.checks['repairTouchedTransitionalPeer'] =
          Trail.lines.any((l) => l.contains('[rtc-repair] repaired')) ||
              Trail.lines.any((l) => l.contains('[rtc-recover] repaired'));

      await waitUntil(() async => world.second.controller.state.isMediaReady,
          timeout: const Duration(seconds: 30));
      final windowStart = Trail.clock.elapsedMilliseconds;
      await hold(kHeartbeat * 3 + const Duration(seconds: 4));
      await result.checkpoint('after-transition', world);
      await gradeRecovery(result, world, windowStartMs: windowStart);
      result.frames = world.hub.sdpFrames();
    } finally {
      await world.teardown();
    }
  }),

  HarnessCase('H', 'camera off then on', (result) async {
    await _toggleCase(result, caseId: 'H', camera: true);
  }),

  HarnessCase('I', 'microphone off then on', (result) async {
    await _toggleCase(result, caseId: 'I', camera: false);
  }),

  HarnessCase('J', 'repeated recovery / idempotence', (result) async {
    final world = await silentNewcomer(
      result: result,
      newcomerIsPolite: false,
      caseId: 'J',
    );
    try {
      final windowStart = Trail.clock.elapsedMilliseconds;
      // Let recovery happen…
      await hold(kHeartbeat * 2 + const Duration(seconds: 4));
      await result.checkpoint('after-recovery', world);
      final afterRecoveryMs = Trail.clock.elapsedMilliseconds;
      final offersAtRecovery = world.hub.offersFrom(world.first.socketId) +
          world.hub.offersFrom(world.second.socketId);

      // …then four more beats. A design that re-detects the same peer every
      // beat produces an endless renegotiation loop that looks fine for the
      // first thirty seconds.
      await hold(kHeartbeat * 4 + const Duration(seconds: 4));
      await result.checkpoint('four-beats-later', world);
      final offersLater = world.hub.offersFrom(world.first.socketId) +
          world.hub.offersFrom(world.second.socketId);

      result.checks['offersAtRecovery'] = offersAtRecovery;
      result.checks['offersFourBeatsLater'] = offersLater;
      result.checks['offersAfterRecovery.FIRST'] =
          world.hub.offersFrom(world.first.socketId, afterMs: afterRecoveryMs);
      result.checks['offersAfterRecovery.SECOND'] =
          world.hub.offersFrom(world.second.socketId, afterMs: afterRecoveryMs);
      result.checks['idempotent'] = offersLater == offersAtRecovery;
      await gradeRecovery(result, world, windowStartMs: windowStart);
      result.frames = world.hub.sdpFrames();
    } finally {
      await world.teardown();
    }
  }),

  HarnessCase('K', 'leave and rejoin', (result) async {
    final world = await World.create(firstIsPolite: true, caseId: 'K');
    try {
      await bringUp(world);
      await waitUntil(() => bothSidesFullyDuplex(world),
          timeout: const Duration(seconds: 25));
      await result.checkpoint('settled', world);

      result.note('SECOND leaves');
      await world.second.controller.leave();
      await hold(const Duration(seconds: 3));
      await result.checkpoint('after-leave', world);
      result.checks['firstStillJoinedAfterPeerLeft'] =
          world.first.controller.state.isJoined;
      result.checks['firstDroppedPeer'] =
          !(await world.first.probe(world.second)).hasPeer;

      result.note('SECOND rejoins on a FRESH socket id, as the server issues one');
      final rejoinMs = Trail.clock.elapsedMilliseconds;
      final returning = await world.rejoinSecond();
      unawaited(returning.controller.join(world.sessionId));
      final rejoined = await waitUntil(
        () async => world.second.controller.state.isJoined,
        timeout: const Duration(seconds: 25),
      );
      final duplex = await waitUntil(
        () => bothSidesFullyDuplex(world),
        timeout: const Duration(seconds: 25),
      );
      await result.checkpoint('after-rejoin', world);
      result.checks['rejoined'] = rejoined;
      result.checks['duplexAfterRejoin'] = duplex;
      await gradeRecovery(result, world, windowStartMs: rejoinMs);
      result.frames = world.hub.sdpFrames();
    } finally {
      await world.teardown();
    }
  }),
];

/// Both sides silent at once, which is the state a beat-driven repair has to
/// survive. FIRST is denied its devices so it OFFERS with zero senders; SECOND
/// stalls so it ANSWERS with zero senders. Both paths are the product's own.
///
/// [gap] is the phase difference between the two heartbeats, and it is the
/// whole experiment: a repair that both sides decide to perform is only
/// dangerous when they decide it at the same time.
Future<void> _symmetricSilence(
  CaseResult result, {
  required String caseId,
  required bool collide,
}) async {
  final world = await World.create(firstIsPolite: true, caseId: caseId);
  try {
    world.first.media.injury = MediaInjury.denyAcquisition;
    world.second.media
      ..injury = MediaInjury.stallAcquisition
      ..stall = const Duration(seconds: 7);

    await bringUp(world, gap: kStaggeredJoinGap);
    await waitUntil(() async => world.second.controller.state.isMediaReady,
        timeout: const Duration(seconds: 25));

    // FIRST's devices come free. Nothing in the product renegotiates on this —
    // media-ready is not a renegotiation reason — so FIRST stays mute, and both
    // sides are now silent.
    await world.first.media.releaseDevice();
    await result.checkpoint('symmetric-silence', world);
    final windowStart = Trail.clock.elapsedMilliseconds;

    final a = await world.first.probe(world.second);
    final b = await world.second.probe(world.first);
    result.checks['symmetricSilenceReproduced'] = a.mediaReady &&
        b.mediaReady &&
        a.senderKinds.isEmpty &&
        b.senderKinds.isEmpty;
    result.checks['relayDelayMs'] = world.hub.relayDelay.inMilliseconds;
    result.checks['collisionInjected'] = collide;

    if (collide) {
      // DETERMINISTIC COLLISION. Both controllers are left to decide, on their
      // own heartbeats, that repair is needed; their genuine offers are parked
      // at the wire and released into each other only once BOTH exist. Nothing
      // about the offers is synthesised, and no timer is aligned — simultaneity
      // is produced where it actually lives, in delivery.
      world.hub.holdOffers = true;
      final bothOffered = await waitUntil(
        () async => world.hub.heldOfferSenders.length >= 2,
        timeout: const Duration(seconds: 60),
      );
      result.checks['bothSidesIndependentlyOffered'] = bothOffered;
      result.checks['heldOfferSenders'] = world.hub.heldOfferSenders.toList();
      result.checks['heldOffersBeforeRelease'] = world.hub.heldOfferCount;
      if (bothOffered) {
        result.note('both real recovery offers parked; releasing together');
        world.hub.holdOffers = false;
        world.hub.releaseHeldOffers();
      } else {
        result.note('only one side ever offered — no collision to release');
        world.hub.holdOffers = false;
        world.hub.releaseHeldOffers();
      }
    }

    // Long enough for the collision, the real 8s watchdog, and three further
    // heartbeats to all take their turn.
    await hold(kWatchdog + kHeartbeat * 3 + const Duration(seconds: 5));
    await result.checkpoint('after-collision-and-3-heartbeats', world);
    await gradeRecovery(result, world, windowStartMs: windowStart);

    final offers = world.hub.frames
        .where((f) =>
            f['event'] == 'session:offer' && (f['at'] as int) >= windowStart)
        .toList();
    result.checks['recoveryOfferTimeline'] = offers;
    result.checks['distinctOfferers'] =
        offers.map((f) => f['from']).toSet().length;

    // Did the shipped remedy help? retryMedia() is the product's Retry
    // affordance; if it cannot restore a silent peer then silence has no
    // in-product escape and a repair design is not optional.
    if (!(result.checks['fullyDuplex'] as bool? ?? false)) {
      final beforeRetry = Trail.clock.elapsedMilliseconds;
      result.note('probing the shipped remedy: retryMedia() on both sides');
      await Future.wait(<Future<void>>[
        world.first.controller.retryMedia(),
        world.second.controller.retryMedia(),
      ]);
      await hold(const Duration(seconds: 8));
      await result.checkpoint('after-simultaneous-retryMedia', world);
      result.checks['retryMedia.restoredDuplex'] = await bothSidesFullyDuplex(world);
      result.checks['retryMedia.offers.FIRST'] =
          world.hub.offersFrom(world.first.socketId, afterMs: beforeRetry);
      result.checks['retryMedia.offers.SECOND'] =
          world.hub.offersFrom(world.second.socketId, afterMs: beforeRetry);
    }
    result.frames = world.hub.sdpFrames();
  } finally {
    world.hub.holdOffers = false;
    await world.teardown();
  }
}

/// Camera and microphone toggles share a shape: flip it off, hold across two
/// heartbeats, flip it back on, hold again. The point is what must NOT happen —
/// an `enabled=false` track is still a sender, and any design that reads it as
/// a missing one will renegotiate a perfectly healthy call.
Future<void> _toggleCase(
  CaseResult result, {
  required String caseId,
  required bool camera,
}) async {
  final world = await World.create(firstIsPolite: true, caseId: caseId);
  try {
    await bringUp(world);
    await waitUntil(() => bothSidesFullyDuplex(world),
        timeout: const Duration(seconds: 25));
    await result.checkpoint('settled', world);
    final windowStart = Trail.clock.elapsedMilliseconds;

    result.note('${camera ? "camera" : "microphone"} OFF on SECOND');
    if (camera) {
      await world.second.controller.toggleCamera();
    } else {
      await world.second.controller.toggleMicrophone();
    }
    await hold(kHeartbeat * 2 + const Duration(seconds: 3));
    await result.checkpoint('off-across-2-heartbeats', world);
    final offProbe = await world.second.probe(world.first);
    result.checks['sendersWhileOff'] = offProbe.senderKinds;
    result.checks['directionsWhileOff'] = offProbe.transceiverDirections;
    result.checks['offersWhileOff.FIRST'] =
        world.hub.offersFrom(world.first.socketId, afterMs: windowStart);
    result.checks['offersWhileOff.SECOND'] =
        world.hub.offersFrom(world.second.socketId, afterMs: windowStart);

    result.note('${camera ? "camera" : "microphone"} back ON on SECOND');
    if (camera) {
      await world.second.controller.toggleCamera();
    } else {
      await world.second.controller.toggleMicrophone();
    }
    await hold(kHeartbeat + const Duration(seconds: 3));
    await result.checkpoint('back-on', world);
    await gradeRecovery(result, world, windowStartMs: windowStart);
    result.frames = world.hub.sdpFrames();
  } finally {
    await world.teardown();
  }
}

// ── Runner ──────────────────────────────────────────────────────────────────

Future<void> runSuite(void Function(String) status) async {
  final selected = kOnlyCases.trim().isEmpty
      ? kCases
      : kCases
          .where((c) => kOnlyCases.toUpperCase().split(',').contains(c.id))
          .toList();

  final report = <String, dynamic>{
    'design': kDesign,
    'cases': <Map<String, dynamic>>[],
  };

  for (final harnessCase in selected) {
    status('case ${harnessCase.id}: ${harnessCase.title}');
    Trail.reset();
    Trail.say('=== CASE ${harnessCase.id} — ${harnessCase.title} (design=$kDesign)');
    final result = CaseResult(harnessCase.id, harnessCase.title);
    try {
      await harnessCase.body(result);
    } catch (error, stack) {
      result.error = '$error\n$stack';
      Trail.say('CASE ${harnessCase.id} THREW: $error');
    }
    result.trail = Trail.relevant();
    (report['cases'] as List<Map<String, dynamic>>).add(result.toJson());
    // Post incrementally so a run that dies late still leaves the cases that
    // already completed on disk.
    await _post(report, status);
    // Let stray watchdog timers from the case that just ended expire before the
    // next case starts, so one case's noise is never another case's evidence.
    await hold(const Duration(seconds: 10));
  }

  status('DONE — ${(report['cases'] as List).length} cases');
  Trail.say('SUITE COMPLETE');
  await _post(report, status, done: true);
}

Future<void> _post(
  Map<String, dynamic> report,
  void Function(String) status, {
  bool done = false,
}) async {
  try {
    await http.post(
      Uri.base.resolve('report'),
      headers: <String, String>{'content-type': 'application/json'},
      body: jsonEncode(<String, dynamic>{...report, 'complete': done}),
    );
  } catch (error) {
    status('report POST failed: $error');
  }
}
