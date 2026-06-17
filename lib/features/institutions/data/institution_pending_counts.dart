import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'institutions_repository.dart';

/// Aggregated "needs operator action" counts for one institution workspace.
///
/// Backs the dashboard Action Queue and the navigation attention badges so both
/// read the same numbers from a single fetch. Only meaningful for admins/owners;
/// for other roles the admin endpoints 403 and the counts degrade to zero.
class InstitutionPendingCounts {
  const InstitutionPendingCounts({
    this.joinRequests = 0,
    this.invites = 0,
  });

  /// Pending join requests awaiting approve/reject. The backend list endpoint
  /// already returns PENDING-only, so this is the list length.
  final int joinRequests;

  /// Outstanding invite codes — created, not yet used, not expired.
  final int invites;

  int get total => joinRequests + invites;
  bool get hasAny => total > 0;

  static const empty = InstitutionPendingCounts();
}

/// Fetches pending counts for [institutionId]. Each endpoint is guarded
/// independently so a failure on one (e.g. a 403 for a non-admin) never blanks
/// the other. autoDispose so it re-fetches when the operator returns to the
/// dashboard; invalidate it after approve/reject/invite to refresh badges.
final institutionPendingCountsProvider = FutureProvider.autoDispose
    .family<InstitutionPendingCounts, String>((ref, institutionId) async {
  final id = institutionId.trim();
  if (id.isEmpty) return InstitutionPendingCounts.empty;

  final repo = ref.read(institutionsRepositoryProvider);

  var joinRequests = 0;
  try {
    final requests = await repo.listJoinRequests(id);
    joinRequests = requests.length;
  } catch (_) {
    // Non-admins (or transient errors) simply contribute zero.
  }

  var invites = 0;
  try {
    final all = await repo.listInvites(id);
    invites = all.where((invite) {
      if (invite['usedAt'] != null) return false;
      final expiresAt = invite['expiresAt']?.toString().trim() ?? '';
      if (expiresAt.isNotEmpty) {
        final exp = DateTime.tryParse(expiresAt);
        if (exp != null && exp.isBefore(DateTime.now())) return false;
      }
      return true;
    }).length;
  } catch (_) {
    // ignore
  }

  return InstitutionPendingCounts(
    joinRequests: joinRequests,
    invites: invites,
  );
});
