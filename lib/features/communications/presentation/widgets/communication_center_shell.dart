import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/admin_access_provider.dart';
import '../../../../core/ui/aura_space.dart';
import '../../domain/communications_models.dart';
import 'admin_communication_workspace.dart';
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
    required this.adminAsync,
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
  final AsyncValue<AppAdminAccess> adminAsync;

  bool get _isAdmin => adminAsync.maybeWhen(
        data: (v) => v.isAdmin,
        orElse: () => false,
      );

  bool get _adminLoading => adminAsync.isLoading;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CommunicationRoleHero(
          preferences: preferences,
          isAdmin: _isAdmin,
        ),
        const SizedBox(height: AuraSpace.s16),
        CommunicationStatusCards(
          preferences: preferences,
          isAdmin: _isAdmin,
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
        else if (preferences != null) ...[
          MemberCommunicationOverview(
            preferences: preferences!,
            savingKeys: savingKeys,
            onChannelChanged: onChannelChanged,
            onFrequencyChanged: onFrequencyChanged,
          ),
          if (_isAdmin) ...[
            const SizedBox(height: AuraSpace.s32),
            const AdminCommunicationWorkspace(),
          ] else if (_adminLoading) ...[
            const SizedBox(height: AuraSpace.s16),
            const CommLoadingState(
              message: 'Loading protected communication tools…',
            ),
          ],
        ],
      ],
    );
  }
}
