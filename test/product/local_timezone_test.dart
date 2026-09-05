import 'package:aura/core/utils/local_timezone.dart';
import 'package:flutter_test/flutter_test.dart';

/// A ZONE IS A PLACE, OR IT IS NOTHING.
///
/// ── THE DEFECT ───────────────────────────────────────────────────────────
///
/// `resolveLocalTimezone()` used to map about two dozen United States display
/// names and abbreviations to IANA zones and return anything else unchanged.
/// The backend then coerced whatever it could not read to UTC.
///
/// Between them, a person in Karachi, Istanbul or Berlin could be shown a
/// meeting time that was simply wrong, while a person in New York was shown the
/// right one — because their zone happened to be in the table. Nothing reported
/// a fault. The only way to discover it was to miss a meeting.
///
/// The shape of that is worth naming: a fallback that is correct in the
/// author's own locale hides its own failure from the author. These tests are
/// written from outside it deliberately.
void main() {
  group('what counts as a zone identifier', () {
    const realZones = [
      'Asia/Karachi',
      'Europe/Istanbul',
      'Europe/Berlin',
      'Asia/Kolkata',
      'Africa/Lagos',
      'Africa/Johannesburg',
      'Australia/Sydney',
      'America/New_York',
      'America/Argentina/Buenos_Aires',
      'Pacific/Honolulu',
      'UTC',
    ];

    for (final zone in realZones) {
      test('$zone is a zone', () {
        expect(isIanaZoneId(zone), isTrue);
      });
    }
  });

  group('what does not count, and used to', () {
    // Every one of these was previously sent to the backend and turned into
    // UTC. Production held all of them on real registered devices.
    const notZones = [
      'PKT',
      'EDT',
      'PDT',
      'AEST',
      'SAST',
      'WAT',
      'EEST',
      'Pakistan Standard Time',
      'India Standard Time',
      'Eastern Daylight Time',
      '+03',
      '+08',
      'GMT+05:00',
      '',
      '   ',
    ];

    for (final value in notZones) {
      test('${value.isEmpty ? "(empty)" : value} is not a zone', () {
        expect(isIanaZoneId(value), isFalse);
      });
    }

    test('an abbreviation is rejected even when it names a real place', () {
      // "PKT" unambiguously means Pakistan to a person. It means nothing to
      // ICU, which is what has to compute the time — and the gap between those
      // two facts is the entire defect.
      expect(isIanaZoneId('PKT'), isFalse);
      expect(isIanaZoneId('Asia/Karachi'), isTrue);
    });
  });

  group('the resolver refuses to guess', () {
    test('nothing resolved means null, never a plausible default', () async {
      // In a unit test there is no browser ICU and no platform channel, so the
      // stub answers null. The assertion is that null survives: no layer turns
      // it into UTC on the way out.
      expect(await resolveLocalTimezone(), isNull);
      expect(cachedLocalTimezone, isNull);
    });

    test('priming does not populate the cache with a guess', () async {
      expect(await primeLocalTimezone(), isNull);
      expect(cachedLocalTimezone, isNull);
    });
  });
}
