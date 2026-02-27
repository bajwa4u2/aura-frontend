import 'package:flutter/material.dart';

import '../core/ui/document_scaffold.dart';

class InvestorsHubScreen extends StatelessWidget {
  const InvestorsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DocumentScaffold(
      title: 'Investors',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Doc.title('Investors'),
          const SizedBox(height: 10),
          Doc.meta('Support durable civic infrastructure.'),
          Doc.lede(
            'Aura is designed as civic communication infrastructure. Its architecture intentionally resists short-term engagement mechanics.',
          ),
          Doc.p(
            'The objective is structural trust: identity integrity, visible correction, chronological record, and constrained AI assistance.',
          ),
          Doc.h('What we optimize for'),
          Doc.bullets([
            'Integrity of identity (who is speaking)',
            'Continuity of record (what remains visible)',
            'Correction that stays attached to the original statement',
            'Privacy by default (counts remain private)',
            'AI as structural assistance, not amplification',
          ]),
          Doc.h('What we do not optimize for'),
          Doc.bullets([
            'Viral velocity',
            'Engagement extraction',
            'Algorithmic amplification as a growth engine',
          ]),
          Doc.callout(
            'We seek alignment with partners who understand that durability matters more than acceleration.',
          ),
        ],
      ),
    );
  }
}