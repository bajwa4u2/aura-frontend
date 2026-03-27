import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';
import '../../search/search_repository.dart';
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
        await controller.hydrateSession(widget.sessionId);
      }
    });
  }

  @override
  void dispose() {
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
      await ref.read(realtimeControllerProvider.notifier).inviteMember(
            invitedUserId: invitedUserId,
            note: _inviteNoteController.text.trim().isEmpty
                ? null
                : _inviteNoteController.text.trim(),
          );
      if (!mounted) return;
      setState(() {
        _inviteResults = _inviteResults.where((u) => (u['id'] ?? '').toString() != invitedUserId).toList();
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
    final memberCountLabel = state.participants.length == 1
        ? '1 in the room'
        : '${state.participants.length} in the room';

    return AuraScaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _RoomHeaderCard(
            title: roomTitle,
            subtitle: roomSubtitle,
            sessionId: state.sessionId ?? widget.sessionId,
            memberCountLabel: memberCountLabel,
            roomStateLabel: _roomStateLabel(state.session, policy, state.joinState),
          ),
          const SizedBox(height: AuraSpace.s12),
          RealtimeStatusStrip(state: state),
          const SizedBox(height: AuraSpace.s12),
          if ((state.errorMessage ?? '').isNotEmpty) ...[
            AuraCard(
              child: Text(
                state.errorMessage!,
                style: AuraText.body,
              ),
            ),
            const SizedBox(height: AuraSpace.s12),
          ],
          if ((state.infoMessage ?? '').isNotEmpty) ...[
            AuraCard(
              child: Text(
                state.infoMessage!,
                style: AuraText.small,
              ),
            ),
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
            canModerate: canModerate,
            currentUserId: myUserId,
            hostUserId: state.session?.startedByUserId,
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
    if (joinState == RealtimeJoinState.rejected) return 'Your entry request was declined.';
    if (joinState == RealtimeJoinState.removed) return 'You were removed from this room.';
    if (session?.isActive == false) return 'This room has ended.';
    if (session?.isLocked == true) return 'Closed to new entries.';
    return 'Active now.';
  }

  String _roomStateLabel(
    RealtimeSession? session,
    RealtimePolicy? policy,
    RealtimeJoinState joinState,
  ) {
    if (joinState == RealtimeJoinState.requested) return 'Waiting for approval';
    if (joinState == RealtimeJoinState.rejected) return 'Entry declined';
    if (joinState == RealtimeJoinState.removed) return 'Removed from room';
    if (session?.isActive == false) return 'Ended';
    if (session?.isLocked == true || policy?.isLocked == true) return 'Closed';
    return 'Open';
  }
}

class _RoomHeaderCard extends StatelessWidget {
  const _RoomHeaderCard({
    required this.title,
    required this.subtitle,
    required this.sessionId,
    required this.memberCountLabel,
    required this.roomStateLabel,
  });

  final String title;
  final String subtitle;
  final String sessionId;
  final String memberCountLabel;
  final String roomStateLabel;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AuraText.title),
          const SizedBox(height: AuraSpace.s4),
          Text(
            subtitle,
            style: AuraText.small,
          ),
          const SizedBox(height: AuraSpace.s12),
          Wrap(
            spacing: AuraSpace.s8,
            runSpacing: AuraSpace.s8,
            children: [
              _MetaPill(label: roomStateLabel),
              _MetaPill(label: memberCountLabel),
              _MetaPill(label: 'Ref ${_shortSessionId(sessionId)}'),
            ],
          ),
        ],
      ),
    );
  }

  static String _shortSessionId(String id) {
    final value = id.trim();
    if (value.length <= 8) return value;
    return value.substring(0, 8);
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
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AuraText.small.copyWith(fontWeight: FontWeight.w600),
      ),
    );
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
    final isClosed = session?.isLocked == true || policy?.isLocked == true;
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
          Text('Invite members', style: AuraText.title),
          const SizedBox(height: AuraSpace.s8),
          Text(
            'Find existing Aura members and invite them into this room.',
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
              child: LinearProgressIndicator(),
            )
          else if (searchController.text.trim().isEmpty)
            Text(
              'Search to invite people already on Aura.',
              style: AuraText.small,
            )
          else if (results.isEmpty)
            Text(
              'No matching members found.',
              style: AuraText.small,
            )
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
                            style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
                          ),
                          if (subtitle.isNotEmpty) ...[
                            const SizedBox(height: AuraSpace.s4),
                            Text(
                              subtitle,
                              style: AuraText.small,
                            ),
                          ],
                        ],
                      ),
                    ),
                    FilledButton(
                      onPressed: isInviting ? null : () => onInvite(user),
                      child: Text(isInviting ? 'Inviting…' : 'Invite'),
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
        ? (recordingCount == 1 ? '1 recording created' : '$recordingCount recordings created')
        : 'Recording unavailable in this room';
    final transcriptLabel = policy?.canTranscribe == true
        ? (transcriptCount == 1 ? '1 live note created' : '$transcriptCount live notes created')
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
          Text(
            artifactCount == 1 ? '1 saved artifact' : '$artifactCount saved artifacts',
            style: AuraText.small,
          ),
        ],
      ),
    );
  }
}
