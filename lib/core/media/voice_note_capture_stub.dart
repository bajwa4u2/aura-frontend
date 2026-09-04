import 'dart:typed_data';

import 'package:record/record.dart';

import 'voice_note_capture.dart';

/// Unreachable: every target Aura builds for resolves to either the `dart:io`
/// or the `dart:html` implementation. Present so the conditional import has a
/// default, which is the pattern the rest of `core/media` already uses.
VoiceNoteFormat voiceNoteFormat() => const VoiceNoteFormat(
      encoder: AudioEncoder.wav,
      extension: 'wav',
      mimeType: 'audio/wav',
    );

Future<String> voiceNoteTargetPath(String extension) async =>
    'voice-note.$extension';

Future<Uint8List> readCapturedVoiceNote(String handle) async {
  throw UnsupportedError('Voice notes are not supported on this platform.');
}

Future<void> discardCapturedVoiceNote(String handle) async {}
