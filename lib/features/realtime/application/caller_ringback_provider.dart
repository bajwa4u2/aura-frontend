import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../correspondence/data/correspondence_live_service.dart';

/// Tracks sessions for which the backend has confirmed that invites were
/// dispatched and callee devices are actively ringing.
///
/// The caller watches this to show a confirmed "Ringing…" indicator instead
/// of an optimistic animation. Sessions are removed when [call:terminal] or
/// [call:declined] arrives, signalling the ring ended.
final callerRingbackProvider =
    StateNotifierProvider<CallerRingbackNotifier, Set<String>>(
  (ref) {
    final notifier = CallerRingbackNotifier();
    final service = ref.watch(correspondenceLiveServiceProvider);
    final sub = service.events.listen((event) {
      final sid = (event.payload['sessionId'] ?? '').toString().trim();
      if (sid.isEmpty) return;
      switch (event.name) {
        case 'call:ringing_started':
          notifier._markRinging(sid);
        case 'call:terminal':
        case 'call:declined':
          notifier._clearRinging(sid);
      }
    });
    ref.onDispose(sub.cancel);
    return notifier;
  },
);

class CallerRingbackNotifier extends StateNotifier<Set<String>> {
  CallerRingbackNotifier() : super(const <String>{});

  void _markRinging(String sessionId) {
    if (state.contains(sessionId)) return;
    state = {...state, sessionId};
  }

  void _clearRinging(String sessionId) {
    if (!state.contains(sessionId)) return;
    state = state.where((id) => id != sessionId).toSet();
  }

  void clear(String sessionId) => _clearRinging(sessionId);
}
