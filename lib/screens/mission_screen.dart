import 'package:flutter/material.dart';

import '../core/ui/aura_radius.dart';
import '../core/ui/aura_space.dart';
import '../core/ui/aura_surface.dart';
import '../core/ui/aura_text.dart';
import '../core/ui/document_scaffold.dart';

/// Mission page for Aura Platform LLC.
///
/// Philosophical surface, now coherent with the two-product company:
/// Aura (accountable communication) and Orchestrate (AI-assisted
/// operational execution). The page is the public framing — what we
/// protect, what each product does, and what we refuse — kept compact
/// enough to scan in one read.
class MissionScreen extends StatelessWidget {
  const MissionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DocumentScaffold(
      title: 'Mission',
      showSiteFooter: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Doc.title('Mission'),
          const SizedBox(height: 10),
          Doc.meta('Aura Platform LLC'),
          Doc.lede(
            'Build durable systems for communication, coordination, and '
            'execution in the AI era.',
          ),

          Doc.p(
            'Modern work is fast, but unstable. Conversations scatter '
            'across tools. Identity blurs. Decisions move forward, but '
            'the record of who said what — and what was supposed to '
            'happen next — gets lost between the tab and the calendar.',
          ),
          Doc.p(
            'Aura Platform exists to fix that fragmentation at the '
            'infrastructure layer. We build systems where identity, '
            'action, and records stay connected.',
          ),

          Doc.h('What we protect'),
          const _Protect(
            label: 'Identity',
            body: 'Every voice and every action is attributed to a real, '
                'verifiable person or institution.',
          ),
          const SizedBox(height: AuraSpace.sm),
          const _Protect(
            label: 'Accountability',
            body: 'Authority is named, scoped, and reviewable — for '
                'individuals, institutions, and AI alike.',
          ),
          const SizedBox(height: AuraSpace.sm),
          const _Protect(
            label: 'Continuity',
            body: 'Conversations, decisions, and outcomes remain attached '
                'over time. Context does not evaporate.',
          ),
          const SizedBox(height: AuraSpace.sm),
          const _Protect(
            label: 'Human authority',
            body: 'AI assists; humans decide. Final authority stays with '
                'an identity-bound person or institution.',
          ),
          const SizedBox(height: AuraSpace.sm),
          const _Protect(
            label: 'Operational memory',
            body: 'What was promised, scheduled, owed, and delivered is '
                'preserved as a structured record, not a thread to '
                'reconstruct later.',
          ),

          Doc.h('What Aura does'),
          Doc.p(
            'Aura is the communication side of the platform. It gives '
            'people and institutions an accountable place to speak, '
            'respond, and record outcomes. Public discourse, '
            'institutional announcements, member conversations, and '
            'correspondence all share one identity layer — so positions '
            'stay attributable and corrections stay attached.',
          ),

          Doc.h('What Orchestrate does'),
          Doc.p(
            'Orchestrate is the execution side of the platform. It is '
            'AI-assisted revenue automation and operational execution — '
            'from outreach to meetings to workflow to billing — for '
            'institutional teams that need follow-through to stay '
            'connected to the people accountable for it.',
          ),

          Doc.h('What we refuse'),
          Doc.bullets([
            'Engagement extraction as a business model',
            'Generic AI automation that detaches action from identity',
            'Disconnected action without a record of who decided what',
            'Growth mechanics that undermine trust',
          ]),

          Doc.callout(
            'Infrastructure for accountable communication and AI-assisted '
            'operational execution.',
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Local helper: compact labelled block for "What we protect".
// Visually consistent with the value blocks on InvestorsHubScreen so
// the two pages read as one company surface.
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
          Text(body, style: AuraText.body.copyWith(height: 1.55)),
        ],
      ),
    );
  }
}
