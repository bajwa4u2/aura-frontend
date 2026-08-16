/// C2 — CANONICAL TRUST PRESENTATION AUTHORITY.
///
/// The one place verification facts become user-facing presentation.
/// Every mark answers, in its own copy: WHAT was verified — never a bare
/// generic "Verified" whose subject the user must guess.
///
/// Presentation doctrine (frozen by the C2 verification reconstruction):
///  - RESTRAINED — a mark appears only where the trust fact is relevant;
///    absence of verification renders NOTHING (absence is not suspicion);
///  - CONTEXTUAL — compact marks inline, fuller meaning through
///    tooltip/semantics; admin surfaces use richer state elsewhere;
///  - TRUTHFUL — labels restate the governed fact and nothing more.
///    Verification is information, not endorsement, popularity or
///    authority. Official institutional speech remains a C1 capability,
///    never inferred from any mark here.
library;

import 'package:flutter/material.dart';

import '../ui/aura_radius.dart';
import '../ui/aura_space.dart';
import '../ui/aura_surface.dart';
import '../ui/aura_text.dart';
import 'verification.dart';

/// Every trust fact the release client may present. Typed, so a consumer
/// can never invent a new meaning by concatenating strings.
enum TrustFact {
  identityVerified(
    label: 'Identity verified',
    meaning: 'Aura has verified this person is who they say they are.',
  ),
  affiliationVerified(
    label: 'Affiliation verified',
    meaning:
        'A relationship between this person and an institution has been verified on Aura.',
  ),
  // FOUNDER RULING (2026-08-16): the backend ROLE_OR_CREDENTIAL enum is an
  // Aura-governed attestation, never leaked mechanically to users and
  // never presented as a credential. Public wire carries the class only
  // (no subtype), so the narrowest non-overclaiming wording is used for
  // every record of this class; if the model later distinguishes
  // credential-like subtypes publicly, the specific attested fact can be
  // presented instead.
  roleAttested(
    label: 'Role attested',
    meaning:
        "Aura has a governed record supporting this person's stated role. This is an Aura record, not a portable credential.",
  ),
  institutionVerified(
    label: 'Verified institution',
    meaning:
        'This institution\'s identity has been verified on Aura. Verification is not an endorsement.',
  ),
  domainVerified(
    label: 'Domain verified',
    meaning: 'Ownership of this institution\'s web domain has been confirmed.',
  ),
  emailVerified(
    label: 'Email verified',
    meaning: 'This account\'s email address has been confirmed.',
  ),
  phoneVerified(
    label: 'Phone verified',
    meaning: 'This account\'s phone number has been confirmed.',
  );

  const TrustFact({required this.label, required this.meaning});

  /// Subject-explicit canonical wording. Never bare "Verified".
  final String label;

  /// One-sentence human meaning, used for tooltips and accessibility
  /// semantics.
  final String meaning;

  static TrustFact ofPersonClass(PersonVerificationClass c) =>
      switch (c) {
        PersonVerificationClass.identity => TrustFact.identityVerified,
        PersonVerificationClass.institutionAffiliation =>
          TrustFact.affiliationVerified,
        PersonVerificationClass.roleOrCredential => TrustFact.roleAttested,
      };
}

/// Visual weight of a mark, chosen by the consuming context.
enum TrustMarkSize {
  /// Icon + short label at micro scale — for identity rows and headers.
  micro,

  /// Pill chip with full label — for profile headers and detail surfaces.
  standard,
}

/// A single trust fact, presented truthfully.
///
/// The visible label is always the fact's subject-explicit wording. The
/// [Semantics]/[Tooltip] carry the full meaning, so a compact mark never
/// costs comprehension.
class TrustMark extends StatelessWidget {
  const TrustMark({
    super.key,
    required this.fact,
    this.size = TrustMarkSize.standard,
    this.color,
  });

  final TrustFact fact;
  final TrustMarkSize size;
  final Color? color;

  static const IconData _icon = Icons.verified_rounded;

  @override
  Widget build(BuildContext context) {
    final fg = color ?? AuraSurface.coVerdant;
    final Widget mark;
    switch (size) {
      case TrustMarkSize.micro:
        mark = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icon, size: 12, color: fg),
            const SizedBox(width: 3),
            Text(
              fact.label,
              style: AuraText.micro.copyWith(
                color: fg,
                fontWeight: FontWeight.w700,
                fontSize: 10,
              ),
            ),
          ],
        );
      case TrustMarkSize.standard:
        mark = Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s8,
            vertical: 3,
          ),
          decoration: BoxDecoration(
            color: fg.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(AuraRadius.pill),
            border: Border.all(color: fg.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_icon, size: 12, color: fg),
              const SizedBox(width: AuraSpace.s4),
              Text(
                fact.label,
                style: AuraText.micro.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
    }
    return Semantics(
      label: '${fact.label}. ${fact.meaning}',
      child: Tooltip(message: fact.meaning, child: mark),
    );
  }
}

/// A person's layered verification, as a coherent compact row.
///
/// Renders one mark per active class — never a collapsed "Verified
/// person". Renders nothing when no class is verified: verification is
/// information, and its absence must not read as suspicion.
class PersonVerificationMarks extends StatelessWidget {
  const PersonVerificationMarks({
    super.key,
    required this.verification,
    this.size = TrustMarkSize.standard,
    this.spacing = AuraSpace.s6,
  });

  final PersonVerification verification;
  final TrustMarkSize size;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (!verification.hasAny) return const SizedBox.shrink();
    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: [
        for (final c in verification.classes)
          TrustMark(fact: TrustFact.ofPersonClass(c), size: size),
      ],
    );
  }
}

/// Institution verification, presented inline next to an institution's
/// name. `Institution.isVerified` is the canonical institution field
/// (§16) — the boolean is legitimate; the generic PRESENTATION was not.
///
/// The visible label may compact to "Verified" ONLY because this widget
/// is defined to sit directly against the institution identity it
/// describes (the §15 unambiguous-subject case); assistive technology and
/// the tooltip always receive the full subject-explicit meaning.
class InstitutionVerifiedMark extends StatelessWidget {
  const InstitutionVerifiedMark({
    super.key,
    this.size = TrustMarkSize.micro,
    this.color,
    this.compactLabel = true,
  });

  final TrustMarkSize size;
  final Color? color;

  /// True only in layouts where the mark is adjacent to the institution
  /// name. Standalone placements must keep the full label.
  final bool compactLabel;

  @override
  Widget build(BuildContext context) {
    const fact = TrustFact.institutionVerified;
    final fg = color ?? AuraSurface.coVerdant;
    if (!compactLabel) {
      return TrustMark(fact: fact, size: size, color: color);
    }
    final double iconSize = size == TrustMarkSize.micro ? 12 : 14;
    return Semantics(
      label: '${fact.label}. ${fact.meaning}',
      child: Tooltip(
        message: fact.meaning,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_rounded, size: iconSize, color: fg),
            const SizedBox(width: 3),
            Text(
              'Verified',
              style: AuraText.micro.copyWith(
                color: fg,
                fontWeight: FontWeight.w700,
                fontSize: size == TrustMarkSize.micro ? 10 : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Icon-only institution mark for layouts too tight for any label.
/// Carries the full meaning through semantics/tooltip, so even the
/// smallest mark never degrades to an unexplained checkmark.
class InstitutionVerifiedIcon extends StatelessWidget {
  const InstitutionVerifiedIcon({super.key, this.iconSize = 14, this.color});

  final double iconSize;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    const fact = TrustFact.institutionVerified;
    return Semantics(
      label: '${fact.label}. ${fact.meaning}',
      child: Tooltip(
        message: fact.meaning,
        child: Icon(
          Icons.verified_rounded,
          size: iconSize,
          color: color ?? AuraSurface.coVerdant,
        ),
      ),
    );
  }
}
