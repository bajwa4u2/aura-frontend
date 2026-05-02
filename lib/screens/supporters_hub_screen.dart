import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/ui/aura_space.dart';
import '../core/ui/document_scaffold.dart';

class SupportersHubScreen extends StatelessWidget {
  const SupportersHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DocumentScaffold(
      title: 'Supporters',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Doc.title('Supporters'),
          const SizedBox(height: 10),
          Doc.meta('Contribution, not capital.'),
          Doc.lede(
            'Supporters contribute time, effort, expertise, and feedback to help Aura work better — not capital.',
          ),

          Doc.h('What a Supporter is'),
          Doc.p(
            'A Supporter is distinct from a Patron and an Investor. Patrons provide ongoing financial support. Investors provide equity capital. Supporters contribute neither — they contribute participation: testing, moderation assistance, documentation, translation, and constructive feedback.',
          ),
          Doc.p(
            'Supporting Aura does not purchase visibility, governance authority, algorithmic preference, or platform access beyond what any member has.',
          ),

          Doc.h('What supporting involves'),
          Doc.bullets([
            'Moderation assistance under defined constraints and training',
            'Documentation review and policy feedback',
            'Testing new flows and reporting issues carefully and precisely',
            'Translation and accessibility improvements',
            'Constructive, identity-bound participation in the public record',
          ]),

          Doc.h('Current state'),
          Doc.p(
            'No formal supporter program is currently open. There are no public listings of supporters on this platform.',
          ),
          Doc.p(
            'When a structured program opens, it will be governed by clear constraints consistent with the platform\'s principles: no visibility rewards, no governance leverage, and no path to changing what Aura refuses to become.',
          ),

          const SizedBox(height: AuraSpace.lg),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => context.go('/support/agent'),
              child: const Text('Contact Support'),
            ),
          ),
        ],
      ),
    );
  }
}
