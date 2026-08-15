/// ACTING CONTEXT AUTHORITY — C1.
///
/// > **WHO AM I ACTING AS?**
///
/// ── WHY THIS EXISTS ──────────────────────────────────────────────────────
/// The client already had an acting-identity model, and it was wrong in three
/// measurable ways:
///
///  1. **Acting identity was derived from the URL.** `ActorContext` decided you
///     were speaking *as an institution* because the path began with
///     `/institution/`. That is the exact defect frozen after the Meetings
///     router regression: **institutionId-in-path ≠ institution-actor
///     identity.** A path is navigation, not authority.
///  2. **A path-blind twin disagreed with it.** `activeActorContextProvider`
///     returned the *institution* actor whenever any institution identity had
///     loaded, regardless of context — so presence heartbeats were being sent
///     as the institution for every person who merely belongs to one.
///  3. **`canSpeakAsInstitution` was `canPublishPosts || isAdmin`** — a role
///     OR-ed into a capability question.
///
/// ── THE MODEL ────────────────────────────────────────────────────────────
/// Acting identity is **not global state**. There is no ambient "current
/// actor" to read, because a person is not continuously in a mode.
///
///     ordinary action        → the person, with no ceremony
///     consequential action   → resolved explicitly, for that act
///
/// A person is always the actor of record. Institutional acts are performed
/// **by a person, for an institution**, and [ActingOption.personId] keeps that
/// human attributable — an institution never acts by itself.
///
/// ── WHAT THIS DOES NOT DO ────────────────────────────────────────────────
/// It does not authorize anything. It answers *who this act would represent*
/// and *why that is available*. Enforcement is the backend's, always.
library;

import '../product/product_language.dart';
import 'capability_projection.dart';

/// The two first-class identities. Never collapsed (FD-11).
enum ActingIdentityKind { person, institution }

/// Why an acting identity is available for an act.
///
/// Carried so a surface can *explain* authority instead of merely obeying it,
/// and so a reviewer can see the provenance of every offer.
enum ActingAvailability {
  /// The person acting as themselves. Always available; needs no explanation.
  personalDefault,

  /// The person holds the required capability in this institution, as reported
  /// by the backend.
  institutionalCapability,

  /// Governance authority the backend enforces as a **role**, not a capability
  /// — ownership transfer, institution lifecycle, appointing admins. These are
  /// deliberately not delegable, so they are not capabilities.
  institutionalGovernanceRole,

  /// The session itself is the institution (institution account token).
  institutionAccount,
}

extension ActingAvailabilityExplanation on ActingAvailability {
  /// Short human explanation of *why* this option exists. Deliberately plain;
  /// surfaces may use it or write better contextual copy.
  String get explanation {
    switch (this) {
      case ActingAvailability.personalDefault:
        return 'You are acting as yourself.';
      case ActingAvailability.institutionalCapability:
        return 'You hold this responsibility in this institution.';
      case ActingAvailability.institutionalGovernanceRole:
        return 'This is governance authority held by your role.';
      case ActingAvailability.institutionAccount:
        return 'You are signed in as the institution.';
    }
  }
}

/// One identity an act could be performed as.
class ActingOption {
  const ActingOption({
    required this.kind,
    required this.id,
    required this.displayName,
    required this.availability,
    required this.personId,
    this.avatarUrl,
    this.institutionId,
  });

  final ActingIdentityKind kind;

  /// Person id or institution id, per [kind].
  final String id;

  final String displayName;
  final String? avatarUrl;
  final ActingAvailability availability;

  /// **The human behind this act, always.** An institutional act is performed
  /// *by a person for an institution*; attribution never disappears into the
  /// organisation. Empty only for an institution-account session, where no
  /// individual person is present in the token.
  final String personId;

  /// Set when [kind] is [ActingIdentityKind.institution].
  final String? institutionId;

  bool get isInstitution => kind == ActingIdentityKind.institution;
  bool get isPerson => kind == ActingIdentityKind.person;

  /// The canonical noun for this identity (C0 Product Language).
  ProductNoun get noun =>
      isInstitution ? ProductNoun.institution : ProductNoun.person;
}

/// The resolved answer for one consequential act.
class ActingResolution {
  const ActingResolution({
    required this.act,
    required this.options,
    required this.recommended,
    required this.requiresExplicitChoice,
  });

  final ConsequentialAct act;

  /// Every identity this act could legitimately be performed as, in the order
  /// a surface should present them. Empty means the act is not available at
  /// all — the surface must not offer it.
  final List<ActingOption> options;

  /// The identity the surface should default to. Null when [options] is empty.
  final ActingOption? recommended;

  /// True when the person could act as more than one identity, so the choice
  /// is materially theirs and must be visible **before** they commit.
  ///
  /// False is the ordinary case, and it is the reason Aura does not feel like
  /// a permission console: one legitimate identity means no ceremony.
  final bool requiresExplicitChoice;

  bool get isAvailable => options.isNotEmpty;

  /// True when performing this act speaks in an institution's voice.
  bool get isInstitutionalSpeech => recommended?.isInstitution ?? false;
}

/// Resolves acting identity for a consequential act.
///
/// Deliberately a pure function of *state that was given to it* — no route, no
/// ambient context, no globals. A path can never make someone an institution.
class ActingContextAuthority {
  const ActingContextAuthority({
    required this.personId,
    required this.personDisplayName,
    this.personAvatarUrl,
    this.institution,
  });

  final String personId;
  final String personDisplayName;
  final String? personAvatarUrl;

  /// The institution currently in view, if any. **Being in an institution's
  /// context is not acting as it** — this only says which institution's
  /// authority is relevant to resolve against.
  final InstitutionStanding? institution;

  ActingOption get _personOption => ActingOption(
        kind: ActingIdentityKind.person,
        id: personId,
        displayName: personDisplayName,
        avatarUrl: personAvatarUrl,
        availability: ActingAvailability.personalDefault,
        personId: personId,
      );

  /// Resolve who [act] could be performed as.
  ///
  /// Ordinary personal acts resolve to the person with no choice to make.
  /// Institutional acts resolve only when the backend actually reports the
  /// required authority — never from a role guess, never from a route.
  /// [offerPersonalAlternative] is declared by the **surface**, not the act.
  ///
  /// Whether a person could legitimately do this same thing as themselves
  /// depends on where they are: an institution's post composer offers only the
  /// institution's voice, while a unified composer that can publish either way
  /// offers both. Modelling it on the act produced a chooser that a
  /// single-purpose surface could not honour — a control that changes nothing
  /// is worse than no control.
  ActingResolution resolve(
    ConsequentialAct act, {
    bool offerPersonalAlternative = false,
  }) {
    final requirement = act.requirement;

    if (requirement.isPersonal) {
      return ActingResolution(
        act: act,
        options: [_personOption],
        recommended: _personOption,
        requiresExplicitChoice: false,
      );
    }

    final standing = institution;
    if (standing == null) {
      return ActingResolution(
        act: act,
        options: const [],
        recommended: null,
        requiresExplicitChoice: false,
      );
    }

    final availability = standing.availabilityFor(requirement);
    if (availability == null) {
      return ActingResolution(
        act: act,
        options: const [],
        recommended: null,
        requiresExplicitChoice: false,
      );
    }

    final institutionOption = ActingOption(
      kind: ActingIdentityKind.institution,
      id: standing.institutionId,
      displayName: standing.institutionName,
      avatarUrl: standing.institutionLogoUrl,
      availability: availability,
      personId: personId,
      institutionId: standing.institutionId,
    );

    // Where the surface legitimately offers both, the person must see the
    // choice before committing — the two outcomes are materially different in
    // public. Where it does not, attribution is stated and no choice is
    // manufactured.
    final options = <ActingOption>[
      institutionOption,
      if (offerPersonalAlternative && act.requirement.capability != null)
        _personOption,
    ];

    return ActingResolution(
      act: act,
      options: options,
      recommended: institutionOption,
      requiresExplicitChoice: options.length > 1,
    );
  }
}
