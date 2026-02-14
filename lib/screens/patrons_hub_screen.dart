import 'package:flutter/material.dart';

import 'document_scaffold.dart';

class PatronsHubScreen extends StatelessWidget {
  const PatronsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DocumentScaffold(
      title: 'Patrons',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Doc.title('Patrons'),
          const SizedBox(height: 10),
          Doc.meta('Hub placeholder. Lane will be activated later.'),
          Doc.lede('Quiet monthly support, without turning attention into a marketplace.'),

          Doc.p(
            'This hub will explain how patron support works inside Aura without distorting the writing space.',
          ),

          Doc.h('Planned scope'),
          Doc.bullets([
            'Support tiers (calm, non-promotional)',
            'What support pays for (infrastructure, moderation, preservation)',
            'Clear boundaries (no pay-for-reach)',
            'Later: payments integration and receipts',
          ]),

          Doc.callout('Support is present, not noisy.'),
        ],
      ),
    );
  }
}
