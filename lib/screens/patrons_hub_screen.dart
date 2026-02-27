import 'package:flutter/material.dart';

import '../core/ui/document_scaffold.dart';

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
          Doc.meta('Support without steering.'),
          Doc.lede(
            'Patronage in Aura exists to protect structural integrity, not to influence visibility or direction.',
          ),
          Doc.p(
            'This lane will open only after the core architecture is stable and moderation systems are mature. Financial support must reduce distortion, not introduce new leverage.',
          ),
          Doc.h('Planned principles'),
          Doc.bullets([
            'No purchase of visibility',
            'No public leaderboards',
            'Support is acknowledged privately or in limited, non-performative ways',
            'Funding should reduce distortion, not create new distortions',
          ]),
          Doc.callout('This hub is intentionally minimal for now.'),
        ],
      ),
    );
  }
}