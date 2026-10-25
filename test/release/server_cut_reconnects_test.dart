import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A SERVER CUT IS NOT A TRANSPORT LOSS, 2026-10-24.
///
/// socket.io's client reconnects by itself after a transport loss and never
/// after "io server disconnect". The controller waited for a 'socket:connected'
/// that could not come; the guest sat on "Reconnecting…" until the server's
/// 30 s grace marked them gone.
void main() {
  final src = File('lib/features/realtime/application/realtime_controller.dart')
      .readAsStringSync();
  final disconnected = src.substring(
    src.indexOf("case 'socket:disconnected':"),
    src.indexOf("case 'session:server.restarting':"),
  );

  test('a server cut while the room is open asks for the connection again', () {
    final resume = disconnected.substring(0, disconnected.indexOf('} else {'));
    expect(resume, contains("'io server disconnect'"));
    expect(resume, contains('await connect();'));
    expect(resume, contains('!state.isCallRoomVisible'));
  });
}
