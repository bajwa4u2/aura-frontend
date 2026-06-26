import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../application/meetings_provider.dart';
import '../domain/meeting.dart';

class MeetingDetailScreen extends ConsumerWidget {
  final String meetingId;
  const MeetingDetailScreen({super.key, required this.meetingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meetingAsync = ref.watch(meetingProvider(meetingId));

    return meetingAsync.when(
      loading: () => AuraScaffold(
        title: 'Meeting',
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => AuraScaffold(
        title: 'Meeting',
        body: Center(child: Text('Could not load meeting: $e')),
      ),
      data: (meeting) => _MeetingDetailBody(meeting: meeting),
    );
  }
}

class _MeetingDetailBody extends ConsumerStatefulWidget {
  final Meeting meeting;
  const _MeetingDetailBody({required this.meeting});

  @override
  ConsumerState<_MeetingDetailBody> createState() =>
      _MeetingDetailBodyState();
}

class _MeetingDetailBodyState extends ConsumerState<_MeetingDetailBody> {
  bool _actioning = false;

  Meeting get meeting => widget.meeting;

  Future<void> _startMeeting() async {
    setState(() => _actioning = true);
    try {
      final repo = ref.read(meetingsRepositoryProvider);
      final updated = await repo.startMeeting(meeting.id);
      ref.invalidate(meetingProvider(meeting.id));
      ref.invalidate(upcomingMeetingsProvider);

      if (!mounted) return;
      if (updated.sessionId != null) {
        context.push('/realtime/${updated.sessionId}?action=join');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to start: $e')));
    } finally {
      if (mounted) setState(() => _actioning = false);
    }
  }

  Future<void> _endMeeting() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('End meeting?'),
        content:
            const Text('This will end the meeting for all participants.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('End meeting')),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _actioning = true);
    try {
      await ref.read(meetingsRepositoryProvider).endMeeting(meeting.id);
      ref.invalidate(meetingProvider(meeting.id));
      ref.invalidate(upcomingMeetingsProvider);
      ref.invalidate(pastMeetingsProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to end: $e')));
    } finally {
      if (mounted) setState(() => _actioning = false);
    }
  }

  Future<void> _cancelMeeting() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel meeting?'),
        content: const Text(
            'Participants will be notified that the meeting has been cancelled.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep')),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade700),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Cancel meeting')),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _actioning = true);
    try {
      await ref.read(meetingsRepositoryProvider).cancelMeeting(meeting.id);
      ref.invalidate(meetingProvider(meeting.id));
      ref.invalidate(upcomingMeetingsProvider);
      if (!mounted) return;
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to cancel: $e')));
    } finally {
      if (mounted) setState(() => _actioning = false);
    }
  }

  void _copyLink() {
    Clipboard.setData(ClipboardData(text: meeting.joinUrl));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Meeting link copied')));
  }

  void _inviteGuest() {
    final emailCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Invite by email'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                  labelText: 'Name (optional)',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                  labelText: 'Email address',
                  border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final email = emailCtrl.text.trim();
              final name = nameCtrl.text.trim();
              if (email.isEmpty) return;
              Navigator.pop(context);
              try {
                await ref.read(meetingsRepositoryProvider).inviteToMeeting(
                      meeting.id,
                      email: email,
                      name: name.isEmpty ? null : name,
                    );
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invitation sent')));
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not send invite: $e')));
              }
            },
            child: const Text('Send invite'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatter = DateFormat('EEEE, MMMM d · h:mm a');
    final scheduledLabel = meeting.scheduledAt != null
        ? formatter.format(meeting.scheduledAt!.toLocal())
        : 'Instant meeting';

    return AuraScaffold(
      title: '',
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => context.pop(),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AuraSpace.s16),
        children: [
          // Header
          Row(
            children: [
              _StateChip(state: meeting.state),
              const Spacer(),
              if (!meeting.isEnded)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz_rounded),
                  onSelected: (v) {
                    if (v == 'cancel') _cancelMeeting();
                    if (v == 'copy') _copyLink();
                    if (v == 'invite') _inviteGuest();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                        value: 'copy',
                        child: Text('Copy meeting link')),
                    const PopupMenuItem(
                        value: 'invite',
                        child: Text('Invite by email')),
                    if (!meeting.isEnded)
                      const PopupMenuItem(
                          value: 'cancel',
                          child: Text('Cancel meeting')),
                  ],
                ),
            ],
          ),

          const SizedBox(height: AuraSpace.s8),
          Text(meeting.title, style: theme.textTheme.headlineSmall),
          if (meeting.description != null) ...[
            const SizedBox(height: AuraSpace.s6),
            Text(meeting.description!,
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF6B7280))),
          ],

          const SizedBox(height: AuraSpace.s20),

          // Meeting details
          _InfoRow(
            icon: Icons.schedule_rounded,
            text: scheduledLabel,
          ),
          _InfoRow(
            icon: Icons.timer_outlined,
            text: _formatDuration(meeting.durationMinutes),
          ),
          _InfoRow(
            icon: Icons.link_rounded,
            text: meeting.meetingCode,
            onTap: _copyLink,
            trailing: const Icon(Icons.copy_rounded, size: 16),
          ),
          if (meeting.host != null)
            _InfoRow(
              icon: Icons.person_outline_rounded,
              text: 'Hosted by ${meeting.host!.name}',
            ),

          const SizedBox(height: AuraSpace.s20),
          const Divider(),
          const SizedBox(height: AuraSpace.s16),

          // Participants
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Participants',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
              if (!meeting.isEnded)
                TextButton.icon(
                  icon: const Icon(Icons.person_add_outlined, size: 16),
                  label: const Text('Invite'),
                  onPressed: _inviteGuest,
                  style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      tapTargetSize:
                          MaterialTapTargetSize.shrinkWrap),
                ),
            ],
          ),
          const SizedBox(height: AuraSpace.s8),
          if (meeting.participants.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AuraSpace.s8),
              child: Text('No participants yet.',
                  style: TextStyle(color: Color(0xFF9CA3AF))),
            )
          else
            ...meeting.participants.map((p) => _ParticipantRow(p: p)),

          const SizedBox(height: AuraSpace.s24),

          // Action buttons
          if (meeting.isScheduled) ...[
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                icon: const Icon(Icons.video_call_rounded),
                label: const Text('Start meeting'),
                onPressed: _actioning ? null : _startMeeting,
              ),
            ),
          ],
          if (meeting.isActive) ...[
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                icon: const Icon(Icons.video_call_rounded),
                label: const Text('Join meeting'),
                onPressed: _actioning
                    ? null
                    : () {
                        if (meeting.sessionId != null) {
                          context.push(
                              '/realtime/${meeting.sessionId}?action=join');
                        } else {
                          context.push('/meetings/join/${meeting.meetingCode}');
                        }
                      },
              ),
            ),
            const SizedBox(height: AuraSpace.s12),
            SizedBox(
              height: 44,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('End meeting'),
                onPressed: _actioning ? null : _endMeeting,
                style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade600),
              ),
            ),
          ],
          if (!meeting.isEnded) ...[
            const SizedBox(height: AuraSpace.s16),
            SizedBox(
              height: 44,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.share_rounded),
                label: const Text('Copy invite link'),
                onPressed: _copyLink,
              ),
            ),
          ],

          const SizedBox(height: AuraSpace.s32),
        ],
      ),
    );
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) return '$minutes minutes';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (m == 0) return '$h hour${h != 1 ? 's' : ''}';
    return '$h hour${h != 1 ? 's' : ''} $m minutes';
  }
}

class _StateChip extends StatelessWidget {
  final String state;
  const _StateChip({required this.state});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (state) {
      'ACTIVE' => ('Live', const Color(0xFF10B981)),
      'SCHEDULED' => ('Scheduled', const Color(0xFF6C63FF)),
      'ENDED' => ('Ended', const Color(0xFF9CA3AF)),
      'CANCELLED' => ('Cancelled', const Color(0xFFEF4444)),
      _ => ('Draft', const Color(0xFF9CA3AF)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600)),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _InfoRow({
    required this.icon,
    required this.text,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AuraSpace.s6),
        child: Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFF6B7280)),
            const SizedBox(width: AuraSpace.s10),
            Expanded(
              child: Text(text,
                  style: Theme.of(context).textTheme.bodyMedium),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

class _ParticipantRow extends StatelessWidget {
  final MeetingParticipant p;
  const _ParticipantRow({required this.p});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AuraSpace.s6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFF374151),
            child: Text(
              p.displayName.isNotEmpty
                  ? p.displayName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: AuraSpace.s10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.displayName,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w500)),
                if (p.isGuest)
                  const Text('Guest',
                      style: TextStyle(
                          color: Color(0xFF9CA3AF), fontSize: 12)),
              ],
            ),
          ),
          if (p.isHost)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('Host',
                  style: TextStyle(
                      color: Color(0xFF6C63FF),
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}
