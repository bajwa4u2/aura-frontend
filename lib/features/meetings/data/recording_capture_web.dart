// Web meeting recording — CLIENT CAPTURE architecture.
//
// The host records their own view of the meeting via `getDisplayMedia`
// (choosing "This tab" captures every participant tile plus tab audio) and
// a `MediaRecorder`. This deliberately does NOT touch the frozen RTC stack:
// capture consumes the rendered surface, not the peer connections. Server
// capture would require an SFU/recording bot (a new media topology); hybrid
// post-processing can be layered later without changing this seam.
import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

@JS('navigator.mediaDevices.getDisplayMedia')
external JSPromise<JSObject> _getDisplayMedia(JSObject options);

@JS('MediaRecorder')
extension type _MediaRecorder._(JSObject _) implements JSObject {
  external factory _MediaRecorder(JSObject stream, JSObject options);
  external void start(int timeslice);
  external void stop();
  external String get state;
}

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
  JSObject? _stream;
  _MediaRecorder? _recorder;
  final List<JSObject> _chunks = [];
  DateTime? _startedAt;

  bool get isSupported => true;
  bool get isRecording => _recorder != null;

  Future<bool> start() async {
    if (_recorder != null) return true;
    try {
      final options = JSObject()
        ..setProperty('video'.toJS, true.toJS)
        ..setProperty('audio'.toJS, true.toJS);
      final stream = await _getDisplayMedia(options).toDart;
      _stream = stream;
      _chunks.clear();

      final recorderOptions = JSObject()
        ..setProperty('mimeType'.toJS, 'video/webm'.toJS);
      final recorder = _MediaRecorder(stream, recorderOptions);

      final onData = ((JSObject event) {
        final data = event.getProperty<JSObject?>('data'.toJS);
        if (data != null) {
          final size = (data.getProperty<JSNumber?>('size'.toJS))?.toDartInt ?? 0;
          if (size > 0) _chunks.add(data);
        }
      }).toJS;
      recorder.setProperty('ondataavailable'.toJS, onData);

      // If the host stops sharing from the browser chrome, end cleanly.
      final tracks =
          stream.callMethod<JSArray<JSObject>>('getTracks'.toJS).toDart;
      final onEnded = (() {
        final r = _recorder;
        if (r != null && r.state == 'recording') r.stop();
      }).toJS;
      for (final track in tracks) {
        track.setProperty('onended'.toJS, onEnded);
      }

      recorder.start(5000); // timeslice keeps chunks flowing
      _recorder = recorder;
      _startedAt = DateTime.now();
      return true;
    } catch (_) {
      _cleanup();
      return false;
    }
  }

  Future<RecordingResult?> stop() async {
    final recorder = _recorder;
    if (recorder == null) return null;

    final done = Completer<void>();
    recorder.setProperty(
      'onstop'.toJS,
      (() {
        if (!done.isCompleted) done.complete();
      }).toJS,
    );
    if (recorder.state == 'recording' || recorder.state == 'paused') {
      recorder.stop();
    } else {
      if (!done.isCompleted) done.complete();
    }
    await done.future.timeout(const Duration(seconds: 10), onTimeout: () {});

    final durationSeconds = _startedAt == null
        ? 0
        : DateTime.now().difference(_startedAt!).inSeconds;

    final chunks = _chunks.toList();
    _cleanup();
    if (chunks.isEmpty) return null;

    // Combine chunk Blobs into one and read its bytes.
    final blobParts = chunks.jsify() as JSObject;
    final blobOptions = JSObject()
      ..setProperty('type'.toJS, 'video/webm'.toJS);
    final blobCtor = globalContext.getProperty<JSFunction>('Blob'.toJS);
    final blob = blobCtor.callAsConstructor<JSObject>(blobParts, blobOptions);

    final bufferPromise =
        blob.callMethod<JSPromise<JSArrayBuffer>>('arrayBuffer'.toJS);
    final buffer = (await bufferPromise.toDart).toDart;
    final bytes = buffer.asUint8List();
    if (bytes.isEmpty) return null;

    return RecordingResult(
      bytes: bytes,
      mimeType: 'video/webm',
      durationSeconds: durationSeconds,
    );
  }

  void _cleanup() {
    final stream = _stream;
    if (stream != null) {
      try {
        final tracks =
            stream.callMethod<JSArray<JSObject>>('getTracks'.toJS).toDart;
        for (final track in tracks) {
          track.callMethod<JSAny?>('stop'.toJS);
        }
      } catch (_) {}
    }
    _stream = null;
    _recorder = null;
    _startedAt = null;
  }
}
