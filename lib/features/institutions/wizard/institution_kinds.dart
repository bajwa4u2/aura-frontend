import 'package:flutter/material.dart';

/// The seven kinds of institution Aura serves (DD-42, 2026-10-08).
///
/// The kind is asked once, first, and decides emphasis, words and the proof an
/// institution is asked for — never its authority. `wire` is the server's
/// `InstitutionCategory` value.
class InstitutionKind {
  const InstitutionKind({
    required this.wire,
    required this.title,
    required this.examples,
    required this.icon,
    required this.existenceProof,
    required this.authorityProof,
    required this.alwaysReviewed,
  });

  final String wire;
  final String title;

  /// Who this kind is, in a person's words.
  final String examples;
  final IconData icon;

  /// What shows the institution exists, in this kind's words.
  final String existenceProof;

  /// What shows the person may act for it.
  final String authorityProof;

  /// A person at Aura always reviews this kind (policy §1.3).
  final bool alwaysReviewed;

  static InstitutionKind? fromWire(String? wire) {
    for (final k in all) {
      if (k.wire == wire) return k;
    }
    return null;
  }

  static const all = <InstitutionKind>[
    InstitutionKind(
      wire: 'GOVERNMENT_CIVIC',
      title: 'Government or civic body',
      examples: 'City, township, county, agency or public board',
      icon: Icons.account_balance_outlined,
      existenceProof:
          'Your official government website (for example a .gov address) or a public registry listing.',
      authorityProof:
          'A government credential showing your position, or approval from someone who already speaks for it on Aura.',
      alwaysReviewed: true,
    ),
    InstitutionKind(
      wire: 'EDUCATIONAL',
      title: 'School, college or university',
      examples: 'School district, school, college or university',
      icon: Icons.school_outlined,
      existenceProof:
          'Its accreditation or state school registry listing, or its official website.',
      authorityProof:
          'A letter naming your role, or approval from someone who already speaks for it on Aura.',
      alwaysReviewed: true,
    ),
    InstitutionKind(
      wire: 'NONPROFIT_COMMUNITY',
      title: 'Nonprofit or community organisation',
      examples: 'Charity, foundation, association or club',
      icon: Icons.volunteer_activism_outlined,
      existenceProof:
          'Its registration or tax-exemption number (for example its EIN or 501(c) letter).',
      authorityProof:
          'Approval from someone who already speaks for it on Aura, or a letter or minutes naming your role.',
      alwaysReviewed: false,
    ),
    InstitutionKind(
      wire: 'RELIGIOUS',
      title: 'Faith institution',
      examples: 'Mosque, church, temple or synagogue',
      icon: Icons.diversity_1_outlined,
      existenceProof:
          'Its registry number if it is registered. If not, a letter on its letterhead, a lease or a utility bill in its name is enough.',
      authorityProof:
          'A letter from its board or leadership naming your role, or approval from someone who already speaks for it on Aura.',
      alwaysReviewed: false,
    ),
    InstitutionKind(
      wire: 'CORPORATE_BUSINESS',
      title: 'Company or business',
      examples: 'Company, firm, shop or practice',
      icon: Icons.storefront_outlined,
      existenceProof: 'Its company registration (your state filing number).',
      authorityProof:
          'The state filing listing you as an officer, or approval from someone who already speaks for it on Aura.',
      alwaysReviewed: false,
    ),
    InstitutionKind(
      wire: 'MEDIA',
      title: 'Media or journalism',
      examples: 'Newsroom, broadcaster or publisher',
      icon: Icons.newspaper_outlined,
      existenceProof:
          'Its business filing and a published masthead or page naming its editor.',
      authorityProof:
          'The masthead or filing naming you, or approval from someone who already speaks for it on Aura.',
      alwaysReviewed: true,
    ),
    InstitutionKind(
      wire: 'HEALTHCARE',
      title: 'Healthcare provider',
      examples: 'Clinic, hospital or health department',
      icon: Icons.local_hospital_outlined,
      existenceProof:
          'Its licence or provider number (NPI), or a state registry listing.',
      authorityProof:
          'A letter naming your role, or approval from someone who already speaks for it on Aura.',
      alwaysReviewed: true,
    ),
  ];
}
