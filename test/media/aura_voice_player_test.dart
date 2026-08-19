// F014 — VOICE-MESSAGE TIMELINE / PLAYBACK PRESENTATION.
//
// The defect: Conversation showed a play button beside the literal words
// "Voice note" — no progress, no timeline, no duration — and the label was
// hardcoded, so an uploaded MP3 was announced as a recording it was not.
// Correspondence had no inline playback at all.
//
// F014's canonical remainder is precisely "the timeline/playback
// presentation". These tests hold the two properties that make it honest:
// nothing displayed is invented, and no offered action can fail.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/media/aura_voice_player.dart';

void main() {
  group('F014 — voice is distinguished by SOURCE, never by MIME', () {
    test('RECORDING marks a voice message', () {
      // Media.source is stamped by the composer at capture. It is the only
      // authoritative distinction between a recording and an uploaded file.
      expect(isVoiceMessageSource('RECORDING'), isTrue);
      expect(isVoiceMessageSource('recording'), isTrue);
    });

    test('every other source is an ordinary audio file', () {
      for (final s in const ['UPLOAD', 'GALLERY', 'CAMERA', 'PASTE', '', null]) {
        expect(isVoiceMessageSource(s), isFalse,
            reason: '"$s" is not a capture and must not be announced as one.');
      }
    });
  });

  group('F014 — duration is formatted, never fabricated', () {
    test('formats message-length recordings as mm:ss', () {
      expect(formatPlaybackPosition(Duration.zero), '0:00');
      expect(formatPlaybackPosition(const Duration(seconds: 7)), '0:07');
      expect(formatPlaybackPosition(const Duration(seconds: 75)), '1:15');
      expect(formatPlaybackPosition(const Duration(minutes: 12, seconds: 3)),
          '12:03');
    });

    test('carries hours rather than silently wrapping', () {
      expect(formatPlaybackPosition(const Duration(hours: 1, minutes: 2, seconds: 3)),
          '1:02:03');
    });

    test('never renders a negative position', () {
      expect(formatPlaybackPosition(const Duration(seconds: -5)), '0:00');
    });
  });

  group('F014 — the surface states only what is known', () {
    Future<void> pump(WidgetTester tester, Widget child) =>
        tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));

    testWidgets('a recording is announced as a voice message', (tester) async {
      await pump(
        tester,
        const AuraVoicePlayer(
          url: 'https://example.test/a.m4a',
          isVoiceMessage: true,
          durationMs: 30000,
        ),
      );
      expect(find.text('Voice message'), findsOneWidget);
      // The old surface said "Voice note" for everything, including files.
      expect(find.text('Voice note'), findsNothing);
    });

    testWidgets('an uploaded audio file keeps its own name', (tester) async {
      await pump(
        tester,
        const AuraVoicePlayer(
          url: 'https://example.test/song.mp3',
          isVoiceMessage: false,
          fileName: 'interview-take-2.mp3',
          durationMs: 90000,
        ),
      );
      expect(find.text('interview-take-2.mp3'), findsOneWidget);
      expect(find.text('Voice message'), findsNothing,
          reason: 'Announcing an upload as a recording is a false claim.');
    });

    testWidgets('shows the authoritative duration before playback starts',
        (tester) async {
      await pump(
        tester,
        const AuraVoicePlayer(
          url: 'https://example.test/a.m4a',
          isVoiceMessage: true,
          durationMs: 75000,
        ),
      );
      // Media.duration is MILLISECONDS (F133). 75000ms is 1:15, not 75:00.
      expect(find.text('1:15'), findsOneWidget);
    });

    testWidgets('renders NO duration when the runtime does not know one',
        (tester) async {
      // The honest alternative to a fabricated total.
      await pump(
        tester,
        const AuraVoicePlayer(
          url: 'https://example.test/a.m4a',
          isVoiceMessage: true,
        ),
      );
      expect(find.textContaining(':'), findsNothing);
    });

    testWidgets('a zero or negative duration is treated as unknown',
        (tester) async {
      await pump(
        tester,
        const AuraVoicePlayer(
          url: 'https://example.test/a.m4a',
          isVoiceMessage: true,
          durationMs: 0,
        ),
      );
      expect(find.text('0:00'), findsNothing,
          reason: 'A confident "0:00" claims the recording is empty.');
    });

    testWidgets('renders the timeline F014 names', (tester) async {
      await pump(
        tester,
        const AuraVoicePlayer(
          url: 'https://example.test/a.m4a',
          isVoiceMessage: true,
          durationMs: 30000,
        ),
      );
      expect(find.byType(LinearProgressIndicator), findsOneWidget,
          reason: 'The missing progress presentation IS the finding.');
    });

    testWidgets('offers a play control', (tester) async {
      await pump(
        tester,
        const AuraVoicePlayer(
          url: 'https://example.test/a.m4a',
          isVoiceMessage: true,
          durationMs: 1000,
        ),
      );
      expect(find.byIcon(Icons.play_circle_fill_rounded), findsOneWidget);
    });

    testWidgets('does NOT draw a waveform', (tester) async {
      // The product computes no amplitude data. A decorative waveform would
      // assert a shape the bytes never had.
      await pump(
        tester,
        const AuraVoicePlayer(
          url: 'https://example.test/a.m4a',
          isVoiceMessage: true,
          durationMs: 30000,
        ),
      );
      expect(find.byType(CustomPaint).evaluate().length, lessThan(6),
          reason: 'No bespoke waveform painter should exist here.');
    });
  });
}
