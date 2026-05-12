import 'package:flutter/material.dart';

import '../core/ui/aura_radius.dart';
import '../core/ui/aura_space.dart';
import '../core/ui/aura_surface.dart';
import '../core/ui/aura_text.dart';
import '../core/ui/document_scaffold.dart';

/// Founder page for Aura Platform LLC.
///
/// Operator-builder credibility behind the two-product company (Aura and
/// Orchestrate). Not a biography — a compact statement of who is building
/// the platform, what background informs it, and what principles guide the
/// work. Coherent with Mission + Investors: same Trust / Action / Records /
/// Continuity vocabulary, same labelled-block layout, no manifesto walls.
class FounderMessageScreen extends StatelessWidget {
  const FounderMessageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DocumentScaffold(
      title: 'Founder',
      showSiteFooter: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Doc.title('Founder'),
          const SizedBox(height: 10),
          Doc.meta('Aura Platform LLC'),
          Doc.lede(
            'Aura Platform LLC is being built by an operator-builder '
            'focused on accountable communication, operational execution, '
            'and durable systems.',
          ),

          Doc.h('Operator-builder background'),
          Doc.p(
            'Muhammad Sakhawat (MS Bajwa) is the sole founder and builder. '
            'The background is operator-builder, not media: construction, '
            'excavation, oil and gas infrastructure, and project '
            'management — primarily in Oman. The work demanded the kind '
            'of discipline that does not survive shortcuts: identity '
            'attached to scope, schedules attached to delivery, records '
            'attached to outcomes.',
          ),
          Doc.p(
            'Bajwa Writes™ — long-form work on conscience, institutional '
            'responsibility, and moral structure — informs the platform\'s '
            'editorial posture. Aura Platform is the engineering side of '
            'the same instinct: systems where identity, action, and '
            'records stay connected.',
          ),

          Doc.h('Why Aura'),
          Doc.p(
            'Public and institutional communication has decayed into a '
            'system that rewards reaction over responsibility. Identity '
            'is blurred, corrections are lost, and the record of what was '
            'said and what followed evaporates. Aura is the '
            'communication infrastructure for the opposite: people and '
            'institutions speaking under verified identity, with '
            'structure that keeps positions attributable and outcomes '
            'durable.',
          ),

          Doc.h('Why Orchestrate'),
          Doc.p(
            'Operational execution suffers from the same fragmentation. '
            'Conversations live in one tool, scheduling in another, '
            'workflow in a third, billing in a fourth. Decisions move '
            'forward, but the people accountable for follow-through lose '
            'context between the tabs. Orchestrate is AI-assisted '
            'revenue automation and operational execution — from '
            'outreach to meetings to workflow to billing — that keeps '
            'action and identity attached end-to-end.',
          ),

          Doc.h('Builder principles'),
          const _ValueBlock(
            label: 'Trust',
            body:
                'Identity and authority are named on every action — '
                'across people, institutions, and AI.',
          ),
          const SizedBox(height: AuraSpace.sm),
          const _ValueBlock(
            label: 'Action',
            body:
                'Communication and execution share one fabric. Decisions '
                'move forward without losing context.',
          ),
          const SizedBox(height: AuraSpace.sm),
          const _ValueBlock(
            label: 'Records',
            body:
                'What was said, decided, and shipped remains visible to '
                'the right audience over time.',
          ),
          const SizedBox(height: AuraSpace.sm),
          const _ValueBlock(
            label: 'Continuity',
            body:
                'Context does not evaporate between sessions, tools, or '
                'people. Operational memory is treated as a first-class '
                'system property.',
          ),

          Doc.callout(
            'The company is being built with infrastructure discipline, '
            'not short-term engagement logic.',
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
