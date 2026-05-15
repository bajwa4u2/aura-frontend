import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../../config.dart';
import '../../../core/auth/auth_providers.dart';

final correspondenceLiveServiceProvider = Provider<CorrespondenceLiveService>((ref) {
  final service = CorrespondenceLiveService(ref);
  ref.onDispose(service.dispose);
  return service;
});

class CorrespondenceLiveEvent {
  const CorrespondenceLiveEvent({required this.name, required this.payload});

  final String name;
  final Map<String, dynamic> payload;

  String get threadId => _pickString(payload, const ['threadId']);
  String get spaceId => _pickString(payload, const ['spaceId']);
  String get invitationId => _pickString(payload, const ['invitationId', 'id']);

  bool matchesThread(String value) => value.trim().isNotEmpty && value.trim() == threadId;
  bool matchesSpace(String value) => value.trim().isNotEmpty && value.trim() == spaceId;
}

class CorrespondenceLiveService {
  CorrespondenceLiveService(this._ref);

  final Ref _ref;
  io.Socket? _socket;
  String? _activeToken;
  final _events = StreamController<CorrespondenceLiveEvent>.broadcast();
  final Set<String> _joinedRooms = <String>{};

  Stream<CorrespondenceLiveEvent> get events => _events.stream;

  Future<void> ensureConnected() async {
    final token = _ref.read(tokenStoreProvider).accessToken?.trim() ?? '';
    if (token.isEmpty) return;
    if (_socket != null && _socket!.connected && _activeToken == token) return;
    await _connect(token);
  }

  Future<void> joinSpace(String spaceId) async {
    final id = spaceId.trim();
    if (id.isEmpty) return;
    await ensureConnected();
    final room = 'space:$id';
    if (_joinedRooms.contains(room)) return;
    _socket?.emitWithAck('correspondence:join', {'spaceId': id}, ack: (_) {});
    _joinedRooms.add(room);
  }

  Future<void> leaveSpace(String spaceId) async {
    final id = spaceId.trim();
    if (id.isEmpty) return;
    _socket?.emitWithAck('correspondence:leave', {'spaceId': id}, ack: (_) {});
    _joinedRooms.remove('space:$id');
  }

  Future<void> joinThread(String threadId) async {
    final id = threadId.trim();
    if (id.isEmpty) return;
    await ensureConnected();
    final room = 'thread:$id';
    if (_joinedRooms.contains(room)) return;
    _socket?.emitWithAck('correspondence:join', {'threadId': id}, ack: (_) {});
    _joinedRooms.add(room);
  }

  Future<void> leaveThread(String threadId) async {
    final id = threadId.trim();
    if (id.isEmpty) return;
    _socket?.emitWithAck('correspondence:leave', {'threadId': id}, ack: (_) {});
    _joinedRooms.remove('thread:$id');
  }

  Future<void> _connect(String token) async {
    await disconnect();
    final uri = Uri.parse(AppConfig.apiBaseUrl);
    final origin = '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';

    final socket = io.io(
      origin,
      <String, dynamic>{
        'transports': <String>['websocket'],
        'autoConnect': false,
        'forceNew': false,
        'auth': <String, dynamic>{
          'token': token,
          'accessToken': token,
        },
        'extraHeaders': <String, dynamic>{
          'Authorization': 'Bearer $token',
        },
      },
    );

    void onNamed(String name) {
      socket.on(name, (dynamic data) {
        final payload = data is Map<String, dynamic>
            ? data
            : (data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{'value': data});
        if (!_events.isClosed) {
          _events.add(CorrespondenceLiveEvent(name: name, payload: payload));
        }
      });
    }

    for (final name in const <String>[
      'call:incoming',
      'call:ringing_started',
      'call:terminal',
      'invite:created',
      'invite:updated',
      'space:member.joined',
      'space:member.updated',
      'thread:member.joined',
      'thread:member.updated',
      'thread:message.created',
      'thread:message.updated',
      'thread:message.deleted',
      'thread:read.updated',
      'session:participant.joined',
      'session:participant.resumed',
      'session:participant.left',
      'session:removed',
      'realtime:removed',
      // R3 — cross-device interaction + follow reconciliation. Payloads
      // are minimal triggers; listeners fan out to canonical providers
      // via `RealtimeReconciliationController` so backend remains the
      // truth source.
      'post:interaction.changed',
      'follow:state.changed',
      'feed:item.changed',
    ]) {
      onNamed(name);
    }

    // R3 — emit a synthetic `socket:connected` so reconcile controllers
    // can flush canonical providers after a missed-event window
    // (reconnect closes that window). socket_io_client fires onConnect
    // both on first connect and after reconnect, so we don't need to
    // distinguish.
    socket.onConnect((_) {
      if (!_events.isClosed) {
        _events.add(const CorrespondenceLiveEvent(
          name: 'socket:connected',
          payload: <String, dynamic>{},
        ));
      }
    });

    socket.connect();
    _socket = socket;
    _activeToken = token;
  }

  Future<void> disconnect() async {
    final socket = _socket;
    if (socket != null) {
      // Order matters: socket_io_client's dispose() removes the listener
      // table while disconnect() actually closes the underlying transport.
      // Calling dispose() first leaves the active transport flushing
      // events into a now-empty listener set and produces dangling
      // engine.io frames in flight. Disconnect first, then release.
      try {
        socket.disconnect();
      } catch (_) {
        // Already-disconnected sockets throw; ignore — dispose still
        // needs to run.
      }
      try {
        socket.dispose();
      } catch (_) {
        // dispose is best-effort cleanup of internal handlers.
      }
    }
    _socket = null;
    _activeToken = null;
    _joinedRooms.clear();
  }

  void dispose() {
    unawaited(disconnect().catchError((_) {}));
    _events.close();
  }
}

String _pickString(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty) return text;
  }
  return '';
}
