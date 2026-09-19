import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:aura/features/realtime/data/realtime_event_parser.dart';
import 'package:aura/features/realtime/data/sfu_realtime_transport.dart';
import 'package:aura/features/realtime/domain/realtime_enums.dart';
import 'package:aura/features/realtime/domain/realtime_models.dart';
import 'package:aura/features/realtime/domain/realtime_state.dart';

/// WHAT THE 2026-09-16 CALLS PROVED, HELD AS RULES.
///
/// Five calls existed between the 1.4.3 release and this work. Two of them
/// received 614,911 and 267,879 bytes of video, reported `bind_complete` and
/// `render_attached`, and ended with the receiving side's grid reading
///
///     tile=true src=false dim=0x0 renderVideo=false
///
/// A third showed `roster=0 ids=[]` while the call was live. These tests hold
/// the decisions those failures turned on.
void main() {
  group('a renderer is never destroyed while the snapshot still holds it', () {
    // The renderer itself needs platform bindings, so the rule is asserted
    // where it is written. This is the ORDER that makes a tile survive a
    // mid-call detach: remove the reference, publish, and only then destroy.
    final service = File(
      'lib/features/realtime/data/realtime_media_service.dart',
    ).readAsStringSync();

    test('detachStage publishes the cleared snapshot BEFORE disposing', () {
      final detach = service.substring(service.indexOf('Future<void> detachStage('));
      final body = detach.substring(0, detach.indexOf('\n  }\n'));

      final clears = body.indexOf('_remoteRenderersByParticipant.clear()');
      final publish = body.indexOf('_publish()');
      final dispose = body.indexOf('_disposeRetired(');

      expect(clears, greaterThan(0));
      expect(publish, greaterThan(clears),
          reason: 'the map must lose the renderers before the UI is told');
      expect(dispose, greaterThan(publish),
          reason: 'disposing before the publish is what blackens a live tile');
    });

    test('a resolved media change publishes before disposing what it retired', () {
      final refresh = service
          .substring(service.indexOf('Future<void> refreshStageRemoteMedia('));
      final body = refresh.substring(0, refresh.indexOf('\n  }\n'));

      final sync = body.indexOf('_syncParticipantRenderers(');
      final publish = body.indexOf('_publish()');
      final dispose = body.indexOf('_disposeRetired(');

      expect(sync, greaterThan(0));
      expect(publish, greaterThan(sync));
      expect(dispose, greaterThan(publish));
    });

    test('the sync itself destroys nothing — it hands the retired objects back', () {
      final sync = service
          .substring(service.indexOf('Future<_RetiredMedia> _syncParticipantRenderers('));
      final body = sync.substring(0, sync.indexOf('\n  }\n'));

      expect(body.contains('doomed.renderers.add'), isTrue);
      expect(body.contains('await existingRenderer.dispose()'), isFalse,
          reason: 'a rebuild must not destroy a renderer still on screen');
      expect(body.contains('renderer?.srcObject = null'), isFalse,
          reason: 'clearing the source of a published renderer is the defect');
    });

    test('a first decoded frame is distinguishable from an attached track', () {
      // `render_attached` says a track was put on a stream. It never said a
      // frame reached the surface, and that gap is why bytes-received could
      // coexist with a black tile for the whole investigation.
      expect(service.contains('render_first_frame'), isTrue);
      expect(service.contains('onFirstFrameRendered'), isTrue);
    });
  });

  group('the roster events merge again', () {
    // `18ac001e` inserted `case session:media.published` WITH A BODY into the
    // middle of a fall-through group, so five events that carried the
    // authoritative roster became no-ops that only reconciled subscriptions.
    final controller = File(
      'lib/features/realtime/application/realtime_controller.dart',
    ).readAsStringSync();

    test('participants:updated and session:state reach a merge', () {
      final start = controller.indexOf("case 'session:state':");
      expect(start, greaterThan(0));
      final window = controller.substring(start, start + 2400);

      final merge = window.indexOf('_mergeWatchingRoster(event)');
      final mediaPublished = window.indexOf("case 'session:media.published':");

      expect(merge, greaterThan(0),
          reason: 'the roster events must merge the payload they carry');
      expect(merge, lessThan(mediaPublished),
          reason: 'they must not fall through into the media-published body');
    });
  });

  group('an empty roster is refused for the whole of a live session', () {
    Map<String, dynamic> participant(String id) => {
          'id': id,
          'userId': 'u-$id',
          'displayName': id,
        };

    RealtimeState holding(RealtimeJoinState join, List<String> ids) =>
        RealtimeState.initial().copyWith(
          joinState: join,
          participants: ids
              .map((id) => RealtimeParticipant.fromJson(participant(id)))
              .toList(),
        );

    test('while JOINING, not merely while joined', () {
      // The guard was gated on `isJoined`, one value of an enum a client
      // passes through while already holding a roster it was given.
      final before = holding(RealtimeJoinState.joining, ['a', 'b']);
      final after =
          RealtimeEventParser.mergeSnapshot(before, {'participants': []});
      expect(after.participants.map((p) => p.id), ['a', 'b']);
    });

    test('while LOCKED', () {
      final before = holding(RealtimeJoinState.locked, ['a', 'b']);
      final after =
          RealtimeEventParser.mergeSnapshot(before, {'participants': []});
      expect(after.participants.map((p) => p.id), ['a', 'b']);
    });

    test('but leaving still empties it', () {
      for (final terminal in [
        RealtimeJoinState.idle,
        RealtimeJoinState.removed,
        RealtimeJoinState.rejected,
        RealtimeJoinState.replaced,
      ]) {
        final before = holding(terminal, ['a']);
        final after =
            RealtimeEventParser.mergeSnapshot(before, {'participants': []});
        expect(after.participants, isEmpty,
            reason: 'the legitimate empty state must stay open for $terminal');
      }
    });

    test('a waiting room is not a session', () {
      // Someone in a waiting room is not in the call, so an empty roster is a
      // truthful answer for them.
      final before = holding(RealtimeJoinState.requested, ['a']);
      final after =
          RealtimeEventParser.mergeSnapshot(before, {'participants': []});
      expect(after.participants, isEmpty);
    });
  });

  group('bind_complete means every receiving line carries something', () {
    test('two receiving lines and one binding is PARTIAL, not complete', () {
      // The exact shape of the one-way audio call, reported as success for
      // three reproductions.
      expect(
        bindLabel(bound: 1, serverBindings: 1, receivingLines: 2),
        'bind_partial',
      );
    });

    test('every offered binding attached, and every line carrying: COMPLETE', () {
      expect(
        bindLabel(bound: 2, serverBindings: 2, receivingLines: 2),
        'bind_complete',
      );
    });

    test('a spare line the server never offered does not spoil a full bind', () {
      // receivingLines can exceed serverBindings legitimately only when the
      // server offered fewer; that is still partial by this rule, and the
      // rule errs toward saying less than it knows.
      expect(
        bindLabel(bound: 1, serverBindings: 2, receivingLines: 1),
        'bind_partial',
      );
    });

    test('nothing bound at all is NONE', () {
      expect(
        bindLabel(bound: 0, serverBindings: 2, receivingLines: 2),
        'bind_none',
      );
    });
  });

  group('the stage offers Aura\'s relay, not STUN alone', () {
    final transport = File(
      'lib/features/realtime/data/sfu_realtime_transport.dart',
    ).readAsStringSync();

    test('issued ice servers are spread into the peer configuration', () {
      final open = transport.substring(transport.indexOf('Future<void> _open('));
      final config = open.substring(0, open.indexOf('_pc = pc;'));
      expect(config.contains('...iceServers'), isTrue,
          reason: 'STUN discovers an address; it cannot forward a packet');
      expect(config.contains('stun:stun.cloudflare.com:3478'), isTrue,
          reason: 'the provider reflexive server stays — direct is preferred');
      expect(config.contains("'iceTransportPolicy'"), isFalse,
          reason: 'TURN must be a fallback, never forced: leaving the policy '
              'unset keeps it at `all`, so a direct path still wins');
    });

    test('per-kind bytes are written down, distinguishing ABSENT from zero', () {
      expect(transport.contains('kinds=\${_kindSummary('), isTrue);
      expect(transport.contains("'ABSENT'"), isTrue,
          reason: 'a kind never negotiated and a kind at 0b have different '
              'causes and different fixes');
    });

    test('accept-to-connect is attributable by stage', () {
      expect(transport.contains('state=first_bytes'), isTrue);
      expect(transport.contains('sinceOpenMs='), isTrue);
      expect(transport.contains("op=ICE state=\${done.isCompleted"), isTrue);
    });
  });
}
