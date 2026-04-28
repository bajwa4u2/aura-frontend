import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/ui/aura_card.dart';
import '../../../../core/ui/aura_platform_components.dart';
import '../../../../core/ui/aura_space.dart';
import '../../../../core/ui/aura_text.dart';

class SupportContactPanel extends StatelessWidget {
  const SupportContactPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Support and contact', style: AuraText.subtitle),
          const SizedBox(height: AuraSpace.s8),
          const Text(
            'Support acknowledgements remain transactional. The public contact form preserves its success state and confirmation behavior.',
            style: AuraText.body,
          ),
          const SizedBox(height: AuraSpace.s12),
          AuraSecondaryButton(
            label: 'Open contact',
            onPressed: () => context.go('/contact'),
            icon: Icons.mail_outline,
          ),
        ],
      ),
    );
  }
}
