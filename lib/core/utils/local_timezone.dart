/// Resolve the device's timezone as an IANA identifier (e.g. "America/New_York").
///
/// Flutter's `DateTime.now().timeZoneName` returns a *display name* on web
/// ("Eastern Daylight Time") and an abbreviation on some platforms ("EDT").
/// Neither is a valid IANA zone, and sending them to the backend made its
/// `Intl.DateTimeFormat`-based slot resolution throw
/// `RangeError: Invalid time zone specified` → a 500 on the public booking page.
///
/// This maps the common US display names / abbreviations to IANA. For anything
/// unmapped it returns the raw value; the backend coerces unknown zones to UTC
/// rather than crashing, so this never produces a hard failure.
String resolveLocalTimezone() {
  final raw = DateTime.now().timeZoneName.trim();
  if (raw.isEmpty) return 'UTC';
  return _displayNameToIana[raw.toLowerCase()] ?? raw;
}

const Map<String, String> _displayNameToIana = {
  'eastern daylight time': 'America/New_York',
  'eastern standard time': 'America/New_York',
  'central daylight time': 'America/Chicago',
  'central standard time': 'America/Chicago',
  'mountain daylight time': 'America/Denver',
  'mountain standard time': 'America/Denver',
  'pacific daylight time': 'America/Los_Angeles',
  'pacific standard time': 'America/Los_Angeles',
  'edt': 'America/New_York',
  'est': 'America/New_York',
  'cdt': 'America/Chicago',
  'cst': 'America/Chicago',
  'mdt': 'America/Denver',
  'mst': 'America/Denver',
  'pdt': 'America/Los_Angeles',
  'pst': 'America/Los_Angeles',
  'alaska daylight time': 'America/Anchorage',
  'alaska standard time': 'America/Anchorage',
  'akdt': 'America/Anchorage',
  'akst': 'America/Anchorage',
  'hawaii-aleutian standard time': 'Pacific/Honolulu',
  'hawaii standard time': 'Pacific/Honolulu',
  'hst': 'Pacific/Honolulu',
};
