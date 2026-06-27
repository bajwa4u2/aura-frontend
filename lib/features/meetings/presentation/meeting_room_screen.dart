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
        title: 'Meeting room',
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => AuraScaffold(
        title: 'Meeting room',
        body: Center(child: Text('Could not load meeting room: $e')),
      ),
      data: (meeting) {
        final room = meeting.room;
        final canStart = room?.canStart == true && !_busy;
        final sessionId = (_sessionId ?? room?.realtimeSessionId ?? '').trim();
        final isHost = (me['id']?.toString().trim() ?? '') == meeting.host?.id;
        final isTerminal = room?.isTerminal == true || meeting.isEnded;
        final roomStatus = room?.status ?? MeetingRoomStatus.unknown;
        final statusLabel = switch (roomStatus) {
          MeetingRoomStatus.scheduled => 'Scheduled',
          MeetingRoomStatus.waiting => 'Waiting',
          MeetingRoomStatus.live => 'Live',
          MeetingRoomStatus.ended => 'Ended',
          MeetingRoomStatus.cancelled => 'Cancelled',
          MeetingRoomStatus.unknown => meeting.state,
        };

        return AuraScaffold(
          title: 'Meeting room',
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
                      Wrap(
                        spacing: AuraSpace.s16,
                        runSpacing: AuraSpace.s16,
                        children: [
                          _InfoPanel(
                            title: 'Room state',
                            children: [
                              _InfoRow(
                                icon: Icons.event_available_rounded,
                                label: 'Status',
                                value: statusLabel,
                              ),
                              _InfoRow(
                                icon: Icons.people_alt_rounded,
                                label: 'Active participants',
                                value: '${room?.activeParticipantCount ?? 0}',
                              ),
                              _InfoRow(
                                icon: Icons.schedule_rounded,
                                label: 'Scheduled',
                                value: _scheduledLabel(context, meeting),
                              ),
                              _InfoRow(
                                icon: Icons.public_rounded,
                                label: 'Timezone',
                                value: meeting.timezone,
                              ),
                            ],
                          ),
                          _InfoPanel(
                            title: 'Meeting context',
                            children: [
                              _InfoRow(
                                icon: Icons.person_outline_rounded,
                                label: 'Host',
                                value: meeting.host?.name ?? 'Host',
                              ),
                              _InfoRow(
                                icon: Icons.business_rounded,
                                label: 'Institution',
                                value:
                                    meeting.booking?.institution?.name ??
                                    widget.institutionId ??
                                    'None',
                              ),
                              _InfoRow(
                                icon: Icons.link_rounded,
                                label: 'Join link',
                                value: meeting.joinUrl,
                                onTap: () => _copyLink(meeting),
                                trailing: const Icon(
                                  Icons.content_copy_rounded,
                                  size: 16,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: AuraSpace.s16),
                      _RoomStateCard(
                        meeting: meeting,
                        room: room,
                        isHost: isHost,
                        busy: _busy,
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
                  label: Text(sessionId != null ? 'Enter room' : 'Open room'),
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
  final VoidCallback? onStart;
  final VoidCallback? onEnter;
  final VoidCallback onCopy;
  final bool isTerminal;

  const _RoomStateCard({
    required this.meeting,
    required this.room,
    required this.isHost,
    required this.busy,
    required this.onStart,
    required this.onEnter,
    required this.onCopy,
    required this.isTerminal,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roomStatus = room?.status ?? MeetingRoomStatus.unknown;
    final statusText = switch (roomStatus) {
      MeetingRoomStatus.scheduled => 'Scheduled meeting',
      MeetingRoomStatus.waiting =>
        isHost ? 'Waiting for guest to join' : 'Waiting for host to start',
      MeetingRoomStatus.live => 'Meeting is live',
      MeetingRoomStatus.ended => 'Meeting ended',
      MeetingRoomStatus.cancelled => 'Meeting cancelled',
      MeetingRoomStatus.unknown => meeting.state,
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
                  ? 'This room is closed.'
                  : 'MeetingRoom owns lifecycle. RealtimeSession is transport only.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: AuraSpace.s16),
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
                  label: const Text('Copy meeting link'),
                ),
              ],
            ),
          ],
        ),
      ),
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

class _InfoPanel extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _InfoPanel({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AuraSpace.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AuraSpace.s12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: AuraSpace.s6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF6B7280)),
          const SizedBox(width: AuraSpace.s10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 2),
                Text(value),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AuraSpace.s8),
            trailing!,
          ],
        ],
      ),
    );

    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}
