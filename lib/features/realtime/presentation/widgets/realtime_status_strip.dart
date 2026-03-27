import 'package:flutter/material.dart';

import '../../../../core/ui/aura_card.dart';
import '../../../../core/ui/aura_space.dart';
import '../../../../core/ui/aura_text.dart';
import '../../domain/realtime_models.dart';
import '../../domain/realtime_state.dart';

class RealtimeStatusStrip extends StatelessWidget {
  const RealtimeStatusStrip({
    super.key,
    required this.state,
  });

  final RealtimeState state;

  @override
  Widget build(BuildContext context) {
    final bits = <_StatusBit>[
      _StatusBit('Connection', state.connectionStatus.name),
      _StatusBit('Join', state.joinState.name),
      if (state.session?.isLocked == true) const _StatusBit('Session', 'Locked'),
      if (state.policy?.waitingRoomEnabled == true)
        const _StatusBit('Entry', 'Waiting room'),
      if (state.recordings.isNotEmpty)
        _StatusBit('Recording', state.recordings.first.status.name),
      if (state.transcripts.isNotEmpty)
        _StatusBit('Transcript', state.transcripts.first.status.name),
      if (state.lastSocketEvent != null && state.lastSocketEvent!.trim().isNotEmpty)
        _StatusBit('Event', state.lastSocketEvent!),
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
