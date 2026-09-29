import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/product/temporal.dart';

/// Dates are written out, with their time (founder, 2026-09-29: "rather than
/// 2026-09-29 ... tuesday, september 29, 2026").
void main() {
  final at = DateTime(2026, 9, 29, 9, 4);

  test('full: weekday, month name, day, year and time', () {
    expect(AuraTemporal.full(at), 'Tuesday, September 29, 2026 · 9:04 AM');
  });

  test('fullShort: the same, abbreviated for a tight line', () {
    expect(AuraTemporal.fullShort(at), 'Tue, Sep 29, 2026 · 9:04 AM');
  });

  test('day: a heading over one day', () {
    expect(AuraTemporal.day(DateTime(2026, 10, 4)), 'Sunday, October 4, 2026');
  });

  test('midnight and noon read as 12', () {
    expect(AuraTemporal.full(DateTime(2026, 1, 1)), 'Thursday, January 1, 2026 · 12:00 AM');
    expect(AuraTemporal.fullShort(DateTime(2026, 1, 1, 12, 30)), 'Thu, Jan 1, 2026 · 12:30 PM');
  });
}
