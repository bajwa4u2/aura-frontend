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
          'Aura is built to reduce distortion between people and systems, without asking society to go backwards.',
        ),
        Doc.p(
          'Most platforms amplify what spreads. Aura is built around what survives: statements that can be revisited, corrected, and held to account.',
        ),
        Doc.h('The core decision'),
        Doc.p(
          'Aura treats attention as private. The system does not publish totals, rankings, or status ladders. That choice governs the interface and the incentives.',
        ),
        Doc.h('Who this is for'),
        Doc.bullets([
          'Individuals who want to speak with responsibility',
          'Writers and media creators who prefer clarity over reach',
          'Institutions that are willing to participate as verified actors',
          'Observers who want to understand reality without being manipulated by it',
        ]),
        Doc.h('Non-negotiable constraints'),
        Doc.bullets([
          'No public counts (likes, follows, replies) as a social scoreboard',
          'No algorithmic pressure that rewards outrage and punishes nuance',
          'No expansion that weakens consent, privacy, or identity integrity',
          'No design that turns civic frustration into entertainment',
        ]),
        Doc.h('Moderation posture'),
        Doc.p(
          'The goal is not purity. The goal is repair. When possible, we prefer re-contextualizing, requesting edits, and inviting responsible reposts over simple deletion.',
        ),
        Doc.h('What success looks like'),
        Doc.bullets([
          'People return because the space stays readable and honest',
          'Institutions participate without dominating the room',
          'Disagreement remains legible instead of becoming a war',
          'A record exists that outlives trends, campaigns, and personalities',
        ]),
        Doc.h('The standard'),
        Doc.p('Calm and measured. Repeatable. Built to outlive all of us.'),
      ],
    );
  }
}
