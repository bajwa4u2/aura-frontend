import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/ui/aura_card.dart';
import '../../../../core/ui/aura_platform_components.dart';
import '../../../../core/ui/aura_space.dart';
import '../../../../core/ui/aura_text.dart';
import '../../domain/communications_models.dart';

class CommunicationRoleHero extends StatelessWidget {
  const CommunicationRoleHero({
    super.key,
    required this.preferences,
    required this.isAdmin,
  });

  final CommunicationPreferences? preferences;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AuraGradientHeader(
          title: 'Communication center',
          subtitle: isAdmin
              ? 'Member preferences and protected admin communication operations in one workspace.'
              : 'Control how Aura reaches you — set channels, digest schedule, and notification delivery.',
        ),
        const SizedBox(height: AuraSpace.s16),
        _DeliveryPostureCard(preferences: preferences, isAdmin: isAdmin),
      ],
    );
  }
}

class _DeliveryPostureCard extends StatelessWidget {
  const _DeliveryPostureCard({
    required this.preferences,
    required this.isAdmin,
  });

  final CommunicationPreferences? preferences;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Delivery posture', style: AuraText.subtitle),
          const SizedBox(height: AuraSpace.s8),
          const Text(
            'In-app is the primary channel. Email is reserved for important, digest, support, and security communication.',
            style: AuraText.body,
          ),
          const SizedBox(height: AuraSpace.s12),
          Wrap(
            spacing: AuraSpace.s10,
            runSpacing: AuraSpace.s10,
            children: [
              AuraBadge(
                label: preferences?.inAppEnabled == true
                    ? 'In-app enabled'
                    : 'In-app disabled',
                icon: Icons.chat_bubble_outline,
              ),
              AuraBadge(
                label: preferences?.emailEnabled == true
                    ? 'Email enabled'
                    : 'Email disabled',
                icon: Icons.mail_outline,
              ),
              const AuraBadge(
                label: 'Transactional support/security always visible',
                icon: Icons.verified_outlined,
              ),
              if (isAdmin)
                const AuraBadge(
                  label: 'Admin workspace active',
                  icon: Icons.admin_panel_settings_outlined,
                ),
            ],
          ),
          if (isAdmin) ...[
            const SizedBox(height: AuraSpace.s16),
            AuraSecondaryButton(
              label: 'Open admin workspace',
              onPressed: () => context.go('/admin'),
              icon: Icons.admin_panel_settings_outlined,
            ),
          ],
        ],
      ),
    );
  }
}
