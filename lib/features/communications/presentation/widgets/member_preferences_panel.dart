import 'package:flutter/material.dart';

import '../../../../core/ui/aura_card.dart';
import '../../../../core/ui/aura_platform_components.dart';
import '../../../../core/ui/aura_space.dart';
import '../../../../core/ui/aura_surface.dart';
import '../../../../core/ui/aura_text.dart';
import '../../domain/communications_models.dart';

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
  final void Function(String key, CommunicationChannelOption value)
      onChannelChanged;
  final void Function(String key, CommunicationFrequencyOption value)
      onFrequencyChanged;

  static const _order = <String>[
    'social',
    'messages',
    'institutions',
    'announcements',
    'securityAuth',
    'support',
    'productUpdates',
    'newsletter',
    'digest',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AuraSectionHeader(
          title: 'Your preferences',
          subtitle:
              'Choose where each category lands and how often it should arrive.',
        ),
        const SizedBox(height: AuraSpace.s12),
        ..._order.map((key) {
          final group = preferences.group(key);
          if (group == null) return const SizedBox.shrink();
          final channelField = _channelFieldFor(key);
          final frequencyField = _frequencyFieldFor(key);
          return Padding(
            padding: const EdgeInsets.only(bottom: AuraSpace.s12),
            child: _PreferenceGroupCard(
              group: group,
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

class _PreferenceGroupCard extends StatelessWidget {
  const _PreferenceGroupCard({
    required this.group,
    required this.saving,
    required this.onChannelChanged,
    required this.onFrequencyChanged,
  });

  final CommunicationPreferenceGroup group;
  final bool saving;
  final ValueChanged<CommunicationChannelOption> onChannelChanged;
  final ValueChanged<CommunicationFrequencyOption> onFrequencyChanged;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(group.title, style: AuraText.subtitle),
                        ),
                        if (group.protected) ...[
                          const SizedBox(width: AuraSpace.s8),
                          const AuraStatusChip(
                            label: 'Transactional',
                            backgroundColor: AuraSurface.infoBg,
                            textColor: AuraSurface.infoInk,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AuraSpace.s4),
                    Text(group.subtitle, style: AuraText.muted),
                  ],
                ),
              ),
              if (saving) ...[
                const SizedBox(width: AuraSpace.s10),
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
          const SizedBox(height: AuraSpace.s12),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 620;
              final channelField = _DropdownField<CommunicationChannelOption>(
                label: 'Channel',
                value: group.channel,
                items: CommunicationChannelOption.values
                    .map(
                      (o) => DropdownMenuItem(
                        value: o,
                        child: Text(o.label),
                      ),
                    )
                    .toList(),
                onChanged:
                    saving ? null : (v) => v != null ? onChannelChanged(v) : null,
              );
              final frequencyField =
                  _DropdownField<CommunicationFrequencyOption>(
                label: 'Frequency',
                value: group.frequency,
                items: CommunicationFrequencyOption.values
                    .map(
                      (o) => DropdownMenuItem(
                        value: o,
                        child: Text(o.label),
                      ),
                    )
                    .toList(),
                onChanged:
                    saving ? null : (v) => v != null ? onFrequencyChanged(v) : null,
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
  });

  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: items,
      onChanged: onChanged,
    );
  }
}
