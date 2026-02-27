import 'package:flutter/material.dart';

import '../core/ui/document_scaffold.dart';

class FounderMessageScreen extends StatelessWidget {
  const FounderMessageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DocumentScaffold(
      title: "Founder's message",
      child: _FounderBody(),
    );
  }
}

class _FounderBody extends StatelessWidget {
  const _FounderBody();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Doc.title("Founder’s message"),
        const SizedBox(height: 10),
        Doc.meta('Intent, constraints, and operating commitments.'),
        Doc.lede(
          'Aura exists to reduce structural distortion between people and institutions, without retreating from modern technology.',
        ),
        Doc.p(
          'Most platforms optimize for what spreads. Aura is built around what can be returned to: statements that remain attached to identity, continuity, and correction.',
        ),
        Doc.h('The core decision'),
        Doc.p(
          'Attention is treated as private. The system does not publish totals, rankings, or social scoreboards. That decision shapes both interface and incentive.',
        ),
        Doc.h('Who this is for'),
        Doc.bullets([
          'Individuals who want to speak under identity, not anonymity at scale',
          'Writers and creators who prefer clarity over reach',
          'Institutions willing to participate under formal correction obligations',
          'Observers who want legible reality without manipulation',
        ]),
        Doc.h('Non-negotiable constraints'),
        Doc.bullets([
          'No public engagement counts as social currency',
          'No algorithmic amplification as a visibility engine',
          'No growth that weakens identity integrity or consent',
          'No design that converts civic tension into spectacle',
        ]),
        Doc.h('Moderation posture'),
        Doc.p(
          'The goal is structural integrity. When possible, we prefer clarification, revision, and responsible reposting over silent deletion.',
        ),
        Doc.h('What success looks like'),
        Doc.bullets([
          'People return because the space remains readable and calm',
          'Institutions participate without dominating the room',
          'Disagreement remains visible without becoming a weapon',
          'A record exists that outlives campaigns, trends, and personalities',
        ]),
        Doc.h('The standard'),
        Doc.p('Measured. Repeatable. Built to outlast the moment.'),
      ],
    );
  }
}