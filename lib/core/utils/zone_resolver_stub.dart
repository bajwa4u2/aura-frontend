/// Fallback when neither dart:io nor js_interop is available.
///
/// Returns null rather than a guess. A platform that cannot answer says so.
Future<String?> resolvePlatformZoneId() async => null;
