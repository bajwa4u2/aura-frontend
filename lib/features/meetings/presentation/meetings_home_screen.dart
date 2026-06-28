import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../institutions/ui/institution_ds.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../application/meetings_provider.dart';
import '../domain/meeting.dart';
import '../domain/meeting_identity.dart';
import '../domain/meeting_room.dart';
import 'meeting_lifecycle_presenter.dart';

class MeetingsHomeScreen extends ConsumerWidget {
  final String? institutionId;

  const MeetingsHomeScreen({super.key, this.institutionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final institutionId = this.institutionId;
    final upcomingAsync = institutionId == null
        ? ref.watch(upcomingMeetingsProvider)
        : ref.watch(institutionUpcomingMeetingsProvider(institutionId));
    final pastAsync = institutionId == null
        ? ref.watch(pastMeetingsProvider)
        : ref.watch(institutionPastMeetingsProvider(institutionId));

    return AuraScaffold(
      title: institutionId == null ? 'Meetings' : 'Institution meetings',
      actions: [
        IconButton(
          icon: const Icon(Icons.add_rounded),
          tooltip: 'New meeting',
          onPressed: () => context.push('/meetings/new'),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: () async {
          if (institutionId == null) {
            ref.invalidate(upcomingMeetingsProvider);
            ref.invalidate(pastMeetingsProvider);
          } else {
            ref.invalidate(institutionUpcomingMeetingsProvider(institutionId));
            ref.invalidate(institutionPastMeetingsProvider(institutionId));
          }
        },
        child: ListView(
          padding: const EdgeInsets.all(AuraSpace.s16),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _HostHeader(),
                    const SizedBox(height: AuraSpace.s20),
                    upcomingAsync.when(
                      loading: () => const _LoadingPanel(
                        message: 'Loading scheduled meetings...',
                      ),
                      error: (e, _) => _ErrorPanel(
                        message: 'Could not load scheduled meetings.',
                        detail: '$e',
                      ),
                      data: (meetings) {
                        final now = DateTime.now();
                        final active = meetings
                            .where((m) => !m.isEnded)
                            .toList(growable: false);
                        final today = active
                            .where((m) => _isToday(m.scheduledAt, now))
                            .toList(growable: false);
                        final upcoming = active
                            .where((m) => !_isToday(m.scheduledAt, now))
                            .toList(growable: false);
                        final requests = active
                            .where((m) => m.booking != null)
                            .toList(growable: false);

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _MeetingSection(
                              title: "Today's meetings",
                              emptyTitle: 'No meetings today',
                              emptyBody:
                                  'New guest bookings will appear here when they are scheduled for today.',
                              meetings: today,
                              institutionId: institutionId,
                              highlightToday: true,
                              compact: true,
                            ),
                            const SizedBox(height: AuraSpace.s20),
                            _CollapsibleMeetingSection(
                              title: 'Upcoming conversations',
                              emptyTitle: 'No upcoming conversations',
                              emptyBody:
                                  'Scheduled meetings and guest bookings will appear here.',
                              meetings: upcoming,
                              institutionId: institutionId,
                              initiallyExpanded: false,
                              compact: true,
                            ),
                            const SizedBox(height: AuraSpace.s20),
                            _MeetingSection(
                              title: 'Booking requests received',
                              emptyTitle: 'No guest bookings yet',
                              emptyBody:
                                  'When a guest books from a public booking page, their details and source page will appear here.',
                              meetings: requests,
                              institutionId: institutionId,
                              compact: true,
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: AuraSpace.s20),
                    pastAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (meetings) => _CollapsibleMeetingSection(
                        title: 'Past meetings',
                        emptyTitle: 'No past meetings yet',
                        emptyBody:
                            'Completed and cancelled meetings appear here.',
                        meetings: meetings.take(8).toList(growable: false),
                        institutionId: institutionId,
                        compact: true,
                        initiallyExpanded: false,
                      ),
                    ),
                    const SizedBox(height: AuraSpace.s32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HostHeader extends ConsumerWidget {
  const _HostHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InsModeHeader(
      title: 'Meetings',
      description:
          'Manage guest bookings, upcoming conversations, and meeting links from the workspace.',
      primaryAction: Wrap(
        spacing: AuraSpace.s10,
        runSpacing: AuraSpace.s10,
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.login_rounded),
            label: const Text('Join by code'),
            onPressed: () => _showJoinDialog(context),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.video_call_rounded),
            label: const Text('Start meeting'),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              try {
                final meeting = await ref
                    .read(meetingsRepositoryProvider)
                    .startInstantMeeting();
                ref.invalidate(upcomingMeetingsProvider);
                if (!context.mounted) return;
                _showMeetingStarted(context, meeting);
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Could not start meeting: $e')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _showMeetingStarted(BuildContext context, Meeting meeting) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Meeting started'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Share this meeting link with guests.'),
            const SizedBox(height: AuraSpace.s12),
            SelectableText(meeting.joinUrl),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: meeting.joinUrl));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Meeting link copied')),
              );
            },
            child: const Text('Copy meeting link'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              context.push(
                meeting.sessionId != null
                    ? '/meetings/${meeting.id}/room?sessionId=${meeting.sessionId}'
                    : '/meetings/${meeting.id}/room',
              );
            },
            child: const Text('Enter room'),
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
            child: const Text('Join meeting'),
          ),
        ],
      ),
    );
  }
}

class _MeetingSection extends StatelessWidget {
  final String title;
  final String emptyTitle;
  final String emptyBody;
  final List<Meeting> meetings;
  final String? institutionId;
  final bool compact;
  final bool highlightToday;

  const _MeetingSection({
    required this.title,
    required this.emptyTitle,
    required this.emptyBody,
    required this.meetings,
    this.institutionId,
    this.compact = false,
    this.highlightToday = false,
  });

  @override
  Widget build(BuildContext context) {
    return InsSection(
      title: title,
      child: meetings.isEmpty
          ? _EmptyState(title: emptyTitle, body: emptyBody)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < meetings.length; i++) ...[
                  _MeetingCard(
                    meeting: meetings[i],
                    institutionId: institutionId,
                    compact: compact,
                    highlight: highlightToday,
                  ),
                  if (i != meetings.length - 1)
                    const SizedBox(height: InsSpacing.cardGap),
                ],
              ],
            ),
    );
  }
}

class _CollapsibleMeetingSection extends StatelessWidget {
  final String title;
  final String emptyTitle;
  final String emptyBody;
  final List<Meeting> meetings;
  final String? institutionId;
  final bool compact;
  final bool initiallyExpanded;

  const _CollapsibleMeetingSection({
    required this.title,
    required this.emptyTitle,
    required this.emptyBody,
    required this.meetings,
    this.institutionId,
    this.compact = false,
    this.initiallyExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: const Color(0xFF243244)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        tilePadding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.s18,
          vertical: AuraSpace.s4,
        ),
        childrenPadding: const EdgeInsets.only(
          left: AuraSpace.s18,
          right: AuraSpace.s18,
          bottom: AuraSpace.s18,
          top: InsSpacing.cardGap,
        ),
        collapsedIconColor: const Color(0xFF9CA3AF),
        iconColor: const Color(0xFF9CA3AF),
        title: Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        children: [
          meetings.isEmpty
              ? _EmptyState(title: emptyTitle, body: emptyBody)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < meetings.length; i++) ...[
                      _MeetingCard(
                        meeting: meetings[i],
                        institutionId: institutionId,
                        compact: compact,
                        highlight: false,
                      ),
                      if (i != meetings.length - 1)
                        const SizedBox(height: InsSpacing.cardGap),
                    ],
                  ],
                ),
        ],
      ),
    );
  }
}

class _MeetingCard extends ConsumerWidget {
  final Meeting meeting;
  final String? institutionId;
  final bool compact;
  final bool highlight;

  const _MeetingCard({
    required this.meeting,
    this.institutionId,
    this.compact = false,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final booking = meeting.booking;
    final bookerIdentity = booking?.bookerIdentity;
    final guestName =
        bookerIdentity?.displayName ??
        booking?.bookerName ??
        _guestParticipant?.displayName;
    final guestEmail =
        bookerIdentity?.email ??
        booking?.bookerEmail ??
        _guestParticipant?.guestEmail;
    final source = _sourceLabel(meeting);
    final scheduledLabel = _scheduledLabel(context, meeting);
    final lifecycle = MeetingLifecyclePresenter.present(
      meeting,
      room: meeting.room,
      isHost: true,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.s10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: meeting.isActive || highlight
              ? const Color(0xFF6C63FF).withValues(alpha: 0.10)
              : theme.colorScheme.surface,
          border: Border.all(
            color: meeting.isActive
                ? const Color(0xFF10B981).withValues(alpha: 0.55)
                : const Color(0xFF243244),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => context.push(_detailPath),
          child: Padding(
            padding: const EdgeInsets.all(AuraSpace.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MeetingIcon(meeting: meeting),
                    const SizedBox(width: AuraSpace.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: AuraSpace.s8,
                            runSpacing: AuraSpace.s6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                meeting.title,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              _StatusChip(lifecycle: lifecycle),
                            ],
                          ),
                          const SizedBox(height: AuraSpace.s6),
                          _Line(
                            icon: Icons.schedule_rounded,
                            text:
                                '$scheduledLabel • ${meeting.durationMinutes} min • ${meeting.timezone}',
                          ),
                          if (guestName != null)
                            _IdentityLine(
                              identity: bookerIdentity,
                              fallbackName: guestName,
                              fallbackEmail: guestEmail,
                            ),
                          if (source != null)
                            _Line(
                              icon: Icons.calendar_today_rounded,
                              text: source,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (!compact && booking?.bookerNotes?.trim().isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 52,
                      top: AuraSpace.s10,
                    ),
                    child: Text(
                      booking!.bookerNotes!.trim(),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFFCBD5E1),
                        height: 1.35,
                      ),
                    ),
                  ),
                const SizedBox(height: AuraSpace.s12),
                Wrap(
                  spacing: AuraSpace.s8,
                  runSpacing: AuraSpace.s8,
                  children: [
                    _PrimaryActionButton(
                      lifecycle: lifecycle,
                      onStart: () => _startMeeting(context, ref),
                      onEnter: () => _joinMeeting(context),
                      onOpenDetails: () => context.push(_detailPath),
                      onOpenSummary: () => context.push(_summaryPath),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.content_copy_rounded, size: 18),
                      label: const Text('Copy meeting link'),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: meeting.joinUrl));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Meeting link copied')),
                        );
                      },
                    ),
                    PopupMenuButton<_MeetingMenuAction>(
                      tooltip: 'More actions',
                      onSelected: (value) async {
                        switch (value) {
                          case _MeetingMenuAction.details:
                            context.push(_detailPath);
                            break;
                          case _MeetingMenuAction.summary:
                            context.push(_summaryPath);
                            break;
                          case _MeetingMenuAction.copyLink:
                            Clipboard.setData(
                              ClipboardData(text: meeting.joinUrl),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Meeting link copied'),
                              ),
                            );
                            break;
                          case _MeetingMenuAction.cancel:
                            await _cancelMeeting(context, ref);
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: _MeetingMenuAction.details,
                          child: Text('Open details'),
                        ),
                        const PopupMenuItem(
                          value: _MeetingMenuAction.summary,
                          child: Text('View summary'),
                        ),
                        const PopupMenuItem(
                          value: _MeetingMenuAction.copyLink,
                          child: Text('Copy meeting link'),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: _MeetingMenuAction.cancel,
                          child: Text('Cancel meeting'),
                        ),
                      ],
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

  MeetingParticipant? get _guestParticipant {
    for (final participant in meeting.participants) {
      if (participant.isGuest) return participant;
    }
    return null;
  }

  String? get _resolvedInstitutionId =>
      institutionId ?? meeting.booking?.institution?.id;

  String get _detailPath => _resolvedInstitutionId == null
      ? '/meetings/${meeting.id}'
      : '/institution/${_resolvedInstitutionId!}/meetings/${meeting.id}';
  String get _summaryPath => _resolvedInstitutionId == null
      ? '/meetings/${meeting.id}/summary'
      : '/institution/${_resolvedInstitutionId!}/meetings/${meeting.id}/summary';
  String get _roomBasePath => _resolvedInstitutionId == null
      ? '/meetings/${meeting.id}/room'
      : '/institution/${_resolvedInstitutionId!}/meetings/${meeting.id}/room';
  String get _roomPath => _roomBasePath;

  String get _meetingRoomReturnTo => Uri.encodeComponent(_roomBasePath);

  Future<void> _startMeeting(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final updated = await ref
          .read(meetingsRepositoryProvider)
          .startMeeting(meeting.id);
      ref.invalidate(meetingProvider(meeting.id));
      if (institutionId == null) {
        ref.invalidate(upcomingMeetingsProvider);
      } else {
        ref.invalidate(institutionUpcomingMeetingsProvider(institutionId!));
      }
      if (!context.mounted) return;
      if (updated.sessionId != null) {
        context.push(
          '$_roomPath?sessionId=${updated.sessionId}&returnTo=$_meetingRoomReturnTo',
        );
      } else {
        context.push(_roomPath);
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not start meeting: $e')),
      );
    }
  }

  void _joinMeeting(BuildContext context) {
    if (meeting.sessionId != null) {
      context.push(
        '$_roomPath?sessionId=${meeting.sessionId}&returnTo=$_meetingRoomReturnTo',
      );
    } else {
      context.push(_roomPath);
    }
  }

  Future<void> _cancelMeeting(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel meeting?'),
        content: const Text('This will cancel the meeting for everyone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep meeting'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel meeting'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await ref.read(meetingsRepositoryProvider).cancelMeeting(meeting.id);
      ref.invalidate(meetingProvider(meeting.id));
      if (institutionId == null) {
        ref.invalidate(upcomingMeetingsProvider);
        ref.invalidate(pastMeetingsProvider);
      } else {
        ref.invalidate(institutionUpcomingMeetingsProvider(institutionId!));
        ref.invalidate(institutionPastMeetingsProvider(institutionId!));
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Meeting cancelled')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not cancel meeting: $e')));
    }
  }
}

enum _MeetingMenuAction { details, summary, copyLink, cancel }

class _MeetingIcon extends StatelessWidget {
  final Meeting meeting;

  const _MeetingIcon({required this.meeting});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: meeting.room?.status == MeetingRoomStatus.live
            ? const Color(0xFF10B981)
            : const Color(0xFF6C63FF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        meeting.room?.status == MeetingRoomStatus.live
            ? Icons.sensors_rounded
            : Icons.calendar_today_rounded,
        color: Colors.white,
        size: 20,
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final MeetingLifecycleViewModel lifecycle;

  const _StatusChip({required this.lifecycle});

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
        'Guest waiting',
        const Color(0xFFF59E0B),
      ),
      MeetingLifecycleStatus.hostWaiting => (
        'Host waiting',
        const Color(0xFFF59E0B),
      ),
      MeetingLifecycleStatus.inProgress => (
        'In progress',
        const Color(0xFF10B981),
      ),
      MeetingLifecycleStatus.ended => ('Ended', const Color(0xFF9CA3AF)),
      MeetingLifecycleStatus.missed => ('Missed', const Color(0xFF9CA3AF)),
      MeetingLifecycleStatus.cancelled => (
        'Cancelled',
        const Color(0xFFEF4444),
      ),
      MeetingLifecycleStatus.connectionIssue => (
        'Connection issue',
        const Color(0xFFF97316),
      ),
      MeetingLifecycleStatus.unknown => ('Scheduled', const Color(0xFF9CA3AF)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  final MeetingLifecycleViewModel lifecycle;
  final VoidCallback onStart;
  final VoidCallback onEnter;
  final VoidCallback onOpenDetails;
  final VoidCallback onOpenSummary;

  const _PrimaryActionButton({
    required this.lifecycle,
    required this.onStart,
    required this.onEnter,
    required this.onOpenDetails,
    required this.onOpenSummary,
  });

  @override
  Widget build(BuildContext context) {
    final label = lifecycle.primaryAction;
    if (label == 'View summary' || label == 'Review missed') {
      return FilledButton.icon(
        icon: const Icon(Icons.description_outlined, size: 18),
        label: Text(label),
        onPressed: onOpenSummary,
      );
    }
    if (label == 'Retry connection') {
      return FilledButton.icon(
        icon: const Icon(Icons.refresh_rounded, size: 18),
        label: Text(label),
        onPressed: onEnter,
      );
    }
    if (label == 'Enter room') {
      return FilledButton.icon(
        icon: const Icon(Icons.video_call_rounded, size: 18),
        label: const Text('Enter room'),
        onPressed: onEnter,
      );
    }
    return FilledButton.icon(
      icon: const Icon(Icons.video_call_rounded, size: 18),
      label: const Text('Start meeting'),
      onPressed: onStart,
    );
  }
}

class _Line extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Line({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AuraSpace.s4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF9CA3AF)),
          const SizedBox(width: AuraSpace.s8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFF9CA3AF)),
            ),
          ),
        ],
      ),
    );
  }
}

class _IdentityLine extends StatelessWidget {
  final MeetingIdentityRef? identity;
  final String fallbackName;
  final String? fallbackEmail;

  const _IdentityLine({
    required this.identity,
    required this.fallbackName,
    required this.fallbackEmail,
  });

  @override
  Widget build(BuildContext context) {
    final name = identity?.displayName ?? fallbackName;
    final email = identity?.email ?? fallbackEmail ?? '';
    final avatar = identity?.avatarUrl;
    final title = identity?.title;

    return Padding(
      padding: const EdgeInsets.only(top: AuraSpace.s4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 8,
            backgroundColor: const Color(0xFF6C63FF).withValues(alpha: 0.18),
            backgroundImage: avatar != null && avatar.trim().isNotEmpty
                ? NetworkImage(avatar)
                : null,
            child: avatar == null || avatar.trim().isEmpty
                ? Text(
                    name.trim().isEmpty ? 'G' : name.trim()[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: AuraSpace.s8),
          Expanded(
            child: Text(
              [
                name,
                if (email.isNotEmpty) email,
                if (title?.trim().isNotEmpty == true) title!.trim(),
              ].join(' · '),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFF9CA3AF)),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  final String message;

  const _LoadingPanel({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AuraSpace.s24),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: AuraSpace.s12),
          Text(message),
        ],
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  final String message;
  final String detail;

  const _ErrorPanel({required this.message, required this.detail});

  @override
  Widget build(BuildContext context) {
    return _EmptyState(title: message, body: detail);
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String body;

  const _EmptyState({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: const Color(0xFF243244)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AuraSpace.s18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AuraSpace.s6),
            Text(
              body,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF9CA3AF)),
            ),
          ],
        ),
      ),
    );
  }
}

bool _isToday(DateTime? date, DateTime now) {
  if (date == null) return false;
  final local = date.toLocal();
  return local.year == now.year &&
      local.month == now.month &&
      local.day == now.day;
}

String _scheduledLabel(BuildContext context, Meeting meeting) {
  final scheduled = meeting.scheduledAt;
  if (scheduled == null) return 'Instant meeting';
  final local = scheduled.toLocal();
  final localizations = MaterialLocalizations.of(context);
  final date = localizations.formatMediumDate(local);
  final time = TimeOfDay.fromDateTime(local).format(context);
  return '$date at $time';
}

String? _sourceLabel(Meeting meeting) {
  final booking = meeting.booking;
  if (booking == null) return null;
  final page = booking.bookingPageName?.trim();
  final institution = booking.institution?.name.trim();
  if (page?.isNotEmpty == true && institution?.isNotEmpty == true) {
    return '$page - $institution';
  }
  if (page?.isNotEmpty == true) return page;
  if (institution?.isNotEmpty == true) return institution;
  return 'Public booking page';
}
