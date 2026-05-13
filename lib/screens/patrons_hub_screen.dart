import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/ui/aura_platform_components.dart';
import '../core/ui/aura_radius.dart';
import '../core/ui/aura_space.dart';
import '../core/ui/aura_surface.dart';
import '../core/ui/aura_text.dart';
import '../core/ui/publication/publication.dart';

/// Patrons page for Aura Platform LLC.
///
/// Migrated to the publication system in the May 2026 publication
/// pass. Patrons provide ongoing financial support — explicitly not
/// equity, not investment, not governance, not a promise of return.
class PatronsHubScreen extends StatelessWidget {
  const PatronsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final hero = AuraPublicationHero(
      eyebrow: 'Patrons',
      title: 'Ongoing support for durable infrastructure.',
      subtitle:
          'Patrons sustain the infrastructure that keeps public '
          'discourse accountable and institutional execution attached '
          'to identity — while the products mature.',
      actions: [
        AuraPrimaryButton(
          label: 'Talk to the Aura team',
          icon: Icons.mail_outline_rounded,
          onPressed: () => context.go('/support/agent'),
        ),
        AuraGhostButton(
          label: 'Investors',
          icon: Icons.account_balance_outlined,
          onPressed: () => context.go('/investors'),
        ),
      ],
    );

    return AuraPublicationLayout(
      title: 'Patrons',
      hero: hero,
      children: [
        PubText.h('What patronage supports'),
        const _ValueBlock(
          label: 'Infrastructure',
          body:
              'Hosting, storage, realtime, and AI operating costs that '
              'keep both Aura and Orchestrate running reliably.',
        ),
        const SizedBox(height: AuraSpace.s10),
        const _ValueBlock(
          label: 'Reliability',
          body:
              'Engineering time spent on durability — observability, '
              'recovery, performance — rather than growth tricks.',
        ),
        const SizedBox(height: AuraSpace.s10),
        const _ValueBlock(
          label: 'Public surfaces',
          body:
              'The accountable public communication layer stays '
              'available without engagement-extraction pressure.',
        ),
        const SizedBox(height: AuraSpace.s10),
        const _ValueBlock(
          label: 'Continuity',
          body:
              'Founder-led development continues without the short-'
              'horizon trade-offs that come from optimizing only for '
              'next-quarter revenue.',
        ),

        PubText.h('What patronage is not'),
        PubText.bullets(const [
          'Not equity — patrons hold no ownership in Aura Platform LLC',
          'Not investment — patrons receive no financial return, '
              'dividend, or distribution',
          'Not control — patronage does not influence editorial, '
              'moderation, ranking, or product decisions',
          'Not a promise of refund or service level beyond what any '
              'public user receives',
        ]),

        PubText.h('Why patronage matters'),
        PubText.p(
          'Durable systems need time, care, and continuity. The '
          'infrastructure required to keep public discourse '
          'accountable — and to keep institutional execution '
          'attached to identity — is expensive to operate honestly. '
          'Patronage is how people who believe in that direction '
          'help fund the runway it takes to build it properly.',
        ),
        PubText.p(
          'Formal capital relationships — equity, board, or governance '
          'partnerships — are handled separately on the Investors page.',
        ),

        const AuraPublicationCallout(
          text: 'Patronage protects the conditions for trust, action, '
              'and records to remain durable.',
        ),

        const AuraPublicationDivider(),
        const AuraPublicationColophon(
          publisher: 'Aura Platform LLC',
          version: 'Patrons',
          updatedLabel: 'May 2026',
        ),
      ],
    );
  }
}

class _ValueBlock extends StatelessWidget {
  const _ValueBlock({required this.label, required this.body});

  final String label;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AuraSpace.md),
      decoration: BoxDecoration(
        color: AuraSurface.elevated,
        borderRadius: BorderRadius.circular(AuraRadius.md),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: AuraText.micro.copyWith(
              color: AuraSurface.muted,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(body, style: AuraText.body.copyWith(fontSize: 15, height: 1.6)),
        ],
      ),
    );
  }
}
