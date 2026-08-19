// RC8 — BOOKING, RESCHEDULE AND MEETING-ENTRY DESTINATIONS THAT SURVIVE.
//
// Four booking routes carried their subject in `state.extra` — the in-memory
// object the previous screen happened to hold. A refresh, a bookmark, a
// shared link or an email click supplies none, so `/meet/:slug/book` fell
// through to a booking page for NOBODY (with the slug right there in the
// path) and `/meet/reschedule/:token` fell through to a CANCEL screen with
// the token discarded — meaning that route, which is only ever reached from a
// confirmation email, never worked at all.
//
// The route now carries IDENTITY and everything else is read back from the
// authority that owns it. What a URL must never carry is permission.
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/meetings/domain/availability_profile.dart';
import 'package:aura/features/meetings/presentation/booking_route_entry.dart';

void main() {
  group('RC8 — the chosen slot is a value, and travels as one', () {
    test('a start time and duration round-trip through the address bar', () {
      final slot = TimeSlot(
        startAt: DateTime.utc(2026, 9, 1, 10),
        endAt: DateTime.utc(2026, 9, 1, 10, 30),
      );
      final query = bookingSelectionQuery(slot: slot, duration: 30);
      final parsed = slotFromQuery(Uri.parse('/meet/x/book$query').queryParameters);

      expect(parsed, isNotNull);
      expect(parsed!.startAt.toUtc(), slot.startAt);
      expect(parsed.endAt.toUtc(), slot.endAt);
    });

    test('the duration decides the end — a slot is a selection, not a record', () {
      final parsed = slotFromQuery({
        'start': '2026-09-01T10:00:00.000Z',
        'duration': '45',
      });
      expect(parsed!.endAt.difference(parsed.startAt), const Duration(minutes: 45));
    });

    test('no selection means the person picks again, not a slot nobody chose', () {
      for (final query in <Map<String, String>>[
        {},
        {'start': ''},
        {'start': 'not-a-time', 'duration': '30'},
        {'start': '2026-09-01T10:00:00.000Z'},
        {'start': '2026-09-01T10:00:00.000Z', 'duration': '0'},
        {'start': '2026-09-01T10:00:00.000Z', 'duration': '-30'},
        {'start': '2026-09-01T10:00:00.000Z', 'duration': 'abc'},
      ]) {
        expect(slotFromQuery(query), isNull, reason: '$query');
      }
    });

    test('the selection carries NO credential and NO authority', () {
      final slot = TimeSlot(
        startAt: DateTime.utc(2026, 9, 1, 10),
        endAt: DateTime.utc(2026, 9, 1, 10, 30),
      );
      final query = bookingSelectionQuery(slot: slot, duration: 30);
      final keys = Uri.parse('/meet/x/book$query').queryParameters.keys.toList()
        ..sort();

      // Only what the person chose. Availability, notice, advance and
      // capacity stay where they are decided: on the server, every time.
      expect(keys, ['duration', 'start']);
      for (final forbidden in ['token', 'auth', 'session', 'host', 'profileId']) {
        expect(query, isNot(contains(forbidden)), reason: forbidden);
      }
    });

    test('the encoded start survives a URL round trip intact', () {
      final slot = TimeSlot(
        startAt: DateTime.utc(2026, 12, 31, 23, 45),
        endAt: DateTime.utc(2027, 1, 1, 0, 15),
      );
      final uri = Uri.parse(
          '/i/acme/meet/intro/book${bookingSelectionQuery(slot: slot, duration: 30)}');
      expect(slotFromQuery(uri.queryParameters)!.startAt.toUtc(), slot.startAt);
    });
  });
}
