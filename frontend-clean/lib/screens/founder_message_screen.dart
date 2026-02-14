import 'package:flutter/material.dart';

import 'document_scaffold.dart';

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
        Doc.lede('Aura is built to protect the integrity of writing over time.'),

        Doc.p(
          'Most platforms optimize for attention and velocity. Aura optimizes for continuity: return, revision, '
          'and durable archives. The product is designed so that the work does not get distorted by the system '
          'meant to host it.',
        ),

        Doc.h('The core decision'),
        Doc.p(
          'Aura treats attention as a private ledger, not a public marketplace. That single choice governs the '
          'interface, the incentives, and the limits of what we allow.',
        ),

        Doc.h('What this place is'),
        Doc.bullets([
          'A correspondence table, not a feed',
          'A home for work that stays intact',
          'A system designed for return, not refresh',
        ]),

        Doc.h('Non-negotiable constraints'),
        Doc.bullets([
          'No ranking-by-reaction as the primary organizing principle',
          'No engagement pressure disguised as “growth”',
          'No product decisions that convert writing into noise',
          'No expansion that weakens privacy, consent, or authorship',
        ]),

        Doc.h('Operating posture'),
        Doc.p(
          'Aura stays deliberate. Features ship only when they protect the work or reduce distortion. '
          'If a feature increases activity but reduces integrity, it does not ship.',
        ),

        Doc.h('What success looks like'),
        Doc.bullets([
          'Writers return because the space holds their work',
          'Readers discover through identity, not anonymous amplification',
          'Archives remain coherent and usable years later',
          'Trust compounds because the system does not exploit attention',
        ]),

        Doc.h('Trust is the output'),
        Doc.p(
          'If Aura earns anything, it should earn trust: that what you place here will not be repackaged into bait, '
          'and that attention will not be treated as a commodity.',
        ),

        Doc.h('The standard'),
        Doc.p('Quiet. Slow. Repeatable.'),
      ],
    );
  }
}
