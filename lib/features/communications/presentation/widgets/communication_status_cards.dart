import 'package:flutter/material.dart';

import '../../../../core/ui/aura_platform_components.dart';
import '../../../../core/ui/aura_space.dart';
import '../../domain/communications_models.dart';

class CommunicationStatusCards extends StatelessWidget {
  const CommunicationStatusCards({
    super.key,
    required this.preferences,
    required this.isAdmin,
  });

  final CommunicationPreferences? preferences;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final prefs = preferences;
    final inApp = prefs?.inAppEnabled == true;
    final email = prefs?.emailEnabled == true;
    final digestLabel = prefs?.group('digest')?.frequency.label ?? '—';

    return Wrap(
      spacing: AuraSpace.s12,
      runSpacing: AuraSpace.s12,
      children: [
        _card(
          label: 'In-app',
          value: prefs == null ? '—' : (inApp ? 'On' : 'Off'),
          subtext: 'Primary signal',
        ),
        _card(
          label: 'Email',
          value: prefs == null ? '—' : (email ? 'On' : 'Off'),
          subtext: 'Reserved and digest driven',
        ),
        _card(
          label: 'Digest',
          value: digestLabel,
          subtext: 'Preview before creating',
        ),
        _card(
          label: 'Admin tools',
          value: isAdmin ? 'Available' : 'Hidden',
          subtext: 'Protected communication workspace',
        ),
      ],
    );
  }

  Widget _card({
    required String label,
    required String value,
    required String subtext,
  }) {
    return SizedBox(
      width: 230,
      child: AuraMetricCard(label: label, value: value, subtext: subtext),
    );
  }
}
