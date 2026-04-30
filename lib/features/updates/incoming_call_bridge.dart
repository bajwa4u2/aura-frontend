import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../correspondence/data/correspondence_live_service.dart';

final incomingCallBridgeProvider =
    StateNotifierProvider<IncomingCallBridgeNotifier, List<Map<String, dynamic>>>(
  (ref) {
    final notifier = IncomingCallBridgeNotifier();
    final service = ref.watch(correspondenceLiveServiceProvider);
    final sub = service.events.listen((event) {
      if (event.name == 'call:incoming') {
        notifier._onCallIncoming(event.payload);
      } else if (event.name == 'session:removed' ||
          event.name == 'realtime:removed') {
        final sid = _str(event.payload['sessionId']);
        if (sid.isNotEmpty) notifier._onSessionTerminated(sid);
      }
    });
    ref.onDispose(sub.cancel);
    return notifier;
  },
);

class IncomingCallBridgeNotifier
    extends StateNotifier<List<Map<String, dynamic>>> {
  IncomingCallBridgeNotifier() : super(const <Map<String, dynamic>>[]);

  void _onCallIncoming(Map<String, dynamic> payload) {
    final id = _str(payload['id']);
    if (id.isEmpty) return;
    state = [
      payload,
      ...state.where((item) => _str(item['id']) != id),
    ];
  }

  void _onSessionTerminated(String sessionId) {
    final next = state.where((item) {
      final data = item['data'];
      final sid = data is Map ? _str(data['sessionId']) : '';
      return sid != sessionId;
    }).toList();
    if (next.length != state.length) state = next;
  }

  void remove(String id) {
    if (id.isEmpty) return;
    state = state.where((item) => _str(item['id']) != id).toList();
  }
}

String _str(dynamic value) => value == null ? '' : value.toString().trim();
