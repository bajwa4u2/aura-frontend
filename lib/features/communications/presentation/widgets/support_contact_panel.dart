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
          const Text('Support', style: AuraText.subtitle),
          const SizedBox(height: AuraSpace.s8),
          const Text(
            'Our AI support agent can help with account issues, safety concerns, privacy requests, and general questions. For sensitive matters it escalates directly to the Aura team.',
            style: AuraText.body,
          ),
          const SizedBox(height: AuraSpace.s12),
          AuraPrimaryButton(
            label: 'Open support agent',
            onPressed: () => context.go('/support/agent'),
            icon: Icons.support_agent_outlined,
          ),
        ],
      ),
    );
  }
}
