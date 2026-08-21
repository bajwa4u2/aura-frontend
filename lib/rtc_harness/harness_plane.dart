// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member, avoid_renaming_method_parameters
// CONTROLLER-LEVEL NEGOTIATION CERTIFICATION HARNESS — the substituted edges.
//
// NOT PRODUCT. See main.dart in this directory for what the rig is for.
//
// Everything in this file is an EDGE: the signalling plane, the REST plane, the
// token store, and two injected media injuries. Nothing here reimplements
// negotiation. The controller and the media service under test are the real
// ones, untouched.

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:aura/core/auth/auth_providers.dart';
import 'package:aura/core/client_identity/client_identity.dart';
import 'package:aura/features/realtime/application/realtime_controller.dart';
import 'package:aura/features/realtime/data/realtime_event_parser.dart';
import 'package:aura/features/realtime/data/realtime_media_service.dart';
import 'package:aura/features/realtime/data/realtime_repository.dart';
import 'package:aura/features/realtime/data/realtime_socket_service.dart';
import 'package:aura/features/realtime/domain/realtime_models.dart';

// ── Evidence trail ──────────────────────────────────────────────────────────
//
// The product narrates itself through debugPrint: glare decisions, rollbacks,
// "attach: NO local stream", watchdog re-offers, repair sweeps. debugPrint is a
// replaceable global in Flutter, so the harness captures that narration rather
// than inferring it from the outside. Every line is timestamped against the
// case clock, because in a glare the ORDER is the entire question.
class Trail {
  static final List<String> lines = <String>[];
  static Stopwatch clock = Stopwatch()..start();
  static bool _installed = false;

  static void install() {
    if (_installed) return;
    _installed = true;
    final original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      final text = message ?? '';
      lines.add('${clock.elapsedMilliseconds}|$text');
      if (lines.length > 8000) lines.removeRange(0, 3000);
      original(message, wrapWidth: wrapWidth);
    };
  }

  static void say(String text) {
    lines.add('${clock.elapsedMilliseconds}|[HX] $text');
    // ignore: avoid_print
    print('[HX] ${clock.elapsedMilliseconds} $text');
  }

  static void reset() {
    lines.clear();
    clock = Stopwatch()..start();
  }

  /// Only the lines that carry negotiation meaning. The controller is very
  /// chatty and an unfiltered trail buries the four lines that matter.
  static List<String> relevant() {
    const keep = <String>[
      '[HX]',
      '[rtc]',
      '[rtc-repair]',
      '[rtc-recover]',
      '[join-seq]',
    ];
    return lines.where((l) => keep.any(l.contains)).toList();
  }
}

// ── The signalling plane ────────────────────────────────────────────────────

/// In-process stand-in for the backend realtime gateway.
///
/// It implements the gateway's CONTRACT rather than a convenience shortcut:
/// relay by `targetSocketId` while stamping `fromSocketId`/`userId` on the way
/// through, and broadcast `session:participant.joined` to everyone except the
/// joiner. Those two behaviours are the reason the "existing peer offers, the
/// newcomer answers" invariant holds in production, so faking them would
/// certify a protocol the product does not speak.
///
/// Socket ids are assigned here, deliberately: politeness is decided by
/// comparing raw socket ids, so owning id assignment is what lets a case place
/// the injured participant on the polite or the impolite side ON PURPOSE
/// instead of hoping a real server hands ids out in the useful order.
class SignalHub {
  SignalHub({this.relayDelay = const Duration(milliseconds: 8)});

  final Duration relayDelay;
  final Map<String, HarnessSocketService> _sockets =
      <String, HarnessSocketService>{};
  final Map<String, String> _userBySocket = <String, String>{};
  final Map<String, Map<String, dynamic>> _rosterBySocket =
      <String, Map<String, dynamic>>{};

  /// Every frame that crossed the wire, for the report.
  final List<Map<String, dynamic>> frames = <Map<String, dynamic>>[];

  // ── Deterministic collision control ──────────────────────────────────────
  //
  // A collision cannot be produced by hoping two free-running 10s timers land
  // inside a 150ms network window. It also does not need to be: the gateway
  // owns DELIVERY, and a collision is a delivery property.
  //
  // So the harness holds genuine, controller-generated offers at the wire and
  // releases them together. What is held is exactly what the product decided to
  // send — the harness never fabricates SDP, never offers on a controller's
  // behalf, never calls repair, and never touches politeness, the offer queue
  // or join state. It decides WHEN real signalling arrives, not WHAT it says.
  //
  // Holding is itself a real production condition: the offer relay is
  // fire-and-forget, so a delayed or lost frame is a failure mode the product
  // already claims to survive.

  /// While true, outbound `session:offer` frames are parked instead of
  /// delivered. The sender has already applied its own local description by
  /// then, so a held offer is a genuinely in-flight offer — its side is in
  /// have-local-offer with its answer watchdog armed, exactly as if the network
  /// were slow.
  bool holdOffers = false;

  /// While true, outbound `session:answer` frames are parked. This is what lets
  /// the real 8s answer watchdog become eligible without inventing anything.
  bool holdAnswers = false;

  final List<Map<String, dynamic>> _heldOffers = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> _heldAnswers = <Map<String, dynamic>>[];

  /// Which sides currently have a real offer parked at the wire.
  Set<String> get heldOfferSenders =>
      _heldOffers.map((h) => h['from'] as String).toSet();

  Set<String> get heldAnswerSenders =>
      _heldAnswers.map((h) => h['from'] as String).toSet();

  int get heldOfferCount => _heldOffers.length;
  int get heldAnswerCount => _heldAnswers.length;

  /// Release every parked offer into its target at the same instant. [stagger]
  /// is the deliberate spacing between them; zero means "as simultaneous as the
  /// event loop allows", which is the collision the design has to survive.
  void releaseHeldOffers({Duration stagger = Duration.zero}) {
    final batch = List<Map<String, dynamic>>.from(_heldOffers);
    _heldOffers.clear();
    for (var i = 0; i < batch.length; i++) {
      final held = batch[i];
      final delay = relayDelay + stagger * i;
      Trail.say(
        'hub: RELEASING held offer from ${held['from']} '
        'to ${held['target']} (+${delay.inMilliseconds}ms)',
      );
      Timer(delay, () {
        final target = _sockets[held['target'] as String];
        target?.inject('session:offer', held['payload'] as Map<String, dynamic>);
      });
    }
  }

  void releaseHeldAnswers({Duration stagger = Duration.zero}) {
    final batch = List<Map<String, dynamic>>.from(_heldAnswers);
    _heldAnswers.clear();
    for (var i = 0; i < batch.length; i++) {
      final held = batch[i];
      Trail.say('hub: RELEASING held answer from ${held['from']}');
      Timer(relayDelay + stagger * i, () {
        final target = _sockets[held['target'] as String];
        target?.inject('session:answer', held['payload'] as Map<String, dynamic>);
      });
    }
  }

  /// Drop frames the predicate selects, WITHOUT acking differently. The offer
  /// relay is fire-and-forget in production, so a lost answer is a real failure
  /// mode and the only way to make the 8s answer watchdog fire on demand. The
  /// count is recorded so a case can never silently drop more than it meant to.
  bool Function(String event, String from)? dropIf;
  final List<Map<String, dynamic>> dropped = <Map<String, dynamic>>[];

  /// Roster rows as first registered, so a party that left can rejoin. Leaving
  /// removes the row (the gateway does the same), and a rejoin must put an
  /// equivalent row back rather than invent a new identity.
  final Map<String, Map<String, dynamic>> _rosterTemplate =
      <String, Map<String, dynamic>>{};

  /// Put a party that left back on the roster, as a rejoin does.
  void restore(String socketId) {
    final template = _rosterTemplate[socketId];
    if (template == null) return;
    _rosterBySocket[socketId] = Map<String, dynamic>.from(template);
  }

  /// Frames are the ground truth for "who initiated negotiation". The hub sees
  /// the emitter of every offer, so an authority claim can be checked against
  /// the wire instead of against a code reading.
  int offersFrom(String socketId, {int? afterMs}) => frames
      .where((f) =>
          f['event'] == 'session:offer' &&
          f['from'] == socketId &&
          (afterMs == null || (f['at'] as int) >= afterMs))
      .length;

  int answersFrom(String socketId, {int? afterMs}) => frames
      .where((f) =>
          f['event'] == 'session:answer' &&
          f['from'] == socketId &&
          (afterMs == null || (f['at'] as int) >= afterMs))
      .length;

  /// When [socketId] first emitted [event], or null. The heartbeat's first beat
  /// is emitted the instant the socket join is acked, so the timestamp of a
  /// side's first `session:heartbeat` IS the phase of its 10s beat — which is
  /// the only clock that decides whether two beat-driven repairs collide.
  int? firstFrameAt(String socketId, String event) {
    for (final frame in frames) {
      if (frame['from'] == socketId && frame['event'] == event) {
        return frame['at'] as int;
      }
    }
    return null;
  }

  List<Map<String, dynamic>> sdpFrames() => frames
      .where((f) =>
          f['event'] == 'session:offer' || f['event'] == 'session:answer')
      .toList();

  void register(HarnessSocketService socket, String userId, String displayName) {
    _sockets[socket.assignedId] = socket;
    _userBySocket[socket.assignedId] = userId;
    _rosterBySocket[socket.assignedId] = <String, dynamic>{
      'id': 'p-$userId',
      'userId': userId,
      'socketId': socket.assignedId,
      'role': 'MEMBER',
      'joinState': 'ACTIVE',
      'isPresent': true,
      'audioState': 'ON',
      'videoState': 'ON',
      'displayName': displayName,
    };
    _rosterTemplate[socket.assignedId] =
        Map<String, dynamic>.from(_rosterBySocket[socket.assignedId]!);
  }

  /// The roster as the REST bundle serves it: identities WITHOUT live socket
  /// ids, because production's REST roster has no runtimeDeviceId. The
  /// newcomer's inability to see peers' sockets is exactly what stops it from
  /// offering; handing sockets out here would silently delete the invariant.
  List<Map<String, dynamic>> restRoster() {
    return _rosterBySocket.values.map((row) {
      final copy = Map<String, dynamic>.from(row);
      copy.remove('socketId');
      copy.remove('runtimeDeviceId');
      return copy;
    }).toList();
  }

  Future<Map<String, dynamic>> emit(
    HarnessSocketService from,
    String event,
    Map<String, dynamic> payload,
  ) async {
    final fromId = from.assignedId;
    frames.add(<String, dynamic>{
      'at': Trail.clock.elapsedMilliseconds,
      'event': event,
      'from': fromId,
      'target': (payload['targetSocketId'] ?? '').toString(),
    });

    if (dropIf != null && dropIf!(event, fromId)) {
      dropped.add(<String, dynamic>{
        'at': Trail.clock.elapsedMilliseconds,
        'event': event,
        'from': fromId,
      });
      Trail.say('hub: DROPPED $event from $fromId (injected loss)');
      return <String, dynamic>{'ok': true};
    }

    switch (event) {
      case 'session:join':
        Trail.say('hub: $fromId joined');
        _broadcastExcept(fromId, 'session:participant.joined', <String, dynamic>{
          ...?_rosterBySocket[fromId],
          'sessionId': payload['sessionId'],
        });
        return <String, dynamic>{'ok': true, 'sessionId': payload['sessionId']};

      case 'session:offer':
      case 'session:answer':
      case 'session:ice-candidate':
        final target = (payload['targetSocketId'] ?? '').toString().trim();
        final relayed = <String, dynamic>{
          ...payload,
          'fromSocketId': fromId,
          'socketId': fromId,
          'userId': _userBySocket[fromId] ?? '',
        };
        final parked = <String, dynamic>{
          'at': Trail.clock.elapsedMilliseconds,
          'from': fromId,
          'target': target,
          'payload': relayed,
        };
        if (event == 'session:offer' && holdOffers) {
          _heldOffers.add(parked);
          Trail.say('hub: HOLDING offer from $fromId to $target');
          return <String, dynamic>{'ok': true};
        }
        if (event == 'session:answer' && holdAnswers) {
          _heldAnswers.add(parked);
          Trail.say('hub: HOLDING answer from $fromId to $target');
          return <String, dynamic>{'ok': true};
        }
        _deliver(target, event, relayed);
        return <String, dynamic>{'ok': true};

      case 'session:audio.set':
      case 'session:video.set':
      case 'session:screen.set':
        final row = _rosterBySocket[fromId];
        if (row != null) {
          final on = payload['enabled'] == true ? 'ON' : 'OFF';
          if (event == 'session:audio.set') row['audioState'] = on;
          if (event == 'session:video.set') row['videoState'] = on;
          if (event == 'session:screen.set') row['screenState'] = on;
          _broadcastExcept(fromId, 'session:track.updated', <String, dynamic>{
            'sessionId': payload['sessionId'],
            'userId': _userBySocket[fromId] ?? '',
            'socketId': fromId,
            'audioState': row['audioState'] ?? 'OFF',
            'videoState': row['videoState'] ?? 'OFF',
            'screenState': row['screenState'] ?? 'OFF',
          });
        }
        return <String, dynamic>{'ok': true};

      case 'session:leave':
        _broadcastExcept(fromId, 'session:participant.left', <String, dynamic>{
          'sessionId': payload['sessionId'],
          'userId': _userBySocket[fromId] ?? '',
          'socketId': fromId,
          'reason': 'left',
        });
        _rosterBySocket.remove(fromId);
        return <String, dynamic>{'ok': true};

      default:
        return <String, dynamic>{'ok': true};
    }
  }

  void _deliver(
    String targetSocketId,
    String event,
    Map<String, dynamic> payload,
  ) {
    final target = _sockets[targetSocketId];
    if (target == null) return;
    Timer(relayDelay, () => target.inject(event, payload));
  }

  void _broadcastExcept(
    String exceptSocketId,
    String event,
    Map<String, dynamic> payload,
  ) {
    for (final entry in _sockets.entries) {
      if (entry.key == exceptSocketId) continue;
      final socket = entry.value;
      Timer(relayDelay, () => socket.inject(event, payload));
    }
  }
}

/// The transport edge. Overrides ONLY what touches the wire. Every guard the
/// controller depends on is preserved — `isConnected` still means "connected
/// AND server-assigned id", and `emitAck` still refuses to fire before
/// readiness — because those guards are part of the join sequence under test.
class HarnessSocketService extends RealtimeSocketService {
  HarnessSocketService(this.assignedId, this.hub);

  final String assignedId;
  final SignalHub hub;

  final StreamController<RealtimeParsedEvent> _events =
      StreamController<RealtimeParsedEvent>.broadcast();
  bool _connected = false;
  bool _dead = false;

  @override
  Stream<RealtimeParsedEvent> get events => _events.stream;

  @override
  bool get isConnected => _connected && !_dead;

  @override
  String? get socketId => _connected ? assignedId : null;

  @override
  Future<void> ensureConnected({
    required String accessToken,
    ClientIdentity? identity,
  }) async {
    if (_dead) {
      throw RealtimeTransportException('harness socket disposed');
    }
    if (_connected) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
    _connected = true;
  }

  @override
  Future<Map<String, dynamic>> emitAck(
    String event,
    Map<String, dynamic> payload,
  ) async {
    if (!isConnected) {
      throw RealtimeTransportException(
        'emitAck($event) called before the transport was ready',
      );
    }
    return hub.emit(this, event, payload);
  }

  void inject(String event, Map<String, dynamic> payload) {
    if (_dead || _events.isClosed) return;
    _events.add(RealtimeParsedEvent(name: event, payload: payload));
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
  }

  @override
  void dispose() {
    _dead = true;
    _connected = false;
    if (!_events.isClosed) _events.close();
  }
}

// ── The REST plane ──────────────────────────────────────────────────────────

/// A synthetic MEETING bundle. `kind: MIXED` is what MeetingSessionBridgeService
/// creates, and _applyBundle maps MIXED to callMode `video` — so the harness
/// exercises the audio+video path the defect actually lives on rather than an
/// audio-only shortcut where a missing video sender would be unobservable.
class HarnessRepository extends RealtimeRepository {
  HarnessRepository(this.hub, this.sessionId) : super(Dio());

  final SignalHub hub;
  final String sessionId;

  Map<String, dynamic> _bundleJson() => <String, dynamic>{
        'session': <String, dynamic>{
          'id': sessionId,
          'surfaceType': 'meeting',
          'surfaceId': 'meeting-1',
          'startedByUserId': 'user-a',
          'status': 'ACTIVE',
          'kind': 'MIXED',
          'isActive': true,
          'isLocked': false,
          'waitingRoomEnabled': false,
        },
        'participants': hub.restRoster(),
        'policy': <String, dynamic>{
          'audioAllowed': true,
          'videoAllowed': true,
        },
      };

  @override
  Future<RealtimeSessionSnapshot> loadSessionBundle(
    String id, {
    bool forceRefresh = false,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 3));
    return RealtimeSessionSnapshot.fromJson(_bundleJson());
  }

  @override
  Future<RealtimeSessionSnapshot> joinSession(RealtimeSession session) async {
    await Future<void>.delayed(const Duration(milliseconds: 3));
    return RealtimeSessionSnapshot.fromJson(_bundleJson());
  }

  @override
  Future<Map<String, dynamic>> issueTurnCredentials(String id) async {
    // STUN only. A TURN relay would add a real network dependency without
    // changing anything about who is allowed to initiate negotiation, which is
    // the only question this rig exists to answer. Recorded as an unproven
    // boundary rather than quietly assumed away.
    return <String, dynamic>{
      'iceServers': <dynamic>[
        <String, dynamic>{'urls': 'stun:stun.l.google.com:19302'},
      ],
      'ttlSeconds': 3600,
    };
  }

  @override
  Future<void> leaveSession(RealtimeSession? session) async {}

  @override
  Future<void> endSession(RealtimeSession? session) async {}

  @override
  void clearBundleCache([String? id]) {}
}

/// TokenStore.load() nulls the access token on web by design (cookie-based
/// refresh). The controller refuses to connect without one, so the harness
/// supplies a constant instead of pretending to authenticate.
class HarnessTokenStore extends TokenStore {
  @override
  Future<void> load() async {}

  @override
  String? get accessToken => 'harness-token';
}

// ── Injected media injuries ─────────────────────────────────────────────────

/// The two ways production actually leaves a peer with no senders. Neither is a
/// harness-only mutation of WebRTC state: both drive the product through its
/// own code paths and let it injure itself.
enum MediaInjury {
  /// Healthy.
  none,

  /// ANSWERER silence. Local acquisition stalls, so the inbound offer lands
  /// while `_ensureMediaReady` is still busy. The controller's own
  /// `if (state.isMediaBusy) return;` early-return then lets `handleRemoteOffer`
  /// run with a null local stream and answer recvonly. This is 381c452's defect
  /// reproduced through the product's own guard, not simulated.
  stallAcquisition,

  /// OFFERER silence. Acquisition yields no stream at all (denied camera and
  /// mic, or a device held by another app) until the harness releases it.
  /// `_flushPendingOffers` deliberately proceeds without media — a recvonly
  /// connection still lets the user see and hear the room — so the offer is
  /// created with zero senders. Releasing the device afterwards is what makes
  /// the peer repairable and, until it is repaired, permanently mute.
  ///
  /// The deny must persist rather than lapse after one call: the controller
  /// retries `_ensureMediaReady` on every reconcile, so a one-shot failure
  /// would be silently healed by the next offer attempt and the injury would
  /// never reach the wire.
  denyAcquisition,
}

/// Wraps the REAL media service. It does not override negotiation, track
/// handling, or repair — only when acquisition happens and whether the first
/// attempt yields anything.
class HarnessMediaService extends RealtimeMediaService {
  MediaInjury injury = MediaInjury.none;
  Duration stall = const Duration(seconds: 7);
  int acquisitions = 0;
  int suppressed = 0;
  bool _denied = false;

  @override
  Future<void> ensureLocalMedia({
    required bool audio,
    required bool video,
  }) async {
    acquisitions++;
    if (injury == MediaInjury.denyAcquisition) {
      _denied = true;
      suppressed++;
      Trail.say('media: acquisition denied, no stream (injected)');
      return;
    }
    if (injury == MediaInjury.stallAcquisition && acquisitions == 1) {
      Trail.say('media: acquisition stalled ${stall.inMilliseconds}ms (injected)');
      await Future<void>.delayed(stall);
    }
    return super.ensureLocalMedia(audio: audio, video: video);
  }

  bool get isDenied => _denied && injury == MediaInjury.denyAcquisition;

  /// The device becomes available. Called by the harness, never by the product
  /// — the product has no retry for a denied device, which is itself part of
  /// why the silent-peer condition persists once it exists.
  Future<void> releaseDevice() async {
    injury = MediaInjury.none;
    Trail.say('media: device released, acquiring for real');
    await super.ensureLocalMedia(audio: true, video: true);
  }
}

// ── Probe ───────────────────────────────────────────────────────────────────

/// Everything a proof needs about one side of one peer pair, read from LIVE
/// WebRTC state.
///
/// `transceiverDirections` is the load-bearing field. Sender counting cannot
/// tell "the far side turned its camera off" from "the far side never attached
/// a sender", because both leave the local side unchanged. Negotiated
/// direction can: an answerer that attached nothing answers recvonly, so the
/// OFFERER's transceiver settles at sendonly. A camera merely disabled leaves
/// the direction at sendrecv. That difference is SDP truth, agreed by both
/// ends, not a local guess.
class PeerProbe {
  const PeerProbe({
    required this.socketId,
    required this.peerKey,
    required this.joinState,
    required this.isJoined,
    required this.mediaReady,
    required this.cameraEnabled,
    required this.micEnabled,
    required this.hasPeer,
    required this.signalling,
    required this.senderKinds,
    required this.receiverKinds,
    required this.transceiverDirections,
    required this.remoteVideoLive,
    required this.remoteAudioLive,
    required this.errorMessage,
    required this.participantCount,
  });

  final String socketId;
  final String peerKey;
  final String joinState;
  final bool isJoined;
  final bool mediaReady;
  final bool cameraEnabled;
  final bool micEnabled;
  final bool hasPeer;
  final String signalling;
  final List<String> senderKinds;
  final List<String> receiverKinds;
  final Map<String, String> transceiverDirections;
  final bool remoteVideoLive;
  final bool remoteAudioLive;
  final String? errorMessage;
  final int participantCount;

  /// This side is publishing nothing it should be publishing.
  bool get locallySilent => mediaReady && senderKinds.isEmpty;

  /// The FAR side is not publishing on a negotiated m-line. Read from
  /// `currentDirection`, so it is what both ends agreed in SDP.
  bool get remoteSilent =>
      transceiverDirections.values.isNotEmpty &&
      transceiverDirections.values.every(
        (d) => d == 'SendOnly' || d == 'Inactive',
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'socketId': socketId,
        'peerKey': peerKey,
        'joinState': joinState,
        'isJoined': isJoined,
        'mediaReady': mediaReady,
        'cameraEnabled': cameraEnabled,
        'micEnabled': micEnabled,
        'hasPeer': hasPeer,
        'signalling': signalling,
        'senderKinds': senderKinds,
        'receiverKinds': receiverKinds,
        'transceiverDirections': transceiverDirections,
        'remoteVideoLive': remoteVideoLive,
        'remoteAudioLive': remoteAudioLive,
        'locallySilent': locallySilent,
        'remoteSilent': remoteSilent,
        'errorMessage': errorMessage,
        'participantCount': participantCount,
      };
}

/// One participant: the real controller plus the edges it was given.
class Party {
  Party({
    required this.label,
    required this.userId,
    required this.socketId,
    required this.controller,
    required this.media,
    required this.socket,
  });

  final String label;
  final String userId;
  final String socketId;
  final RealtimeController controller;
  final HarnessMediaService media;
  final HarnessSocketService socket;

  String peerKeyOf(Party other) => other.socketId;

  /// True when THIS party is the polite one relative to [other], computed by
  /// the same rule the product uses in its session:offer handler.
  bool politeAgainst(Party other) =>
      _raw(socketId).compareTo(_raw(other.socketId)) < 0;

  static String _raw(String s) =>
      s.startsWith('socket:') ? s.substring('socket:'.length) : s;

  Future<PeerProbe> probe(Party other) async {
    final peerKey = peerKeyOf(other);
    final state = controller.state;
    final snapshot = media.currentSnapshot;
    final connection = media.debugPeer(peerKey);

    final senderKinds = <String>[];
    final receiverKinds = <String>[];
    final directions = <String, String>{};
    var signalling = '-';

    if (connection != null) {
      signalling = connection.signalingState?.name ?? '-';
      try {
        for (final sender in await connection.getSenders()) {
          final kind = sender.track?.kind;
          if (kind != null && kind.isNotEmpty) senderKinds.add(kind);
        }
      } catch (_) {}
      try {
        for (final receiver in await connection.getReceivers()) {
          final kind = receiver.track?.kind;
          if (kind != null && kind.isNotEmpty) receiverKinds.add(kind);
        }
      } catch (_) {}
      try {
        for (final transceiver in await connection.getTransceivers()) {
          final direction = await transceiver.getCurrentDirection();
          final kind = transceiver.receiver.track?.kind ??
              transceiver.sender.track?.kind ??
              transceiver.mid;
          directions[kind] = direction?.name ?? 'null';
        }
      } catch (_) {}
    }

    final renderers = snapshot.remoteRenderers.values;
    final remoteStream =
        renderers.isEmpty ? null : renderers.first.srcObject;

    return PeerProbe(
      socketId: socketId,
      peerKey: peerKey,
      joinState: state.joinState.name,
      isJoined: state.isJoined,
      mediaReady: state.isMediaReady,
      cameraEnabled: state.cameraEnabled,
      micEnabled: state.microphoneEnabled,
      hasPeer: connection != null,
      signalling: signalling,
      senderKinds: senderKinds..sort(),
      receiverKinds: receiverKinds..sort(),
      transceiverDirections: directions,
      remoteVideoLive:
          (remoteStream?.getVideoTracks().isNotEmpty ?? false) &&
              remoteStream!.getVideoTracks().first.muted != true,
      remoteAudioLive: remoteStream?.getAudioTracks().isNotEmpty ?? false,
      errorMessage: state.errorMessage,
      participantCount: state.participants.length,
    );
  }
}
