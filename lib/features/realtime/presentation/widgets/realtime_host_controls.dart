import 'package:flutter/material.dart';

import '../../../../core/ui/aura_card.dart';
import '../../../../core/ui/aura_platform_components.dart';
import '../../../../core/ui/aura_radius.dart';
import '../../../../core/ui/aura_space.dart';
import '../../../../core/ui/aura_surface.dart';
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
    final waitingRoom = policy?.waitingRoomEnabled == true;
    final locked = session?.isLocked == true || policy?.isLocked == true;
    final canRecord = policy?.canRecord == true;
    final canTranscribe = policy?.canTranscribe == true;

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Room controls', style: AuraText.title),
          const SizedBox(height: AuraSpace.s8),
          const Text('Manage access and room behavior.', style: AuraText.muted),
          const SizedBox(height: AuraSpace.s12),
          SwitchListTile(
            value: waitingRoom,
            contentPadding: EdgeInsets.zero,
            title: const Text('Entry requests'),
            subtitle: Text(
              waitingRoom
                  ? 'New entries wait for approval before joining.'
                  : 'Anyone with access can enter directly.',
            ),
            onChanged: onToggleWaitingRoom,
          ),
          SwitchListTile(
            value: locked,
            contentPadding: EdgeInsets.zero,
            title: Text(locked ? 'Room is closed' : 'Room is open'),
            subtitle: Text(
              locked
                  ? 'New entries are blocked.'
                  : 'Anyone with access can enter.',
            ),
            onChanged: onToggleLock,
          ),
          const SizedBox(height: AuraSpace.s8),
          Wrap(
            spacing: AuraSpace.s8,
            runSpacing: AuraSpace.s8,
            children: [
              AuraSecondaryButton(
                label: 'Request consent',
                onPressed: onRequestConsent,
              ),
              if (canRecord)
                AuraSecondaryButton(
                  label: 'Request recording',
                  onPressed: onRequestRecording,
                )
              else
                const _PassivePill(label: 'Recording unavailable'),
              if (canTranscribe)
                AuraSecondaryButton(
                  label: 'Request live notes',
                  onPressed: onRequestTranscript,
                )
              else
                const _PassivePill(label: 'Live notes unavailable'),
              AuraSecondaryButton(label: 'Refresh room', onPressed: onRefresh),
            ],
          ),
        ],
      ),
    );
  }
}

class _PassivePill extends StatelessWidget {
  const _PassivePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s12,
        vertical: AuraSpace.s10,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: AuraSurface.divider),
        borderRadius: BorderRadius.circular(AuraRadius.pill),
      ),
      child: Text(
        label,
        style: AuraText.small.copyWith(
          color: AuraText.muted.color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
