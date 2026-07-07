import 'dart:typed_data';

/// Non-web stub — meeting recording capture is a web (host) capability in
/// this release. Mobile hosts see no Record control.
class RecordingResult {
  final Uint8List bytes;
  final String mimeType;
  final int durationSeconds;

  const RecordingResult({
    required this.bytes,
    required this.mimeType,
    required this.durationSeconds,
  });
}

class MeetingRecordingCapture {
  /// Fired when the capture ends OUTSIDE the app's own Stop control (e.g.
  /// the browser's "Stop sharing" bar) so the room can finalize the upload.
  void Function()? onExternalStop;

  bool get isSupported => false;
  bool get isRecording => false;

  Future<bool> start() async => false;

  Future<RecordingResult?> stop() async => null;
}
