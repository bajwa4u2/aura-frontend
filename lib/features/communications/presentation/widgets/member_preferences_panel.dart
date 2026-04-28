import 'package:flutter/material.dart';

import '../../../../core/ui/aura_card.dart';
import '../../../../core/ui/aura_platform_components.dart';
import '../../../../core/ui/aura_space.dart';
import '../../../../core/ui/aura_surface.dart';
import '../../../../core/ui/aura_text.dart';
import '../../domain/communications_models.dart';

// ── Category display metadata ─────────────────────────────────────────────────

class _CategoryMeta {
  const _CategoryMeta({
    required this.icon,
    required this.description,
  });

  final IconData icon;
  final String description;
}

const _categoryMeta = <String, _CategoryMeta>{
  'social': _CategoryMeta(
    icon: Icons.people_outline,
    description:
        'Follows, likes, replies, reposts, and mentions. Set to digest to '
        'receive a single summary instead of individual emails.',
  ),
  'messages': _CategoryMeta(
    icon: Icons.chat_bubble_outline,
    description:
        'Direct messages and thread invitations. You control whether these '
        'arrive instantly, as a digest, or only inside the app.',
  ),
  'institutions': _CategoryMeta(
    icon: Icons.account_balance_outlined,
    description:
        'Space and institution invitations. These arrive promptly so you '
        'never miss an invite.',
  ),
  'announcements': _CategoryMeta(
    icon: Icons.campaign_outlined,
    description:
        'Community and platform announcements from your spaces and from Aura. '
        'Set to digest or in-app only to reduce email volume.',
  ),
  'securityAuth': _CategoryMeta(
    icon: Icons.shield_outlined,
    description:
        'Verification, password reset, new device alerts, and account '
        'security notices. Always delivered — cannot be disabled.',
  ),
  'support': _CategoryMeta(
    icon: Icons.support_agent_outlined,
    description:
        'Responses to support requests you have opened. '
        'Always delivered so you can follow up.',
  ),
  'productUpdates': _CategoryMeta(
    icon: Icons.rocket_launch_outlined,
    description:
        'Platform improvements, new features, and product news. '
        'Can be set to digest or disabled.',
  ),
  'newsletter': _CategoryMeta(
    icon: Icons.newspaper_outlined,
    description:
        'Curated newsletters from Aura. Always include an unsubscribe link. '
        'Set to none to stop receiving them.',
  ),
  'digest': _CategoryMeta(
    icon: Icons.inbox_outlined,
    description:
        'Daily or weekly summaries of activity you may have missed. '
        'Adjust the frequency or turn off entirely.',
  ),
};

// ── Panel ─────────────────────────────────────────────────────────────────────

class MemberPreferencesPanel extends StatelessWidget {
  const MemberPreferencesPanel({
    super.key,
    required this.preferences,
    required this.savingKeys,
    required this.onChannelChanged,
    required this.onFrequencyChanged,
  });

  final CommunicationPreferences preferences;
  final Set<String> savingKeys;
  final void Function(String key, CommunicationChannelOption value) onChannelChanged;
  final void Function(String key, CommunicationFrequencyOption value) onFrequencyChanged;

  static const _order = <String>[
    'security',
    'securityAuth',
    'support',
    'messages',
    'institutions',
    'announcements',
    'productUpdates',
    'newsletter',
    'digest',
    'social',
  ];

  String _channelFieldFor(String key) {
    if (key == 'securityAuth') return 'securityChannel';
    return '${key}Channel';
  }

  String _frequencyFieldFor(String key) {
    if (key == 'securityAuth') return 'securityFrequency';
    return '${key}Frequency';
  }

  @override
  Widget build(BuildContext context) {
    final visibleKeys =
        _order.where((key) => preferences.group(key) != null).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AuraSectionHeader(
          title: 'Your preferences',
          subtitle:
              'Choose where each category lands and how often it arrives. '
              'Transactional categories are always delivered and cannot be disabled.',
        ),
        const SizedBox(height: AuraSpace.s12),
        ...visibleKeys.map((key) {
          final group = preferences.group(key)!;
          final channelField = _channelFieldFor(key);
          final frequencyField = _frequencyFieldFor(key);
          final meta = _categoryMeta[key];

          return Padding(
            padding: const EdgeInsets.only(bottom: AuraSpace.s12),
            child: _PreferenceGroupCard(
              group: group,
              icon: meta?.icon,
              richDescription: meta?.description,
              saving: savingKeys.contains(channelField) ||
                  savingKeys.contains(frequencyField),
              onChannelChanged: (next) => onChannelChanged(key, next),
              onFrequencyChanged: (next) => onFrequencyChanged(key, next),
            ),
          );
        }),
      ],
    );
  }
}

// ── Card ──────────────────────────────────────────────────────────────────────

class _PreferenceGroupCard extends StatelessWidget {
  const _PreferenceGroupCard({
    required this.group,
    required this.saving,
    required this.onChannelChanged,
    required this.onFrequencyChanged,
    this.icon,
    this.richDescription,
  });

  final CommunicationPreferenceGroup group;
  final bool saving;
  final IconData? icon;
  final String? richDescription;
  final ValueChanged<CommunicationChannelOption> onChannelChanged;
  final ValueChanged<CommunicationFrequencyOption> onFrequencyChanged;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: group.protected
                        ? AuraSurface.infoBg
                        : AuraSurface.accentSoft,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    icon,
                    size: 16,
                    color: group.protected
                        ? AuraSurface.infoInk
                        : AuraSurface.accentText,
                  ),
                ),
                const SizedBox(width: AuraSpace.s12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            group.title,
                            style: AuraText.subtitle,
                          ),
                        ),
                        if (group.protected) ...[
                          const SizedBox(width: AuraSpace.s8),
                          const AuraStatusChip(
                            label: 'Transactional',
                            backgroundColor: AuraSurface.infoBg,
                            textColor: AuraSurface.infoInk,
                          ),
                        ],
                        if (saving) ...[
                          const SizedBox(width: AuraSpace.s10),
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AuraSurface.accentText,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AuraSpace.s4),
                    Text(
                      richDescription ?? group.subtitle,
                      style: AuraText.muted,
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Protected notice
          if (group.protected) ...[
            const SizedBox(height: AuraSpace.s10),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AuraSpace.s12,
                vertical: AuraSpace.s8,
              ),
              decoration: BoxDecoration(
                color: AuraSurface.infoBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.lock_outline,
                    size: 13,
                    color: AuraSurface.infoInk,
                  ),
                  const SizedBox(width: AuraSpace.s6),
                  Expanded(
                    child: Text(
                      'These communications are always delivered and cannot be disabled.',
                      style: AuraText.small.copyWith(
                        color: AuraSurface.infoInk,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: AuraSpace.s12),

          // Channel / frequency dropdowns
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 620;
              final channelField = _DropdownField<CommunicationChannelOption>(
                label: 'Channel',
                value: group.channel,
                enabled: !group.protected && !saving,
                items: CommunicationChannelOption.values
                    .map(
                      (o) => DropdownMenuItem(
                        value: o,
                        child: Text(o.label),
                      ),
                    )
                    .toList(),
                onChanged: (v) => v != null ? onChannelChanged(v) : null,
              );
              final frequencyField =
                  _DropdownField<CommunicationFrequencyOption>(
                label: 'Frequency',
                value: group.frequency,
                enabled: !group.protected && !saving,
                items: CommunicationFrequencyOption.values
                    .map(
                      (o) => DropdownMenuItem(
                        value: o,
                        child: Text(o.label),
                      ),
                    )
                    .toList(),
                onChanged: (v) => v != null ? onFrequencyChanged(v) : null,
              );
              if (wide) {
                return Row(
                  children: [
                    Expanded(child: channelField),
                    const SizedBox(width: AuraSpace.s12),
                    Expanded(child: frequencyField),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  channelField,
                  const SizedBox(height: AuraSpace.s12),
                  frequencyField,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        enabled: enabled,
      ),
      items: items,
      onChanged: enabled ? onChanged : null,
    );
  }
}
