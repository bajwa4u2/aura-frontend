
import '../institutions/institution_access_provider.dart';

/// Discriminator for actor identity.
enum ActorType { user, institution }

/// Phase-2 active actor used by every interaction button (follow, message,
/// like, reply). Determined by the active shell:
///
///   * `/institution/...` paths      → institution actor (institutionId from
///                                      [institutionIdentityProvider])
///   * any other authenticated path  → user actor
///   * unauthenticated               → null (caller renders Sign in / Join)
class ActorContext {
  const ActorContext({
    required this.type,
    this.userId,
    this.institutionId,
    this.displayName,
    this.avatarUrl,
    this.canSpeakAsInstitution = false,
  });

  final ActorType type;
  final String? userId;
  final String? institutionId;
  final String? displayName;
  final String? avatarUrl;

  /// True when [type] == institution AND the human has speaker rights for
  /// that institution. Buttons that mutate (follow, send DM) require this
  /// to be true on the institution side; reads (state probes) do not.
  final bool canSpeakAsInstitution;

  bool get isInstitution => type == ActorType.institution;
  bool get isUser => type == ActorType.user;

  /// Stable identifier of whatever this actor is. For routing + provider
  /// keys.
  String get id =>
      isInstitution ? (institutionId ?? '') : (userId ?? '');
}

/// C3 RETIREMENT (2026-08-16) — the former `resolveActorContext` and its
/// `_pathIsInstitutionShell` inference are DELETED. They manufactured an
/// institutional acting context from the URL prefix, violating the frozen
/// C1 rule that acting context is per act and never route-derived.
/// Consumers now receive context EXPLICITLY:
///   • institution_detail Follow → explicit Follow-as selection;
///   • institution inbox/thread → `institutionContextId` stated by the
///     destination's own route builder (viewing context, not authority).
/// C7 HANDOFF: the correspondence sender-choice EXPERIENCE (explicit
/// acting choice at message initiation, per `ConsequentialAct.
/// correspondAsInstitution`) remains C7-owned; until C7 closes, the
/// institution inbox preserves shipped viewing behavior through the
/// explicit parameter above. No route-derived sender may survive C7
/// closure.
