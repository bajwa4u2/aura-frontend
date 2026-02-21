import 'package:flutter/material.dart';

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
          Doc.meta('Readers, builders, reviewers, moderators.'),
          Doc.lede(
            'Aura needs people who care about clarity more than victory.',
          ),
          Doc.p(
            'Support can be technical, editorial, or civic. The goal is not to agree. The goal is to keep the record honest and readable.',
          ),
          Doc.h('Ways to support (planned)'),
          Doc.bullets([
            'Moderation assistance and review (with training + constraints)',
            'Documentation and policy feedback',
            'Testing new flows carefully',
            'Translation and accessibility improvements',
          ]),
          Doc.callout('This hub will expand after the first stable public release.'),
        ],
      ),
    );
  }
}
