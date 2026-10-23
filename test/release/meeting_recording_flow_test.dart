import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// MEETING RECORDING, AS FOUND IN THE 1.7.0 (47) MEETING, 2026-10-23.
///
/// The founder pressed Record: the browser's share picker opened, the server
/// then held the recording for consent and the choice was thrown away; the
/// host had to guess when to press again; the recording that did start was
/// lost on save (`EntityTooSmall`) and left "recording" on the record.
void main() {
  String code(String path) => const LineSplitter()
      .convert(File(path).readAsStringSync())
      .map((l) {
        final i = l.indexOf('//');
        return i < 0 ? l : l.substring(0, i);
      })
      .join('\n');

  final room =
      code('lib/features/meetings/presentation/meeting_live_room_screen.dart');
  final capture = code('lib/features/meetings/data/recording_capture_web.dart');

  test('the server is asked before the browser capture prompt opens', () {
    final start = room.indexOf('Future<void> _toggleRecording(');
    final body = room.substring(start, room.indexOf('Uint8List _combineParts('));
    expect(body.indexOf('beginRecordingUpload('),
        lessThan(body.indexOf('_recorder.start()')));
    expect(body, contains('abortRecordingUpload('),
        reason: 'a cancelled prompt must not leave an open upload');
  });

  test('the host is offered the start when the last person agrees', () {
    final handler = room.substring(
      room.indexOf("case 'recording:consent.updated':"),
      room.indexOf("case 'session:mute-request':"),
    );
    expect(handler, contains('_awaitingRecordingConsent.remove('));
    expect(handler, contains('_offerRecordingStart()'));
    expect(room, contains("title: const Text('Everyone agreed.')"));
  });

  test('recording asks for this tab, not a screen to pick', () {
    expect(capture, contains("'preferCurrentTab'.toJS, true.toJS"));
    expect(capture, contains("'displaySurface'.toJS, 'browser'.toJS"));
  });

  test('the save waits for the recorder to really stop, however it stopped',
      () {
    final stop = capture.substring(
      capture.indexOf('Future<int> stopCapture('),
      capture.indexOf('Future<bool> start('),
    );
    expect(stop, contains('await stopped.future'));
    expect(capture, contains("'onstop'.toJS"));
  });

  test('a refused save does not stay recording', () {
    final save = room.substring(
      room.indexOf('Future<void> _stopAndSaveRecording('),
      room.indexOf('bool _showFiles'),
    );
    final failure = save.substring(save.lastIndexOf('} catch (_) {'));
    expect(failure, contains('abortRecordingUpload('));
  });
  test('a window or screen is refused before a frame is kept', () {
    final start = capture.substring(capture.indexOf('Future<bool> start('));
    final check = start.indexOf("surface != 'browser'");
    expect(check, greaterThan(0));
    expect(check, lessThan(start.indexOf('_MediaRecorder(stream')));
    expect(room, contains('_recorder.refusedNotATab'));
  });

  test('the tab hint is shown before the browser asks', () {
    final start = room.indexOf('Future<void> _toggleRecording(');
    final body = room.substring(start, room.indexOf('Uint8List _combineParts('));
    expect(body.indexOf('Choose this tab'),
        lessThan(body.indexOf('_recorder.start()')));
  });
}
