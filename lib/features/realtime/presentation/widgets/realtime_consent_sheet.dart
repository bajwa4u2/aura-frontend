import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/aura_card.dart';
import '../../../../core/ui/aura_platform_components.dart';
import '../../../../core/ui/aura_space.dart';
import '../../../../core/ui/aura_text.dart';
import '../../application/realtime_providers.dart';
import '../../domain/realtime_enums.dart';
import '../../domain/realtime_models.dart';

class RealtimeConsentSheet extends ConsumerWidget {
  const RealtimeConsentSheet({
    super.key,
    required this.currentUserId,
    required this.consents,
  });

  final String? currentUserId;
  final List<RealtimeConsent> consents;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mine = consents.where((c) => c.userId == currentUserId).toList();
    if (mine.isEmpty) {
      return const SizedBox.shrink();
    }

    final latest = mine.first;
    if (latest.status != RealtimeConsentStatus.pending) {
      return const SizedBox.shrink();
    }

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Consent requested', style: AuraText.title),
          const SizedBox(height: AuraSpace.s8),
          const Text(
            'The room host is asking for a fresh consent decision before continuing.',
            style: AuraText.body,
          ),
          const SizedBox(height: AuraSpace.s12),
          Row(
            children: [
              Expanded(
                child: AuraSecondaryButton(
                  label: 'Decline',
                  onPressed: () async {
                    await ref
                        .read(realtimeControllerProvider.notifier)
                        .answerConsent(granted: false);
                  },
                ),
              ),
              const SizedBox(width: AuraSpace.s8),
              Expanded(
                child: AuraPrimaryButton(
                  label: 'Grant',
                  onPressed: () async {
                    await ref
                        .read(realtimeControllerProvider.notifier)
                        .answerConsent(granted: true);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
