// Meeting recording capture — conditional export: real MediaRecorder-based
// capture on web, inert stub elsewhere.
export 'recording_capture_stub.dart'
    if (dart.library.html) 'recording_capture_web.dart';
