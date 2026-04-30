import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../search/search_repository.dart';
import '../application/realtime_controller.dart';
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

final _realtimeCurrentUserProvider = FutureProvider<Map<String, dynamic>>((
  ref,
) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/users/me');
  return _unwrapResponseMap(response.data);
});

class RealtimeRoomScreen extends ConsumerStatefulWidget {
  const RealtimeRoomScreen({super.key, required this.sessionId, this.action});

  final String sessionId;
  final String? action;

  @override
  ConsumerState<RealtimeRoomScreen> createState() => _RealtimeRoomScreenState();
}

class _RealtimeRoomScreenState extends ConsumerState<RealtimeRoomScreen> {
  bool _didBoot = false;
  String? _lastConsentSyncKey;
  Timer? _durationTimer;
  DateTime _now = DateTime.now();
  final TextEditingController _inviteSearchController = TextEditingController();
  final TextEditingController _inviteNoteController = TextEditingController();
  Timer? _searchDebounce;
  List<Map<String, dynamic>> _inviteResults = const [];
  bool _inviteSearchBusy = false;
  String? _invitingUserId;

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
        // Skip hydration if the controller is already managing this session
        // in a joined state — the caller (ensureCorrespondenceLive or
        // incoming overlay) already ran join() which hydrated on the way in.
        final currentState = ref.read(realtimeControllerProvider);
        final managedId =
            (currentState.sessionId ?? currentState.session?.id ?? '').trim();
        final alreadyJoined =
            currentState.isJoined && managedId == widget.sessionId.trim();
        if (!alreadyJoined) {
          await controller.hydrateSession(widget.sessionId);
        }
      }
    });

    _durationTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _now = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _searchDebounce?.cancel();
    _inviteSearchController.dispose();
    _inviteNoteController.dispose();
    super.dispose();
  }

  void _onInviteSearchChanged({
    required String query,
    required String myUserId,
    required List<RealtimeParticipant> participants,
  }) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      _searchMembers(
        query: query,
        myUserId: myUserId,
        participants: participants,
      );
    });
  }

  Future<void> _searchMembers({
    required String query,
    required String myUserId,
    required List<RealtimeParticipant> participants,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      if (!mounted) return;
      setState(() {
        _inviteResults = const [];
        _inviteSearchBusy = false;
      });
      return;
    }

    setState(() {
      _inviteSearchBusy = true;
    });

    try {
      final repo = SearchRepository(ref.read(dioProvider));
      final result = await repo.search(trimmed, limit: 8);
      final existingIds = participants.map((p) => p.userId).toSet();

      final filtered = result.users.where((user) {
        final id = (user['id'] ?? '').toString().trim();
        if (id.isEmpty) return false;
        if (id == myUserId) return false;
        if (existingIds.contains(id)) return false;
        return true;
      }).toList();

      if (!mounted) return;
      setState(() {
        _inviteResults = filtered;
        _inviteSearchBusy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _inviteResults = const [];
        _inviteSearchBusy = false;
      });
    }
  }

  Future<void> _inviteMember(Map<String, dynamic> user) async {
    final invitedUserId = (user['id'] ?? '').toString().trim();
    if (invitedUserId.isEmpty || _invitingUserId != null) return;

    setState(() {
      _invitingUserId = invitedUserId;
    });

    try {
      await ref
          .read(realtimeControllerProvider.notifier)
          .inviteMember(
            invitedUserId: invitedUserId,
            note: _inviteNoteController.text.trim().isEmpty
                ? null
                : _inviteNoteController.text.trim(),
          );
      if (!mounted) return;
      setState(() {
        _inviteResults = _inviteResults
            .where((u) => (u['id'] ?? '').toString() != invitedUserId)
            .toList();
        _invitingUserId = null;
      });
      _inviteSearchController.clear();
      _inviteNoteController.clear();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _invitingUserId = null;
      });
    }
  }

  void _syncConsentsIfNeeded({
    required RealtimeController controller,
    required String sessionId,
    required bool? canManageConsents,
  }) {
    if (sessionId.trim().isEmpty || canManageConsents != true) return;

    final syncKey = '$sessionId:moderator';
    if (_lastConsentSyncKey == syncKey) return;
    _lastConsentSyncKey = syncKey;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      controller.syncConsentsVisibility(canManageConsents: canManageConsents);
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

    final isHost =
        myUserId.isNotEmpty && state.session?.startedByUserId == myUserId;
    final canModerate = myParticipant?.isModerator ?? isHost;
    final canManageConsents = canModerate;
    final policy = state.policy;
    final roomIsClosed =
        state.session?.isLocked == true || policy?.isLocked == true;
    final roomTitle = _roomTitle(state.session);
    final roomSubtitle = _roomSubtitle(state.session, state.joinState);
    final showConnectionRecovery =
        state.connectionStatus == RealtimeConnectionStatus.disconnected ||
        state.connectionStatus == RealtimeConnectionStatus.error;
    final participantCount = state.participants.length;
    final memberCountLabel = participantCount == 1
        ? '1 member listed here'
        : '$participantCount members listed here';
    final presentCount = state.participants
        .where((participant) => participant.isPresent)
        .length;
    final mediaActiveCount = state.participants
        .where(
          (participant) =>
              participant.audioOn ||
              participant.videoOn ||
              participant.screenOn,
        )
        .length;
    final callDurationLabel = _callDurationLabel(state.session, _now);

    _syncConsentsIfNeeded(
      controller: controller,
      sessionId: state.sessionId ?? widget.sessionId,
      canManageConsents: canManageConsents,
    );

    return AuraScaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1080;

          final stageColumn = <Widget>[
            _RoomHeaderCard(
              title: roomTitle,
              subtitle: roomSubtitle,
              sessionId: state.sessionId ?? widget.sessionId,
              memberCountLabel: memberCountLabel,
              roomStateLabel: _roomStateLabel(
                state.session,
                policy,
                state.joinState,
              ),
              callDurationLabel: callDurationLabel,
            ),
            const SizedBox(height: AuraSpace.s12),
            RealtimeStatusStrip(state: state, now: _now),
            const SizedBox(height: AuraSpace.s12),
            if (showConnectionRecovery) ...[
              _ConnectionRecoveryCard(
                isBusy:
                    state.isBusy ||
                    state.connectionStatus ==
                        RealtimeConnectionStatus.connecting ||
                    state.connectionStatus ==
                        RealtimeConnectionStatus.reconnecting,
                onReconnect: () => controller.resume(widget.sessionId),
                onReload: () => controller.hydrateSession(widget.sessionId),
              ),
              const SizedBox(height: AuraSpace.s12),
            ],
            if ((state.errorMessage ?? '').isNotEmpty) ...[
              AuraCard(child: Text(state.errorMessage!, style: AuraText.body)),
              const SizedBox(height: AuraSpace.s12),
            ],
            if ((state.mediaError ?? '').isNotEmpty) ...[
              AuraCard(child: Text(state.mediaError!, style: AuraText.body)),
              const SizedBox(height: AuraSpace.s12),
            ],
            if ((state.infoMessage ?? '').isNotEmpty) ...[
              AuraCard(child: Text(state.infoMessage!, style: AuraText.small)),
              const SizedBox(height: AuraSpace.s12),
            ],
            _MediaStageCard(
              localRenderer: state.localRenderer,
              remoteRenderers: state.remoteRenderers,
              microphoneEnabled: state.microphoneEnabled,
              cameraEnabled: state.cameraEnabled,
              isMediaReady: state.isMediaReady,
              isMediaBusy: state.isMediaBusy,
              mediaError: state.mediaError,
              onToggleMicrophone: controller.toggleMicrophone,
              onToggleCamera: controller.toggleCamera,
            ),
          ];

          final supportColumn = <Widget>[
            _RoomOverviewCard(
              session: state.session,
              policy: policy,
              participantCount: participantCount,
              presentCount: presentCount,
              mediaActiveCount: mediaActiveCount,
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
                onToggleWaitingRoom: (value) => controller.setWaitingRoom(value),
                onToggleLock: (value) => controller.setLocked(value),
                onRequestConsent: () => controller.requestConsent(),
                onRequestRecording: () => controller.requestRecording(),
                onRequestTranscript: () => controller.requestTranscript(),
                onRefresh: () => controller.hydrateSession(widget.sessionId),
              ),
              const SizedBox(height: AuraSpace.s12),
              _RoomInviteCard(
                searchController: _inviteSearchController,
                noteController: _inviteNoteController,
                isSearching: _inviteSearchBusy,
                results: _inviteResults,
                invitingUserId: _invitingUserId,
                onSearchChanged: (value) => _onInviteSearchChanged(
                  query: value,
                  myUserId: myUserId,
                  participants: state.participants,
                ),
                onInvite: (user) => _inviteMember(user),
              ),
              const SizedBox(height: AuraSpace.s12),
              RealtimeJoinRequestsPanel(
                requests: policy?.joinRequests ?? const [],
                onApprove: (value) => controller.approveJoinRequest(value),
                onReject: (value) => controller.rejectJoinRequest(value),
              ),
              const SizedBox(height: AuraSpace.s12),
            ],
            RealtimeParticipantList(
              participants: state.participants,
              session: state.session,
              canModerate: canModerate,
              currentUserId: myUserId,
              hostUserId: state.session?.startedByUserId,
              remoteRenderers: state.remoteRenderers,
              onRemove: (value) => controller.removeParticipant(value),
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
                if ((_spaceRouteFromSession(state.session) ?? '').isNotEmpty)
                  AuraSecondaryButton(
                    label: 'Return to conversation',
                    onPressed: () =>
                        context.go(_spaceRouteFromSession(state.session)!),
                  ),
                AuraSecondaryButton(
                  label: 'Refresh',
                  onPressed: () => controller.hydrateSession(widget.sessionId),
                ),
                AuraSecondaryButton(
                  label: 'Leave call',
                  onPressed: controller.leave,
                ),
                if (state.joinState != RealtimeJoinState.joined)
                  AuraPrimaryButton(
                    label: 'Join ${_contextLabel(state.session)}',
                    onPressed: () => controller.join(widget.sessionId),
                  ),
                if (state.joinState == RealtimeJoinState.locked ||
                    state.joinState == RealtimeJoinState.rejected ||
                    state.joinState == RealtimeJoinState.failed ||
                    roomIsClosed)
                  AuraSecondaryButton(
                    label: policy?.waitingRoomEnabled == true || roomIsClosed
                        ? 'Request access'
                        : 'Try again',
                    onPressed: () => controller.requestJoin(widget.sessionId),
                  ),
              ],
            ),
          ];

          if (wide) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: stageColumn,
                    ),
                  ),
                  const SizedBox(width: AuraSpace.s16),
                  SizedBox(
                    width: 380,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: supportColumn,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              ...stageColumn,
              const SizedBox(height: AuraSpace.s12),
              ...supportColumn,
            ],
          );
        },
      ),
    );
  }

  String _roomTitle(RealtimeSession? session) {
    if (session == null) return 'Call';
    switch (session.surfaceType) {
      case RealtimeSurfaceType.dm:
      case RealtimeSurfaceType.thread:
        return 'Call';
      case RealtimeSurfaceType.space:
      case RealtimeSurfaceType.room:
        return 'Space call';
      case RealtimeSurfaceType.institution:
        return 'Institution call';
      case RealtimeSurfaceType.unknown:
        return 'Call';
    }
  }

  String? _spaceRouteFromSession(RealtimeSession? session) {
    if (session == null) return null;
    if (session.surfaceType == RealtimeSurfaceType.space) {
      final spaceId = (session.surfaceId ?? '').trim();
      if (spaceId.isNotEmpty) return '/me/correspondence/$spaceId';
    }
    return null;
  }

  String _contextLabel(RealtimeSession? session) {
    if (session == null) return 'call';
    switch (session.surfaceType) {
      case RealtimeSurfaceType.dm:
      case RealtimeSurfaceType.thread:
        return 'call';
      case RealtimeSurfaceType.space:
      case RealtimeSurfaceType.room:
        return 'space call';
      case RealtimeSurfaceType.institution:
        return 'institution call';
      case RealtimeSurfaceType.unknown:
        return 'call';
    }
  }

  String _roomSubtitle(RealtimeSession? session, RealtimeJoinState joinState) {
    if (joinState == RealtimeJoinState.joined) return 'You are here now.';
    if (joinState == RealtimeJoinState.requested) {
      return 'Your request to join is pending.';
    }
    if (joinState == RealtimeJoinState.rejected) {
      return 'Your request to join was declined.';
    }
    if (joinState == RealtimeJoinState.removed) {
      return 'You were removed from this call.';
    }
    if (session?.isActive == false) return 'This call has ended.';
    if (session?.isLocked == true) return 'Closed to new joins.';
    return 'Active now.';
  }

  String _roomStateLabel(
    RealtimeSession? session,
    RealtimePolicy? policy,
    RealtimeJoinState joinState,
  ) {
    if (joinState == RealtimeJoinState.requested) return 'Waiting for approval';
    if (joinState == RealtimeJoinState.rejected) return 'Entry declined';
    if (joinState == RealtimeJoinState.removed) return 'Removed';
    if (session?.isActive == false) return 'Ended';
    if (session?.isLocked == true || policy?.isLocked == true) return 'Closed';
    return 'Open';
  }

  String? _callDurationLabel(RealtimeSession? session, DateTime now) {
    if (session == null) return null;

    final startedAt =
        session.answeredAt ?? session.firstJoinedAt ?? session.startedAt ?? session.createdAt;
    if (startedAt == null) return null;

    final finishedAt = session.endedAt;
    final elapsed = finishedAt != null
        ? finishedAt.difference(startedAt)
        : now.difference(startedAt);
    final safe = elapsed.inSeconds < 0 ? Duration.zero : elapsed;
    final durationText = _formatDuration(safe);

    if (finishedAt != null || session.status == 'ENDED') {
      return 'Ended after $durationText';
    }
    if (session.isActive) {
      return 'Live $durationText';
    }
    return 'Duration $durationText';
  }

  String _formatDuration(Duration duration) {
    final totalSeconds = math.max(0, duration.inSeconds);
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    String two(int value) => value.toString().padLeft(2, '0');

    if (hours > 0) {
      return '${two(hours)}:${two(minutes)}:${two(seconds)}';
    }
    return '${two(minutes)}:${two(seconds)}';
  }
}

class _ConnectionRecoveryCard extends StatelessWidget {
  const _ConnectionRecoveryCard({
    required this.isBusy,
    required this.onReconnect,
    required this.onReload,
  });

  final bool isBusy;
  final Future<void> Function() onReconnect;
  final Future<void> Function() onReload;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Live connection needs attention',
            style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AuraSpace.s8),
          const Text(
            'You can reconnect to the call or reload the call state.',
            style: AuraText.muted,
          ),
          const SizedBox(height: AuraSpace.s12),
          Wrap(
            spacing: AuraSpace.s8,
            runSpacing: AuraSpace.s8,
            children: [
              AuraPrimaryButton(
                label: 'Reconnect',
                onPressed: isBusy ? null : onReconnect,
              ),
              AuraSecondaryButton(
                label: 'Reload state',
                onPressed: isBusy ? null : onReload,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoomHeaderCard extends StatelessWidget {
  const _RoomHeaderCard({
    required this.title,
    required this.subtitle,
    required this.sessionId,
    required this.memberCountLabel,
    required this.roomStateLabel,
    required this.callDurationLabel,
  });

  final String title;
  final String subtitle;
  final String sessionId;
  final String memberCountLabel;
  final String roomStateLabel;
  final String? callDurationLabel;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AuraText.title),
          const SizedBox(height: AuraSpace.s4),
          Text(subtitle, style: AuraText.small),
          const SizedBox(height: AuraSpace.s12),
          Wrap(
            spacing: AuraSpace.s8,
            runSpacing: AuraSpace.s8,
            children: [
              _MetaPill(label: roomStateLabel),
              _MetaPill(label: memberCountLabel),
              if ((callDurationLabel ?? '').trim().isNotEmpty)
                _MetaPill(label: callDurationLabel!),
            ],
          ),
        ],
      ),
    );
  }

}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.label});
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

class _MediaStageCard extends StatelessWidget {
  const _MediaStageCard({
    required this.localRenderer,
    required this.remoteRenderers,
    required this.microphoneEnabled,
    required this.cameraEnabled,
    required this.isMediaReady,
    required this.isMediaBusy,
    required this.mediaError,
    required this.onToggleMicrophone,
    required this.onToggleCamera,
  });

  final RTCVideoRenderer? localRenderer;
  final Map<String, RTCVideoRenderer> remoteRenderers;
  final bool microphoneEnabled;
  final bool cameraEnabled;
  final bool isMediaReady;
  final bool isMediaBusy;
  final String? mediaError;
  final VoidCallback onToggleMicrophone;
  final VoidCallback onToggleCamera;

  @override
  Widget build(BuildContext context) {
    final renderers = <MapEntry<String, RTCVideoRenderer>>[
      if (localRenderer != null)
        MapEntry<String, RTCVideoRenderer>('local', localRenderer!),
      ...remoteRenderers.entries,
    ];

    final mediaStateLabel = isMediaBusy
        ? 'Preparing media'
        : isMediaReady
        ? 'Media ready'
        : (mediaError ?? '').trim().isNotEmpty
        ? 'Media unavailable'
        : 'Waiting for browser media';

    final mediaHelpText = isMediaBusy
        ? 'Aura is requesting access to your camera and microphone.'
        : isMediaReady
        ? 'Your preview and connected participants appear here.'
        : (mediaError ?? '').trim().isNotEmpty
        ? 'You joined live, but this browser did not start media.'
        : 'Your browser has not started camera or microphone yet.';

    final controlsEnabled = isMediaReady && !isMediaBusy;

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Media', style: AuraText.title),
          const SizedBox(height: AuraSpace.s8),
          Wrap(
            spacing: AuraSpace.s8,
            runSpacing: AuraSpace.s8,
            children: [
              _MetaPill(label: mediaStateLabel),
              if (localRenderer != null)
                const _MetaPill(label: 'Local preview on'),
              if (remoteRenderers.isNotEmpty)
                _MetaPill(
                  label:
                      '${remoteRenderers.length} remote feed${remoteRenderers.length == 1 ? '' : 's'}',
                ),
            ],
          ),
          const SizedBox(height: AuraSpace.s8),
          Text(mediaHelpText, style: AuraText.muted),
          const SizedBox(height: AuraSpace.s12),
          if (renderers.isEmpty)
            Container(
              height: 220,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: AuraSpace.s16),
              child: Text(
                isMediaBusy
                    ? 'Waiting for browser permission'
                    : isMediaReady
                    ? 'Media is ready, but no preview is showing yet'
                    : (mediaError ?? '').trim().isNotEmpty
                    ? 'Media did not start in this browser'
                    : 'Camera and microphone have not started yet',
                textAlign: TextAlign.center,
                style: AuraText.body.copyWith(color: Colors.white70),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, tileConstraints) {
                // On wide screens use up to 2 tiles per row at 260px each;
                // on narrow screens let a single tile fill the full width.
                final availableWidth = tileConstraints.maxWidth;
                final tileWidth = availableWidth >= 560
                    ? math.min(260.0, (availableWidth - AuraSpace.s10) / 2)
                    : availableWidth;

                return Wrap(
                  spacing: AuraSpace.s10,
                  runSpacing: AuraSpace.s10,
                  children: renderers.map((entry) {
                    final isLocal = entry.key == 'local';
                    return SizedBox(
                      width: tileWidth,
                      child: _VideoTile(
                        label: isLocal ? 'You' : 'Connected participant',
                        renderer: entry.value,
                        mirror: isLocal,
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          const SizedBox(height: AuraSpace.s12),
          Wrap(
            spacing: AuraSpace.s8,
            runSpacing: AuraSpace.s8,
            children: [
              AuraSecondaryButton(
                label: microphoneEnabled ? 'Mute microphone' : 'Turn mic on',
                onPressed: controlsEnabled ? onToggleMicrophone : null,
              ),
              AuraSecondaryButton(
                label: cameraEnabled ? 'Turn camera off' : 'Turn camera on',
                onPressed: controlsEnabled ? onToggleCamera : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VideoTile extends StatelessWidget {
  const _VideoTile({
    required this.label,
    required this.renderer,
    this.mirror = false,
  });

  final String label;
  final RTCVideoRenderer renderer;
  final bool mirror;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 180,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: RTCVideoView(
            renderer,
            mirror: mirror,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
          ),
        ),
        const SizedBox(height: AuraSpace.s8),
        Text(
          label,
          style: AuraText.small.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _RoomOverviewCard extends StatelessWidget {
  const _RoomOverviewCard({
    required this.session,
    required this.policy,
    required this.participantCount,
    required this.presentCount,
    required this.mediaActiveCount,
  });

  final RealtimeSession? session;
  final RealtimePolicy? policy;
  final int participantCount;
  final int presentCount;
  final int mediaActiveCount;

  @override
  Widget build(BuildContext context) {
    final isLive = session?.isActive != false;
    final isClosed = session?.isLocked == true || policy?.isLocked == true;
    final requestsOn = policy?.waitingRoomEnabled == true;

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isLive ? 'Call in progress' : 'Call ended',
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
            participantCount == 1
                ? '1 member is listed here'
                : '$participantCount members are listed here',
            style: AuraText.body,
          ),
          Text(
            presentCount == 1
                ? '1 participant currently appears present'
                : '$presentCount participants currently appear present',
            style: AuraText.body,
          ),
          Text(
            mediaActiveCount == 1
                ? '1 participant is publishing media'
                : '$mediaActiveCount participants are publishing media',
            style: AuraText.body,
          ),
        ],
      ),
    );
  }
}

class _RoomInviteCard extends StatelessWidget {
  const _RoomInviteCard({
    required this.searchController,
    required this.noteController,
    required this.isSearching,
    required this.results,
    required this.invitingUserId,
    required this.onSearchChanged,
    required this.onInvite,
  });

  final TextEditingController searchController;
  final TextEditingController noteController;
  final bool isSearching;
  final List<Map<String, dynamic>> results;
  final String? invitingUserId;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<Map<String, dynamic>> onInvite;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Invite members', style: AuraText.title),
          const SizedBox(height: AuraSpace.s8),
          const Text(
            'Find existing Aura members and invite them into this call.',
            style: AuraText.muted,
          ),
          const SizedBox(height: AuraSpace.s12),
          TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: const InputDecoration(
              labelText: 'Search members',
              hintText: 'Name, handle, or bio',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: AuraSpace.s10),
          TextField(
            controller: noteController,
            decoration: const InputDecoration(
              labelText: 'Optional note',
              hintText: 'Add context for the invite',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            minLines: 1,
            maxLines: 2,
          ),
          const SizedBox(height: AuraSpace.s12),
          if (isSearching)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AuraSpace.s8),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AuraSurface.accent,
                  ),
                ),
              ),
            )
          else if (searchController.text.trim().isEmpty)
            const Text(
              'Search to invite people already on Aura.',
              style: AuraText.small,
            )
          else if (results.isEmpty)
            const Text('No matching members found.', style: AuraText.small)
          else
            ...results.map((user) {
              final id = (user['id'] ?? '').toString();
              final displayName = (user['displayName'] ?? '').toString().trim();
              final handle = (user['handle'] ?? '').toString().trim();
              final bio = (user['bio'] ?? '').toString().trim();
              final title = displayName.isNotEmpty
                  ? displayName
                  : handle.isNotEmpty
                  ? '@$handle'
                  : 'Member';
              final subtitle = [
                if (handle.isNotEmpty && displayName.isNotEmpty) '@$handle',
                if (bio.isNotEmpty) bio,
              ].join(' • ');

              final isInviting = invitingUserId == id;

              return Padding(
                padding: const EdgeInsets.only(bottom: AuraSpace.s10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: AuraText.body.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (subtitle.isNotEmpty) ...[
                            const SizedBox(height: AuraSpace.s4),
                            Text(subtitle, style: AuraText.small),
                          ],
                        ],
                      ),
                    ),
                    AuraPrimaryButton(
                      label: isInviting ? 'Inviting…' : 'Invite',
                      onPressed: isInviting ? null : () => onInvite(user),
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
        ? (recordingCount == 1
              ? '1 recording created'
              : '$recordingCount recordings created')
        : 'Recording unavailable in this call';
    final transcriptLabel = policy?.canTranscribe == true
        ? (transcriptCount == 1
              ? '1 note created'
              : '$transcriptCount notes created')
        : 'Notes unavailable in this call';

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Call output',
            style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AuraSpace.s8),
          Text(recordingLabel, style: AuraText.small),
          Text(transcriptLabel, style: AuraText.small),
          Text(
            artifactCount == 1
                ? '1 saved artifact'
                : '$artifactCount saved artifacts',
            style: AuraText.small,
          ),
        ],
      ),
    );
  }
}
