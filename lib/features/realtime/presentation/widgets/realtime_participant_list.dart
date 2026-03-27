import 'package:flutter/material.dart';

import '../../../../core/ui/aura_card.dart';
import '../../../../core/ui/aura_space.dart';
import '../../../../core/ui/aura_text.dart';
import '../../domain/realtime_models.dart';

class RealtimeParticipantList extends StatelessWidget {
  const RealtimeParticipantList({
    super.key,
    required this.participants,
    required this.canModerate,
    required this.onRemove,
  });

  final List<RealtimeParticipant> participants;
  final bool canModerate;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Participants', style: AuraText.title),
          const SizedBox(height: AuraSpace.s12),
          if (participants.isEmpty)
            Text('No participants yet.', style: AuraText.muted)
          else
            ...participants.map(
              (participant) => Padding(
                padding: const EdgeInsets.only(bottom: AuraSpace.s10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            participant.userId,
                            style: AuraText.body.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: AuraSpace.s4),
                          Text(
                            [
                              participant.role.name,
                              if (participant.audioOn) 'audio on',
                              if (participant.videoOn) 'video on',
                              if (participant.screenOn) 'screen on',
                              if (!participant.isPresent) 'not present',
                            ].join(' • '),
                            style: AuraText.small,
                          ),
                        ],
                      ),
                    ),
                    if (canModerate && participant.userId.isNotEmpty)
                      OutlinedButton(
                        onPressed: () => onRemove(participant.userId),
                        child: const Text('Remove'),
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
