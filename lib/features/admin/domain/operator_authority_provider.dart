/// The operator's authority, derived from the server and nowhere else.
///
/// This reads the payload the client was already fetching and discarding.
/// `appAdminAccessProvider` keeps its probe discipline — it still refuses to
/// fire `/admin/me` for a signed-in non-admin, which is what stopped every
/// route change producing an `admin.access.denied` audit entry. Capability
/// truth rides on the response that probe already makes; it adds no requests.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/admin_access_provider.dart';
import 'operator_area.dart';
import 'operator_capability.dart';

/// Authoritative capability truth. `AsyncValue`, because "we do not know yet"
/// is a real state an operator console must render honestly rather than
/// guessing at and correcting a frame later.
final operatorAuthorityProvider = Provider<AsyncValue<OperatorAuthority>>((ref) {
  final access = ref.watch(appAdminAccessProvider);
  return access.whenData((value) {
    // Deliberately NOT gated on a role boolean. `me` is populated only by a
    // successful `/v1/admin/me`, and what an operator holds is then decided by
    // the permissions in that payload — never by the fact that a role exists.
    // An operator whose grant has been narrowed to nothing must come back as
    // holding nothing, not as an admin with an empty console.
    final me = value.me;
    if (me == null) return const OperatorAuthority.none();
    return OperatorAuthority.fromMe(me);
  });
});

/// Areas this operator may enter, in frozen order. Empty while unknown —
/// never optimistically full, because showing areas and then removing them is
/// worse than showing them a moment later.
final visibleOperatorAreasProvider = Provider<List<OperatorArea>>((ref) {
  return ref.watch(operatorAuthorityProvider).maybeWhen(
        data: OperatorArea.visibleFor,
        orElse: () => const <OperatorArea>[],
      );
});

/// Whether a specific capability is held. Used by surfaces and actions alike,
/// so a visible control and the action behind it can never disagree.
final hasOperatorCapabilityProvider =
    Provider.family<bool, OperatorCapability>((ref, capability) {
  return ref.watch(operatorAuthorityProvider).maybeWhen(
        data: (a) => a.can(capability),
        orElse: () => false,
      );
});
