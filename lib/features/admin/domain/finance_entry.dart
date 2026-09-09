/// THE FINANCE DOORWAY.
///
/// AURA_ADMIN != FINANCE_AUTHORITY. Founder-frozen.
///
/// Finance is DELIBERATELY NOT an [OperatorArea]. Every area gates on
/// [OperatorCapability], and an area with an empty `anyOf` is visible to any
/// operator with admin authority at all — which is precisely the forbidden
/// `if isAdmin then show Finance`. Modelling Finance as an area would also say
/// something untrue about the architecture: Finance is not an Aura
/// responsibility that operators administer, it is a separate system with its
/// own authority that some principals may enter.
///
/// So visibility comes from ONE fact, resolved by Finance itself: does this
/// principal hold an active FinanceGrant. Not the operator's role, not identity
/// completeness, not admissionBasis, not a verification badge, not a name or
/// email match.
///
/// FAIL CLOSED. Unknown, unreachable, errored and unauthenticated all render
/// the destination ABSENT. A door you cannot open reads as a fault in the
/// product rather than a fact about your authority — and a door shown to
/// someone with no authority also discloses that there is something behind it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/admin_providers.dart';

/// The Finance destination, named once.
///
/// Not a raw path literal at a call site: the C3 gate forbids that, because a
/// path typed at a call site is a path nothing can check. This estate has
/// already shipped a routed surface linked from nowhere.
const String kFinanceDestinationPath = '/admin/finance';

/// What Aura Admin is allowed to know about a principal's Finance standing.
///
/// EXACTLY ONE BIT, and deliberately no more. Not the role, not the
/// capabilities, not which books or how many. `eligible: false, books: 0` would
/// already disclose that books exist and that this caller has none of them.
@immutable
class FinanceEntry {
  const FinanceEntry({required this.eligible});

  /// Whether this principal currently has a usable Finance destination.
  final bool eligible;

  /// The only safe default. Used for unknown, error and unauthenticated alike,
  /// so that no failure mode can reveal a destination.
  static const FinanceEntry absent = FinanceEntry(eligible: false);
}

/// Does this principal have a Finance destination?
///
/// Resolved from Finance's own authority through a narrow server-side
/// introspection. Aura Admin never computes this itself, because Aura Admin is
/// not the authority for it.
///
/// Returns `absent` rather than throwing on ANY failure. An outage must not be
/// distinguishable from a revoked grant at this surface: both mean "no
/// destination", and telling them apart here would leak the existence of
/// financial authority to someone who does not hold it. Operators diagnose an
/// outage from the Finance service's own health, not from this tab.
final financeEntryProvider = FutureProvider<FinanceEntry>((ref) async {
  final repository = ref.watch(adminRepositoryProvider);
  try {
    return await repository.fetchFinanceEntry();
  } catch (_) {
    return FinanceEntry.absent;
  }
});

/// Whether to render the destination at all.
///
/// A synchronous read of the async fact, collapsing every non-eligible state to
/// false. `loading` is false rather than optimistically true: showing a
/// destination and then removing it is worse than showing it a moment later,
/// and here it would briefly disclose financial authority to someone who has
/// none.
///
/// WRITTEN OUT RATHER THAN `maybeWhen`, and that is not a style choice.
/// `maybeWhen` defaults to `skipLoadingOnRefresh: true`, so a REFRESH keeps
/// answering with the previous value while the new one is in flight. The
/// destination therefore stayed visible across a revocation until the refetch
/// landed — the exact opposite of the fail-closed rule this file states, and
/// invisible in the first-load case every casual test exercises. Caught by
/// `finance_doorway_boundary_test.dart`, which revokes a live grant.
///
/// Loading is loading, whether it is the first one or the fifth.
final financeDestinationVisibleProvider = Provider<bool>((ref) {
  final entry = ref.watch(financeEntryProvider);
  if (entry.isLoading || entry.hasError) return false;
  return entry.value?.eligible ?? false;
});

/// Presentation for the destination. Kept beside the authority so a future
/// change cannot move one without seeing the other.
abstract final class FinanceDestination {
  static const String label = 'Finance';
  static const IconData icon = Icons.account_balance_rounded;

  /// Deliberately says nothing about money. The destination names the system it
  /// leads to; the Finance application owns every financial presentation.
  static const String description =
      'The financial record of Aura Platform LLC. Opens the Finance workspace.';
}
