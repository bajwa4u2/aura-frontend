import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../../config.dart';
import 'realtime_event_parser.dart';

class RealtimeSocketService {
  RealtimeSocketService();

  io.Socket? _socket;
  final _eventsController = StreamController<RealtimeParsedEvent>.broadcast();
  Future<void>? _connectFuture;
  bool _disposing = false;

  Stream<RealtimeParsedEvent> get events => _eventsController.stream;

  bool get isConnected => _socket?.connected ?? false;
  String? get socketId => _socket?.id;

  Future<void> connect({required String accessToken}) async {
    if (_disposing) return;
    if (isConnected) return;
    if (_connectFuture != null) return _connectFuture!;

    _connectFuture = _connectInternal(accessToken: accessToken);
    try {
      await _connectFuture!;
    } finally {
      _connectFuture = null;
    }
  }

  Future<void> _connectInternal({required String accessToken}) async {
    await disconnect();

    final uri = Uri.parse(AppConfig.apiBaseUrl);
    final origin =
        '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';

    final socket = io.io(
      '$origin/realtime',
      <String, dynamic>{
        'transports': <String>['websocket'],
        'autoConnect': false,
        'forceNew': true,
        'auth': <String, dynamic>{
          'token': accessToken,
          'accessToken': accessToken,
        },
        'extraHeaders': <String, dynamic>{
          'Authorization': 'Bearer $accessToken',
        },
      },
    );

    _wireCoreEvents(socket);
    _socket = socket;
    socket.connect();

    await _waitForConnect(socket);
  }

  Future<void> _waitForConnect(io.Socket socket) async {
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
      if (!completer.isCompleted) {
        cleanup();
        completer.completeError(
          StateError(
            'Realtime socket failed to connect: ${error?.toString() ?? 'unknown_error'}',
          ),
        );
      }
    };

    onError = (dynamic error) {
      if (!completer.isCompleted) {
        cleanup();
        completer.completeError(
          StateError(
            'Realtime socket error: ${error?.toString() ?? 'unknown_error'}',
          ),
        );
      }
    };

    onDisconnect = (dynamic reason) {
      if (!completer.isCompleted) {
        cleanup();
        completer.completeError(
          StateError(
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
    ];

    for (final name in names) {
      onNamed(name);
    }
  }

  Future<Map<String, dynamic>> emitAck(
    String event,
    Map<String, dynamic> payload,
  ) async {
    final socket = _socket;
    if (socket == null) {
      throw StateError('Realtime socket is not connected.');
    }

    if (!socket.connected) {
      await _waitForConnect(socket);
    }

    final completer = Completer<Map<String, dynamic>>();

    socket.emitWithAck(event, payload, ack: (dynamic ack) {
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
    });

    return completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw TimeoutException('Realtime request timed out: $event'),
    );
  }

  Future<void> disconnect() async {
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
