import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// ONE AUTHORITY DECIDES WHERE A CALL IS HEARD.
///
/// 2026-11-02, S24: video calls played through the earpiece, the speaker
/// button did nothing, calls opened on the speaker and dropped to the
/// earpiece, and a chosen route moved back on its own. Android had two
/// things routing call audio — Telecom and WebRTC's own audio switch — and
/// they fought. Now exactly one owns each call's route.
void main() {
  final kotlin = File(
    'android/app/src/main/kotlin/org/auraplatform/app/AuraTelecom.kt',
  ).readAsStringSync();
  final telecom =
      File('lib/core/notifications/android_telecom.dart').readAsStringSync();
  final media = File('lib/features/realtime/data/realtime_media_service.dart')
      .readAsStringSync();
  final controller =
      File('lib/features/realtime/application/realtime_controller.dart')
          .readAsStringSync();
  final picker =
      File('lib/core/media/audio_output_native.dart').readAsStringSync();

  String body(String source, String start, String end) {
    final i = source.indexOf(start);
    // Called while groups are built, where `expect` is not allowed.
    if (i < 0) throw StateError('missing: $start');
    return source.substring(i, source.indexOf(end, i));
  }

  group('when Telecom holds the call, WebRTC keeps out of routing', () {
    final configure = body(media, 'Future<bool> configureCallAudio(',
        'Future<void> removePeer(');
    final claim = body(media, 'Future<bool> _claimAudioRoute(',
        'Future<void> removePeer(');

    test('the owner is chosen from whether Telecom holds a call', () {
      expect(claim, contains('AndroidTelecom.instance.holdsCall()'));
      expect(configure, contains('await _claimAudioRoute()'));
      expect(kotlin, contains('"holdsCall" -> result.success(calls.isNotEmpty())'));
      expect(telecom, contains("invokeMethod<bool>('holdsCall')"));
    });

    test("WebRTC's switch is told to leave focus, mode and routing alone", () {
      // Its routing runs only in a call mode or when forced; focus and mode
      // are touched only when it manages focus.
      expect(claim, contains('manageAudioFocus: false'));
      expect(claim, contains('androidAudioMode: AndroidAudioMode.normal'));
      expect(claim, contains('forceHandleAudioRouting: false'));
      expect(claim, contains('if (telecomOwns) await Helper.clearAndroidCommunicationDevice()'),
          reason: "the switch's earlier speaker request outranked Telecom");
    });

    test('without a system call, WebRTC keeps the communication setup', () {
      expect(claim, contains(': AndroidAudioConfiguration.communication'));
    });

    test('the starting output goes to the owner only', () {
      expect(configure, contains('await AndroidTelecom.instance.setSpeaker(speaker)'));
      expect(configure, contains('await Helper.setSpeakerphoneOn(speaker)'));
    });
  });

  test('the owner is claimed before every microphone start', () {
    // The answer warm-up opens the microphone before the call's media step.
    final acquire = body(media, 'Future<void> _acquireLocalMedia(',
        'navigator.mediaDevices.getUserMedia(');
    expect(acquire, contains('if (audio) await _claimAudioRoute();'));
  });

  test('the starting output is set before the microphone starts', () {
    final configureAt = controller.indexOf('_mediaService.configureCallAudio(');
    final captureAt =
        controller.indexOf('capture = _mediaService.ensureLocalMedia(');
    expect(configureAt, greaterThan(-1));
    expect(configureAt, lessThan(captureAt),
        reason: 'started first, WebRTC picks the speaker and the call flips');
    expect(controller, contains('_routeDefaultSessionId = sessionId;'),
        reason: 'once per call, however the devices became ready');
  });

  test('the speaker toggle asks the owner, never both', () {
    final toggle = body(media, 'Future<void> setSpeakerphoneEnabled(',
        'Future<void> removePeer(');
    expect(toggle, contains('AndroidTelecom.instance.setSpeaker(enabled)'));
    expect(toggle, contains('if (!viaTelecom) await Helper.setSpeakerphoneOn(enabled)'));
  });

  test('the output button asks the owner, never both, and waits for it', () {
    final select = body(picker, 'Future<AudioOutputRoute?> select(',
        '_platformRoutes(String');
    expect(select, contains('AndroidTelecom.instance.setRoute(route.id)'));
    expect(select, contains('if (!viaTelecom) {'));
    expect(select, contains('if (now?.id == route.id) return now;'));
    expect(kotlin, contains('"setRoute" ->'));
  });

  test("Telecom's routes are kept as they change, never awaited at tap time",
      () {
    // availableEndpoints / currentCallEndpoint emit on change; awaiting
    // .first() when tapped hung the fourth tap on the S24.
    expect(kotlin, contains('availableEndpoints.collect { endpointsBySession[sessionId] = it }'));
    expect(kotlin, contains('currentCallEndpoint.collect { currentBySession[sessionId] = it }'));
    expect(kotlin, isNot(contains('availableEndpoints.first()')));
    expect(kotlin, isNot(contains('currentCallEndpoint.first()')));
  });

  test('an ended call stops its endpoint watchers, so it leaves the list', () {
    // Left running, they kept every ended call "live": route requests went
    // to all of them, and holdsCall would wrongly hand a meeting to Telecom.
    expect(kotlin, contains('watchersBySession[sessionId] = listOf('));
    final disconnectAt = kotlin.indexOf('{ cause ->');
    expect(kotlin.indexOf('stopWatching(sessionId)', disconnectAt),
        greaterThan(disconnectAt),
        reason: 'the system ending the call stops them');
    final endAt = kotlin.indexOf('it.disconnect(DisconnectCause(cause))');
    expect(endAt, greaterThan(-1));
    expect(kotlin.indexOf('stopWatching(sessionId)', endAt) - endAt,
        lessThan(120), reason: 'Aura ending the call stops them');
  });

  test('a route request is never skipped as "already there"', () {
    // The current-endpoint flow lags a change just made; trusting it
    // swallowed the tap back to the earpiece on the S24.
    expect(kotlin, isNot(contains('currentCallEndpoint.first().type == type) return')));
    expect(kotlin, isNot(contains('if (current.type == wanted) return')));
    expect(kotlin, contains('control.requestEndpointChange(endpoint)'));
  });

  test('a headset is never pulled off when the speaker goes off', () {
    expect(kotlin,
        contains('if (!speaker && current != null && current.type != CallEndpointCompat.TYPE_SPEAKER) return'));
  });
}
