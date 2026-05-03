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
          event.name == 'realtime:removed' ||
          event.name == 'call:terminal') {
        final sid = event.name == 'call:terminal'
            ? _str(event.payload['sessionId'])
            : _str(event.payload['sessionId']);
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

    // Suppress stale invites: if expiresAt is in the past, don't add to state.
    final data = payload['data'];
    if (data is Map) {
      final expiresAtStr = _str(data['expiresAt']);
      if (expiresAtStr.isNotEmpty) {
        final expiresAt = DateTime.tryParse(expiresAtStr);
        if (expiresAt != null && expiresAt.isBefore(DateTime.now().toUtc())) {
          return;
        }
      }
    }

    final sessionId = data is Map ? _str(data['sessionId']) : '';

    // Dedup by both notification ID and session ID so two pushes for the same
    // session (e.g. delivery retry on a different notification ID) don't produce
    // two ring cards stacked on top of each other.
    state = [
      payload,
      ...state.where((item) {
        if (_str(item['id']) == id) return false;
        if (sessionId.isNotEmpty) {
          final itemData = item['data'];
          if (itemData is Map && _str(itemData['sessionId']) == sessionId) {
            return false;
          }
        }
        return true;
      }),
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
