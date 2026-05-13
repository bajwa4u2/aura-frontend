import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/ui/aura_platform_components.dart';
import '../core/ui/aura_radius.dart';
import '../core/ui/aura_space.dart';
import '../core/ui/aura_surface.dart';
import '../core/ui/aura_text.dart';
import '../core/ui/publication/publication.dart';

/// Mission page for Aura Platform LLC.
///
/// Migrated to the publication system in the May 2026 publication
/// pass. The visual register now matches the White Paper: hero band
/// with eyebrow + display title + subtitle, reading column at 720,
/// publication typography for body text.
class MissionScreen extends StatelessWidget {
  const MissionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final hero = AuraPublicationHero(
      eyebrow: 'Mission',
      title: 'Durable systems for communication, '
          'coordination, and execution.',
      subtitle:
          'Aura Platform LLC builds infrastructure where identity, '
          'authority, and outcomes stay connected — across people, '
          'institutions, and AI.',
      actions: [
        AuraGhostButton(
          label: 'White Paper',
          icon: Icons.menu_book_outlined,
          onPressed: () => context.go('/white-paper'),
        ),
        AuraGhostButton(
          label: 'Founder',
          icon: Icons.person_outline_rounded,
          onPressed: () => context.go('/founder'),
        ),
      ],
    );

    return AuraPublicationLayout(
      title: 'Mission',
      hero: hero,
      children: [
        PubText.p(
          'Modern work is fast, but unstable. Conversations scatter '
          'across tools. Identity blurs. Decisions move forward, but '
          'the record of who said what — and what was supposed to '
          'happen next — gets lost between the tab and the calendar.',
        ),
        PubText.p(
          'Aura Platform exists to fix that fragmentation at the '
          'infrastructure layer. We build systems where identity, '
          'action, and records stay connected.',
        ),

        PubText.h('What we protect'),
        const _Protect(
          label: 'Identity',
          body: 'Every voice and every action is attributed to a real, '
              'verifiable person or institution.',
        ),
        const SizedBox(height: AuraSpace.s10),
        const _Protect(
          label: 'Accountability',
          body: 'Authority is named, scoped, and reviewable — for '
              'individuals, institutions, and AI alike.',
        ),
        const SizedBox(height: AuraSpace.s10),
        const _Protect(
          label: 'Continuity',
          body: 'Conversations, decisions, and outcomes remain attached '
              'over time. Context does not evaporate.',
        ),
        const SizedBox(height: AuraSpace.s10),
        const _Protect(
          label: 'Human authority',
          body: 'AI assists; humans decide. Final authority stays with '
              'an identity-bound person or institution.',
        ),
        const SizedBox(height: AuraSpace.s10),
        const _Protect(
          label: 'Operational memory',
          body: 'What was promised, scheduled, owed, and delivered is '
              'preserved as a structured record, not a thread to '
              'reconstruct later.',
        ),

        PubText.h('What Aura does'),
        PubText.p(
          'Aura is the communication side of the platform. It gives '
          'people and institutions an accountable place to speak, '
          'respond, and record outcomes. Public discourse, '
          'institutional announcements, member conversations, and '
          'correspondence all share one identity layer — so positions '
          'stay attributable and corrections stay attached.',
        ),

        PubText.h('What Orchestrate does'),
        PubText.p(
          'Orchestrate is the execution side of the platform. It is '
          'AI-assisted revenue automation and operational execution — '
          'from outreach to meetings to workflow to billing — for '
          'institutional teams that need follow-through to stay '
          'connected to the people accountable for it.',
        ),

        PubText.h('What we refuse'),
        PubText.bullets(const [
          'Engagement extraction as a business model',
          'Generic AI automation that detaches action from identity',
          'Disconnected action without a record of who decided what',
          'Growth mechanics that undermine trust',
        ]),

        const AuraPublicationCallout(
          text: 'Infrastructure for accountable communication and '
              'AI-assisted operational execution.',
          attribution: 'Aura Platform thesis',
        ),

        const AuraPublicationDivider(),
        const AuraPublicationColophon(
          publisher: 'Aura Platform LLC',
          version: 'Mission',
          updatedLabel: 'May 2026',
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Local helper: compact labelled block for "What we protect".
// ─────────────────────────────────────────────────────────────────────────────

class _Protect extends StatelessWidget {
  const _Protect({required this.label, required this.body});

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
