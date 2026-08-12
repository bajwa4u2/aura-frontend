import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/realtime/data/realtime_socket_service.dart';

void main() {
  group('RealtimeSocketService — transport readiness invariant', () {
    // 2026-08-14 — freezes the invariant from the transport-ownership
    // repair: REALTIME TRANSPORT READY = connected AND a non-empty
    // server-assigned socket id. No realtime event may be emitted before
    // that condition holds. A freshly constructed service has never
    // connected, so isConnected must be false and emitAck must refuse to
    // fire rather than silently hanging on a socket that was never
    // confirmed ready — this is the exact guard that used to be a silent
    // best-effort wait inside emitAck itself.
    test('a freshly constructed service reports not connected', () {
      final service = RealtimeSocketService();
      expect(service.isConnected, isFalse);
      expect(service.socketId, isNull);
    });

    test('emitAck refuses to fire before the transport is ready', () async {
      final service = RealtimeSocketService();

      await expectLater(
        service.emitAck('session:join', <String, dynamic>{'sessionId': 'x'}),
        throwsA(isA<RealtimeTransportException>()),
      );
    });

    test('disconnect() on a never-connected service is a safe no-op', () async {
      final service = RealtimeSocketService();
      await service.disconnect();
      expect(service.isConnected, isFalse);
    });
  });
}
