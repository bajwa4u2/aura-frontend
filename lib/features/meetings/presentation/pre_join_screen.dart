import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../application/meetings_provider.dart';
import '../domain/meeting.dart';
import 'meeting_lifecycle_presenter.dart';

// Pre-join: shows meeting context (host, org, purpose) before entering.
// Applies the "organization first, Aura second" principle — the guest
// sees WHO is hosting before they encounter any platform branding.
class PreJoinScreen extends ConsumerStatefulWidget {
  final String meetingCode;
  const PreJoinScreen({super.key, required this.meetingCode});

  @override
  ConsumerState<PreJoinScreen> createState() => _PreJoinScreenState();
}

class _PreJoinScreenState extends ConsumerState<PreJoinScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  bool _joining = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _join(Meeting meeting) async {
    final name = _nameCtrl.text.trim();
    setState(() => _joining = true);

    try {
      final repo = ref.read(meetingsRepositoryProvider);
      final result = await repo.joinMeeting(
        widget.meetingCode,
        guestName: name.isEmpty ? null : name,
        guestEmail: _emailCtrl.text.trim().isEmpty
            ? null
            : _emailCtrl.text.trim(),
      );

      if (!mounted) return;

      if (result.shouldWait) {
        _showWaitingRoomMessage();
        return;
      }

      if (result.sessionId != null) {
        context.push(
          '/meetings/${result.meetingId}/room?sessionId=${result.sessionId}'
          '${result.guestToken != null ? '&guestToken=${result.guestToken}' : ''}',
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Meeting is not yet live. Check back later.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not join: $e')));
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  void _showWaitingRoomMessage() {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Waiting for host to start'),
        content: const Text(
          'This meeting room is not open yet. '
          'You will be able to join as soon as the host starts it.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final meetingAsync = ref.watch(meetingByCodeProvider(widget.meetingCode));
    final theme = Theme.of(context);

    return meetingAsync.when(
      loading: () => AuraScaffold(
        title: '',
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => AuraScaffold(
        title: '',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: Color(0xFF9CA3AF),
              ),
              const SizedBox(height: AuraSpace.s16),
              Text('Meeting not found', style: theme.textTheme.titleMedium),
              const SizedBox(height: AuraSpace.s8),
              Text(
                'Check the meeting code and try again.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      ),
      data: (meeting) => _PreJoinBody(
        meeting: meeting,
        nameCtrl: _nameCtrl,
        emailCtrl: _emailCtrl,
        joining: _joining,
        onJoin: () => _join(meeting),
      ),
    );
  }
}

class _PreJoinBody extends ConsumerWidget {
  final Meeting meeting;
  final TextEditingController nameCtrl;
  final TextEditingController emailCtrl;
  final bool joining;
  final VoidCallback onJoin;

  const _PreJoinBody({
    required this.meeting,
    required this.nameCtrl,
    required this.emailCtrl,
    required this.joining,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final lifecycle = MeetingLifecyclePresenter.present(meeting);

    // Is the authenticated user already a participant?
    // If so we skip name/email fields. For now we detect by checking
    // if the meeting has participants — the backend join endpoint will
    // handle the actual auth check. We always show the guest fields
    // as optional so unauthenticated visitors can identify themselves.

    return AuraScaffold(
      title: '',
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => context.pop(),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(AuraSpace.s24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Host context — org/host info before any platform mention
                if (meeting.host != null) ...[
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: const Color(0xFF6C63FF),
                        child: Text(
                          meeting.host!.name.isNotEmpty
                              ? meeting.host!.name[0].toUpperCase()
                              : 'H',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: AuraSpace.s12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            meeting.host!.name,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Text(
                            'has invited you to a meeting',
                            style: TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: AuraSpace.s20),
                  const Divider(),
                  const SizedBox(height: AuraSpace.s20),
                ],

                // Meeting info
                Text(
                  meeting.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AuraSpace.s8),
                if (meeting.booking?.institution != null)
                  Text(
                    meeting.booking!.institution!.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                if (meeting.description != null) ...[
                  const SizedBox(height: AuraSpace.s8),
                  Text(
                    meeting.description!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
                const SizedBox(height: AuraSpace.s6),
                _StatusPill(lifecycle: lifecycle),
                const SizedBox(height: AuraSpace.s12),
                _MeetingMetaRow(
                  icon: Icons.schedule_rounded,
                  text: _scheduledLabel(context, meeting),
                ),

                const SizedBox(height: AuraSpace.s24),

                // Guest identification (optional for signed-in users)
                Text(
                  'Your name',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AuraSpace.s6),
                TextField(
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'Enter your name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                ),
                const SizedBox(height: AuraSpace.s12),
                Text(
                  'Email (optional)',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AuraSpace.s6),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    hintText: 'your@email.com',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.mail_outline_rounded),
                  ),
                ),

                const SizedBox(height: AuraSpace.s24),

                SizedBox(
                  height: 50,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.video_call_rounded),
                    label: Text(_buttonLabel(lifecycle)),
                    onPressed: joining || lifecycle.isTerminal ? null : onJoin,
                  ),
                ),

                const SizedBox(height: AuraSpace.s20),

                // Platform attribution — present, not promotional
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Powered by ',
                      style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
                    ),
                    Text(
                      'Aura',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final MeetingLifecycleViewModel lifecycle;
  const _StatusPill({required this.lifecycle});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (lifecycle.status) {
      MeetingLifecycleStatus.scheduled => (
        'Scheduled',
        const Color(0xFF6C63FF),
      ),
      MeetingLifecycleStatus.startingSoon => (
        'Starting soon',
        const Color(0xFF8B85FF),
      ),
      MeetingLifecycleStatus.guestWaiting => (
        'Waiting for host',
        const Color(0xFFF59E0B),
      ),
      MeetingLifecycleStatus.hostWaiting => (
        'Host waiting',
        const Color(0xFFF59E0B),
      ),
      MeetingLifecycleStatus.inProgress => (
        'Live now',
        const Color(0xFF10B981),
      ),
      MeetingLifecycleStatus.ended => (
        'Meeting ended',
        const Color(0xFF9CA3AF),
      ),
      MeetingLifecycleStatus.missed => ('Missed', const Color(0xFF9CA3AF)),
      MeetingLifecycleStatus.cancelled => (
        'Cancelled',
        const Color(0xFFEF4444),
      ),
      MeetingLifecycleStatus.connectionIssue => (
        'Connection issue',
        const Color(0xFFF97316),
      ),
      MeetingLifecycleStatus.unknown => ('Pending', const Color(0xFF9CA3AF)),
    };

    return Row(
      children: [
        if (lifecycle.status == MeetingLifecycleStatus.inProgress)
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

String _buttonLabel(MeetingLifecycleViewModel lifecycle) {
  return switch (lifecycle.status) {
    MeetingLifecycleStatus.ended => 'Meeting ended',
    MeetingLifecycleStatus.cancelled => 'Meeting cancelled',
    MeetingLifecycleStatus.missed => 'Meeting missed',
    MeetingLifecycleStatus.connectionIssue => 'Retry connection',
    MeetingLifecycleStatus.guestWaiting => 'Wait for host',
    MeetingLifecycleStatus.hostWaiting => 'Join meeting',
    MeetingLifecycleStatus.inProgress => 'Join meeting',
    MeetingLifecycleStatus.startingSoon => 'Join meeting',
    MeetingLifecycleStatus.scheduled => 'Join meeting',
    MeetingLifecycleStatus.unknown => 'Join meeting',
  };
}

String _scheduledLabel(BuildContext context, Meeting meeting) {
  final scheduledAt = meeting.scheduledAt;
  if (scheduledAt == null) return 'Time will be confirmed by the host';
  final local = scheduledAt.toLocal();
  return '${MaterialLocalizations.of(context).formatFullDate(local)} · ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
}

class _MeetingMetaRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MeetingMetaRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF6B7280)),
        const SizedBox(width: AuraSpace.s10),
        Expanded(child: Text(text)),
      ],
    );
  }
}
