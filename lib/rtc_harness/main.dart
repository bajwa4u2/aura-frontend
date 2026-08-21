// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
// CONTROLLER-LEVEL NEGOTIATION CERTIFICATION HARNESS  (NOT PRODUCT)
//
// A separate entrypoint with its own main(). Never reachable from lib/main.dart,
// never registered in router.dart, never in a release bundle.
//
//   flutter build web --release -t lib/rtc_harness/main.dart \
//       --dart-define=DESIGN=<baseline|legacy|optionA>
//
// ─────────────────────────────────────────────────────────────────────────────
// WHY THE PREVIOUS HARNESS WAS NOT A CERTIFICATION RIG
//
// The harness committed with 9815742 exercised RealtimeMediaService alone. It
// proved an eligibility PREDICATE and nothing about the thing that actually
// broke production: WHO IS ALLOWED TO INITIATE NEGOTIATION. A predicate cannot
// see glare, cannot see the answer watchdog, cannot see the offer queue and
// cannot see joinState — so a design whose only real risk is "both peers decide
// to repair at once" was validated by a rig that could not represent two peers
// deciding anything.
//
// This harness puts the REAL RealtimeController on both ends of one peer pair.
// Under test, unmodified: two live controllers, the real join sequence and
// RealtimeJoinState machine, the real RealtimeMediaService over real
// RTCPeerConnections with real getUserMedia and real SDP, the real offer queue
// (_queueOfferTarget / _flushPendingOffers), the real 8s answer watchdog, the
// real 10s heartbeat, and the real politeness rule.
//
// Substituted, with product-equivalent behaviour rather than stubs: the socket
// gateway (an in-process relay that speaks the same contract) and the REST
// bundle. See harness_plane.dart for why each substitution preserves the
// invariant it touches.
//
// The harness never calls repair, never calls _sendOfferToSocket and never
// arbitrates. It joins two controllers, injures one or both, and watches.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/material.dart';

import 'package:aura/features/realtime/application/realtime_controller.dart';

import 'harness_cases.dart';
import 'harness_plane.dart';

/// Which negotiation design this BUILD contains. The harness is design-blind —
/// it drives the product and reports what happened. This only labels the
/// report, so a run can never be attributed to the wrong tree.
const String kDesign = String.fromEnvironment('DESIGN', defaultValue: 'unknown');

/// Comma-separated case letters to run. Empty runs all of them.
const String kOnlyCases = String.fromEnvironment('CASES', defaultValue: '');

const Duration kHeartbeat = Duration(seconds: 10);
const Duration kWatchdog = Duration(seconds: 8);

/// One-way signalling latency. NOT cosmetic, and not a stress knob.
///
/// The first version of this rig relayed in 8ms and staggered the two joins by
/// two seconds. Under those conditions the known-bad design passed every case,
/// because two repairs decided two seconds apart can never collide: the first
/// side's offer lands while the second is still stable, so it is answered as an
/// ordinary renegotiation and no glare exists to be mishandled. A rig that
/// cannot produce the collision cannot falsify a design whose only real risk IS
/// the collision.
///
/// 60ms each way is an ordinary same-region round trip through a server hop,
/// and it is the width of the window inside which two independent decisions
/// become simultaneous.
const Duration kRelayDelay = Duration(milliseconds: 60);

/// Gap between the two joins. The heartbeat starts the instant the socket join
/// is acked, so this gap IS the phase difference between the two sides' 10s
/// beats — and therefore decides whether two beat-driven repairs land on top of
/// each other or politely take turns. Two people clicking into the same meeting
/// land far closer together than two seconds.
const Duration kAlignedJoinGap = Duration(milliseconds: 120);
const Duration kStaggeredJoinGap = Duration(seconds: 2);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Trail.install();
  runApp(const _HarnessApp());
}

class _HarnessApp extends StatefulWidget {
  const _HarnessApp();
  @override
  State<_HarnessApp> createState() => _HarnessAppState();
}

class _HarnessAppState extends State<_HarnessApp> {
  String _status = 'starting';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(runSuite((s) {
        if (mounted) setState(() => _status = s);
      }));
    });
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFF101014),
          body: Center(
            child: Text(
              'design=$kDesign\n$_status',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
          ),
        ),
      );
}

// ── World ───────────────────────────────────────────────────────────────────

/// One peer pair for one case. Fresh every time: a case must never inherit
/// another case's timers, sockets or peer connections.
class World {
  World._(this.hub, this.first, this.second, this.sessionId);

  final SignalHub hub;

  /// The EXISTING peer. It learns the newcomer's live socketId from
  /// participant.joined and is therefore the initial offerer, which is the
  /// production invariant, not a harness choice.
  final Party first;

  /// The NEWCOMER. Its REST roster carries no socketId for [first], so it only
  /// ever answers the initial negotiation. Not final: a rejoin replaces it,
  /// because a rejoining participant gets a NEW socket id from the server and
  /// reusing the old one would quietly test a state production cannot reach.
  Party second;

  final String sessionId;

  /// Measured phase difference between the two 10s heartbeats, in ms. This is
  /// the number that decides whether two beat-driven repairs collide, so it is
  /// reported rather than assumed.
  int beatSkewMs = -1;

  /// [firstIsPolite] chooses which side loses a glare, by choosing socket ids.
  /// Politeness and offerer-ness are INDEPENDENT axes in production — which
  /// side joined first says nothing about which id sorts lower — so a rig that
  /// could not separate them could not tell "only the polite side is silent"
  /// from "only the answerer is silent".
  static Future<World> create({
    required bool firstIsPolite,
    required String caseId,
    Duration relayDelay = kRelayDelay,
  }) async {
    final hub = SignalHub(relayDelay: relayDelay);
    final sessionId = 'session-$caseId';

    // 'a...' sorts below 'z...', so the polite side is chosen by id, exactly
    // as the product's _rawSocket().compareTo() rule decides it.
    final firstId = firstIsPolite ? 'aa-first' : 'zz-first';
    final secondId = firstIsPolite ? 'zz-second' : 'aa-second';

    final first = _makeParty('FIRST', 'user-first', firstId, hub, sessionId);
    final second = _makeParty('SECOND', 'user-second', secondId, hub, sessionId);
    final world = World._(hub, first, second, sessionId);
    // Sampled from the first instant, in every case: a failed join state that
    // lasts less than a checkpoint interval is still a failed join state.
    world.watchJoinState();
    return world;
  }

  static Party _makeParty(
    String label,
    String userId,
    String socketId,
    SignalHub hub,
    String sessionId,
  ) {
    final socket = HarnessSocketService(socketId, hub);
    final media = HarnessMediaService();
    final repository = HarnessRepository(hub, sessionId);
    hub.register(socket, userId, label);
    final controller = RealtimeController(
      repository,
      socket,
      media,
      HarnessTokenStore(),
      () async => null,
      readMyUserId: () async => userId,
    );
    return Party(
      label: label,
      userId: userId,
      controller: controller,
      media: media,
      socket: socket,
    );
  }

  /// A rejoin, as the server performs one: the party comes back on a FRESH
  /// socket id. That difference is load-bearing — the existing peer decides to
  /// offer on "I hold this peer's live socketId and have no peer connection for
  /// it", so a recycled id would make the room look already-negotiated and no
  /// offer would ever be sent.
  // ── Join-state timeline ────────────────────────────────────────────────
  //
  // A checkpoint every ten seconds cannot see a transient. The founder-observed
  // production symptom was a FAILED JOIN STATE, and joinState is a value that
  // can pass through `failed` or `idle` and be back at `joined` before the next
  // checkpoint looks. So it is sampled continuously and reported as a list of
  // TRANSITIONS — an unchanged state costs nothing, and a flicker cannot hide.
  final List<Map<String, dynamic>> joinStateTimeline = <Map<String, dynamic>>[];
  Timer? _joinWatch;

  void watchJoinState() {
    final last = <String, String>{};
    void sample() {
      for (final party in <Party>[first, second, ..._retired]) {
        String value;
        try {
          value = party.controller.state.joinState.name;
        } catch (_) {
          continue; // disposed mid-case; not a transition
        }
        if (last[party.socketId] == value) continue;
        last[party.socketId] = value;
        joinStateTimeline.add(<String, dynamic>{
          'atMs': Trail.clock.elapsedMilliseconds,
          'side': party.label,
          'socketId': party.socketId,
          'joinState': value,
        });
        Trail.say('joinState ${party.label} -> $value');
      }
    }

    sample();
    _joinWatch?.cancel();
    _joinWatch = Timer.periodic(const Duration(milliseconds: 200), (_) => sample());
  }

  Future<Party> rejoinSecond() async {
    final replacement = _makeParty(
      'SECOND2',
      second.userId,
      '${second.socketId}-r2',
      hub,
      sessionId,
    );
    _retired.add(second);
    second = replacement;
    return replacement;
  }

  final List<Party> _retired = <Party>[];

  Future<void> teardown() async {
    _joinWatch?.cancel();
    for (final party in <Party>[first, second, ..._retired]) {
      try {
        await party.controller.leave();
      } catch (_) {}
      try {
        party.controller.dispose();
      } catch (_) {}
      try {
        await party.media.dispose();
      } catch (_) {}
      try {
        party.socket.dispose();
      } catch (_) {}
    }
  }
}

Future<void> hold(Duration d) => Future<void>.delayed(d);

/// Poll until [test] passes or [timeout] elapses. Returns whether it passed, so
/// a timeout is recorded as a result rather than thrown away as an exception.
Future<bool> waitUntil(
  Future<bool> Function() test, {
  Duration timeout = const Duration(seconds: 20),
  Duration poll = const Duration(milliseconds: 250),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (await test()) return true;
    await hold(poll);
  }
  return false;
}

// ── Case scaffolding ────────────────────────────────────────────────────────

class CaseResult {
  CaseResult(this.id, this.title);

  final String id;
  final String title;
  final List<Map<String, dynamic>> checkpoints = <Map<String, dynamic>>[];
  final Map<String, dynamic> checks = <String, dynamic>{};
  final List<String> notes = <String>[];
  List<String> trail = <String>[];
  List<Map<String, dynamic>> frames = <Map<String, dynamic>>[];
  String? error;

  void note(String text) {
    notes.add(text);
    Trail.say('note: $text');
  }

  Future<void> checkpoint(String name, World world) async {
    final a = await world.first.probe(world.second);
    final b = await world.second.probe(world.first);
    checkpoints.add(<String, dynamic>{
      'name': name,
      'atMs': Trail.clock.elapsedMilliseconds,
      'first': a.toJson(),
      'second': b.toJson(),
    });
    Trail.say(
      'checkpoint $name  first[join=${a.joinState} send=${a.senderKinds} '
      'dir=${a.transceiverDirections}]  second[join=${b.joinState} '
      'send=${b.senderKinds} dir=${b.transceiverDirections}]',
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'checks': checks,
        'notes': notes,
        'checkpoints': checkpoints,
        'frames': frames,
        'trail': trail,
        'error': error,
      };
}

/// Counts of the product's own narration. These are the lines that name a
/// negotiation authority, so counting them is how an authority claim is tested
/// against behaviour instead of against a code reading.
Map<String, int> trailCounts() {
  int count(String needle) =>
      Trail.lines.where((l) => l.contains(needle)).length;
  return <String, int>{
    'glareImpoliteIgnores': count('glare: impolite IGNORES'),
    'glarePoliteRollsBack': count('glare: polite ROLLS BACK'),
    'rollbackFailed': count('rollback failed'),
    'watchdogReoffer': count('answer watchdog RE-OFFER'),
    'attachNoLocalStream': count('attach: NO local stream'),
    'staleAnswerIgnored': count('stale answer IGNORED'),
    'repairSweep': count('[rtc-repair]'),
    'repairedPeers': count('[rtc-repair] repaired'),
    'recoverLines': count('[rtc-recover]'),
    'addTrackFailed': count('addTrack FAILED'),
  };
}

/// The end state every case is ultimately graded against: both sides publishing
/// audio and video, and both sides' negotiated directions agreeing that both
/// ends send. Sender counts alone would call a one-way call healthy.
Future<bool> bothSidesFullyDuplex(World world) async {
  final a = await world.first.probe(world.second);
  final b = await world.second.probe(world.first);
  bool ok(probe) =>
      probe.senderKinds.contains('audio') &&
      probe.senderKinds.contains('video') &&
      probe.transceiverDirections.isNotEmpty &&
      probe.transceiverDirections.values.every((d) => d == 'SendRecv');
  return ok(a) && ok(b);
}

/// Bring the pair up. [firstJoinsFirst] is always true — the existing peer must
/// already be in the room for the newcomer to be a newcomer.
/// Bring the pair up with their HEARTBEATS phase-locked, not their join calls.
///
/// Joining the two sides a fixed wall-clock apart does not align anything: the
/// beat starts when the socket join is acked, and each join carries seconds of
/// its own latency, so a 120ms gap between `join()` calls produced beats three
/// seconds apart — far enough that two beat-driven repairs politely took turns
/// and the collision under investigation never happened.
///
/// So the phase is measured rather than assumed. FIRST's own join latency is
/// timed from its first `session:heartbeat` frame, and SECOND is launched one
/// latency BEFORE FIRST's next beat, so both beats land together from then on.
/// Two people clicking into the same meeting are this close in production;
/// a rig that cannot represent it cannot falsify a design whose only real risk
/// is simultaneity.
Future<void> bringUpPhaseLocked(World world) async {
  final t0 = Trail.clock.elapsedMilliseconds;
  Trail.say('join FIRST (${world.first.socketId}) — phase-locked bring-up');
  unawaited(world.first.controller.join(world.sessionId));
  await waitUntil(
    () async =>
        world.hub.firstFrameAt(world.first.socketId, 'session:heartbeat') !=
        null,
    timeout: const Duration(seconds: 30),
    poll: const Duration(milliseconds: 20),
  );
  final beat =
      world.hub.firstFrameAt(world.first.socketId, 'session:heartbeat')!;
  final latency = beat - t0;

  var target = beat + kHeartbeat.inMilliseconds - latency;
  while (target - Trail.clock.elapsedMilliseconds < 200) {
    target += kHeartbeat.inMilliseconds;
  }
  Trail.say(
    'FIRST beat phase=$beat joinLatency=${latency}ms; '
    'launching SECOND at $target to land on the next FIRST beat',
  );
  await hold(Duration(
    milliseconds: target - Trail.clock.elapsedMilliseconds,
  ));
  unawaited(world.second.controller.join(world.sessionId));
  await waitUntil(() async => world.second.controller.state.isJoined,
      timeout: const Duration(seconds: 30));
  final secondBeat =
      world.hub.firstFrameAt(world.second.socketId, 'session:heartbeat');
  final skew = secondBeat == null
      ? -1
      : ((secondBeat - beat) % kHeartbeat.inMilliseconds);
  Trail.say('heartbeat phase skew = ${skew}ms');
  world.beatSkewMs = skew;
}

Future<void> bringUp(World world, {Duration gap = kAlignedJoinGap}) async {
  Trail.say('join FIRST (${world.first.socketId})');
  unawaited(world.first.controller.join(world.sessionId));
  await waitUntil(() async => world.first.controller.state.isJoined,
      timeout: const Duration(seconds: 25));
  await hold(gap);
  Trail.say('join SECOND (${world.second.socketId})');
  unawaited(world.second.controller.join(world.sessionId));
  await waitUntil(() async => world.second.controller.state.isJoined,
      timeout: const Duration(seconds: 25));
}
