import 'dart:typed_data';

import 'package:record/record.dart';

import 'voice_note_capture_stub.dart'
    if (dart.library.io) 'voice_note_capture_io.dart'
    if (dart.library.html) 'voice_note_capture_web.dart' as platform;

/// HOW A VOICE NOTE IS ACTUALLY CAPTURED, PER PLATFORM.
///
/// `record` writes a DIFFERENT container per platform for the same encoder,
/// and returns a DIFFERENT kind of handle from `stop()`. The conversation
/// composer used to assert one of each for all of them:
///
///   * `AudioEncoder.opus` with `fileName: 'voice-note.webm'` and
///     `declaredMimeType: 'audio/webm'` — true only in Chrome and Firefox.
///     On Android that encoder writes an **OGG** container, on iOS a **CAF**
///     one, and on Windows and macOS `record` does not support opus at all.
///   * `Dio().get(path)` to read the recording back — true only on the web,
///     where `stop()` returns a `blob:` URL. On every native platform it
///     returns a FILESYSTEM PATH, which an HTTP client cannot open.
///
/// The composer sits directly under a comment stating that intake "never
/// manufactures a type it has no evidence for". Declaring `audio/webm` for
/// CAF bytes is exactly that, and the backend's content-truth check is what
/// finally refused it — after the person had already recorded.
///
/// Everything platform-shaped now lives here, and the composer asks.
class VoiceNoteCapture {
  const VoiceNoteCapture._();

  /// The encoder to record with, and the container/MIME it genuinely produces.
  ///
  /// Native uses `aacLc`, the one encoder `record` supports on Android, iOS,
  /// Windows, macOS and Linux alike, and which writes an MPEG-4 container on
  /// all of them. `audio/mp4` is already accepted by the client allow-list and
  /// by the backend.
  static VoiceNoteFormat get format => platform.voiceNoteFormat();

  /// Where the recorder should write.
  ///
  /// An ABSOLUTE path on native — `record` needs one, and the bare
  /// `'voice-note.webm'` the composer used to pass is resolved against a
  /// working directory no mobile app meaningfully has. Ignored on the web.
  static Future<String> targetPath(String extension) =>
      platform.voiceNoteTargetPath(extension);

  /// Read back what `stop()` handed us: a file on native, a blob URL on web.
  static Future<Uint8List> readCaptured(String handle) =>
      platform.readCapturedVoiceNote(handle);

  /// Best-effort cleanup of the on-device recording once its bytes are held.
  /// A no-op on the web, where the blob is owned by the browser.
  static Future<void> discardCaptured(String handle) =>
      platform.discardCapturedVoiceNote(handle);
}

/// What a recording will actually be, on this platform.
class VoiceNoteFormat {
  const VoiceNoteFormat({
    required this.encoder,
    required this.extension,
    required this.mimeType,
  });

  final AudioEncoder encoder;

  /// Without the dot.
  final String extension;

  /// The MIME the produced bytes genuinely carry — never a hopeful one.
  final String mimeType;

  String get fileName => 'voice-note.$extension';
}
