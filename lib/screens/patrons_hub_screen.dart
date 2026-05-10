import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/ui/aura_space.dart';
import '../core/ui/document_scaffold.dart';

class PatronsHubScreen extends StatelessWidget {
  const PatronsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DocumentScaffold(
      title: 'Patrons',
      showSiteFooter: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Doc.title('Patrons'),
          const SizedBox(height: 10),
          Doc.meta('Support without steering.'),
          Doc.lede(
            'Patronage in Aura exists to protect structural integrity, not to influence visibility or platform direction.',
          ),

          Doc.h('What a Patron is'),
          Doc.p(
            'A Patron is distinct from a Supporter and an Investor. Supporters contribute time and effort. Investors provide equity capital. Patrons provide ongoing financial support without governance implications.',
          ),
          Doc.p(
            'Patronage does not purchase content visibility, editorial influence, moderation authority, ranking preferences, or preferential system access.',
          ),

          Doc.h('Governing principles'),
          Doc.bullets([
            'No purchase of public visibility or ranking',
            'No public leaderboards or performance metrics attached to financial contribution',
            'No capacity to direct editorial, moderation, or architecture decisions',
            'Financial support is acknowledged privately or not at all — never performatively',
            'Funding should reduce distortion, not introduce new leverage over the system',
          ]),

          Doc.h('Current state'),
          Doc.p(
            'No patron program is currently open. There are no public listings of patrons on this platform.',
          ),
          Doc.p(
            'This lane will open only after the core architecture is stable and moderation systems are mature. Financial support must reduce distortion, not create new forms of it.',
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
