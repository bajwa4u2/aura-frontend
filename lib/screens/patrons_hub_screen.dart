import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/ui/aura_radius.dart';
import '../core/ui/aura_space.dart';
import '../core/ui/aura_surface.dart';
import '../core/ui/aura_text.dart';
import '../core/ui/document_scaffold.dart';

/// Patrons page for Aura Platform LLC.
///
/// Patrons provide ongoing financial support that sustains the
/// infrastructure while the products mature. The page is deliberate
/// about what patronage is and is not — explicitly not equity, not
/// investment, not governance, not a promise of financial return.
/// Investor-grade capital relationships live on /investors. Single CTA:
/// contact the team. No payment flow is exposed here because no first-
/// party payment flow currently exists; surfacing one would be a
/// dishonest promise.
class PatronsHubScreen extends StatelessWidget {
  const PatronsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DocumentScaffold(
      title: 'Patrons',
      showSiteFooter: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Doc.title('Patrons'),
          const SizedBox(height: 10),
          Doc.meta('Aura Platform LLC'),
          Doc.lede(
            'Patrons provide ongoing support for the development of '
            'durable communication and operational infrastructure.',
          ),

          Doc.h('What patronage supports'),
          const _ValueBlock(
            label: 'Infrastructure',
            body:
                'Hosting, storage, realtime, and AI operating costs that '
                'keep both Aura and Orchestrate running reliably.',
          ),
          const SizedBox(height: AuraSpace.sm),
          const _ValueBlock(
            label: 'Reliability',
            body:
                'Engineering time spent on durability — observability, '
                'recovery, performance — rather than growth tricks.',
          ),
          const SizedBox(height: AuraSpace.sm),
          const _ValueBlock(
            label: 'Public surfaces',
            body:
                'The accountable public communication layer (Aura\'s '
                'public discourse, institutional records, verified '
                'identity) stays available without engagement-extraction '
                'pressure.',
          ),
          const SizedBox(height: AuraSpace.sm),
          const _ValueBlock(
            label: 'Continuity',
            body:
                'Founder-led development continues without the short-'
                'horizon trade-offs that come from optimizing only for '
                'next-quarter revenue.',
          ),

          Doc.h('What patronage is not'),
          Doc.bullets([
            'Not equity — patrons hold no ownership in Aura Platform LLC',
            'Not investment — patrons receive no financial return, '
                'dividend, or distribution',
            'Not control — patronage does not influence editorial, '
                'moderation, ranking, or product decisions',
            'Not a promise of refund or service level beyond what any '
                'public user receives',
          ]),

          Doc.h('Why patronage matters'),
          Doc.p(
            'Durable systems need time, care, and continuity. The '
            'infrastructure required to keep public discourse '
            'accountable — and to keep institutional execution '
            'attached to identity — is expensive to operate honestly. '
            'Patronage is how people who believe in that direction '
            'help fund the runway it takes to build it properly.',
          ),
          Doc.p(
            'Formal capital relationships — equity, board, or governance '
            'partnerships — are handled separately on the Investors '
            'page.',
          ),

          Doc.callout(
            'Patronage protects the conditions for trust, action, and '
            'records to remain durable.',
          ),

          const SizedBox(height: AuraSpace.md),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.go('/support/agent'),
              icon: const Icon(Icons.mail_outline_rounded, size: 16),
              label: const Text('Talk to the Aura team about patronage'),
            ),
          ),
        ],
      ),
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
          Text(body, style: AuraText.body.copyWith(height: 1.55)),
        ],
      ),
    );
  }
}
