import 'package:flutter/material.dart';

import '../../../../core/ui/aura_card.dart';
import '../../../../core/ui/aura_space.dart';
import '../../../../core/ui/aura_text.dart';
import '../../domain/realtime_models.dart';

class RealtimeHostControls extends StatelessWidget {
  const RealtimeHostControls({
    super.key,
    required this.session,
    required this.policy,
    required this.onToggleWaitingRoom,
    required this.onToggleLock,
    required this.onRequestConsent,
    required this.onRequestRecording,
    required this.onRequestTranscript,
    required this.onRefresh,
  });

  final RealtimeSession? session;
  final RealtimePolicy? policy;
  final ValueChanged<bool> onToggleWaitingRoom;
  final ValueChanged<bool> onToggleLock;
  final VoidCallback onRequestConsent;
  final VoidCallback onRequestRecording;
  final VoidCallback onRequestTranscript;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final waitingRoom = policy?.waitingRoomEnabled ?? false;
    final locked = session?.isLocked ?? policy?.isLocked ?? false;
    final canRecord = policy?.canRecord ?? false;
    final canTranscribe = policy?.canTranscribe ?? false;

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Room controls', style: AuraText.title),
          const SizedBox(height: AuraSpace.s8),
          Text(
            'Manage entry, room access, and what this room is allowed to produce.',
            style: AuraText.muted,
          ),
          const SizedBox(height: AuraSpace.s12),
          SwitchListTile(
            value: waitingRoom,
            contentPadding: EdgeInsets.zero,
            title: const Text('Entry requests'),
            subtitle: const Text('Review who enters before they join the room.'),
            onChanged: onToggleWaitingRoom,
          ),
          SwitchListTile(
            value: locked,
            contentPadding: EdgeInsets.zero,
            title: const Text('Close room'),
            subtitle: Text(
              locked ? 'New entries are currently blocked.' : 'Anyone with access can still enter.',
            ),
            onChanged: onToggleLock,
          ),
          const SizedBox(height: AuraSpace.s8),
          Wrap(
            spacing: AuraSpace.s8,
            runSpacing: AuraSpace.s8,
            children: [
              OutlinedButton(
                onPressed: onRequestConsent,
                child: const Text('Request consent'),
              ),
              OutlinedButton(
                onPressed: canRecord ? onRequestRecording : null,
                child: Text(canRecord ? 'Request recording' : 'Recording unavailable'),
              ),
              OutlinedButton(
                onPressed: canTranscribe ? onRequestTranscript : null,
                child: Text(canTranscribe ? 'Request live notes' : 'Live notes unavailable'),
              ),
              OutlinedButton(
                onPressed: onRefresh,
                child: const Text('Refresh room'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
