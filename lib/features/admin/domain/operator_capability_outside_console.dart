/// CAPABILITY TRUTH OUTSIDE THE OPERATOR CONSOLE.
///
/// ── THE PROBLEM THIS EXISTS TO SOLVE ────────────────────────────────────────
///
/// An operator control on an ordinary product surface, such as Edit or
/// Unpublish on an announcement a reader is looking at, needs to ask exactly
/// one question: does this person hold the capability the endpoint behind the
/// button will demand? For announcements the backend is explicit. Every
/// handler on `AdminAnnouncementsController` sits under
/// `@RequireAdminPermission(AdminPermission.ANNOUNCEMENTS_WRITE)`, and
/// `AdminPermissionGuard` refuses outright when no permission is declared.
/// The domain also separates `ANNOUNCEMENTS_READ` from `ANNOUNCEMENTS_WRITE`,
/// in a schema whose own comments record that permission boundaries are not
/// collapsed for convenience.
///
/// The client could not ask that question outside `/admin/*`, and the
/// workaround drifted twice:
///
///   * `appAdminAccessProvider.valueOrNull` — null while the probe is in
///     flight and null on error, so the controls were simply never built on a
///     deep-linked route. That is the ordinary case, which is why the founder
///     reported them missing: for them they always were.
///   * `appAdminCachedDisplayProvider` — a cache, true on one visit and false
///     on the next, so the controls flickered in and out of existence.
///   * `canEnterOperatorConsoleProvider` — durable and always populated, and
///     WRONG. It answers "does this person hold AT LEAST ONE operator
///     capability". An operator holding only SUPPORT_READ would have been
///     shown Edit, Unpublish and Remove on a published announcement and would
///     have received a 403 and an audit denial for using them.
///
/// The third is the one worth naming as a rule: AREA ACCESS IS NOT ACTION
/// PERMISSION. Being admitted to the operator console is a different fact from
/// being allowed to perform a specific act, and the domain defines both. A
/// null-or-loading problem is never a reason to answer a narrower question
/// with a broader one.
///
/// ── WHY THIS IS NOT SIMPLY `hasOperatorCapabilityProvider` ──────────────────
///
/// It is, once the authority has loaded. The obstacle is that
/// `appAdminAccessProvider` refuses to fire `GET /v1/admin/me` unless the
/// router has entered an `/admin/*` route, and that refusal is deliberate:
/// before it existed, every signed-in non-admin produced an
/// `admin.access.denied` audit row on every route change. Observation noise,
/// not security signal.
///
/// `GET /v1/admin/entry` is the cheap question that is safe to ask of anyone:
/// one indexed lookup, no permissions in the answer, no audit denial written.
/// When it says this person IS an operator, probing `/admin/me` produces no
/// denial either, because they are entitled to it. So the probe gate can be
/// lifted for exactly the people for whom it was never protecting anything,
/// and capability truth becomes available on product surfaces without
/// reintroducing the noise.
///
/// Order of facts, and it matters:
///
///   1. not signed in, or not an operator  → false, and NO probe
///   2. an operator                        → allow the probe, then answer
///      from the capability the server actually returned
///
/// Absent an answer this says false. A control drawn in error sends somebody
/// to a refusal; a control drawn a moment late costs one frame.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/admin_access_provider.dart';
import 'operator_authority_provider.dart';
import 'operator_capability.dart';
import 'operator_entry.dart';

/// Lifts the `/admin/me` probe gate once, for a confirmed operator only.
///
/// Latching a `StateProvider` from inside a build is forbidden, so this rides
/// a microtask. The gate is itself a latch, so setting it more than once is
/// harmless and setting it late only delays the answer by a frame.
final _operatorProbeUnlock = Provider<void>((ref) {
  if (!ref.watch(canEnterOperatorConsoleProvider)) return;

  var disposed = false;
  ref.onDispose(() => disposed = true);

  Future.microtask(() {
    if (disposed) return;
    final gate = ref.read(appAdminProbeAllowedProvider.notifier);
    if (!gate.state) gate.state = true;
  });
});

/// Whether this person holds [capability], askable from any surface.
///
/// Use this for a control on a product screen. Inside the operator console,
/// where the probe has already fired, `hasOperatorCapabilityProvider` is the
/// same answer without the unlock.
final operatorCapabilityProvider = Provider.family<bool, OperatorCapability>((
  ref,
  capability,
) {
  // Costs one `/admin/entry` for a signed-in person and stops there for
  // everyone who is not an operator.
  if (!ref.watch(canEnterOperatorConsoleProvider)) return false;

  ref.watch(_operatorProbeUnlock);

  // The server decides. An operator whose grant has been narrowed to nothing
  // comes back holding nothing, which is the point of asking.
  return ref.watch(hasOperatorCapabilityProvider(capability));
});
