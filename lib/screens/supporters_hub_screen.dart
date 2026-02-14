import 'package:flutter/material.dart';

import 'document_scaffold.dart';

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
          Doc.meta('Hub placeholder. Lane will be activated later.'),
          Doc.lede('A place for aligned people who carry the work forward.'),

          Doc.p(
            'This hub will hold supporter pathways that are practical and respectful: help with testing, '
            'translation, partnerships, and stewardship.',
          ),

          Doc.h('Planned scope'),
          Doc.bullets([
            'Ways to help (testing, feedback, moderation support)',
            'Translation and accessibility lanes',
            'Institution introductions (only when appropriate)',
            'Later: supporter directory (opt-in)',
          ]),

          Doc.callout('Presence first. Scale later.'),
        ],
      ),
    );
  }
}
