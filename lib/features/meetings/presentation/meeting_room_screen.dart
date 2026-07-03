import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_providers.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../application/meetings_provider.dart';
import '../domain/meeting.dart';
import 'meeting_lifecycle_presenter.dart';
import '../../realtime/application/realtime_providers.dart';
import '../../realtime/data/realtime_media_service.dart';

class MeetingRoomScreen extends ConsumerStatefulWidget {
  final String meetingId;
  final String? institutionId;
  final String? returnTo;
  final String? sessionId;
  final String? meetingCode;
  final String? guestId;

  const MeetingRoomScreen({
    super.key,
    required this.meetingId,
    this.institutionId,
    this.returnTo,
    this.sessionId,
    this.meetingCode,
    this.guestId,
  });

  @override
  ConsumerState<MeetingRoomScreen> createState() => _MeetingRoomScreenState();
}

class _MeetingRoomScreenState extends ConsumerState<MeetingRoomScreen> {
  bool _busy = false;
  bool _roomOpen = false;
  String? _sessionId;

  @override
  void initState() {
    super.initState();
    _sessionId = (widget.sessionId ?? '').trim().isEmpty
        ? null
        : widget.sessionId!.trim();
  }

  @override
  void dispose() {
    try {
      final media = ref.read(realtimeMediaServiceProvider);
      Future.microtask(() => media.resetSessionMedia());
    } catch (_) {}
    super.dispose();
  }

  Future<void> _startMeeting(Meeting meeting) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final updated = await ref
          .read(meetingsRepositoryProvider)
          .startMeeting(meeting.id);
      // Lifecycle trace: host started a scheduled meeting → session minted.
      debugPrint(
        '[scheduled-host] start meetingId=${meeting.id}'
        ' state=${updated.state}'
        ' sessionId=${updated.sessionId ?? updated.room?.realtimeSessionId ?? ''}',
      );
      ref.invalidate(meetingProvider(meeting.id));
      if (!mounted) return;
      setState(() {
        _sessionId = updated.sessionId?.trim().isNotEmpty == true
            ? updated.sessionId!.trim()
            : _sessionId;
        _roomOpen = true;
      });
      try {
        await ref
            .read(realtimeMediaServiceProvider)
            .ensureLocalMedia(audio: true, video: true);
      } catch (_) {}
    } catch (e) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Unable to open meeting room. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _enterRoom(Meeting meeting, {required bool isHost}) async {
    final sessionId = (_sessionId ?? meeting.room?.realtimeSessionId ?? '')
        .trim();
    if (sessionId.isEmpty) return;

    if (!_roomOpen) setState(() => _busy = true);
    try {
      final media = ref.read(realtimeMediaServiceProvider);
      await media.ensureLocalMedia(audio: true, video: true);
      if (!mounted) return;
      setState(() => _roomOpen = true);
      final livePath = widget.institutionId == null
          ? '/meetings/${meeting.id}/live'
          : '/institution/${widget.institutionId}/meetings/${meeting.id}/live';
      final codeParam = (widget.meetingCode ?? '').trim().isNotEmpty
          ? '&code=${Uri.encodeComponent(widget.meetingCode!.trim())}'
          : '';
      final guestParam = (widget.guestId ?? '').trim().isNotEmpty
          ? '&guestId=${Uri.encodeComponent(widget.guestId!.trim())}'
          : '';
      final target =
          '$livePath?sessionId=$sessionId&isHost=${isHost ? 'true' : 'false'}$codeParam$guestParam';
      if (isHost) {
        debugPrint(
          '[scheduled-host] route meetingId=${meeting.id}'
          ' sessionId=$sessionId isHost=true target=$target',
        );
      }
      // Production-visible: proves "Enter room" lands on MeetingLiveRoomScreen.
      debugPrint(
        '[guest-join-click] MeetingRoomScreen'
        ' currentUrl=${GoRouterState.of(context).uri} targetUrl=$target'
        ' meetingId=${meeting.id} sessionId=$sessionId'
        ' code=${(widget.meetingCode ?? '').trim()} guestId=${(widget.guestId ?? '').trim()}',
      );
      context.push(target);
    } catch (_) {
      if (!mounted) return;
      setState(() => _roomOpen = true);
    } finally {
      if (mounted && _busy) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final usePublicMeetingLookup = (widget.meetingCode ?? '').trim().isNotEmpty;
    final meetingAsync = usePublicMeetingLookup
        ? ref.watch(meetingByCodeProvider(widget.meetingCode!.trim()))
        : ref.watch(meetingProvider(widget.meetingId));
    final me = ref.watch(authMeDataProvider).valueOrNull ?? const {};

    return meetingAsync.when(
      loading: () => AuraScaffold(
        title: 'Meeting workspace',
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => AuraScaffold(
        title: 'Meeting workspace',
        body: const Center(child: Text('Unable to load meeting workspace.')),
      ),
      data: (meeting) {
        final room = meeting.room;
        final isHost = (me['id']?.toString().trim() ?? '') == meeting.host?.id;
        final mediaService = ref.watch(realtimeMediaServiceProvider);
        final lifecycle = MeetingLifecyclePresenter.present(
          meeting,
          room: room,
          isHost: isHost,
        );
        final canStart = room?.canStart == true && !_busy;
        final sessionId = (_sessionId ?? room?.realtimeSessionId ?? '').trim();
        final statusLabel = lifecycle.label;
        if (isHost) {
          debugPrint(
            '[scheduled-host] canStart=$canStart roomCanStart=${room?.canStart}'
            ' state=${meeting.state} status=$statusLabel'
            ' sessionId=$sessionId',
          );
        }

        return AuraScaffold(
          title: meeting.title,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
          body: ListView(
            padding: const EdgeInsets.all(AuraSpace.s16),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _HeaderCard(
                        meeting: meeting,
                        statusLabel: statusLabel,
                        onStart: canStart && isHost
                            ? () => _startMeeting(meeting)
                            : null,
                        onEnter: sessionId.isNotEmpty
                            ? () => _enterRoom(meeting, isHost: isHost)
                            : null,
                      ),
                      const SizedBox(height: AuraSpace.s16),
                      _MeetingStudioCard(
                        lifecycle: lifecycle,
                        isHost: isHost,
                        roomOpen: _roomOpen,
                        mediaService: mediaService,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final Meeting meeting;
  final String statusLabel;
  final VoidCallback? onStart;
  final VoidCallback? onEnter;

  const _HeaderCard({
    required this.meeting,
    required this.statusLabel,
    required this.onStart,
    required this.onEnter,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AuraSpace.s20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CompactIdentityRow(meeting: meeting),
            const SizedBox(height: AuraSpace.s16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    meeting.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: AuraSpace.s12),
                _StatusBadge(label: statusLabel),
              ],
            ),
            const SizedBox(height: AuraSpace.s16),
            Wrap(
              spacing: AuraSpace.s12,
              runSpacing: AuraSpace.s12,
              children: [
                FilledButton.icon(
                  onPressed: onEnter ?? onStart,
                  icon: const Icon(Icons.meeting_room_rounded),
                  label: Text(onEnter != null ? 'Enter room' : 'Start meeting'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactIdentityRow extends StatelessWidget {
  final Meeting meeting;

  const _CompactIdentityRow({required this.meeting});

  @override
  Widget build(BuildContext context) {
    final institution = meeting.booking?.institution;
    final host = meeting.host;

    return Row(
      children: [
        if (institution != null)
          _IdentityAvatar(
            name: institution.name,
            logoUrl: institution.logoUrl,
            icon: Icons.business_rounded,
          ),
        if (institution != null && host != null) const SizedBox(width: 8),
        if (host != null)
          _IdentityAvatar(
            name: host.name,
            logoUrl: host.avatarUrl,
            icon: Icons.person_outline_rounded,
          ),
        const SizedBox(width: AuraSpace.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                institution?.name ?? host?.name ?? meeting.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (host?.title?.trim().isNotEmpty == true)
                Text(
                  host!.title!.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF9CA3AF),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _IdentityAvatar extends StatelessWidget {
  final String name;
  final String? logoUrl;
  final IconData icon;

  const _IdentityAvatar({required this.name, required this.icon, this.logoUrl});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 18,
      backgroundColor: const Color(0xFF111827),
      backgroundImage: (logoUrl != null && logoUrl!.trim().isNotEmpty)
          ? NetworkImage(logoUrl!)
          : null,
      child: logoUrl == null || logoUrl!.trim().isEmpty
          ? Icon(icon, color: const Color(0xFFE5E7EB), size: 16)
          : null,
    );
  }
}

class _MeetingStudioCard extends StatelessWidget {
  final MeetingLifecycleViewModel lifecycle;
  final bool isHost;
  final bool roomOpen;
  final RealtimeMediaService mediaService;

  const _MeetingStudioCard({
    required this.lifecycle,
    required this.isHost,
    required this.roomOpen,
    required this.mediaService,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<RealtimeMediaSnapshot>(
      stream: mediaService.snapshots,
      initialData: mediaService.currentSnapshot,
      builder: (context, snapshot) {
        final mediaState = snapshot.data ?? mediaService.currentSnapshot;
        final preview = mediaState.localRenderer;
        final hasPreview = preview != null;
        final statusText = roomOpen
            ? switch (lifecycle.status) {
                MeetingLifecycleStatus.inProgress => 'The room is open.',
                MeetingLifecycleStatus.hostWaiting =>
                  'Waiting for guest to join.',
                MeetingLifecycleStatus.guestWaiting =>
                  'Waiting for host to start.',
                MeetingLifecycleStatus.connectionIssue => 'Connection issue.',
                MeetingLifecycleStatus.ended => 'Meeting ended.',
                MeetingLifecycleStatus.cancelled => 'Meeting cancelled.',
                MeetingLifecycleStatus.missed => 'Meeting missed.',
                MeetingLifecycleStatus.startingSoon => 'Starting soon.',
                MeetingLifecycleStatus.scheduled =>
                  isHost
                      ? 'Waiting for guest to join.'
                      : 'Waiting for host to start.',
                MeetingLifecycleStatus.unknown => 'Waiting for room.',
              }
            : isHost
            ? 'Open room to begin.'
            : 'Join room to wait.';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              statusText,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFFE5E7EB),
              ),
            ),
            const SizedBox(height: AuraSpace.s12),
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  color: const Color(0xFF0F172A),
                  alignment: Alignment.center,
                  child: hasPreview
                      ? RTCVideoView(
                          preview,
                          mirror: true,
                          objectFit:
                              RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.videocam_rounded,
                              color: Color(0xFF94A3B8),
                              size: 40,
                            ),
                            const SizedBox(height: AuraSpace.s8),
                            Text(
                              'Camera preview appears here',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: const Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                ),
              ),
            ),
            const SizedBox(height: AuraSpace.s12),
            Wrap(
              spacing: AuraSpace.s10,
              runSpacing: AuraSpace.s10,
              children: [
                OutlinedButton.icon(
                  onPressed: mediaState.localRenderer == null
                      ? null
                      : () async {
                          await mediaService.setMicrophoneEnabled(
                            !mediaState.micEnabled,
                          );
                        },
                  icon: Icon(
                    mediaState.micEnabled
                        ? Icons.mic_rounded
                        : Icons.mic_off_rounded,
                  ),
                  label: Text(
                    mediaState.micEnabled ? 'Mute mic' : 'Unmute mic',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: mediaState.localRenderer == null
                      ? null
                      : () async {
                          await mediaService.setCameraEnabled(
                            !mediaState.cameraEnabled,
                          );
                        },
                  icon: Icon(
                    mediaState.cameraEnabled
                        ? Icons.videocam_rounded
                        : Icons.videocam_off_rounded,
                  ),
                  label: Text(
                    mediaState.cameraEnabled
                        ? 'Turn camera off'
                        : 'Turn camera on',
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;

  const _StatusBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF6C63FF).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF6C63FF),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
