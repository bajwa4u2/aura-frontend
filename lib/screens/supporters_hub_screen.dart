import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/ui/aura_platform_components.dart';
import '../core/ui/aura_radius.dart';
import '../core/ui/aura_space.dart';
import '../core/ui/aura_surface.dart';
import '../core/ui/aura_text.dart';
import '../core/ui/publication/publication.dart';

/// Supporters page for Aura Platform LLC.
///
/// Migrated to the publication system in the May 2026 publication
/// pass. Supporters contribute attention, testing, and feedback —
/// not capital. The page deliberately distinguishes the role from
/// Patron and Investor.
class SupportersHubScreen extends StatelessWidget {
  const SupportersHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final hero = AuraPublicationHero(
      eyebrow: 'Supporters',
      title: 'Attention, testing, and feedback.',
      subtitle:
          'Supporters help Aura Platform improve through careful use, '
          'precise bug reports, and thoughtful participation — not '
          'capital, not endorsement.',
      actions: [
        AuraPrimaryButton(
          label: 'Share feedback',
          icon: Icons.mail_outline_rounded,
          onPressed: () => context.go('/support/agent'),
        ),
        AuraGhostButton(
          label: 'Mission',
          icon: Icons.flag_outlined,
          onPressed: () => context.go('/mission'),
        ),
      ],
    );

    return AuraPublicationLayout(
      title: 'Supporters',
      hero: hero,
      children: [
        PubText.h('What supporters do'),
        const _ValueBlock(
          label: 'Test',
          body:
              'Walk product flows end-to-end and report what feels '
              'wrong, broken, or unclear.',
        ),
        const SizedBox(height: AuraSpace.s10),
        const _ValueBlock(
          label: 'Report',
          body:
              'File precise bug reports — what you did, what you '
              'expected, what happened.',
        ),
        const SizedBox(height: AuraSpace.s10),
        const _ValueBlock(
          label: 'Improve clarity',
          body:
              'Flag copy, structure, and identity signals that confuse '
              'real users or institutions.',
        ),
        const SizedBox(height: AuraSpace.s10),
        const _ValueBlock(
          label: 'Share',
          body:
              'Invite thoughtful users and institutions who would '
              'benefit from institution operating infrastructure.',
        ),

        PubText.h('What supporters are not'),
        PubText.bullets(const [
          'Not investors — supporters do not provide capital and do '
              'not hold equity',
          'Not patrons — supporters do not provide ongoing financial '
              'support',
          'Not paid endorsers — supporters speak under their own '
              'identity, not on behalf of the company',
        ]),

        PubText.h('Why it matters'),
        PubText.p(
          'Public infrastructure improves through careful use, not '
          'through hype. Every accurate bug report, every honest '
          'critique of a confusing flow, every thoughtful invitation '
          'sharpens the system. Supporters are the early signal that '
          'the platform is being shaped by real participation rather '
          'than marketing motion.',
        ),

        const AuraPublicationCallout(
          text: 'Trust, action, and records improve when people who '
              'care about durable systems actually use them.',
        ),

        const AuraPublicationDivider(),
        const AuraPublicationColophon(
          publisher: 'Aura Platform LLC',
          version: 'Supporters',
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
