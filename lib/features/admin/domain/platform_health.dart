/// PLATFORM HEALTH, NORMALIZED ONCE.
///
/// WHAT WENT WRONG BEFORE
/// ----------------------
/// The console reasoned directly from the payload. It looked for a `services`
/// map that the server has never sent, found the sibling objects `api` and
/// `db` through a fallback, called `.toString()` on them, and rendered
///
///   API   {STATUS: OK, MESSAGE: API PROCESS IS RUNNING}
///
/// as the status pill — while announcing "5 of 5 degraded" over a platform
/// whose own checks all said OK. Two checks it could not find at all
/// (`emailProvider`, `pushProvider`) became `unknown`, and `unknown` was
/// counted as degraded.
///
/// THE RULE THAT REPLACES IT
/// -------------------------
///
///   source payload  →  normalized health  →  operator projection
///
/// The operator surface never sees a payload. It sees [PlatformHealth], whose
/// conditions are only ever set from a word a source actually said. A check
/// the server did not send is [OperatorCondition.unknown], and unknown is
/// counted, displayed and sorted as unknown — never as harm.
library;

import 'operator_signal.dart';

/// One thing Aura depends on, as the platform reports it.
class HealthCheck {
  const HealthCheck({
    required this.key,
    required this.label,
    required this.condition,
    this.message,
    this.checkedAt,
  });

  /// The server's own key: `api`, `db`, `email`, `push`, `realtime`.
  final String key;

  /// What an operator calls it.
  final String label;

  final OperatorCondition condition;

  /// The source's own sentence — "Database connectivity verified", "No push
  /// provider credentials configured". Shown as prose, never as a status word,
  /// because it is an explanation and not a state.
  final String? message;

  final DateTime? checkedAt;

  bool get isKnown => condition != OperatorCondition.unknown;
}

/// Every check, and what the set of them means.
class PlatformHealth {
  const PlatformHealth({required this.checks, this.snapshotAt});

  final List<HealthCheck> checks;
  final DateTime? snapshotAt;

  /// The five checks the server publishes, in the order an operator reads
  /// them: the thing that serves requests, then what it depends on.
  static const _known = <String, String>{
    'api': 'API',
    'db': 'Database',
    'realtime': 'Realtime',
    'email': 'Email delivery',
    'push': 'Push delivery',
  };

  /// Checks that made a positive claim of harm. NOT "everything not healthy".
  Iterable<HealthCheck> get adverse =>
      checks.where((c) => c.condition.isAdverse);

  /// Checks nothing has spoken about. Reported SEPARATELY from adverse ones,
  /// because "we cannot see push" and "push is down" are different problems
  /// with different owners.
  Iterable<HealthCheck> get unknown =>
      checks.where((c) => c.condition == OperatorCondition.unknown);

  Iterable<HealthCheck> get healthy =>
      checks.where((c) => c.condition == OperatorCondition.healthy);

  /// The single condition of the platform, derived worst-first.
  ///
  /// Unknown checks do NOT make the platform degraded. They make it partially
  /// observed, which [summary] says out loud.
  OperatorCondition get condition {
    if (checks.isEmpty) return OperatorCondition.unknown;
    var worst = OperatorCondition.healthy;
    for (final check in checks) {
      if (check.condition.severity > worst.severity &&
          check.condition != OperatorCondition.unknown) {
        worst = check.condition;
      }
    }
    if (worst == OperatorCondition.healthy && unknown.isNotEmpty) {
      return healthy.isEmpty
          ? OperatorCondition.unknown
          : OperatorCondition.attention;
    }
    return worst;
  }

  /// One sentence an operator can read without counting anything.
  String get summary {
    final bad = adverse.length;
    final unseen = unknown.length;

    if (bad > 0 && unseen > 0) {
      return '$bad ${_plural(bad, 'service')} degraded, '
          '$unseen not reporting';
    }
    if (bad > 0) {
      final worst = adverse
          .map((c) => c.condition)
          .reduce((a, b) => a.severity >= b.severity ? a : b);
      return worst == OperatorCondition.failed
          ? '$bad ${_plural(bad, 'service')} failing'
          : '$bad ${_plural(bad, 'service')} degraded';
    }
    if (unseen == checks.length) {
      return 'Nothing is reporting';
    }
    if (unseen > 0) {
      // The precise thing the old surface could not say.
      return 'Everything reporting is healthy · $unseen not reporting';
    }
    return 'All services healthy';
  }

  static String _plural(int n, String word) => n == 1 ? word : '${word}s';

  /// Worst first, then unknown, then healthy — so the eye lands on what
  /// matters without reading every row.
  List<HealthCheck> get ordered {
    final sorted = [...checks];
    sorted.sort((a, b) {
      final bySeverity = b.condition.severity.compareTo(a.condition.severity);
      if (bySeverity != 0) return bySeverity;
      return a.label.compareTo(b.label);
    });
    return sorted;
  }

  /// Reads the payload the server actually sends.
  ///
  /// The checks are SIBLING KEYS — `api`, `db`, `emailProvider`,
  /// `pushProvider`, `realtimeGateway` — each an object carrying its own
  /// `status` word from the `HealthStatus` enum. There is no `services` map;
  /// the previous model invented one.
  ///
  /// `prisma` is deliberately ignored: the server sends it as a duplicate of
  /// `db`, and showing the same check twice under two names is the console
  /// leaking a backend detail.
  factory PlatformHealth.fromJson(Map<String, dynamic> json) {
    final body = json['data'] is Map
        ? Map<String, dynamic>.from(json['data'] as Map)
        : json;

    const sources = <String, String>{
      'api': 'api',
      'db': 'db',
      'realtimeGateway': 'realtime',
      'emailProvider': 'email',
      'pushProvider': 'push',
    };

    final checks = <HealthCheck>[];
    for (final entry in sources.entries) {
      final raw = body[entry.key];
      final key = entry.value;
      final label = _known[key] ?? key;

      if (raw is! Map) {
        // The server did not send this check. Unknown — not degraded, and not
        // silently dropped either: an operator must see that a dependency is
        // unobserved.
        checks.add(HealthCheck(
          key: key,
          label: label,
          condition: OperatorCondition.unknown,
        ));
        continue;
      }

      final map = Map<String, dynamic>.from(raw);
      checks.add(HealthCheck(
        key: key,
        label: label,
        condition: conditionFromStatus(map['status']),
        message: _text(map['message']),
        checkedAt: _date(map['checkedAt']),
      ));
    }

    return PlatformHealth(
      checks: checks,
      snapshotAt: _date(body['snapshotAt']),
    );
  }

  /// Maps the server's `HealthStatus` enum onto an operator condition.
  ///
  /// Anything unrecognised is UNKNOWN. A status word this build has never seen
  /// is not evidence of harm — it is evidence that the server is ahead of the
  /// client, and inventing a verdict from it would be the original defect in a
  /// new place.
  static OperatorCondition conditionFromStatus(dynamic status) {
    final word = (status ?? '').toString().trim().toUpperCase();
    return switch (word) {
      'OK' || 'HEALTHY' || 'UP' => OperatorCondition.healthy,
      'DEGRADED' => OperatorCondition.degraded,
      'DOWN' || 'FAILED' || 'ERROR' => OperatorCondition.failed,
      _ => OperatorCondition.unknown,
    };
  }

  static String? _text(dynamic value) {
    final s = (value ?? '').toString().trim();
    return s.isEmpty ? null : s;
  }

  static DateTime? _date(dynamic value) {
    final s = (value ?? '').toString().trim();
    return s.isEmpty ? null : DateTime.tryParse(s);
  }
}
