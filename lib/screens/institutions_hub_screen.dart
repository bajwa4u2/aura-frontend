import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/ui/aura_space.dart';
import '../core/ui/aura_text.dart';
import '../core/ui/document_scaffold.dart';

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
          Doc.meta('Verified participation, not branding.'),
          Doc.lede(
            'Aura welcomes institutions as verified participants, with the same constraints that protect the public record.',
          ),
          const SizedBox(height: AuraSpace.s12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.go('/institution/sign-in'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AuraSpace.s14,
                      vertical: AuraSpace.s12,
                    ),
                  ),
                  child: Text('Institution sign in', style: AuraText.body),
                ),
              ),
              const SizedBox(width: AuraSpace.s10),
              Expanded(
                child: FilledButton(
                  onPressed: () => context.go('/institution/request-verification'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AuraSpace.s14,
                      vertical: AuraSpace.s12,
                    ),
                  ),
                  child: Text('Request verification', style: AuraText.body.copyWith(color: Colors.white)),
                ),
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s10),
          Doc.p(
            'This lane exists because alignment requires two sides. Public witness matters, and institutional speech matters. What fails is when either side has no accountable place to stand.',
          ),
          Doc.h('What institutions can do here'),
          Doc.bullets([
            'Maintain a verified profile (identity integrity)',
            'Publish posts under moderation (public record when approved)',
            'Respond to public posts without hijacking the space',
            'Issue clarifications, corrections, and commitments that remain readable over time',
          ]),
          Doc.h('What institutions cannot do here'),
          Doc.bullets([
            'Purchase reach or visibility',
            'Use follower totals or engagement counts as public leverage',
            'Flood the system with PR volume',
          ]),
          Doc.callout(
            'Verified participation is a responsibility. It is not a privilege lane.',
          ),
        ],
      ),
    );
  }
}
