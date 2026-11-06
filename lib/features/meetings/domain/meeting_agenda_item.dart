/// One point on a meeting's agenda (6 Nov 2026): ordered, can be ticked off
/// as covered, and after the meeting can become a recorded outcome.
class MeetingAgendaItem {
  const MeetingAgendaItem({
    required this.id,
    required this.text,
    required this.position,
    required this.covered,
    this.outcomeId,
  });

  final String id;
  final String text;
  final int position;
  final bool covered;

  /// Set once the item became an outcome.
  final String? outcomeId;

  factory MeetingAgendaItem.fromJson(Map<String, dynamic> j) =>
      MeetingAgendaItem(
        id: (j['id'] ?? '').toString(),
        text: (j['text'] ?? '').toString(),
        position: (j['position'] as num?)?.toInt() ?? 0,
        covered: j['covered'] == true,
        outcomeId: (j['outcomeId'] as String?)?.trim().isEmpty ?? true
            ? null
            : j['outcomeId'] as String,
      );
}

/// A booking page's last-90-days numbers
/// (`GET /institution/:id/availability/:profileId/stats`).
class BookingPageStats {
  const BookingPageStats({
    required this.days,
    required this.booked,
    required this.upcoming,
    required this.held,
    required this.noShow,
    required this.cancelledByBooker,
    required this.cancelledByHost,
  });

  final int days;
  final int booked;
  final int upcoming;
  final int held;
  final int noShow;
  final int cancelledByBooker;
  final int cancelledByHost;

  int get cancelled => cancelledByBooker + cancelledByHost;

  factory BookingPageStats.fromJson(Map<String, dynamic> j) {
    int n(String k) => (j[k] as num?)?.toInt() ?? 0;
    return BookingPageStats(
      days: n('days') == 0 ? 90 : n('days'),
      booked: n('booked'),
      upcoming: n('upcoming'),
      held: n('held'),
      noShow: n('noShow'),
      cancelledByBooker: n('cancelledByBooker'),
      cancelledByHost: n('cancelledByHost'),
    );
  }

  /// "Last 90 days: 12 booked · 3 upcoming · 6 held · 1 no-show · 2 cancelled"
  String get line {
    String plural(int v, String one, String many) => '$v ${v == 1 ? one : many}';
    return 'Last $days days: $booked booked · $upcoming upcoming · '
        '$held held · ${plural(noShow, 'no-show', 'no-shows')} · '
        '$cancelled cancelled';
  }
}
