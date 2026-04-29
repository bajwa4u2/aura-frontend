import 'package:flutter/material.dart';

import '../../../../core/ui/aura_space.dart';
import '../../../../core/ui/aura_surface.dart';
import '../../../../core/ui/aura_text.dart';
import '../../domain/communications_models.dart';
import 'digest_preferences_panel.dart';
import 'member_preferences_panel.dart';

class MemberCommunicationOverview extends StatelessWidget {
  const MemberCommunicationOverview({
    super.key,
    required this.preferences,
    required this.savingKeys,
    required this.onChannelChanged,
    required this.onFrequencyChanged,
  });

  final CommunicationPreferences preferences;
  final Set<String> savingKeys;
  final void Function(String key, CommunicationChannelOption value)
      onChannelChanged;
  final void Function(String key, CommunicationFrequencyOption value)
      onFrequencyChanged;

  @override
  Widget build(BuildContext context) {
    final initialFrequency =
        preferences.group('digest')?.frequency ??
            CommunicationFrequencyOption.dailyDigest;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel(
          icon: Icons.tune_rounded,
          label: 'Your communication',
          badge: null,
        ),
        const SizedBox(height: AuraSpace.s16),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 860;
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: MemberPreferencesPanel(
                      preferences: preferences,
                      savingKeys: savingKeys,
                      onChannelChanged: onChannelChanged,
                      onFrequencyChanged: onFrequencyChanged,
                    ),
                  ),
                  const SizedBox(width: AuraSpace.s20),
                  Expanded(
                    flex: 2,
                    child: DigestPreferencesPanel(
                      initialFrequency: initialFrequency,
                    ),
                  ),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MemberPreferencesPanel(
                  preferences: preferences,
                  savingKeys: savingKeys,
                  onChannelChanged: onChannelChanged,
                  onFrequencyChanged: onFrequencyChanged,
                ),
                const SizedBox(height: AuraSpace.s16),
                DigestPreferencesPanel(initialFrequency: initialFrequency),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.icon,
    required this.label,
    required this.badge,
  });

  final IconData icon;
  final String label;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AuraSurface.muted),
        const SizedBox(width: AuraSpace.s8),
        Text(
          label,
          style: AuraText.label.copyWith(
            color: AuraSurface.muted,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
          ),
        ),
        if (badge != null) ...[
          const SizedBox(width: AuraSpace.s8),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AuraSpace.s8,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: AuraSurface.accentSoft,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              badge!,
              style: AuraText.micro.copyWith(color: AuraSurface.accentText),
            ),
          ),
        ],
      ],
    );
  }
}
