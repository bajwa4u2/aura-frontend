import 'package:flutter/material.dart';

import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/document_scaffold.dart';

class InstitutionDomainsScreen extends StatelessWidget {
  const InstitutionDomainsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DocumentScaffold(
      title: 'Institution domains',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Doc.title('Institution domains'),
          SizedBox(height: AuraSpace.s10),
          Doc.meta('Institutional domain management and DNS verification.'),
          Doc.lede(
            'This dedicated tool will manage institutional domains, DNS TXT challenges, and verification checks.',
          ),
          SizedBox(height: AuraSpace.s12),
          const AuraCard(
            child: Text(
              'Domain verification UI will be connected here next.',
            ),
          ),
        ],
      ),
    );
  }
}