import 'package:flutter/material.dart';

import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/document_scaffold.dart';

class InstitutionProfileScreen extends StatelessWidget {
  const InstitutionProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DocumentScaffold(
      title: 'Institution profile',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Doc.title('Institution profile'),
          SizedBox(height: AuraSpace.s10),
          Doc.meta('Institution-facing profile surface.'),
          Doc.lede(
            'This dedicated tool will carry institution profile editing and public-facing institution identity settings.',
          ),
          SizedBox(height: AuraSpace.s12),
          const AuraCard(
            child: Text(
              'Institution profile management will be connected here next.',
            ),
          ),
        ],
      ),
    );
  }
}