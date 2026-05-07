/// Accountability tag set by an institutional voice on a reply.
///
/// COMMITMENT: institution will act on the issue.
/// UPDATE:     in-flight progress on a prior commitment.
/// RESOLVED:   the issue is closed (positively or formally).
///
/// Wire-side comes from the backend `AccountabilityTag` enum. Null on
/// any reply that hasn't been tagged.
library;

enum InsAccountabilityTag {
  commitment,
  update,
  resolved,
}

extension InsAccountabilityTagX on InsAccountabilityTag {
  String get wire {
    switch (this) {
      case InsAccountabilityTag.commitment:
        return 'COMMITMENT';
      case InsAccountabilityTag.update:
        return 'UPDATE';
      case InsAccountabilityTag.resolved:
        return 'RESOLVED';
    }
  }

  String get label {
    switch (this) {
      case InsAccountabilityTag.commitment:
        return 'Commitment';
      case InsAccountabilityTag.update:
        return 'Update';
      case InsAccountabilityTag.resolved:
        return 'Resolved';
    }
  }

  static InsAccountabilityTag? fromWire(dynamic raw) {
    if (raw == null) return null;
    final s = raw.toString().trim().toUpperCase();
    switch (s) {
      case 'COMMITMENT':
        return InsAccountabilityTag.commitment;
      case 'UPDATE':
        return InsAccountabilityTag.update;
      case 'RESOLVED':
        return InsAccountabilityTag.resolved;
      default:
        return null;
    }
  }
}
