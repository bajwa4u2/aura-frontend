import 'zone_resolver_stub.dart'
    if (dart.library.io) 'zone_resolver_io.dart'
    if (dart.library.js_interop) 'zone_resolver_web.dart' as platform;

/// THE DEVICE'S TIMEZONE, AS AN IANA IDENTIFIER — OR NOTHING.
///
/// ── WHY THIS WAS REWRITTEN ───────────────────────────────────────────────
///
/// The previous version mapped about two dozen US display names and
/// abbreviations to IANA zones and returned anything else unchanged. The
/// backend then coerced whatever it could not parse to UTC and carried on.
///
/// Together those two silences produced the worst kind of failure: a person in
/// Karachi, Istanbul or Berlin could be shown a time that was simply wrong,
/// with nothing anywhere indicating a problem — while a person in New York was
/// shown the right one, because their zone happened to be in the table. A US
/// user could not have discovered this bug, and neither could a test that ran
/// in a US zone.
///
/// ── THE RULE NOW ─────────────────────────────────────────────────────────
///
/// Resolution goes through the platform's own timezone database — ICU on the
/// web, the OS zone identifier on native — never a hardcoded list. And it is
/// honest: if a real IANA identifier cannot be obtained, this returns NULL.
/// Nothing invents `UTC`, because a guessed zone presented as a resolved one is
/// exactly how someone ends up acting on a wrong time.
///
/// Callers decide what an unknown zone means for them. What none of them may do
/// is substitute a plausible-looking default.
Future<String?> resolveLocalTimezone() async {
  final resolved = (await platform.resolvePlatformZoneId())?.trim();
  if (resolved == null || resolved.isEmpty) return null;
  return isIanaZoneId(resolved) ? resolved : null;
}

/// The last resolved zone, cached after the first successful lookup.
///
/// Native resolution crosses a platform channel, and several call sites are on
/// paths that cannot await one (a widget build, a synchronous request
/// interceptor). A device's zone changes rarely — on travel or a settings
/// change — and [primeLocalTimezone] refreshes it at startup.
String? _cached;

/// Resolve once and remember it. Safe to call more than once.
Future<String?> primeLocalTimezone() async {
  final resolved = await resolveLocalTimezone();
  if (resolved != null) _cached = resolved;
  return _cached;
}

/// The cached zone, or null if resolution has not succeeded.
///
/// NULL IS A REAL ANSWER and must be handled as one. A caller that needs to
/// send a zone should omit the field rather than send a guess; a caller that
/// needs to label something should say nothing rather than name the wrong
/// place.
String? get cachedLocalTimezone => _cached;

/// Does this look like an IANA zone identifier?
///
/// Shape-checked rather than validated against a list: the client cannot carry
/// the IANA database, and a list would rot exactly the way the display-name map
/// did. The platform layer is what actually produces these values, so the job
/// here is to reject the things that are NOT zone identifiers — "PKT", "EDT",
/// "Pakistan Standard Time", "GMT+05:00", "+03" — every one of which the old
/// code passed straight through to a backend that turned it into UTC.
///
/// `UTC` is accepted because it is a genuine identifier. It is only ever a lie
/// when something SUBSTITUTED it, which is what this file no longer does.
bool isIanaZoneId(String value) {
  final v = value.trim();
  if (v.isEmpty) return false;
  if (v == 'UTC' || v == 'GMT') return true;

  // Region/City, optionally Region/Sub/City — the only shape IANA uses.
  // Deliberately rejects a bare abbreviation, a display name (which contains
  // spaces), and any offset form.
  if (!v.contains('/')) return false;
  if (v.contains(' ')) return false;

  final parts = v.split('/');
  if (parts.length < 2 || parts.length > 3) return false;
  for (final part in parts) {
    if (part.isEmpty) return false;
    if (!RegExp(r'^[A-Za-z][A-Za-z0-9_+-]*$').hasMatch(part)) return false;
  }
  return true;
}
