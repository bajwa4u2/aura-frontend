import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/ui/document_scaffold.dart';

class InvestorsHubScreen extends StatelessWidget {
  const InvestorsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DocumentScaffold(
      title: 'Investors Hub',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Doc.title('Investors Hub'),
          const SizedBox(height: 10),
          Doc.meta('Context for aligned partners and institutional readers.'),
          Doc.lede('Structural clarity, not fundraising.'),

          Doc.p(
            'This page exists for durability. Aura is built under constraints that prioritize continuity, '
            'restraint, and long-term integrity of work.',
          ),

          Doc.h('What this project protects'),
          Doc.bullets([
            'Writing that remains intact over time',
            'Identity-tied discovery instead of anonymous amplification',
            'Archives treated as first-class assets',
          ]),

          Doc.h('Design posture'),
          Doc.p(
            'Aura avoids engagement mechanics that distort authorship. Growth, if it occurs, must not compromise '
            'structural integrity.',
          ),

          Doc.h('Partnership philosophy'),
          Doc.p(
            'Capital, if introduced, must reinforce durability rather than accelerate noise. The objective is '
            'alignment, not velocity.',
          ),

          Doc.h('Related hubs'),
          Doc.p(
            'These hubs exist as stable endpoints. Content expands when each lane becomes operational.',
          ),
          const SizedBox(height: 6),

          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton(
                onPressed: () => context.push('/institutions'),
                child: const Text('Institutions'),
              ),
              OutlinedButton(
                onPressed: () => context.push('/patrons'),
                child: const Text('Patrons'),
              ),
              OutlinedButton(
                onPressed: () => context.push('/supporters'),
                child: const Text('Supporters'),
              ),
            ],
          ),

          const SizedBox(height: 6),
          Doc.meta('Links are live now. Promotion comes later, when each hub is ready.'),
        ],
      ),
    );
  }
}
