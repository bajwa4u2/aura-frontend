import 'dart:js_interop';

/// THE BROWSER'S OWN ICU DATABASE ANSWERS THIS.
///
/// `Intl.DateTimeFormat().resolvedOptions().timeZone` returns a real IANA
/// identifier ("Asia/Karachi", "Europe/Istanbul", "Europe/Berlin") in every
/// browser Aura supports. It is the same mechanism the backend uses to
/// interpret the value, so the two agree by construction instead of by a
/// hand-maintained table that only ever covered the United States.
Future<String?> resolvePlatformZoneId() async {
  try {
    final zone = _resolvedTimeZone();
    return zone.isEmpty ? null : zone;
  } catch (_) {
    // A browser that cannot answer has not answered. It has not said UTC.
    return null;
  }
}

@JS('Intl.DateTimeFormat')
extension type _DateTimeFormat._(JSObject _) implements JSObject {
  external factory _DateTimeFormat();
  external _ResolvedOptions resolvedOptions();
}

extension type _ResolvedOptions._(JSObject _) implements JSObject {
  external String? get timeZone;
}

String _resolvedTimeZone() => _DateTimeFormat().resolvedOptions().timeZone ?? '';
