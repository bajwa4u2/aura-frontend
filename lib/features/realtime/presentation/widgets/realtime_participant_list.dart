import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../../core/ui/aura_card.dart';
import '../../../../core/ui/aura_platform_components.dart';
import '../../../../core/ui/aura_space.dart';
import '../../../../core/ui/aura_text.dart';
import '../../domain/realtime_enums.dart';
import '../../domain/realtime_models.dart';

class RealtimeParticipantList extends StatelessWidget {
  const RealtimeParticipantList({
    super.key,
    required this.participants,
    required this.session,
    required this.canModerate,
    required this.onRemove,
    required this.remoteRenderers,
    this.currentUserId,
    this.hostUserId,
  });

  final List<RealtimeParticipant> participants;
  final RealtimeSession? session;
  final bool canModerate;
  final ValueChanged<String> onRemove;
  final Map<String, RTCVideoRenderer> remoteRenderers;
  final String? currentUserId;
  final String? hostUserId;

  String _roleLabel(RealtimeParticipant participant) {
    final explicit = participant.displayRole?.trim() ?? '';
    if (explicit.isNotEmpty) {
      return explicit
          .replaceAll('_', ' ')
          .split(' ')
          .where((part) => part.isNotEmpty)
          .map((part) => part[0].toUpperCase() + part.substring(1))
          .join(' ');
    }

    final surface = session?.surfaceType;
    final me = (currentUserId ?? '').trim();
    final startedBy = (hostUserId ?? '').trim();

    if (participant.userId == me) return 'You';
    if (surface == RealtimeSurfaceType.dm || surface == RealtimeSurfaceType.thread) {
      if (startedBy.isNotEmpty && participant.userId == startedBy) {
        return 'Caller';
      }
      return 'Invitee';
    }
    if (participant.isHost ||
        (startedBy.isNotEmpty && participant.userId == startedBy)) {
      return 'Host';
    }
    if (participant.isModerator) return 'Moderator';
    if ((participant.institutionRole ?? '').toUpperCase() == 'ADMIN' ||
        (participant.institutionName ?? '').trim().isNotEmpty && participant.displayRole == 'institution admin') {
      return 'Institution admin';
    }
    return participant.roleLabel;
  }

  String _joinStateLabel(RealtimeParticipant participant) {
    final value = participant.joinState.trim().toUpperCase();
    switch (value) {
      case 'ACTIVE':
        return 'Joined';
      case 'JOINING':
        return 'Joining';
      case 'INVITED':
        return 'Ringing';
      case 'LEFT':
        return 'Left';
      case 'REMOVED':
        return 'Removed';
      case 'DISCONNECTED':
        return 'Reconnecting';
      case 'DECLINED':
        return 'Declined';
      case 'MISSED':
        return 'Missed';
      case 'RECONNECTING':
        return 'Reconnecting';
      default:
        return value.isEmpty ? 'Joined' : value[0] + value.substring(1).toLowerCase();
    }
  }

  String _mediaStateLabel(RealtimeParticipant participant) {
    final bits = <String>[
      if (!participant.audioOn) 'Mic muted',
      if (!participant.videoOn) 'Camera off',
      if (participant.screenOn) 'Screen sharing',
    ];
    return bits.isEmpty ? 'Media on' : bits.join(' • ');
  }

  String _displayName(RealtimeParticipant participant, int index) {
    final me = (currentUserId ?? '').trim();
    if (me.isNotEmpty && participant.userId == me) return 'You';
    final name = participant.displayName?.trim() ?? '';
    if (name.isNotEmpty) return name;
    final handle = participant.handle?.trim() ?? '';
    if (handle.isNotEmpty) return '@$handle';
    if (participant.isHost ||
        ((hostUserId ?? '').isNotEmpty && participant.userId == hostUserId)) {
      return 'Room host';
    }
    if (participant.isModerator) {
      return 'Moderator ${index + 1}';
    }
    return 'Participant ${index + 1}';
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
              final name = _displayName(participant, index);
              final roleLabel = _roleLabel(participant);
              final joinLabel = _joinStateLabel(participant);
              final mediaLabel = _mediaStateLabel(participant);
              final subtitleBits = <String>[
                if ((participant.handle ?? '').trim().isNotEmpty &&
                    participant.displayName?.trim() != participant.handle?.trim())
                  '@${participant.handle}',
                if ((participant.institutionTitle ?? '').trim().isNotEmpty)
                  participant.institutionTitle!.trim(),
                if ((participant.institutionName ?? '').trim().isNotEmpty)
                  participant.institutionName!.trim(),
              ];

              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == participants.length - 1 ? 0 : AuraSpace.s10,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
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
                                  RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.only(right: AuraSpace.s12),
                            child: AuraAvatar(
                              name: name,
                              imageUrl: participant.avatarUrl,
                              size: 48,
                            ),
                          ),
                      ],
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: AuraText.body.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (subtitleBits.isNotEmpty) ...[
                            const SizedBox(height: AuraSpace.s4),
                            Text(
                              subtitleBits.join(' • '),
                              style: AuraText.small,
                            ),
                          ],
                          const SizedBox(height: AuraSpace.s4),
                          Wrap(
                            spacing: AuraSpace.s6,
                            runSpacing: AuraSpace.s6,
                            children: [
                              AuraStatusChip(label: roleLabel),
                              AuraStatusChip(label: joinLabel),
                              AuraStatusChip(label: mediaLabel),
                              if (!participant.isPresent)
                                const AuraStatusChip(label: 'Away'),
                            ],
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
