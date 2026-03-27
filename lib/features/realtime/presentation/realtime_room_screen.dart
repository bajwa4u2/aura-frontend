import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/net/dio_provider.dart';
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

    return AuraScaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text('Realtime room', style: AuraText.title),
          const SizedBox(height: AuraSpace.s8),
          Text(
            state.sessionId ?? widget.sessionId,
            style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AuraSpace.s12),
          RealtimeStatusStrip(state: state),
          const SizedBox(height: AuraSpace.s12),
          if ((state.errorMessage ?? '').isNotEmpty) ...[
            Text(state.errorMessage!, style: AuraText.body),
            const SizedBox(height: AuraSpace.s12),
          ],
          if ((state.infoMessage ?? '').isNotEmpty) ...[
            Text(state.infoMessage!, style: AuraText.small),
            const SizedBox(height: AuraSpace.s12),
          ],
          RealtimeConsentSheet(
            currentUserId: myUserId.isEmpty ? null : myUserId,
            consents: state.consents,
          ),
          if (state.consents.isNotEmpty) const SizedBox(height: AuraSpace.s12),
          if (canModerate) ...[
            RealtimeHostControls(
              session: state.session,
              policy: state.policy,
              onToggleWaitingRoom: controller.setWaitingRoom,
              onToggleLock: controller.setLocked,
              onRequestConsent: controller.requestConsent,
              onRequestRecording: controller.requestRecording,
              onRequestTranscript: controller.requestTranscript,
              onRefresh: () => controller.hydrateSession(widget.sessionId),
            ),
            const SizedBox(height: AuraSpace.s12),
            RealtimeJoinRequestsPanel(
              requests: state.policy?.joinRequests ?? const [],
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
                child: const Text('Leave'),
              ),
              if (state.joinState != RealtimeJoinState.joined)
                FilledButton(
                  onPressed: () => controller.join(widget.sessionId),
                  child: const Text('Join now'),
                ),
              if (state.joinState == RealtimeJoinState.locked ||
                  state.joinState == RealtimeJoinState.rejected ||
                  state.joinState == RealtimeJoinState.failed)
                OutlinedButton(
                  onPressed: () => controller.requestJoin(widget.sessionId),
                  child: const Text('Request join'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ArtifactBlock extends StatelessWidget {
  const _ArtifactBlock({
    required this.recordingCount,
    required this.transcriptCount,
    required this.artifactCount,
  });

  final int recordingCount;
  final int transcriptCount;
  final int artifactCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AuraSpace.s12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Artifacts',
            style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AuraSpace.s8),
          Text('Recordings: $recordingCount', style: AuraText.small),
          Text('Transcripts: $transcriptCount', style: AuraText.small),
          Text('Artifacts: $artifactCount', style: AuraText.small),
        ],
      ),
    );
  }
}
