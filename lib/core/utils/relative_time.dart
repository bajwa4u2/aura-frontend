/// Frontend-only time-formatting helpers used by feed cards, live room
/// cards, post detail strips, and the realtime room. They produce calm
/// English strings that match the institutional tone — no emoji, no
/// "ago" abbreviations beyond "min" / "h" / "d".
library;

/// Compact relative timestamp: `now`, `5m`, `2h`, `3d`, then ISO date
/// for older values. Used inline in author rows and detail stripes.
String formatRelative(DateTime when) {
  final now = DateTime.now();
  final diff = now.difference(when);
  if (diff.inSeconds < 60) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  final yyyy = when.year.toString().padLeft(4, '0');
  final mm = when.month.toString().padLeft(2, '0');
  final dd = when.day.toString().padLeft(2, '0');
  return '$yyyy-$mm-$dd';
}

/// Long-form past phrase: `just now`, `3 minutes ago`, `2 hours ago`,
/// `4 days ago`, then ISO date. Used in detail strips ("Published 2
/// hours ago") and in the live-room "Started X min ago" line.
String formatPastPhrase(DateTime when) {
  final now = DateTime.now();
  final diff = now.difference(when);
  if (diff.isNegative) return 'just now';
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) {
    final m = diff.inMinutes;
    return '$m ${m == 1 ? 'minute' : 'minutes'} ago';
  }
  if (diff.inHours < 24) {
    final h = diff.inHours;
    return '$h ${h == 1 ? 'hour' : 'hours'} ago';
  }
  if (diff.inDays < 7) {
    final d = diff.inDays;
    return '$d ${d == 1 ? 'day' : 'days'} ago';
  }
  final yyyy = when.year.toString().padLeft(4, '0');
  final mm = when.month.toString().padLeft(2, '0');
  final dd = when.day.toString().padLeft(2, '0');
  return '$yyyy-$mm-$dd';
}

/// Compact "Started X min ago" — the second clause of the live-room
/// presence line. Returns null when the source timestamp is null so
/// the caller can omit the segment.
String? formatStartedAgo(DateTime? when) {
  if (when == null) return null;
  final diff = DateTime.now().difference(when);
  if (diff.isNegative) return 'Just started';
  if (diff.inSeconds < 60) return 'Just started';
  if (diff.inMinutes < 60) return 'Started ${diff.inMinutes} min ago';
  if (diff.inHours < 24) {
    final h = diff.inHours;
    return 'Started $h ${h == 1 ? 'hour' : 'hours'} ago';
  }
  return 'Started ${diff.inDays}d ago';
}
