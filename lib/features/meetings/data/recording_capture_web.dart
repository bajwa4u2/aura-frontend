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
  int _bufferedBytes = 0;
  DateTime? _startedAt;

  /// Fired when the capture ends OUTSIDE the app's own Stop control (the
  /// browser's "Stop sharing" bar). A recording that already happened must
  /// NEVER be silently discarded — the room finalizes the upload from here.
  void Function()? onExternalStop;

  bool get isSupported => true;
  bool get isRecording => _recorder != null;

  /// Bytes captured but not yet drained by [takeBufferedBytes]. The room's
  /// streaming uploader watches this to flush parts to storage WHILE the
  /// meeting runs — durability doctrine: a crashed recording browser loses
  /// at most the unflushed tail, never the meeting.
  int get bufferedByteLength => _bufferedBytes;

  /// Drains the buffered chunks into one byte block (concatenated
  /// MediaRecorder output — byte-concatenation of sequential blocks is the
  /// valid WebM stream). Returns null when nothing is buffered.
  Future<Uint8List?> takeBufferedBytes() async {
    if (_chunks.isEmpty) return null;
    final chunks = _chunks.toList();
    _chunks.clear();
    _bufferedBytes = 0;

    final blobParts = chunks.jsify() as JSObject;
    final blobOptions = JSObject()
      ..setProperty('type'.toJS, 'video/webm'.toJS);
    final blobCtor = globalContext.getProperty<JSFunction>('Blob'.toJS);
    final blob = blobCtor.callAsConstructor<JSObject>(blobParts, blobOptions);
    final bufferPromise =
        blob.callMethod<JSPromise<JSArrayBuffer>>('arrayBuffer'.toJS);
    final buffer = (await bufferPromise.toDart).toDart;
    final bytes = buffer.asUint8List();
    return bytes.isEmpty ? null : bytes;
  }

  /// Stops the recorder and returns the capture duration in seconds. The
  /// final chunks remain buffered — drain them with [takeBufferedBytes] and
  /// upload as the last part.
  Future<int> stopCapture() async {
    final recorder = _recorder;
    if (recorder == null) return 0;

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

    // Release the display stream; keep the buffered chunks for the caller.
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
    return durationSeconds;
  }

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
          if (size > 0) {
            _chunks.add(data);
            _bufferedBytes += size;
          }
        }
      }).toJS;
      recorder.setProperty('ondataavailable'.toJS, onData);

      // If the host stops sharing from the browser chrome, end cleanly.
      final tracks =
          stream.callMethod<JSArray<JSObject>>('getTracks'.toJS).toDart;
      final onEnded = (() {
        final r = _recorder;
        if (r != null && r.state == 'recording') r.stop();
        // Let the room run the full stop-and-save flow.
        onExternalStop?.call();
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
    _chunks.clear();
    _bufferedBytes = 0;
  }
}
