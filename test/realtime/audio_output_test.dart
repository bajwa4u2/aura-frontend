import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/media/audio_output.dart';
import 'package:aura/core/media/audio_output_controller.dart';

/// WHERE A CALL IS HEARD — the contract, held from the outside.
///
/// The picker exists because a binary speaker toggle cannot express a third
/// output. With a Bluetooth headset connected there are at least three
/// legitimate places a call can play, and on 2026-09-05 a real call was left
/// with NO output at all when a paired headset dropped its link — media
/// arriving and correctly bound the whole time, nothing audible, and no control
/// that could fix it.
///
/// So the rules under test are about honesty, not features: show only what the
/// platform reported, show what it ACCEPTED rather than what was asked, and
/// never leave a call pointing at a route that no longer exists.
class _FakeAuthority extends AudioOutputAuthority {
  _FakeAuthority({
    required this.routes,
    this.currentId,
    this.acceptSelection = true,
    this.supported = true,
  });

  List<AudioOutputRoute> routes;
  String? currentId;

  /// When false the platform refuses the request and stays where it was —
  /// which the UI must show rather than the route that was tapped.
  bool acceptSelection;
  bool supported;

  final selected = <String>[];

  @override
  bool get isSupported => supported;

  @override
  Future<List<AudioOutputRoute>> available() async => routes;

  @override
  Future<AudioOutputRoute?> current() async {
    for (final r in routes) {
      if (r.id == currentId) return r;
    }
    return null;
  }

  @override
  Future<AudioOutputRoute?> select(AudioOutputRoute route) async {
    selected.add(route.id);
    if (acceptSelection) currentId = route.id;
    return current();
  }
}

const _earpiece = AudioOutputRoute(id: 'earpiece', kind: AudioOutputKind.earpiece);
const _speaker = AudioOutputRoute(id: 'speaker', kind: AudioOutputKind.speaker);
const _bt = AudioOutputRoute(
  id: 'bluetooth',
  kind: AudioOutputKind.bluetooth,
  deviceName: 'MSBSURFACE',
);

void main() {
  group('what a person is shown', () {
    test('a named headset is named; a built-in output is not', () {
      // A device name earns its place only when it says more than the kind.
      // "Earpiece" named "Earpiece" is noise; a headset someone can recognise
      // is the whole point.
      expect(_bt.label, 'MSBSURFACE');
      expect(_earpiece.label, 'Earpiece');
      expect(_speaker.label, 'Speaker');
      expect(
        const AudioOutputRoute(
          id: 'bluetooth',
          kind: AudioOutputKind.bluetooth,
          deviceName: 'Bluetooth',
        ).label,
        'Bluetooth',
      );
    });

    test('no infrastructure vocabulary reaches a person', () {
      // Nobody making a phone call can act on HFP, SCO, sinkId or
      // AVAudioSession, and naming them puts the plumbing in front of the call.
      const forbidden = ['hfp', 'sco', 'sinkid', 'avaudiosession', 'audiodeviceinfo', 'a2dp'];
      for (final kind in AudioOutputKind.values) {
        final copy = kind.label.toLowerCase();
        for (final word in forbidden) {
          expect(copy.contains(word), isFalse, reason: '$kind leaks "$word"');
        }
        expect(copy.trim(), isNotEmpty);
      }
    });
  });

  group('the control appears only when it is real', () {
    test('an unsupported platform offers nothing', () async {
      const authority = UnsupportedAudioOutputAuthority();
      expect(authority.isSupported, isFalse);
      expect(await authority.available(), isEmpty);
      expect(await authority.current(), isNull);
      // A browser has no earpiece and no Bluetooth routing authority.
      // Manufacturing that picker would offer options that do nothing.
      expect(await authority.select(_speaker), isNull);
    });

    test('one route is not a choice', () {
      const one = AudioOutputState(
        isSupported: true,
        routes: [_earpiece],
        current: _earpiece,
      );
      expect(one.hasChoice, isFalse);

      const two = AudioOutputState(
        isSupported: true,
        routes: [_earpiece, _speaker],
        current: _earpiece,
      );
      expect(two.hasChoice, isTrue);
    });
  });

  group('the route shown is the one the platform accepted', () {
    test('a successful switch is reflected', () async {
      final authority = _FakeAuthority(
        routes: [_bt, _earpiece, _speaker],
        currentId: 'earpiece',
      );
      final controller = AudioOutputController(authority);
      await controller.refresh();
      expect(controller.state.current, _earpiece);

      await controller.select(_bt);
      expect(controller.state.current, _bt);
      controller.dispose();
    });

    test('a REFUSED switch shows where the audio actually is', () async {
      // The single most important rule here. Optimistically claiming the
      // requested route would tell somebody their call moved to a headset it
      // never reached — and they would believe the app over their own ears.
      final authority = _FakeAuthority(
        routes: [_bt, _earpiece, _speaker],
        currentId: 'earpiece',
        acceptSelection: false,
      );
      final controller = AudioOutputController(authority);
      await controller.refresh();

      await controller.select(_bt);
      expect(authority.selected, ['bluetooth']);
      expect(controller.state.current, _earpiece,
          reason: 'the request was made and refused; the tick stays with the '
              'route that is actually carrying the call');
      controller.dispose();
    });
  });

  group('a route that disappears', () {
    test('the call is moved to one that exists', () async {
      // Bluetooth drops mid-call and the platform has NOT re-routed. Doing
      // nothing here is silence — which is exactly what happened on a real
      // device before this control existed.
      final authority = _FakeAuthority(
        routes: [_bt, _earpiece, _speaker],
        currentId: 'bluetooth',
      );
      final controller = AudioOutputController(authority);
      await controller.refresh();
      expect(controller.state.current, _bt);

      authority.routes = [_earpiece, _speaker];
      await controller.refresh();

      expect(authority.selected, contains('earpiece'),
          reason: 'a call must never stay bound to a route that is gone');
      expect(controller.state.current, _earpiece);
      controller.dispose();
    });

    test('a platform that already re-routed is left alone', () async {
      // The usual case: the system moved the audio itself. Selecting again
      // would fight it, so a route that is still in the list is never
      // second-guessed.
      final authority = _FakeAuthority(
        routes: [_earpiece, _speaker],
        currentId: 'speaker',
      );
      final controller = AudioOutputController(authority);
      await controller.refresh();
      expect(controller.state.current, _speaker);
      expect(authority.selected, isEmpty);
      controller.dispose();
    });
  });
}
