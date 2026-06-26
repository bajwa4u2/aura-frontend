import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../application/meetings_provider.dart';
import '../domain/meeting.dart';

class MeetingsHomeScreen extends ConsumerWidget {
  const MeetingsHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upcomingAsync = ref.watch(upcomingMeetingsProvider);
    final pastAsync = ref.watch(pastMeetingsProvider);

    return AuraScaffold(
      title: 'Meetings',
      actions: [
        IconButton(
          icon: const Icon(Icons.add_rounded),
          tooltip: 'New meeting',
          onPressed: () => context.push('/meetings/new'),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.all(AuraSpace.s16),
        children: [
          // Quick action buttons
          _QuickActions(),
          const SizedBox(height: AuraSpace.s24),

          // Upcoming meetings
          const _SectionHeader(title: 'UPCOMING'),
          const SizedBox(height: AuraSpace.s8),
          upcomingAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(AuraSpace.s32),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(AuraSpace.s16),
              child: Text('Could not load meetings: $e',
                  style: Theme.of(context).textTheme.bodySmall),
            ),
            data: (meetings) {
              if (meetings.isEmpty) {
                return const _EmptyState(
                  message: 'No upcoming meetings.',
                  hint: 'Schedule one or share a booking link.',
                );
              }
              return Column(
                children: meetings
                    .map((m) => _MeetingCard(meeting: m))
                    .toList(),
              );
            },
          ),

          const SizedBox(height: AuraSpace.s24),

          // Past meetings
          const _SectionHeader(title: 'RECENT'),
          const SizedBox(height: AuraSpace.s8),
          pastAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (meetings) {
              if (meetings.isEmpty) {
                return const _EmptyState(message: 'No past meetings yet.');
              }
              return Column(
                children: meetings
                    .take(10)
                    .map((m) => _MeetingCard(meeting: m))
                    .toList(),
              );
            },
          ),

          const SizedBox(height: AuraSpace.s32),
        ],
      ),
    );
  }
}

class _QuickActions extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            icon: Icons.video_call_rounded,
            label: 'Start',
            color: const Color(0xFF6C63FF),
            onTap: () async {
              final repo = ref.read(meetingsRepositoryProvider);
              try {
                final meeting = await repo.startInstantMeeting();
                if (!context.mounted) return;
                // Show the meeting code first, then navigate
                _showMeetingStarted(context, meeting);
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to start meeting: $e')),
                );
              }
            },
          ),
        ),
        const SizedBox(width: AuraSpace.s12),
        Expanded(
          child: _ActionButton(
            icon: Icons.login_rounded,
            label: 'Join',
            color: const Color(0xFF10B981),
            onTap: () => _showJoinDialog(context),
          ),
        ),
        const SizedBox(width: AuraSpace.s12),
        Expanded(
          child: _ActionButton(
            icon: Icons.calendar_month_rounded,
            label: 'Schedule',
            color: const Color(0xFFF59E0B),
            onTap: () => context.push('/meetings/new'),
          ),
        ),
      ],
    );
  }

  void _showMeetingStarted(BuildContext context, Meeting meeting) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Meeting started'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Share this code to invite others:',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  meeting.meetingCode,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 20),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: meeting.joinUrl));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Link copied to clipboard')),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              if (meeting.sessionId != null) {
                context.push('/realtime/${meeting.sessionId}?action=join');
              }
            },
            child: const Text('Join now'),
          ),
        ],
      ),
    );
  }

  void _showJoinDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Join a meeting'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter meeting code',
            prefixIcon: Icon(Icons.link_rounded),
          ),
          onSubmitted: (_) {
            final code = ctrl.text.trim();
            if (code.isNotEmpty) {
              Navigator.pop(context);
              context.push('/meetings/join/$code');
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final code = ctrl.text.trim();
              if (code.isNotEmpty) {
                Navigator.pop(context);
                context.push('/meetings/join/$code');
              }
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AuraSpace.s16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: AuraSpace.s6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AuraSpace.s4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
          color: Color(0xFF9CA3AF),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  final String? hint;

  const _EmptyState({required this.message, this.hint});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AuraSpace.s16),
      child: Center(
        child: Column(
          children: [
            Text(message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF6B7280),
                    )),
            if (hint != null) ...[
              const SizedBox(height: AuraSpace.s4),
              Text(hint!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF9CA3AF),
                      )),
            ],
          ],
        ),
      ),
    );
  }
}

class _MeetingCard extends StatelessWidget {
  final Meeting meeting;
  const _MeetingCard({required this.meeting});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = meeting.isActive;
    final formatter = DateFormat('EEE, MMM d · h:mm a');
    final scheduledLabel = meeting.scheduledAt != null
        ? formatter.format(meeting.scheduledAt!.toLocal())
        : 'Instant meeting';

    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.s8),
      child: GestureDetector(
        onTap: () => context.push('/meetings/${meeting.id}'),
        child: Container(
          padding: const EdgeInsets.all(AuraSpace.s16),
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFF6C63FF).withOpacity(0.08)
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive
                  ? const Color(0xFF6C63FF).withOpacity(0.4)
                  : const Color(0xFF374151).withOpacity(0.4),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFF6C63FF)
                      : const Color(0xFF374151),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isActive
                      ? Icons.video_call_rounded
                      : Icons.calendar_today_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: AuraSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (isActive)
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'LIVE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        Expanded(
                          child: Text(
                            meeting.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      scheduledLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF9CA3AF),
                      ),
                    ),
                    Text(
                      '${meeting.durationMinutes} min · ${meeting.participantCount} participant${meeting.participantCount != 1 ? 's' : ''}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              if (isActive)
                FilledButton.tonal(
                  onPressed: () => context.push(
                      '/meetings/join/${meeting.meetingCode}'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                  ),
                  child: const Text('Join', style: TextStyle(fontSize: 13)),
                )
              else
                const Icon(Icons.chevron_right_rounded,
                    color: Color(0xFF6B7280)),
            ],
          ),
        ),
      ),
    );
  }
}
