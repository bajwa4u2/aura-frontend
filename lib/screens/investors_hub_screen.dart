import 'package:flutter/material.dart';

import '../core/ui/document_scaffold.dart';
import '../core/ui/pdf_viewer_screen.dart';

class InvestorsHubScreen extends StatelessWidget {
  const InvestorsHubScreen({super.key});

  void _openPdf(
    BuildContext context, {
    required String title,
    required String assetPath,
  }) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => PdfViewerScreen(
          title: title,
          assetPath: assetPath,
        ),
      ),
    );
  }

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
          const SizedBox(height: 8),
          Doc.h('Investor documents'),
          const SizedBox(height: 8),
          _DocCard(
            title: 'Seed Investment Round',
            meta: 'March 2026',
            description:
                'Capital raise summary, equity range, valuation range, and use of funds.',
            onTap: () => _openPdf(
              context,
              title: 'Seed Investment Round',
              assetPath:
                  'assets/investor/Aura_Seed_Investment_Round_Mar2026.pdf',
            ),
          ),
          const SizedBox(height: 10),
          _DocCard(
            title: 'Business Model Framework',
            meta: 'Version 1.0 • March 2026',
            description:
                'Hybrid participation economy. Institutional subscriptions, verification, research access, and infrastructure contracts.',
            onTap: () => _openPdf(
              context,
              title: 'Business Model Framework',
              assetPath:
                  'assets/investor/Aura_Business_Model_Framework_v1.0_Mar2026.pdf',
            ),
          ),
          const SizedBox(height: 10),
          _DocCard(
            title: 'Governance Framework',
            meta: 'Version 1.0 • March 2026',
            description:
                'Moderation as structural custody, correction records, open observation, and constrained AI assistance.',
            onTap: () => _openPdf(
              context,
              title: 'Governance Framework',
              assetPath:
                  'assets/investor/Aura_Governance_Framework_v1.0_Mar2026.pdf',
            ),
          ),
          const SizedBox(height: 16),
          Doc.callout(
            'We seek alignment with partners who understand that durability matters more than acceleration.',
          ),
        ],
      ),
    );
  }
}

class _DocCard extends StatelessWidget {
  const _DocCard({
    required this.title,
    required this.meta,
    required this.description,
    this.onTap,
  });

  final String title;
  final String meta;
  final String description;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: theme.dividerColor.withOpacity(0.6),
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                meta,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.75),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Open document',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}