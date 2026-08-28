import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'package:aura/features/realtime/domain/realtime_state.dart';

/// A `copyWith` PARAMETER THAT IS ACCEPTED MUST BE ASSIGNED.
///
/// `remoteRenderersByParticipant` was declared on the field list, declared on
/// the `copyWith` signature, passed in by the controller on every media
/// snapshot — and never assigned in the returned object. The field fell back
/// to its `const {}` default, so the canonical participant-keyed renderer map
/// was destroyed on every state update.
///
/// Nothing upstream could show it. The media service built the renderers, the
/// snapshot carried them, the `<video>` element sat in the document with a
/// live 720x1280 track, and the call stage still drew one tile
/// (founder-observed 2026-08-28, on a call where the SFU had bound both
/// remote tracks: `bound=2 noMid=0 noLine=0 dirUnreadable=0 noTrack=0`).
void main() {
  group('RealtimeState.copyWith carries remote media', () {
    test('participant-keyed renderers survive a copy', () {
      final renderer = RTCVideoRenderer();
      final state = RealtimeState.initial().copyWith(
        remoteRenderersByParticipant: {'p1': renderer},
      );
      expect(state.remoteRenderersByParticipant, hasLength(1));
      expect(state.remoteRenderersByParticipant['p1'], same(renderer));
    });

    test('an unrelated copy does not silently drop them', () {
      // The real failure shape: the map is set once, then every later
      // copyWith -- a mic toggle, a busy flag -- erases it.
      final renderer = RTCVideoRenderer();
      final state = RealtimeState.initial()
          .copyWith(remoteRenderersByParticipant: {'p1': renderer})
          .copyWith(microphoneEnabled: false)
          .copyWith(isBusy: true);
      expect(state.remoteRenderersByParticipant, hasLength(1));
    });

    test('clearRemoteRenderers clears BOTH maps, not just the device one', () {
      final state = RealtimeState.initial().copyWith(
        remoteRenderers: {'socket:a': RTCVideoRenderer()},
        remoteRenderersByParticipant: {'p1': RTCVideoRenderer()},
      ).copyWith(clearRemoteRenderers: true);
      expect(state.remoteRenderers, isEmpty);
      expect(state.remoteRenderersByParticipant, isEmpty,
          reason: 'a half-cleared stage leaves a tile behind after a call');
    });
  });
}
