import 'package:flutter/material.dart';

import '../../../../core/ui/aura_card.dart';
import '../../../../core/ui/aura_platform_components.dart';
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

  String _requestLabel(int index) => 'Member ${index + 1}';

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Entry requests', style: AuraText.title),
          const SizedBox(height: AuraSpace.s8),
          Text(
            requests.isEmpty
                ? 'No one is waiting right now.'
                : 'Review who can enter next.',
            style: AuraText.muted,
          ),
          if (requests.isNotEmpty) const SizedBox(height: AuraSpace.s12),
          if (requests.isNotEmpty)
            ...List.generate(requests.length, (index) {
              final request = requests[index];
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == requests.length - 1 ? 0 : AuraSpace.s10,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _requestLabel(index),
                        style: AuraText.body.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    AuraSecondaryButton(
                      label: 'Decline',
                      onPressed: () => onReject(request.userId),
                    ),
                    const SizedBox(width: AuraSpace.s8),
                    AuraPrimaryButton(
                      label: 'Allow in',
                      onPressed: () => onApprove(request.userId),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
