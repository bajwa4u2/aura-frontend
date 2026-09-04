import 'dart:io';
import 'dart:typed_data';

import 'package:record/record.dart';

import 'voice_note_capture.dart';

/// Native capture — Android, iOS, Windows, macOS, Linux.
///
/// `aacLc` is the only encoder `record` 6.x supports across all five, and it
/// writes an MPEG-4 container on every one of them. That makes `audio/mp4` a
/// statement about the bytes rather than a hope about them.
VoiceNoteFormat voiceNoteFormat() => const VoiceNoteFormat(
      encoder: AudioEncoder.aacLc,
      extension: 'm4a',
      mimeType: 'audio/mp4',
    );

/// An absolute path inside the system temp directory.
///
/// Unique per recording: reusing one name let a failed or still-flushing
/// capture leave bytes that the next recording would read back as its own.
Future<String> voiceNoteTargetPath(String extension) async {
  final dir = await Directory.systemTemp.createTemp('aura_voice_');
  return '${dir.path}${Platform.pathSeparator}voice-note.$extension';
}

/// Read the file the recorder wrote.
///
/// This is the whole native defect in one line: the composer used to fetch
/// this path with an HTTP client, which cannot open a filesystem path, so
/// every native voice note failed before it was ever uploaded.
Future<Uint8List> readCapturedVoiceNote(String handle) async {
  final file = File(handle);
  if (!await file.exists()) {
    throw StateError('The recording was not written to $handle.');
  }
  final bytes = await file.readAsBytes();
  if (bytes.isEmpty) {
    throw StateError('The recording at $handle is empty.');
  }
  return bytes;
}

/// Remove the temp file and the directory made for it. Never throws — the
/// bytes are already held by the caller, and failing to tidy up is not a
/// reason to fail a send.
Future<void> discardCapturedVoiceNote(String handle) async {
  try {
    final file = File(handle);
    if (await file.exists()) await file.delete();
    final dir = file.parent;
    if (dir.path.contains('aura_voice_')) {
      await dir.delete(recursive: true);
    }
  } catch (_) {
    // Deliberately silent.
  }
}
