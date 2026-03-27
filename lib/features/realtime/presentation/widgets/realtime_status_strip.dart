import 'package:flutter/material.dart';

import '../../../../core/ui/aura_card.dart';
import '../../../../core/ui/aura_space.dart';
import '../../../../core/ui/aura_text.dart';
import '../../domain/realtime_state.dart';

class RealtimeStatusStrip extends StatelessWidget {
  const RealtimeStatusStrip({
    super.key,
    required this.state,
  });

  final RealtimeState state;

  String _connectionLabel() {
    switch (state.connectionStatus.name) {
      case 'connected':
        return 'Connected';
      case 'connecting':
        return 'Connecting';
      case 'reconnecting':
        return 'Reconnecting';
      case 'error':
        return 'Connection issue';
      default:
        return 'Offline';
    }
  }

  String _entryLabel() {
    switch (state.joinState.name) {
      case 'joined':
        return 'In room';
      case 'joining':
        return 'Entering';
      case 'requested':
        return 'Request pending';
      case 'rejected':
        return 'Declined';
      case 'removed':
        return 'Removed';
      case 'locked':
        return 'Closed';
      case 'failed':
        return 'Unavailable';
      default:
        return 'Not entered';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bits = <_StatusBit>[
      _StatusBit('Connection', _connectionLabel()),
      _StatusBit('Room', _entryLabel()),
      if (state.session?.isLocked == true) const _StatusBit('Access', 'Closed'),
      if (state.policy?.waitingRoomEnabled == true) const _StatusBit('Entry', 'Requests on'),
      if (state.recordings.isNotEmpty)
        _StatusBit('Recording', state.recordings.first.status.name),
      if (state.recordings.isEmpty && state.policy?.canRecord == false)
        const _StatusBit('Recording', 'Unavailable'),
      if (state.transcripts.isNotEmpty)
        _StatusBit('Live notes', state.transcripts.first.status.name),
      if (state.transcripts.isEmpty && state.policy?.canTranscribe == false)
        const _StatusBit('Live notes', 'Unavailable'),
    ];

    return AuraCard(
      child: Wrap(
        spacing: AuraSpace.s8,
        runSpacing: AuraSpace.s8,
        children: bits.map((bit) => _Chip(bit: bit)).toList(),
      ),
    );
  }
}

class _StatusBit {
  const _StatusBit(this.label, this.value);
  final String label;
  final String value;
}

class _Chip extends StatelessWidget {
  const _Chip({required this.bit});

  final _StatusBit bit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s10,
        vertical: AuraSpace.s8,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: RichText(
        text: TextSpan(
          style: AuraText.small,
          children: [
            TextSpan(
              text: '${bit.label}: ',
              style: AuraText.small.copyWith(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: bit.value),
          ],
        ),
      ),
    );
  }
}
