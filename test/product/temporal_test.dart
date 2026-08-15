import 'package:aura/core/product/temporal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Fixed reference instant so every threshold is deterministic.
  final ref = DateTime(2026, 8, 15, 14, 30);

  setUp(() => AuraTemporal.debugClock = () => ref);
  tearDown(() => AuraTemporal.debugClock = null);

  ProductTime ago(Duration d, [TimeEvent e = TimeEvent.occurred]) =>
      ProductTime(ref.subtract(d), e);

  group('Human Temporal — humanized thresholds', () {
    test('compact style', () {
      expect(
        AuraTemporal.humanize(ago(const Duration(seconds: 5)),
            style: TemporalStyle.compact),
        'now',
      );
      expect(
        AuraTemporal.humanize(ago(const Duration(minutes: 5)),
            style: TemporalStyle.compact),
        '5m',
      );
      expect(
        AuraTemporal.humanize(ago(const Duration(hours: 2)),
            style: TemporalStyle.compact),
        '2h',
      );
      expect(
        AuraTemporal.humanize(ago(const Duration(days: 3)),
            style: TemporalStyle.compact),
        '3d',
      );
    });

    test('phrase style pluralises correctly', () {
      expect(AuraTemporal.humanize(ago(const Duration(minutes: 1))),
          '1 minute ago');
      expect(AuraTemporal.humanize(ago(const Duration(minutes: 3))),
          '3 minutes ago');
      expect(AuraTemporal.humanize(ago(const Duration(hours: 1))), '1 hour ago');
      expect(AuraTemporal.humanize(ago(const Duration(days: 1))), '1 day ago');
    });

    test('older values become a human date, never a machine date', () {
      final label = AuraTemporal.humanize(ago(const Duration(days: 30)));
      expect(label, 'Jul 16');
      expect(label, isNot(matches(RegExp(r'^\d{4}-\d{2}-\d{2}$'))));
    });

    test('a date from another year carries the year', () {
      expect(AuraTemporal.humanize(ago(const Duration(days: 400))), 'Jul 11, 2025');
    });

    test('semantic style leads with the event verb', () {
      expect(
        AuraTemporal.humanize(
          ago(const Duration(hours: 2), TimeEvent.published),
          style: TemporalStyle.semantic,
        ),
        'Published 2 hours ago',
      );
      expect(
        AuraTemporal.humanize(
          ago(const Duration(minutes: 4), TimeEvent.received),
          style: TemporalStyle.semantic,
        ),
        'Received 4 minutes ago',
      );
    });
  });

  group('Human Temporal — future instants', () {
    test('a scheduled event never reads as if it already happened', () {
      final soon = ProductTime(
          ref.add(const Duration(minutes: 45)), TimeEvent.scheduled);
      expect(AuraTemporal.humanize(soon), 'in 45 minutes');
      expect(AuraTemporal.humanize(soon, style: TemporalStyle.compact),
          'in 45m');
    });

    test('a future event hours away reads as upcoming', () {
      final later =
          ProductTime(ref.add(const Duration(hours: 5)), TimeEvent.scheduled);
      expect(AuraTemporal.humanize(later), 'in 5 hours');
    });

    test('small clock skew on a past event still reads as just now', () {
      final skewed =
          ProductTime(ref.add(const Duration(seconds: 3)), TimeEvent.posted);
      expect(AuraTemporal.humanize(skewed), 'just now');
    });
  });

  group('Human Temporal — calendar and exact time', () {
    test('calendar uses local calendar days, not elapsed hours', () {
      // 23:50 yesterday is only ~14h before 14:30 today, but it is Yesterday.
      final lateYesterday =
          ProductTime(DateTime(2026, 8, 14, 23, 50), TimeEvent.sent);
      expect(AuraTemporal.calendar(lateYesterday), 'Yesterday, 11:50 PM');

      final earlierToday =
          ProductTime(DateTime(2026, 8, 15, 9, 5), TimeEvent.sent);
      expect(AuraTemporal.calendar(earlierToday), 'Today, 9:05 AM');

      final tomorrow =
          ProductTime(DateTime(2026, 8, 16, 8, 0), TimeEvent.scheduled);
      expect(AuraTemporal.calendar(tomorrow), 'Tomorrow, 8:00 AM');
    });

    test('midnight and noon read correctly', () {
      expect(
        AuraTemporal.calendar(
            ProductTime(DateTime(2026, 8, 15, 0, 0), TimeEvent.sent)),
        'Today, 12:00 AM',
      );
      expect(
        AuraTemporal.calendar(
            ProductTime(DateTime(2026, 8, 15, 12, 0), TimeEvent.sent)),
        'Today, 12:00 PM',
      );
    });

    test('humanization never removes precision', () {
      final t = ago(const Duration(minutes: 5), TimeEvent.posted);
      expect(AuraTemporal.humanize(t), '5 minutes ago');
      expect(t.exact, 'Aug 15, 2:25 PM');
    });
  });

  group('Human Temporal — aging', () {
    test('fresh labels refresh often, settled labels stop refreshing', () {
      expect(AuraTemporal.refreshInterval(ago(const Duration(seconds: 10))),
          const Duration(seconds: 15));
      expect(AuraTemporal.refreshInterval(ago(const Duration(minutes: 10))),
          const Duration(minutes: 1));
      expect(AuraTemporal.refreshInterval(ago(const Duration(days: 2))),
          const Duration(minutes: 30));
      // Dates do not age.
      expect(AuraTemporal.refreshInterval(ago(const Duration(days: 30))), isNull);
    });
  });

  group('Human Temporal — sorting semantics', () {
    test('newest first orders by instant', () {
      final a = ago(const Duration(minutes: 1), TimeEvent.posted);
      final b = ago(const Duration(hours: 3), TimeEvent.posted);
      expect(AuraTemporal.newestFirst(a, b), lessThan(0));
      expect(AuraTemporal.oldestFirst(a, b), greaterThan(0));
    });

    test('sorting across mixed event semantics is rejected', () {
      final posted = ago(const Duration(minutes: 1), TimeEvent.posted);
      final updated = ago(const Duration(hours: 3), TimeEvent.updated);
      expect(
        () => AuraTemporal.newestFirst(posted, updated),
        throwsA(isA<AssertionError>()),
      );
    });

    test('a declared ordering sorts without mutating the source', () {
      final items = [
        ago(const Duration(hours: 3), TimeEvent.posted),
        ago(const Duration(minutes: 1), TimeEvent.posted),
        ago(const Duration(days: 2), TimeEvent.posted),
      ];
      final sorted = AuraTemporal.sortNewestFirst<ProductTime>(
        items,
        (t) => t,
        orderedBy: 'most recent publication',
      );
      expect(sorted.first.instant, items[1].instant);
      expect(sorted.last.instant, items[2].instant);
      expect(items.first.instant, ago(const Duration(hours: 3)).instant);
    });

    test('an ordering must declare what it means', () {
      expect(
        () => AuraTemporal.sortNewestFirst<ProductTime>(const [], (t) => t,
            orderedBy: '  '),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('Human Temporal — event vocabulary', () {
    test('every event has a distinct human verb', () {
      final verbs = TimeEvent.values.map((e) => e.verb).toList();
      expect(verbs.every((v) => v.trim().isNotEmpty), isTrue);
      expect(verbs.toSet().length, verbs.length);
    });

    test('only scheduled is inherently forward-looking', () {
      for (final e in TimeEvent.values) {
        expect(e.isFuture, e == TimeEvent.scheduled, reason: '$e');
      }
    });
  });
}
