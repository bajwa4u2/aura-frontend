/// Monetization label kinds rendered in feed/thread.
///
/// Phase 1 — UI only. The frontend infers `OFFICIAL` from the existing
/// institution-post heuristic (top-level institution post with a title);
/// `PRIORITY` is wired but never derived yet — it will be set by the
/// backend in a later phase.
library;

enum MonetizationKind {
  /// Free, verified institutional voice. No payment, only verification.
  officialResponse,

  /// Paid: pins a reply to the top of a thread for a window. Visible
  /// in-context so readers always know it was paid.
  priorityResponse,

  /// Paid: extended-capacity hosted live session. Visible in-context.
  hostedSession,

  /// Paid: distributes a public post into the global feed for boosted
  /// reach. Visible in-context.
  paidDistribution,
}

extension MonetizationKindX on MonetizationKind {
  /// True when the action is paid. Drives the "PAID" suffix on the
  /// label so the user can distinguish authority-only labels from
  /// monetary ones.
  bool get isPaid {
    switch (this) {
      case MonetizationKind.officialResponse:
        return false;
      case MonetizationKind.priorityResponse:
      case MonetizationKind.hostedSession:
      case MonetizationKind.paidDistribution:
        return true;
    }
  }

  String get label {
    switch (this) {
      case MonetizationKind.officialResponse:
        return 'Official response';
      case MonetizationKind.priorityResponse:
        return 'Priority response';
      case MonetizationKind.hostedSession:
        return 'Hosted session';
      case MonetizationKind.paidDistribution:
        return 'Paid distribution';
    }
  }

  /// Short label used in the in-context stripe — uppercase, ≤ 22 chars.
  String get stripeLabel {
    switch (this) {
      case MonetizationKind.officialResponse:
        return 'OFFICIAL RESPONSE';
      case MonetizationKind.priorityResponse:
        return 'PRIORITY · PAID';
      case MonetizationKind.hostedSession:
        return 'HOSTED SESSION · PAID';
      case MonetizationKind.paidDistribution:
        return 'PAID DISTRIBUTION';
    }
  }
}
