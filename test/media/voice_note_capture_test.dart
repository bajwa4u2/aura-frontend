// VOICE NOTES MUST DECLARE WHAT THEY ACTUALLY ARE.
//
// The conversation composer recorded with `AudioEncoder.opus` and then told
// intake the bytes were `audio/webm` in a file called `voice-note.webm`. That
// is true in Chrome and Firefox and nowhere else: `record` writes OGG on
// Android, CAF on iOS, and refuses opus outright on Windows and macOS. The
// backend's content-truth check is what finally caught it, which meant a
// person recorded a message and only then learned it could not be sent.
//
// These tests run on the VM, so they exercise the NATIVE format — the one
// that was wrong on every platform Aura ships natively.

import 'dart:io';

import 'package:aura/core/media/attachment.dart';
import 'package:aura/core/media/media_mime.dart';
import 'package:aura/core/media/voice_note_capture.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';

void main() {
  group('Voice note capture — the declaration matches the bytes', () {
    test('the native format is one record supports on every native target', () {
      // aacLc is the only encoder `record` 6.x lists for Android, iOS,
      // Windows, macOS AND Linux. opus is absent from Windows and macOS
      // entirely, which is why recording never started there.
      expect(VoiceNoteCapture.format.encoder, AudioEncoder.aacLc);
    });

    test('the declared MIME is a type the client actually accepts', () {
      final mime = VoiceNoteCapture.format.mimeType;
      expect(
        isAnyMimeAllowed(mime),
        isTrue,
        reason: 'Voice notes declare $mime, which intake would refuse.',
      );
      expect(kindFromMime(mime), AttachmentKind.audio);
    });

    test('the file name agrees with the declared MIME', () {
      final format = VoiceNoteCapture.format;
      // A name that infers to a different type than the declaration is the
      // exact shape of the original defect: `voice-note.webm` carrying MPEG-4
      // or CAF bytes.
      expect(
        inferMimeFromFileName(format.fileName),
        format.mimeType,
        reason: 'voice-note.${format.extension} does not infer to '
            '${format.mimeType}; one of the two is a guess.',
      );
    });

    test('the recorder is given an absolute path it can write to', () async {
      final path = await VoiceNoteCapture.targetPath(
        VoiceNoteCapture.format.extension,
      );
      expect(
        p_isAbsolute(path),
        isTrue,
        reason: 'record needs an absolute path natively; the composer used to '
            'pass the bare name "voice-note.webm".',
      );
      expect(path, endsWith('.${VoiceNoteCapture.format.extension}'));

      // Clean up the temp directory `targetPath` created.
      final dir = File(path).parent;
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    test('reading a recording that was never written fails loudly', () async {
      final missing = '${Directory.systemTemp.path}'
          '${Platform.pathSeparator}aura_voice_absent.m4a';
      await expectLater(
        VoiceNoteCapture.readCaptured(missing),
        throwsA(isA<StateError>()),
        reason: 'A silent failure here is what produced "Could not capture '
            'the recording — try again" for a problem retrying never fixed.',
      );
    });

    test('discarding a handle that is not there does not throw', () async {
      final missing = '${Directory.systemTemp.path}'
          '${Platform.pathSeparator}aura_voice_absent.m4a';
      await VoiceNoteCapture.discardCaptured(missing);
    });
  });
}

/// Absolute-path check without pulling in `package:path` for one call.
bool p_isAbsolute(String path) {
  if (path.startsWith('/')) return true;
  // Windows: a drive letter, or a UNC share.
  final drive = RegExp(r'^[A-Za-z]:[\\/]');
  return drive.hasMatch(path) || path.startsWith(r'\\');
}
