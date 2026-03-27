import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';
import '../application/realtime_providers.dart';
import '../domain/realtime_enums.dart';
import '../domain/realtime_models.dart';
import 'widgets/realtime_consent_sheet.dart';
import 'widgets/realtime_host_controls.dart';
import 'widgets/realtime_join_requests_panel.dart';
import 'widgets/realtime_participant_list.dart';
import 'widgets/realtime_status_strip.dart';

Map<String, dynamic> _unwrapResponseMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    if (value['data'] is Map<String, dynamic>) {
      return Map<String, dynamic>.from(value['data'] as Map<String, dynamic>);
    }
    if (value['data'] is Map) {
      return Map<String, dynamic>.from(value['data'] as Map);
    }
    return value;
  }
  if (value is Map) {
    final map = Map<String, dynamic>.from(value);
    final inner = map['data'];
    if (inner is Map<String, dynamic>) return inner;
    if (inner is Map) return Map<String, dynamic>.from(inner);
    return map;
  }
  return <String, dynamic>{};
}

final _realtimeCurrentUserProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/users/me');
  return _unwrapResponseMap(response.data);
});

class RealtimeRoomScreen extends ConsumerStatefulWidget {
  const RealtimeRoomScreen({
    super.key,
    required this.sessionId,
    this.action,
  });

  final String sessionId;
  final String? action;

  @override
  ConsumerState<RealtimeRoomScreen> createState() => _RealtimeRoomScreenState();
}

class _RealtimeRoomScreenState extends ConsumerState<RealtimeRoomScreen> {
  bool _didBoot = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didBoot) return;
    _didBoot = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final controller = ref.read(realtimeControllerProvider.notifier);
      final action = (widget.action ?? '').trim().toLowerCase();

      if (action == 'join') {
        await controller.join(widget.sessionId);
      } else if (action == 'resume') {
        await controller.resume(widget.sessionId);
      } else {
        await controller.hydrateSession(widget.sessionId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(realtimeControllerProvider);
    final controller = ref.read(realtimeControllerProvider.notifier);
    final meAsync = ref.watch(_realtimeCurrentUserProvider);

    final myUserId = meAsync.maybeWhen(
      data: (me) => (me['id'] ?? '').toString(),
      orElse: () => '',
    );

    RealtimeParticipant? myParticipant;
    for (final participant in state.participants) {
      if (participant.userId == myUserId) {
        myParticipant = participant;
        break;
      }
    }

    final canModerate = myParticipant?.isModerator ?? false;
    final policy = state.policy;
    final roomIsClosed = state.session?.isLocked == true || policy?.isLocked == true;
    final roomTitle = _roomTitle(state.session);
    final roomSubtitle = _roomSubtitle(state.session, state.joinState);

    return AuraScaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text(roomTitle, style: AuraText.title),
          const SizedBox(height: AuraSpace.s4),
          Text(
            roomSubtitle,
            style: AuraText.small.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: AuraSpace.s12),
          RealtimeStatusStrip(state: state),
          const SizedBox(height: AuraSpace.s12),
          if ((state.errorMessage ?? '').isNotEmpty) ...[
            AuraCard(child: Text(state.errorMessage!, style: AuraText.body)),
            const SizedBox(height: AuraSpace.s12),
          ],
          if ((state.infoMessage ?? '').isNotEmpty) ...[
            AuraCard(child: Text(state.infoMessage!, style: AuraText.small)),
            const SizedBox(height: AuraSpace.s12),
          ],
          _RoomOverviewCard(
            session: state.session,
            policy: policy,
            participantCount: state.participants.length,
          ),
          const SizedBox(height: AuraSpace.s12),
          RealtimeConsentSheet(
            currentUserId: myUserId.isEmpty ? null : myUserId,
            consents: state.consents,
          ),
          if (state.consents.isNotEmpty) const SizedBox(height: AuraSpace.s12),
          if (canModerate) ...[
            RealtimeHostControls(
              session: state.session,
              policy: policy,
              onToggleWaitingRoom: controller.setWaitingRoom,
              onToggleLock: controller.setLocked,
              onRequestConsent: controller.requestConsent,
              onRequestRecording: controller.requestRecording,
              onRequestTranscript: controller.requestTranscript,
              onRefresh: () => controller.hydrateSession(widget.sessionId),
            ),
            const SizedBox(height: AuraSpace.s12),
            RealtimeJoinRequestsPanel(
              requests: policy?.joinRequests ?? const [],
              onApprove: controller.approveJoinRequest,
              onReject: controller.rejectJoinRequest,
            ),
            const SizedBox(height: AuraSpace.s12),
          ],
          RealtimeParticipantList(
            participants: state.participants,
            canModerate: canModerate,
            onRemove: controller.removeParticipant,
          ),
          const SizedBox(height: AuraSpace.s12),
          _ArtifactBlock(
            policy: policy,
            recordingCount: state.recordings.length,
            transcriptCount: state.transcripts.length,
            artifactCount: state.artifacts.length,
          ),
          const SizedBox(height: AuraSpace.s16),
          Wrap(
            spacing: AuraSpace.s8,
            runSpacing: AuraSpace.s8,
            children: [
              OutlinedButton(
                onPressed: () => controller.hydrateSession(widget.sessionId),
                child: const Text('Refresh room'),
              ),
              OutlinedButton(
                onPressed: controller.leave,
                child: const Text('Leave room'),
              ),
              if (state.joinState != RealtimeJoinState.joined)
                FilledButton(
                  onPressed: () => controller.join(widget.sessionId),
                  child: const Text('Enter room'),
                ),
              if (state.joinState == RealtimeJoinState.locked ||
                  state.joinState == RealtimeJoinState.rejected ||
                  state.joinState == RealtimeJoinState.failed ||
                  roomIsClosed)
                OutlinedButton(
                  onPressed: () => controller.requestJoin(widget.sessionId),
                  child: Text(
                    policy?.waitingRoomEnabled == true || roomIsClosed
                        ? 'Request entry'
                        : 'Try again',
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _roomTitle(RealtimeSession? session) {
    if (session == null) return 'Live Room';
    switch (session.surfaceType) {
      case RealtimeSurfaceType.dm:
        return 'Live Correspondence';
      case RealtimeSurfaceType.space:
        return 'Live Space';
      case RealtimeSurfaceType.institution:
        return 'Institution Room';
      case RealtimeSurfaceType.unknown:
        return 'Live Room';
    }
  }

  String _roomSubtitle(RealtimeSession? session, RealtimeJoinState joinState) {
    if (joinState == RealtimeJoinState.joined) return 'You are in the room.';
    if (joinState == RealtimeJoinState.requested) return 'Your entry request is pending.';
    if (session?.isActive == false) return 'This room has ended.';
    if (session?.isLocked == true) return 'Closed to new entries.';
    return 'Active now.';
  }
}

class _RoomOverviewCard extends StatelessWidget {
  const _RoomOverviewCard({
    required this.session,
    required this.policy,
    required this.participantCount,
  });

  final RealtimeSession? session;
  final RealtimePolicy? policy;
  final int participantCount;

  @override
  Widget build(BuildContext context) {
    final isLive = session?.isActive != false;
    final isClosed = session?.isLocked == true;
    final requestsOn = policy?.waitingRoomEnabled == true;

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isLive ? 'Room is live' : 'Room has ended',
            style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AuraSpace.s8),
          Text(
            isClosed ? 'Closed to new entries' : 'Open to members',
            style: AuraText.body,
          ),
          Text(
            requestsOn ? 'Entry requests enabled' : 'Direct entry available',
            style: AuraText.body,
          ),
          Text(
            participantCount == 1 ? '1 in the room' : '$participantCount in the room',
            style: AuraText.body,
          ),
        ],
      ),
    );
  }
}

class _ArtifactBlock extends StatelessWidget {
  const _ArtifactBlock({
    required this.policy,
    required this.recordingCount,
    required this.transcriptCount,
    required this.artifactCount,
  });

  final RealtimePolicy? policy;
  final int recordingCount;
  final int transcriptCount;
  final int artifactCount;

  @override
  Widget build(BuildContext context) {
    final recordingLabel = policy?.canRecord == true
        ? 'Recordings: $recordingCount'
        : 'Recording unavailable in this room';
    final transcriptLabel = policy?.canTranscribe == true
        ? 'Live notes: $transcriptCount'
        : 'Live notes unavailable in this room';

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Room output',
            style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AuraSpace.s8),
          Text(recordingLabel, style: AuraText.small),
          Text(transcriptLabel, style: AuraText.small),
          Text('Saved artifacts: $artifactCount', style: AuraText.small),
        ],
      ),
    );
  }
}
