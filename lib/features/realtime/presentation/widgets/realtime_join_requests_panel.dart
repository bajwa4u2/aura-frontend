import 'package:flutter/material.dart';

import '../../../../core/ui/aura_card.dart';
import '../../../../core/ui/aura_space.dart';
import '../../../../core/ui/aura_text.dart';
import '../../domain/realtime_models.dart';

class RealtimeJoinRequestsPanel extends StatelessWidget {
  const RealtimeJoinRequestsPanel({
    super.key,
    required this.requests,
    required this.onApprove,
    required this.onReject,
  });

  final List<RealtimeJoinRequest> requests;
  final ValueChanged<String> onApprove;
  final ValueChanged<String> onReject;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Entry requests', style: AuraText.title),
          const SizedBox(height: AuraSpace.s12),
          if (requests.isEmpty)
            Text('No one is waiting right now.', style: AuraText.muted)
          else
            ...requests.map(
              (request) => Padding(
                padding: const EdgeInsets.only(bottom: AuraSpace.s10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        request.userId,
                        style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () => onReject(request.userId),
                      child: const Text('Decline'),
                    ),
                    const SizedBox(width: AuraSpace.s8),
                    FilledButton(
                      onPressed: () => onApprove(request.userId),
                      child: const Text('Allow in'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
