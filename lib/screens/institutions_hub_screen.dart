import 'package:flutter/material.dart';

import 'document_scaffold.dart';

class InstitutionsHubScreen extends StatelessWidget {
  const InstitutionsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DocumentScaffold(
      title: 'Institutions',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Doc.title('Institutions'),
          const SizedBox(height: 10),
          Doc.meta('Hub placeholder. Lane will be activated later.'),
          Doc.lede('Partnerships for ethics, archives, and durable public work.'),

          Doc.p(
            'This hub will hold the institutional posture and the operating model for collaborations that '
            'protect work over time.',
          ),

          Doc.h('Planned scope'),
          Doc.bullets([
            'Read-only institutional pages (verified)',
            'Public statements and constraints (what we will not do)',
            'A quiet contact channel (not a pitch form)',
            'Later: institutional support lanes and governance notes',
          ]),

          Doc.callout('This page is intentionally minimal until the lane is operational.'),
        ],
      ),
    );
  }
}
