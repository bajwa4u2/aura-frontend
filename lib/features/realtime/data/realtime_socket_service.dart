import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../../config.dart';
import '../../../core/client_identity/client_identity.dart';
import '../../../core/concurrency/single_flight.dart';
import 'realtime_event_parser.dart';

/// Thrown for transport-establishment failures — distinguishes a genuine
/// connect problem from a caller misusing the API (e.g. emitting before
/// the transport is ready).
class RealtimeTransportException implements Exception {
  RealtimeTransportException(this.message);
  final String message;
  @override
  String toString() => 'RealtimeTransportException: $message';
}

class RealtimeSocketService {
  RealtimeSocketService();

  io.Socket? _socket;
  final _eventsController = StreamController<RealtimeParsedEvent>.broadcast();
  bool _disposing = false;

  // 2026-08-14 — PERMANENT TRANSPORT OWNERSHIP REPAIR.
  //
  // Proven defect (live device logs cross-referenced against backend
  // logs): RealtimeController.connect() had its own state-based "already
  // connecting" guard (state.connectionStatus), separate and desyncable
  // from this service's own connect() guard. Combined with
  // Future.timeout() not cancelling an abandoned _performJoin() attempt,
  // multiple logical join attempts could each independently call
  // connect() here — which always disconnected and recreated the socket —
  // destroying a sibling attempt's in-progress connection before it could
  // stabilize. Three real join attempts were captured producing an empty
  // socket id each time, none ever reaching a server-acknowledged
  // `session:join`, roughly 2 seconds apart — far too fast to be the 15s
  // per-attempt timeout elapsing, consistent with fast disconnect/error
  // events from this churn.
  //
  // `ensureConnected()` is now the ONLY way to obtain a ready socket, and
  // is genuinely single-flight via the generic, independently-tested
  // SingleFlight primitive (lib/core/concurrency/single_flight.dart): the
  // first caller becomes the sole owner of establishing the connection;
  // every other concurrent caller awaits that SAME in-flight operation
  // instead of starting a competing one. Nobody may disconnect/recreate
  // the socket while an establishment is in flight.
  final SingleFlight<void> _connectFlight = SingleFlight<void>();

  static const _establishTimeout = Duration(seconds: 20);
  static const _idAssignmentPollInterval = Duration(milliseconds: 50);
  static const _idAssignmentMaxWait = Duration(seconds: 5);

  Stream<RealtimeParsedEvent> get events => _eventsController.stream;

  // TRANSPORT READY = Socket.IO connected AND the current socket instance
  // has a non-empty server-assigned id. `.connected` can report true
  // slightly before `.id` is populated, and a caller may be holding a
  // reference to a socket that has since been superseded — both are
  // treated as not-ready so nothing ever emits against a socket that
  // isn't actually server-recognized yet.
  bool get isConnected =>
      (_socket?.connected ?? false) && (_socket?.id ?? '').isNotEmpty;
  String? get socketId => _socket?.id;

  /// The single canonical entry point for obtaining a ready realtime
  /// socket. Returns once transport is server-recognized-ready (connected
  /// AND has a non-empty id). Safe to call from multiple concurrent join
  /// attempts — they share one establishment instead of racing to
  /// reconnect over each other.
  Future<void> ensureConnected({
    required String accessToken,
    ClientIdentity? identity,
  }) async {
    debugPrint(
      '[transport-diag] ensureConnected called disposing=$_disposing'
      ' isConnected=$isConnected inFlight=${_connectFlight.isInFlight}'
      ' currentSocketId=${_socket?.id} currentConnected=${_socket?.connected}',
    );
    if (_disposing) {
      // NEVER a silent void: a disposed service returning normally made
      // connect() report success, after which the join threw the generic
      // 'Transport not ready after connect() returned' forever. If this
      // instance is disposed, say so — the caller's error surface carries
      // the truth instead of an unexplained not-ready loop.
      throw RealtimeTransportException(
        'Realtime socket service is disposed — cannot establish transport.',
      );
    }
    if (isConnected) return;

    try {
      await _connectFlight.run(
        () => _establish(
          accessToken: accessToken,
          identity: identity,
        ).timeout(_establishTimeout),
      );
      debugPrint(
        '[transport-diag] ensureConnected succeeded socketId=${_socket?.id}'
        ' connected=${_socket?.connected}',
      );
    } catch (error) {
      debugPrint('[transport-diag] ensureConnected FAILED error=$error');
      // TEMPORARY release-visible diagnostic (founder stop-order 2026-08-17):
      // debugPrint is stripped in release web builds; the production three-
      // party failure produces zero observable client evidence. Remove once
      // the transport root cause is certified fixed.
      // ignore: avoid_print
      print('[rtc-diag] ensureConnected FAILED: $error');
      rethrow;
    }
  }

  void updateAccessToken(String accessToken) {
    final token = accessToken.trim();
    if (token.isEmpty) return;

    final socket = _socket;
    if (socket == null) return;

    final auth = <String, dynamic>{'token': token, 'accessToken': token};
    socket.auth = auth;

    try {
      final ioOptions = socket.io.options;
      if (ioOptions is Map) {
        ioOptions['auth'] = auth;
        final extraHeaders = ioOptions['extraHeaders'];
        if (extraHeaders is Map) {
          extraHeaders['Authorization'] = 'Bearer $token';
        }
      }
    } catch (_) {
      // Best-effort only; socket.auth is the critical reconnect input.
    }
  }

  // We are the sole owner here — guaranteed by ensureConnected()'s
  // single-flight gate above — so it is safe to tear down any prior
  // socket and build a fresh one without racing a sibling attempt.
  Future<void> _establish({
    required String accessToken,
    ClientIdentity? identity,
  }) async {
    debugPrint(
      '[transport-diag] _establish starting, tearing down prior socket'
      ' (id=${_socket?.id}, connected=${_socket?.connected})',
    );
    await _disconnectSocket();

    final uri = Uri.parse(AppConfig.apiBaseUrl);
    final origin =
        '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';

    final auth = <String, dynamic>{
      'token': accessToken,
      'accessToken': accessToken,
    };
    final extraHeaders = <String, dynamic>{
      'Authorization': 'Bearer $accessToken',
    };
    if (identity != null) {
      auth.addAll(identity.toWsAuth());
      // Mirror as headers too — some Socket.IO transports surface query/auth
      // differently across web vs native; the backend parser checks all three
      // sources. Headers are the most consistently delivered.
      identity.toHttpHeaders().forEach((key, value) {
        extraHeaders[key] = value;
      });
    }

    // TRANSPORT ALIGNMENT (three-party failure correction, 2026-08-17):
    // constructed to match the proven-working messages socket exactly —
    // websocket-only. The prior ['websocket', 'polling'] list left the
    // engine hanging on web with NO transport ever constructed (observed
    // live: zero WebSocket constructions, zero polling XHR, three clean
    // 15s connect timeouts), while a raw WebSocket to the same engine
    // connected instantly. Identity/auth ride the socket.io auth payload,
    // which the backend handshake parser reads.
    final socket = io.io('$origin/realtime', <String, dynamic>{
      'transports': <String>['websocket'],
      'autoConnect': false,
      'forceNew': true,
      'auth': auth,
      'extraHeaders': extraHeaders,
    });

    _wireCoreEvents(socket);
    _socket = socket;
    debugPrint('[transport-diag] new socket object created, calling connect()');
    // ignore: avoid_print
    print('[rtc-diag] socket created for $origin/realtime; invoking connect()');
    socket.connect();
    // ignore: avoid_print
    print('[rtc-diag] connect() invoked; connected=${socket.connected}');

    await _waitForServerRecognizedId(socket);
    debugPrint(
      '[transport-diag] _establish complete, id=${socket.id}'
      ' connected=${socket.connected}',
    );
  }

  /// Waits for the 'connect' event, then — closing the specific race that
  /// produced empty-id readings — additionally waits for a non-empty
  /// socket id if it is not yet populated the instant 'connect' fires.
  /// Aborts if this socket is superseded (torn down by disconnect()) while
  /// waiting, rather than silently proceeding on a dead socket.
  Future<void> _waitForServerRecognizedId(io.Socket socket) async {
    if (!socket.connected) {
      debugPrint('[transport-diag] waiting for connect event...');
      await _waitForConnectEvent(socket);
      debugPrint(
        '[transport-diag] connect event received, id=${socket.id}'
        ' connected=${socket.connected}',
      );
    } else {
      debugPrint(
        '[transport-diag] socket already connected synchronously,'
        ' id=${socket.id}',
      );
    }
    if (!identical(_socket, socket) || _disposing) {
      debugPrint('[transport-diag] superseded right after connect event');
      throw RealtimeTransportException('Socket superseded during connect.');
    }

    var waited = Duration.zero;
    while ((socket.id ?? '').isEmpty) {
      debugPrint(
        '[transport-diag] id still empty, polling... waited=${waited.inMilliseconds}ms'
        ' connected=${socket.connected}',
      );
      if (!identical(_socket, socket) || _disposing) {
        throw RealtimeTransportException(
          'Socket superseded before a server id was assigned.',
        );
      }
      if (waited >= _idAssignmentMaxWait) {
        debugPrint('[transport-diag] gave up waiting for id after ${waited.inMilliseconds}ms');
        throw RealtimeTransportException(
          'Socket connected but never received a server-assigned id.',
        );
      }
      await Future<void>.delayed(_idAssignmentPollInterval);
      waited += _idAssignmentPollInterval;
    }
    debugPrint('[transport-diag] id assigned: ${socket.id}');
  }

  Future<void> _waitForConnectEvent(io.Socket socket) async {
    if (socket.connected) return;

    final completer = Completer<void>();
    late void Function(dynamic) onConnect;
    late void Function(dynamic) onConnectError;
    late void Function(dynamic) onError;
    late void Function(dynamic) onDisconnect;

    void cleanup() {
      socket.off('connect', onConnect);
      socket.off('connect_error', onConnectError);
      socket.off('error', onError);
      socket.off('disconnect', onDisconnect);
    }

    onConnect = (_) {
      if (!completer.isCompleted) {
        cleanup();
        completer.complete();
      }
    };

    onConnectError = (dynamic error) {
      debugPrint('[transport-diag] connect_error fired: $error');
      // ignore: avoid_print
      print('[rtc-diag] connect_error: $error');
      if (!completer.isCompleted) {
        cleanup();
        completer.completeError(
          RealtimeTransportException(
            'Realtime socket failed to connect: ${error?.toString() ?? 'unknown_error'}',
          ),
        );
      }
    };

    onError = (dynamic error) {
      debugPrint('[transport-diag] error event fired: $error');
      if (!completer.isCompleted) {
        cleanup();
        completer.completeError(
          RealtimeTransportException(
            'Realtime socket error: ${error?.toString() ?? 'unknown_error'}',
          ),
        );
      }
    };

    onDisconnect = (dynamic reason) {
      debugPrint('[transport-diag] disconnect event fired before connect completed: $reason');
      // ignore: avoid_print
      print('[rtc-diag] pre-connect disconnect: $reason');
      if (!completer.isCompleted) {
        cleanup();
        completer.completeError(
          RealtimeTransportException(
            'Realtime socket disconnected before connection completed: ${reason?.toString() ?? 'unknown_reason'}',
          ),
        );
      }
    };

    socket.on('connect', onConnect);
    socket.on('connect_error', onConnectError);
    socket.on('error', onError);
    socket.on('disconnect', onDisconnect);

    return completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        cleanup();
        throw TimeoutException('Realtime socket connect timed out.');
      },
    );
  }

  void _wireCoreEvents(io.Socket socket) {
    void onNamed(String eventName) {
      socket.on(eventName, (data) {
        if (_eventsController.isClosed) return;
        _eventsController.add(RealtimeEventParser.parse(eventName, data));
      });
    }

    socket.onConnect((_) {
      if (_eventsController.isClosed) return;
      _eventsController.add(
        const RealtimeParsedEvent(
          name: 'socket:connected',
          payload: <String, dynamic>{},
        ),
      );
    });

    socket.onDisconnect((reason) {
      if (_eventsController.isClosed) return;
      _eventsController.add(
        RealtimeParsedEvent(
          name: 'socket:disconnected',
          payload: <String, dynamic>{'reason': reason?.toString()},
        ),
      );
    });

    socket.onConnectError((error) {
      if (_eventsController.isClosed) return;
      _eventsController.add(
        RealtimeParsedEvent(
          name: 'socket:connect_error',
          payload: <String, dynamic>{'message': error?.toString()},
        ),
      );
    });

    socket.onError((error) {
      if (_eventsController.isClosed) return;
      _eventsController.add(
        RealtimeParsedEvent(
          name: 'socket:error',
          payload: <String, dynamic>{'message': error?.toString()},
        ),
      );
    });

    const names = <String>[
      'session:participant.joined',
      'session:participant.resumed',
      'session:participant.left',
      'session:track.updated',
      'session:offer',
      'session:answer',
      'session:ice-candidate',
      'session:replaced',
      'session:removed',
      'realtime:removed',
      'session:state',
      'participants:updated',
      'policy:updated',
      'session:policyUpdated',
      'session:updated',
      'session:participantUpdated',
      'session:participantRemoved',
      'consent:updated',
      'recording:updated',
      'transcript:updated',
      'artifact:updated',
      'join:requested',
      'join:approved',
      'join:rejected',
      // C6: terminal/incoming/decline lifecycle events. The realtime
      // controller's _handleSocketEvent already has switch cases for
      // these — they were never wired through, so a terminal event that
      // arrives on the realtime socket (vs the correspondence socket) was
      // silently dropped. Listing them here lets either transport drive
      // the same controller transitions, eliminating split-state risk.
      'session:ended',
      'session:stale',
      // Deployment resilience: the server announces a restart so clients hold
      // their media plane through the signaling gap instead of tearing down.
      'session:server.restarting',
      // 2026-08-14 repair: authoritative caller-facing ACCEPT truth,
      // independent of realtime/media join completing. See
      // RealtimeController's 'call:accepted' case for the state it sets.
      'call:accepted',
      'call:declined',
      'call:terminal',
      'call:incoming',
      // Realtime Architecture Correction — Phase 4 (Notification/Ringing
      // Projection Migration). Canonical dot-case wire names, dual-emitted
      // by RealtimeGateway on this same namespace since Phase 2/3
      // (CANONICAL_WIRE_NAME map). Previously never registered here, so
      // silently dropped even though the backend already sent them.
      // `session.cancelled` is SESSION_CANCELLED's wire name — the one
      // canonical event with no pre-existing legacy equivalent name.
      // Amended Phase 4 Gate 2, 2026-08-13: was briefly `participant.cancelled`
      // (a pre-existing inconsistency in the backend's own Phase 0 wire-name
      // table, corrected there — SESSION_CANCELLED is session-scoped truth,
      // matching session.created/session.ending/session.ended/session.failed).
      'invite.issued',
      'participant.accepted',
      'participant.declined',
      'participant.expired',
      'session.cancelled',
      'session.ended',
      'meeting.state_changed',
      // Phase 3.2 — in-call participation (ephemeral fan-out).
      'session:reaction',
      'session:hand.updated',
      'session:mute-request',
      // Phase 4 — Meeting Conversation Stream (persisted, meeting-owned).
      'session:conversation.message',
      'session:conversation.deleted',
      // Materials sync — the room refetches assets when the host shares.
      'session:assets.updated',
    ];

    for (final name in names) {
      onNamed(name);
    }
  }

  /// Emits an event and awaits its ack. Requires the transport to already
  /// be ready (via ensureConnected()) — this is a hard invariant, not a
  /// convenience fallback: no realtime event may be emitted before the
  /// client has a currently valid, server-recognized socket identity. A
  /// caller that violates this has a bug and should fail loudly rather
  /// than silently waiting on a socket it never confirmed was ready.
  Future<Map<String, dynamic>> emitAck(
    String event,
    Map<String, dynamic> payload,
  ) async {
    if (!isConnected) {
      throw RealtimeTransportException(
        'emitAck($event) called before the transport was ready — '
        'callers must await ensureConnected() first.',
      );
    }
    final socket = _socket!;

    final completer = Completer<Map<String, dynamic>>();

    socket.emitWithAck(
      event,
      payload,
      ack: (dynamic ack) {
        if (completer.isCompleted) return;
        if (ack is Map<String, dynamic>) {
          completer.complete(ack);
          return;
        }
        if (ack is Map) {
          completer.complete(Map<String, dynamic>.from(ack));
          return;
        }
        completer.complete(<String, dynamic>{'ok': true, 'data': ack});
      },
    );

    return completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () =>
          throw TimeoutException('Realtime request timed out: $event'),
    );
  }

  /// Tears down the current socket and, if a connection establishment is
  /// currently in flight, aborts it so any waiters don't hang forever
  /// awaiting a connection that is being intentionally torn down.
  Future<void> disconnect() async {
    _connectFlight.abort(
      RealtimeTransportException('Disconnected while connecting.'),
    );
    await _disconnectSocket();
  }

  Future<void> _disconnectSocket() async {
    final socket = _socket;
    _socket = null;
    if (socket != null) {
      try {
        socket.disconnect();
      } catch (_) {}
      try {
        socket.dispose();
      } catch (_) {}
    }
  }

  void dispose() {
    _disposing = true;
    unawaited(disconnect());
    if (!_eventsController.isClosed) {
      _eventsController.close();
    }
  }
}
