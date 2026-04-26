import 'package:flutter/material.dart';

import '../core/ui/aura_card.dart';
import '../core/ui/aura_design_system.dart';
import '../core/ui/aura_platform_components.dart';
import '../core/ui/aura_scaffold.dart';
import '../core/ui/aura_space.dart';
import '../core/ui/aura_text.dart';

class SupportFallbackScreen extends StatelessWidget {
  const SupportFallbackScreen({super.key, required this.handle});

  final String handle;

  @override
  Widget build(BuildContext context) {
    return AuraScaffold(
      title: 'Support',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AuraSpace.lg,
          AuraSpace.lg,
          AuraSpace.lg,
          AuraSpace.xl,
        ),
        children: [
          AuraGradientHero(
            badge: 'Support and guidance',
            title: 'Support @${handle.trim()}',
            subtitle: 'A calm fallback while the full support surface is reconciled.',
            actions: const [
              AuraTrustBadge(label: 'Trusted help'),
              AuraTrustBadge(label: 'Account care', icon: Icons.support_agent_rounded),
            ],
            metrics: const [
              AuraMetricCard(label: 'Response', value: 'Accountable'),
              AuraMetricCard(label: 'Help path', value: 'Documented'),
              AuraMetricCard(label: 'Status', value: 'Fallback'),
            ],
          ),
          const SizedBox(height: AuraSpace.lg),
          AuraCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('How support works', style: AuraText.title),
                const SizedBox(height: AuraSpace.s10),
                Text(
                  'Aura support is routed through the primary contact and document surfaces until the dedicated support workspace is fully restored.',
                  style: AuraText.body,
                ),
                const SizedBox(height: AuraSpace.s12),
                const AuraTrustBadge(label: 'Fallback route active'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
