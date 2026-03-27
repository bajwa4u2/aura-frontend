import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../../config.dart';
import 'realtime_event_parser.dart';

class RealtimeSocketService {
  RealtimeSocketService();

  io.Socket? _socket;
  final _eventsController = StreamController<RealtimeParsedEvent>.broadcast();

  Stream<RealtimeParsedEvent> get events => _eventsController.stream;

  bool get isConnected => _socket?.connected ?? false;

  Future<void> connect({required String accessToken}) async {
    await disconnect();

    final uri = Uri.parse(AppConfig.apiBaseUrl);
    final origin = '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';

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
    socket.connect();
    _socket = socket;
  }

  void _wireCoreEvents(io.Socket socket) {
    void onNamed(String eventName) {
      socket.on(eventName, (data) {
        _eventsController.add(RealtimeEventParser.parse(eventName, data));
      });
    }

    socket.onConnect((_) {
      _eventsController.add(
        const RealtimeParsedEvent(
          name: 'socket:connected',
          payload: <String, dynamic>{},
        ),
      );
    });

    socket.onDisconnect((reason) {
      _eventsController.add(
        RealtimeParsedEvent(
          name: 'socket:disconnected',
          payload: <String, dynamic>{'reason': reason?.toString()},
        ),
      );
    });

    socket.onConnectError((error) {
      _eventsController.add(
        RealtimeParsedEvent(
          name: 'socket:connect_error',
          payload: <String, dynamic>{'message': error?.toString()},
        ),
      );
    });

    socket.onError((error) {
      _eventsController.add(
        RealtimeParsedEvent(
          name: 'socket:error',
          payload: <String, dynamic>{'message': error?.toString()},
        ),
      );
    });

    const names = <String>[
      'session:participant.joined',
      'session:participant.left',
      'session:track.updated',
      'session:offer',
      'session:answer',
      'session:ice-candidate',
      'session:replaced',
      'session:removed',
      'realtime:removed',
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

    final completer = Completer<Map<String, dynamic>>();

    socket.emitWithAck(event, payload, ack: (dynamic ack) {
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
    if (socket != null) {
      socket.dispose();
      socket.disconnect();
    }
    _socket = null;
  }

  void dispose() {
    unawaited(disconnect());
    _eventsController.close();
  }
}
