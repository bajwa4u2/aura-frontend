import '../core/ui/aura_chamber.dart';
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
      // THE CANONICAL MISSION SENTENCE, VERBATIM.
      //
      // Authority: representation/inventory/PRODUCT_IDENTITY_CANON.md, Company
      // Mission, frozen by founder decision 2026-09-05. This hero previously
      // carried a generic-technology framing that named no product identity at
      // all — and it was the source of the wording on the committed mission
      // social card, so the page and its own preview agreed with each other
      // while both disagreed with the route metadata beside them.
      title: 'Build durable public communication where people '
          'participate purposefully and institutions remain accountable.',
      subtitle:
          'Aura Platform LLC makes three products that keep what people and '
          'organizations say, do and publish on the record: Aura for public '
          'communication, Orchestrate for business relationships, and '
          'Colophon for authored work.',
      actions: [
        AuraGhostButton(
          label: 'White Paper',
          icon: Icons.menu_book_outlined,
          onPressed: () => context.push('/white-paper'),
        ),
        AuraGhostButton(
          label: 'Founder',
          icon: Icons.person_outline_rounded,
          onPressed: () => context.push('/founder'),
        ),
      ],
    );

    return AuraPublicationLayout(
      title: 'Mission',
      hero: hero,
      children: [
        PubText.p(
          'People say things in public that matter, and organizations '
          'make promises to them. Most tools let both disappear: posts '
          'scroll away, context splits across apps, and later no one '
          'can show what was said or what was promised.',
        ),
        PubText.p(
          'Aura Platform exists to keep that record. Each of our '
          'products keeps who said or did something, and when, '
          'attached to it for as long as it matters.',
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
          body: 'Authority is named, scoped, and reviewable, for '
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
          'Aura is public-first communication. It gives people, and '
          'the institutions they deal with, an accountable place to speak, '
          'respond, and record outcomes. Public discourse, '
          'institutional announcements, member conversations, and '
          'correspondence all share one identity layer, so positions '
          'stay attributable and corrections stay attached.',
        ),

        PubText.h('What Orchestrate does'),
        PubText.p(
          'Orchestrate is a governed execution platform for business '
          'relationships. It carries a relationship from first contact '
          'to a paid, delivered engagement with AI present at every '
          'step, but never acting ahead of a deterministic check. It '
          'is built for businesses in regulated or reputation-sensitive '
          'sectors.',
        ),

        PubText.h('What Colophon does'),
        PubText.p(
          'Colophon is reading, authorship and publishing for authored '
          'work. A work keeps its author, its editions and its '
          'provenance, so what was written stays attributable over '
          'time.',
        ),

        PubText.p(
          'The three products are built independently and share no code '
          'or infrastructure. What they share is one governance pattern.',
        ),

        PubText.h('What we refuse'),
        PubText.bullets(const [
          'Engagement extraction as a business model',
          'Generic AI automation that detaches action from identity',
          'Disconnected action without a record of who decided what',
          'Growth mechanics that undermine trust',
        ]),

        const AuraPublicationCallout(
          text: 'Three products that keep what people and organizations '
              'say, do and publish on the record.',
          attribution: 'Aura Platform LLC',
        ),

        const AuraPublicationDivider(),
        const AuraPublicationColophon(
          publisher: 'Aura Platform LLC',
          version: 'Mission',
          updatedLabel: 'Wednesday, September 30, 2026 · 3:45 AM ET',
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
        color: chamberTone(context, AuraSurface.elevated),
        borderRadius: BorderRadius.circular(AuraRadius.md),
        border: Border.all(color: chamberTone(context, AuraSurface.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: AuraText.micro.copyWith(
              color: chamberTone(context, AuraSurface.muted),
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
