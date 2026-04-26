import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../../core/ui/aura_card.dart';
import '../../../../core/ui/aura_platform_components.dart';
import '../../../../core/ui/aura_space.dart';
import '../../../../core/ui/aura_text.dart';
import '../../domain/realtime_models.dart';

class RealtimeParticipantList extends StatelessWidget {
  const RealtimeParticipantList({
    super.key,
    required this.participants,
    required this.canModerate,
    required this.onRemove,
    required this.remoteRenderers,
    this.currentUserId,
    this.hostUserId,
  });

  final List<RealtimeParticipant> participants;
  final bool canModerate;
  final ValueChanged<String> onRemove;
  final Map<String, RTCVideoRenderer> remoteRenderers;
  final String? currentUserId;
  final String? hostUserId;

  String _displayName(RealtimeParticipant participant, int index) {
    final me = (currentUserId ?? '').trim();
    if (me.isNotEmpty && participant.userId == me) return 'You';
    if (participant.isHost ||
        ((hostUserId ?? '').isNotEmpty && participant.userId == hostUserId)) {
      return 'Room host';
    }
    if (participant.isModerator) {
      return 'Moderator ${index + 1}';
    }
    return 'Member ${index + 1}';
  }

  String _roleLabel(RealtimeParticipant participant) {
    if (participant.isHost ||
        ((hostUserId ?? '').isNotEmpty && participant.userId == hostUserId)) {
      return 'Room host';
    }
    if (participant.isModerator) return 'Moderator';
    switch (participant.role.name) {
      case 'guest':
        return 'Guest';
      default:
        return 'Member';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Members', style: AuraText.title),
          const SizedBox(height: AuraSpace.s8),
          Text(
            participants.isEmpty
                ? 'No one is in the room yet.'
                : participants.length == 1
                ? '1 person is here.'
                : '${participants.length} people are here.',
            style: AuraText.muted,
          ),
          if (participants.isNotEmpty) const SizedBox(height: AuraSpace.s12),
          if (participants.isNotEmpty)
            ...List.generate(participants.length, (index) {
              final participant = participants[index];
              final renderer = remoteRenderers[participant.userId];
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == participants.length - 1 ? 0 : AuraSpace.s10,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (renderer != null)
                      Container(
                        width: 92,
                        height: 68,
                        margin: const EdgeInsets.only(right: AuraSpace.s12),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: RTCVideoView(
                          renderer,
                          objectFit:
                              RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                        ),
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _displayName(participant, index),
                            style: AuraText.body.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: AuraSpace.s4),
                          Text(
                            [
                              _roleLabel(participant),
                              if (participant.audioOn) 'audio on',
                              if (participant.videoOn) 'camera on',
                              if (participant.screenOn) 'screen on',
                              if (!participant.isPresent) 'away',
                            ].join(' • '),
                            style: AuraText.small,
                          ),
                        ],
                      ),
                    ),
                    if (canModerate &&
                        participant.userId.isNotEmpty &&
                        participant.userId != (currentUserId ?? '').trim())
                      AuraSecondaryButton(
                        label: 'Remove',
                        onPressed: () => onRemove(participant.userId),
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
