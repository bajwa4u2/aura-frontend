import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_providers.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../application/meetings_provider.dart';
import '../domain/meeting.dart';
import '../domain/meeting_room.dart';
import 'meeting_lifecycle_presenter.dart';

class MeetingRoomScreen extends ConsumerStatefulWidget {
  final String meetingId;
  final String? institutionId;
  final String? returnTo;
  final String? sessionId;

  const MeetingRoomScreen({
    super.key,
    required this.meetingId,
    this.institutionId,
    this.returnTo,
    this.sessionId,
  });

  @override
  ConsumerState<MeetingRoomScreen> createState() => _MeetingRoomScreenState();
}

class _MeetingRoomScreenState extends ConsumerState<MeetingRoomScreen> {
  bool _busy = false;
  String? _sessionId;

  @override
  void initState() {
    super.initState();
    _sessionId = (widget.sessionId ?? '').trim().isEmpty
        ? null
        : widget.sessionId!.trim();
  }

  String get _roomBasePath => widget.institutionId == null
      ? '/meetings/${widget.meetingId}/room'
      : '/institution/${widget.institutionId}/meetings/${widget.meetingId}/room';
  String get _returnTo => widget.returnTo ?? Uri.encodeComponent(_roomBasePath);

  Future<void> _startMeeting(Meeting meeting) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final updated = await ref
          .read(meetingsRepositoryProvider)
          .startMeeting(meeting.id);
      ref.invalidate(meetingProvider(meeting.id));
      if (!mounted) return;
      setState(() {
        _sessionId = updated.sessionId?.trim().isNotEmpty == true
            ? updated.sessionId!.trim()
            : _sessionId;
      });
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not open meeting room: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _enterTransport(Meeting meeting) {
    final sessionId = (_sessionId ?? meeting.room?.realtimeSessionId ?? '')
        .trim();
    if (sessionId.isEmpty) return;
    context.push('/realtime/$sessionId?action=join&returnTo=$_returnTo');
  }

  void _copyLink(Meeting meeting) {
    Clipboard.setData(ClipboardData(text: meeting.joinUrl));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Meeting link copied')));
  }

  @override
  Widget build(BuildContext context) {
    final meetingAsync = ref.watch(meetingProvider(widget.meetingId));
    final me = ref.watch(authMeDataProvider).valueOrNull ?? const {};

    return meetingAsync.when(
      loading: () => AuraScaffold(
        title: 'Meeting workspace',
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => AuraScaffold(
        title: 'Meeting workspace',
        body: Center(child: Text('Could not load meeting: $e')),
      ),
      data: (meeting) {
        final room = meeting.room;
        final isHost = (me['id']?.toString().trim() ?? '') == meeting.host?.id;
        final lifecycle = MeetingLifecyclePresenter.present(
          meeting,
          room: room,
          isHost: isHost,
        );
        final canStart = room?.canStart == true && !_busy;
        final sessionId = (_sessionId ?? room?.realtimeSessionId ?? '').trim();
        final isTerminal = room?.isTerminal == true || meeting.isEnded;
        final statusLabel = lifecycle.label;

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
                        room: room,
                        sessionId: sessionId,
                        onStart: canStart && isHost
                            ? () => _startMeeting(meeting)
                            : null,
                        onEnter: sessionId.isNotEmpty
                            ? () => _enterTransport(meeting)
                            : null,
                        onCopy: () => _copyLink(meeting),
                      ),
                      const SizedBox(height: AuraSpace.s16),
                      _MeetingStatusStrip(
                        meeting: meeting,
                        room: room,
                        lifecycle: lifecycle,
                      ),
                      const SizedBox(height: AuraSpace.s16),
                      _RoomStateCard(
                        meeting: meeting,
                        room: room,
                        isHost: isHost,
                        busy: _busy,
                        lifecycle: lifecycle,
                        onStart: canStart && isHost
                            ? () => _startMeeting(meeting)
                            : null,
                        onEnter: sessionId.isNotEmpty
                            ? () => _enterTransport(meeting)
                            : null,
                        onCopy: () => _copyLink(meeting),
                        isTerminal: isTerminal,
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
  final MeetingRoom? room;
  final String? sessionId;
  final VoidCallback? onStart;
  final VoidCallback? onEnter;
  final VoidCallback onCopy;

  const _HeaderCard({
    required this.meeting,
    required this.statusLabel,
    required this.room,
    required this.sessionId,
    required this.onStart,
    required this.onEnter,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AuraSpace.s20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    meeting.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _StatusBadge(label: statusLabel),
              ],
            ),
            if ((meeting.description ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: AuraSpace.s8),
              Text(meeting.description!.trim()),
            ],
            const SizedBox(height: AuraSpace.s16),
            Wrap(
              spacing: AuraSpace.s12,
              runSpacing: AuraSpace.s12,
              children: [
                FilledButton.icon(
                  onPressed: sessionId != null ? onEnter : onStart,
                  icon: const Icon(Icons.meeting_room_rounded),
                  label: Text(
                    sessionId != null ? 'Enter room' : 'Start meeting',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: onCopy,
                  icon: const Icon(Icons.content_copy_rounded),
                  label: const Text('Copy link'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomStateCard extends StatelessWidget {
  final Meeting meeting;
  final MeetingRoom? room;
  final bool isHost;
  final bool busy;
  final MeetingLifecycleViewModel lifecycle;
  final VoidCallback? onStart;
  final VoidCallback? onEnter;
  final VoidCallback onCopy;
  final bool isTerminal;

  const _RoomStateCard({
    required this.meeting,
    required this.room,
    required this.isHost,
    required this.busy,
    required this.lifecycle,
    required this.onStart,
    required this.onEnter,
    required this.onCopy,
    required this.isTerminal,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusText = switch (lifecycle.status) {
      MeetingLifecycleStatus.scheduled => 'Scheduled meeting',
      MeetingLifecycleStatus.startingSoon => 'Starting soon',
      MeetingLifecycleStatus.guestWaiting => 'Waiting for host to start',
      MeetingLifecycleStatus.hostWaiting => 'Waiting for guest to join',
      MeetingLifecycleStatus.inProgress => 'Meeting is live',
      MeetingLifecycleStatus.ended => 'Meeting ended',
      MeetingLifecycleStatus.missed => 'Meeting missed',
      MeetingLifecycleStatus.cancelled => 'Meeting cancelled',
      MeetingLifecycleStatus.connectionIssue => 'Connection issue',
      MeetingLifecycleStatus.unknown => meeting.state,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AuraSpace.s20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              statusText,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AuraSpace.s8),
            Text(
              isTerminal
                  ? 'This meeting has ended.'
                  : lifecycle.status == MeetingLifecycleStatus.inProgress
                  ? 'The meeting room is open.'
                  : 'The meeting is ready when you are.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: AuraSpace.s16),
            if (!isTerminal) ...[
              Row(
                children: [
                  Icon(
                    lifecycle.status == MeetingLifecycleStatus.inProgress
                        ? Icons.people_alt_rounded
                        : Icons.schedule_rounded,
                    size: 18,
                    color: const Color(0xFF6B7280),
                  ),
                  const SizedBox(width: AuraSpace.s8),
                  Expanded(
                    child: Text(
                      lifecycle.status == MeetingLifecycleStatus.inProgress
                          ? '${room?.activeParticipantCount ?? 0} people in the room'
                          : isHost
                          ? 'Waiting for guest to join'
                          : 'Waiting for host to start',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AuraSpace.s16),
            ],
            Wrap(
              spacing: AuraSpace.s12,
              runSpacing: AuraSpace.s12,
              children: [
                if (onStart != null)
                  FilledButton.icon(
                    onPressed: busy ? null : onStart,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Start meeting'),
                  ),
                if (onEnter != null)
                  FilledButton.icon(
                    onPressed: busy ? null : onEnter,
                    icon: const Icon(Icons.meeting_room_outlined),
                    label: const Text('Enter room'),
                  ),
                OutlinedButton.icon(
                  onPressed: onCopy,
                  icon: const Icon(Icons.content_copy_rounded),
                  label: const Text('Copy link'),
                ),
              ],
            ),
            if (!isTerminal) ...[
              const SizedBox(height: AuraSpace.s16),
              Text(
                'If the room is still loading, refresh to reconnect. The meeting stays open until the host ends it.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF6B7280),
                ),
              ),
            ] else ...[
              const SizedBox(height: AuraSpace.s16),
              Text(
                'You can still open the meeting details page for notes and history.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF6B7280),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MeetingStatusStrip extends StatelessWidget {
  final Meeting meeting;
  final MeetingRoom? room;
  final MeetingLifecycleViewModel lifecycle;

  const _MeetingStatusStrip({
    required this.meeting,
    required this.room,
    required this.lifecycle,
  });

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      _TinyChip(
        icon: Icons.schedule_rounded,
        label: _scheduledLabel(context, meeting),
      ),
      _TinyChip(icon: Icons.public_rounded, label: meeting.timezone),
      _TinyChip(icon: Icons.event_available_rounded, label: lifecycle.label),
      _TinyChip(
        icon: Icons.people_alt_rounded,
        label: '${room?.activeParticipantCount ?? 0} participants',
      ),
    ];

    return Wrap(
      spacing: AuraSpace.s8,
      runSpacing: AuraSpace.s8,
      children: chips,
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

class _TinyChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _TinyChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        border: Border.all(color: const Color(0xFF243244)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF9CA3AF)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFE5E7EB),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

String _scheduledLabel(BuildContext context, Meeting meeting) {
  final scheduledAt = meeting.scheduledAt;
  if (scheduledAt == null) return 'Not scheduled';
  final localizations = MaterialLocalizations.of(context);
  final date = localizations.formatFullDate(scheduledAt.toLocal());
  final time = localizations.formatTimeOfDay(
    TimeOfDay.fromDateTime(scheduledAt.toLocal()),
  );
  return '$date · $time';
}
