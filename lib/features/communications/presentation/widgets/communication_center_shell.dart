import 'package:flutter/material.dart';

import '../../../../core/ui/aura_space.dart';
import '../../domain/communications_models.dart';
import 'communication_empty_error_states.dart';
import 'communication_role_hero.dart';
import 'communication_status_cards.dart';
import 'member_communication_overview.dart';

class CommunicationCenterShell extends StatelessWidget {
  const CommunicationCenterShell({
    super.key,
    required this.preferences,
    required this.loading,
    required this.error,
    required this.savingKeys,
    required this.onLoad,
    required this.onChannelChanged,
    required this.onFrequencyChanged,
    required this.isAdmin,
  });

  final CommunicationPreferences? preferences;
  final bool loading;
  final String? error;
  final Set<String> savingKeys;
  final VoidCallback onLoad;
  final void Function(String key, CommunicationChannelOption value)
      onChannelChanged;
  final void Function(String key, CommunicationFrequencyOption value)
      onFrequencyChanged;
  // Synchronous display gate — populated from
  // `appAdminCachedDisplayProvider`. Never triggers an `/admin/me` probe.
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CommunicationRoleHero(
          preferences: preferences,
          isAdmin: isAdmin,
        ),
        const SizedBox(height: AuraSpace.s16),
        CommunicationStatusCards(
          preferences: preferences,
          isAdmin: isAdmin,
        ),
        const SizedBox(height: AuraSpace.s16),
        if (loading)
          const CommLoadingState(
            message: 'Loading communication settings…',
          )
        else if (error != null)
          CommErrorState(
            title: 'Could not load communication settings',
            body: error!,
            onRetry: onLoad,
          )
        else if (preferences != null)
          MemberCommunicationOverview(
            preferences: preferences!,
            savingKeys: savingKeys,
            onChannelChanged: onChannelChanged,
            onFrequencyChanged: onFrequencyChanged,
          ),
      ],
    );
  }
}
