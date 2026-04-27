import 'package:flutter/material.dart';

import '../../../../core/ui/aura_card.dart';
import '../../../../core/ui/aura_radius.dart';
import '../../../../core/ui/aura_space.dart';
import '../../../../core/ui/aura_surface.dart';
import '../../../../core/ui/aura_text.dart';
import '../../domain/realtime_state.dart';

class RealtimeStatusStrip extends StatelessWidget {
  const RealtimeStatusStrip({
    super.key,
    required this.state,
    required this.now,
  });

  final RealtimeState state;
  final DateTime now;

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
        return 'Entry declined';
      case 'removed':
        return 'Removed';
      case 'locked':
        return 'Room closed';
      case 'failed':
        return 'Unavailable';
      default:
        return 'Not entered';
    }
  }

  String? _durationLabel() {
    final session = state.session;
    if (session == null) return null;

    final startedAt =
        session.answeredAt ?? session.firstJoinedAt ?? session.startedAt ?? session.createdAt;
    if (startedAt == null) return null;

    final finishedAt = session.endedAt;
    final elapsed = finishedAt != null
        ? finishedAt.difference(startedAt)
        : now.difference(startedAt);
    final seconds = elapsed.inSeconds < 0 ? 0 : elapsed.inSeconds;
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    String two(int value) => value.toString().padLeft(2, '0');
    final formatted = hours > 0
        ? '${two(hours)}:${two(minutes)}:${two(secs)}'
        : '${two(minutes)}:${two(secs)}';

    if (finishedAt != null || session.status == 'ENDED') {
      return 'Ended after $formatted';
    }
    if (session.isActive) {
      return 'Live $formatted';
    }
    return 'Duration $formatted';
  }

  @override
  Widget build(BuildContext context) {
    final bits = <String>[
      _connectionLabel(),
      _entryLabel(),
      if (state.session?.isLocked == true) 'Closed to new entries',
      if (state.policy?.waitingRoomEnabled == true) 'Entry requests on',
      if (state.recordings.isNotEmpty) 'Recording ${state.recordings.first.status.name}',
      if (state.recordings.isEmpty && state.policy?.canRecord == false) 'Recording unavailable',
      if (state.transcripts.isNotEmpty) 'Live notes ${state.transcripts.first.status.name}',
      if (state.transcripts.isEmpty && state.policy?.canTranscribe == false) 'Live notes unavailable',
      if (_durationLabel() != null) _durationLabel()!,
    ];

    return AuraCard(
      child: Wrap(
        spacing: AuraSpace.s8,
        runSpacing: AuraSpace.s8,
        children: bits.map((bit) => _Chip(label: bit)).toList(),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s10,
        vertical: AuraSpace.s8,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: AuraSurface.divider),
        borderRadius: BorderRadius.circular(AuraRadius.pill),
      ),
      child: Text(
        label,
        style: AuraText.small.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}
