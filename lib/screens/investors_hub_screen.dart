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
          Doc.meta('Support the structure, not the spectacle.'),
          Doc.lede(
            'Aura is built as civic infrastructure. The product is deliberately resistant to the usual growth mechanics.',
          ),
          Doc.p(
            'If you are looking for attention extraction, this is not a fit. If you are looking for durable trust, long-term integrity, and accountable public record, we can talk.',
          ),
          Doc.h('What we optimize for'),
          Doc.bullets([
            'Integrity of identity (who is speaking)',
            'Moderated public record (what is approved to stand)',
            'Privacy by default (counts are private, not public trophies)',
            'Longevity (archives that remain usable over time)',
          ]),
          Doc.h('What we do not optimize for'),
          Doc.bullets([
            'Viral reach',
            'Engagement loops',
            'Algorithmic amplification as a business model',
          ]),
          Doc.callout(
            'We prefer support that keeps the system honest, even when that slows the curve.',
          ),
        ],
      ),
    );
  }
}
