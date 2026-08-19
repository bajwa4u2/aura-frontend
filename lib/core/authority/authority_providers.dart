/// C1 authority wiring.
///
/// Binds the Acting Context Authority and Capability Projection to real
/// backend truth. These providers are the **only** place the client turns a
/// backend payload into authority state.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session_providers.dart';
import '../institutions/institution_access_provider.dart';
import 'acting_context.dart';
import 'capability_projection.dart';
import '../identity/person_identity_model.dart';

/// The person's standing in the institution currently in context, built from
/// the backend's effective capability set.
///
/// **Nothing is fabricated here.** A six-token capability injection used to
/// live downstream of this, compensating for a supposed institution-account
/// gap. Investigation proved the gap does not exist — `institution-bootstrap`
/// always creates an `InstitutionMember` row with `role: OWNER`, so a session
/// governing an institution always has a role. The compensation was
/// unreachable, and it has been removed.
///
/// `isInstitutionAccount` is retained only to describe *why* an act is
/// available when a session genuinely represents the institution itself; it
/// never adds a capability.
final institutionStandingProvider = Provider<InstitutionStanding?>((ref) {
  final identity = ref.watch(institutionIdentityProvider);
  if (identity == null || identity.id.isEmpty) return null;

  final isInstitutionAccount =
      identity.isAuthorizedSpeaker && (identity.role ?? '').isEmpty;

  return InstitutionStanding.fromBackend(
    institutionId: identity.id,
    institutionName: identity.name,
    institutionLogoUrl: identity.logoUrl,
    capabilities: identity.capabilities,
    roleWire: identity.role,
    isInstitutionAccount: isInstitutionAccount,
  );
});

/// Standing in a **named** institution — the one a surface is actually about.
///
/// C1: `/institutions/me` now returns effective capabilities for every
/// membership, so a surface no longer has to reason with whichever institution
/// the person happened to join first. Ask for the institution you are showing.
final standingForInstitutionProvider =
    Provider.family<InstitutionStanding?, String>((ref, institutionId) {
  final id = institutionId.trim();
  if (id.isEmpty) return null;

  for (final a in ref.watch(myAffiliationsProvider)) {
    if (a.id != id) continue;
    return InstitutionStanding.fromBackend(
      institutionId: a.id,
      institutionName: a.name,
      institutionLogoUrl: a.logoUrl,
      capabilities: a.capabilities,
      roleWire: a.role,
    );
  }

  // Fall back to the active-membership projection when the affiliation list
  // has not resolved, but never to a DIFFERENT institution's authority.
  final active = ref.watch(institutionStandingProvider);
  return active?.institutionId == id ? active : null;
});

/// Capability projection for a named institution.
final capabilityProjectionForProvider =
    Provider.family<CapabilityProjection, String>((ref, institutionId) {
  return CapabilityProjection(
    ref.watch(standingForInstitutionProvider(institutionId)),
  );
});

/// Capability projection for the institution currently in context.
///
/// Presentation only. Never a security boundary.
final capabilityProjectionProvider = Provider<CapabilityProjection>((ref) {
  return CapabilityProjection(ref.watch(institutionStandingProvider));
});

/// The Acting Context Authority for the signed-in person.
///
/// Null when unauthenticated. **Not route-aware by design** — a path is
/// navigation, never authority. Consumers ask [ActingContextAuthority.resolve]
/// for a specific act rather than reading an ambient "current actor".
final actingContextAuthorityProvider =
    Provider<ActingContextAuthority?>((ref) {
  if (ref.watch(authStatusProvider) != AuthStatus.authed) return null;

  // F053/F116 — the ACTING authority reads the person through the canonical
  // model. It previously insisted the person be nested under `user` and
  // unpacked the fields itself, so a payload shaped even slightly differently
  // produced no acting context at all — the F057 failure mode, in the one
  // place that decides who an act is attributed to.
  final me = AuraPersonIdentity.fromJson(
    ref.watch(authMeDataProvider).valueOrNull,
  );
  if (me.userId.isEmpty) return null;

  return ActingContextAuthority(
    personId: me.userId,
    // Acting attribution names a person; `label` is the shared honest order.
    personDisplayName: me.label,
    personAvatarUrl: me.avatarUrl,
    institution: ref.watch(institutionStandingProvider),
  );
});

/// Resolve who a consequential act would be performed as.
///
/// The ordinary answer is "you, with no ceremony" — [ActingResolution
/// .requiresExplicitChoice] is false unless the person genuinely has more than
/// one legitimate identity for this act.
final actingResolutionProvider =
    Provider.family<ActingResolution?, ConsequentialAct>((ref, act) {
  return ref.watch(actingContextAuthorityProvider)?.resolve(act);
});

/// Resolve for a surface that legitimately offers the personal alternative
/// too (a composer that can publish either way). Single-purpose surfaces use
/// [actingResolutionProvider] and get attribution without a manufactured
/// choice.
final actingResolutionWithPersonalAlternativeProvider =
    Provider.family<ActingResolution?, ConsequentialAct>((ref, act) {
  return ref
      .watch(actingContextAuthorityProvider)
      ?.resolve(act, offerPersonalAlternative: true);
});
