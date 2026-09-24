import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// C-8 — THE BROWSER'S OWN STOP BUTTON IS THE ONE PEOPLE PRESS.
///
/// Chrome floats a "Stop sharing" bar over every shared screen. Pressing it
/// ends the display track directly; the app is never asked. Nothing listened,
/// so the entire stop path was skipped and one stuck flag produced three
/// separate symptoms at once.
///
/// Measured live on a real meeting, 2026-09-24, and all three were reported by
/// the founder in the same minute:
///
///   * `SCREEN publishState=ON` at 07:25:53 and **no OFF ever** — the server
///     still had him sharing.
///   * The far side's decoder frozen at exactly **1,625 frames** across five
///     consecutive samples while bytes kept arriving — a sender still holding
///     a track that had stopped producing.
///   * His OWN tile reading **"camera off"**, because a tile hides local video
///     while it believes a share is running.
///
/// The repair is to listen, and then to say so: the media service ends the
/// share when the track ends, and the controller announces a stop it did not
/// start. A stop the app started must not be announced twice.
void main() {
  final media = File(
    'lib/features/realtime/data/realtime_media_service.dart',
  ).readAsStringSync();
  final controller = File(
    'lib/features/realtime/application/realtime_controller.dart',
  ).readAsStringSync();

  group('the media service notices the browser ending the share', () {
    test('a started share is watched', () {
      expect(media, contains('_watchScreenShareEnded(screenTrack);'),
          reason: 'C-8: nothing listens for the browser stopping the share');
    });

    test('the watcher runs the real stop path, not a flag flip', () {
      final start = media.indexOf('void _watchScreenShareEnded(');
      expect(start, greaterThan(-1));
      final body = media.substring(start, start + 900);
      expect(body, contains('screenTrack.onEnded'));
      expect(body, contains('stopScreenShare()'),
          reason: 'the camera must be restored and the dead track released, '
              'which only the real stop path does');
      expect(body, contains('catch (_)'),
          reason: 'a platform without the callback must not fail the share');
    });

    test('the watcher does not re-enter a stop already running', () {
      final start = media.indexOf('void _watchScreenShareEnded(');
      final body = media.substring(start, start + 900);
      expect(body, contains('!_isScreenSharing'));
    });
  });

  group('the controller announces a stop it did not start', () {
    test('an unsolicited stop emits session:screen.set false', () {
      final start = controller.indexOf('void _handleMediaSnapshot(');
      expect(start, greaterThan(-1));
      final body = controller.substring(start, start + 1400);
      expect(body, contains('!snapshot.isScreenSharing'));
      expect(body, contains('_screenStopAnnounced'));
      expect(body, contains("'enabled': false,"),
          reason: 'the room is never told the screen went away');
    });

    test('a stop the app started is not announced twice', () {
      final start = controller.indexOf('Future<void> stopScreenShare() async {');
      expect(start, greaterThan(-1));
      final body = controller.substring(start, start + 700);
      expect(body, contains('_screenStopAnnounced = true;'));
      expect(body, contains("emitAck('session:screen.set'"),
          reason: 'the app-initiated stop still signals for itself');
    });

    test('starting a share re-arms the watcher', () {
      final start = controller.indexOf('Future<void> startScreenShare() async {');
      final body = controller.substring(start, start + 900);
      expect(body, contains('_screenStopAnnounced = false;'),
          reason: 'a second share after a browser stop would never be '
              'announced when it ends');
    });
  });
}
