import 'dart:async';

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
import 'meeting_status_chip.dart';

class MeetingsHomeScreen extends ConsumerStatefulWidget {
  final String? institutionId;

  const MeetingsHomeScreen({super.key, this.institutionId});

  @override
  ConsumerState<MeetingsHomeScreen> createState() => _MeetingsHomeScreenState();
}

class _MeetingsHomeScreenState extends ConsumerState<MeetingsHomeScreen> {
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    // F3 — Poll every 30 seconds to catch state changes for near-start meetings.
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      _refreshIfNearStartMeeting();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _refreshIfNearStartMeeting() {
    final institutionId = widget.institutionId;
    // Always invalidate upcoming list when near-start window polling fires;
    // the check for ±30 min meetings happens implicitly after the refresh.
    if (institutionId == null) {
      ref.invalidate(upcomingMeetingsProvider);
    } else {
      ref.invalidate(institutionUpcomingMeetingsProvider(institutionId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final institutionId = widget.institutionId;

    // F2 — Invalidate providers when a meeting.state_changed WebSocket event arrives.
    ref.listen(meetingStateChangedEventProvider, (_, next) {
      next.whenData((event) {
        ref.invalidate(meetingProvider(event.meetingId));
        if (institutionId == null) {
          ref.invalidate(upcomingMeetingsProvider);
        } else {
          ref.invalidate(institutionUpcomingMeetingsProvider(institutionId));
        }
      });
    });

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
                              emptyBody: 'No bookings confirmed for today.',
                              meetings: today,
                              institutionId: institutionId,
                              highlightToday: true,
                              compact: true,
                            ),
                            const SizedBox(height: AuraSpace.s20),
                            _CollapsibleMeetingSection(
                              title: 'Upcoming meetings',
                              emptyTitle: 'No upcoming meetings',
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
                              emptyBody: 'Confirmed guest bookings appear here.',
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
                    if (institutionId != null)
                      _OpenCommitmentsSection(institutionId: institutionId),
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
              debugPrint('[instant] tap start');
              try {
                final meeting = await ref
                    .read(meetingsRepositoryProvider)
                    .startInstantMeeting();
                debugPrint(
                  '[instant] meeting created id=${meeting.id}'
                  ' joinUrl=${meeting.joinUrl} sessionId=${meeting.sessionId}',
                );
                ref.invalidate(upcomingMeetingsProvider);
                if (!context.mounted) return;
                _showMeetingStarted(context, meeting);
              } catch (e, st) {
                debugPrint('[instant][fatal] start: $e\n$st');
                messenger.showSnackBar(
                  SnackBar(content: Text('Start meeting failed: $e')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _showMeetingStarted(BuildContext context, Meeting meeting) {
    // Capture the messenger from the SCREEN context up front so the action
    // handlers never call ScaffoldMessenger.of() on the dialog context after
    // it has been popped (a dead-context lookup there throws and, mid-gesture,
    // blanks the surface). Pops target the dialog's own context.
    final messenger = ScaffoldMessenger.of(context);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
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
              debugPrint(
                '[instant] copy link pressed joinUrl=${meeting.joinUrl}',
              );
              try {
                debugPrint('[instant] before clipboard');
                Clipboard.setData(ClipboardData(text: meeting.joinUrl));
                debugPrint('[instant] after clipboard');
                // Do NOT pop the dialog here. Closing it forced the host to
                // re-tap "Start meeting" to reach "Enter room", which minted a
                // SECOND instant session — so the host joined a different
                // realtime session than the link the guest already had, and
                // both sides waited forever. Keep the dialog open so the host
                // copies the link AND enters the SAME session (meeting.id /
                // meeting.sessionId).
                debugPrint('[instant] before snackbar');
                messenger.showSnackBar(
                  const SnackBar(content: Text('Meeting link copied')),
                );
              } catch (e, st) {
                debugPrint('[instant][fatal] copy: $e\n$st');
                messenger.showSnackBar(
                  SnackBar(content: Text('Copy link failed: $e')),
                );
              }
            },
            child: const Text('Copy meeting link'),
          ),
          FilledButton(
            onPressed: () {
              // Go STRAIGHT to the live room (deep-linkable with sessionId) —
              // not the /room lobby. This makes the host's URL reloadable: a
              // page refresh re-mounts the live room and rejoins the SAME
              // session instead of bouncing to the workspace / forcing a new
              // instant meeting. isHost=true is correct here (this user just
              // created the instant meeting) and also fixes the "waiting for
              // the host" label + host-only controls.
              final route = meeting.sessionId != null
                  ? '/meetings/${meeting.id}/live'
                        '?sessionId=${meeting.sessionId}&isHost=true'
                  : '/meetings/${meeting.id}/room';
              debugPrint('[instant] before navigate route=$route');
              try {
                Navigator.pop(dialogContext);
                context.push(route);
              } catch (e, st) {
                debugPrint('[instant][fatal] enter room: $e\n$st');
                messenger.showSnackBar(
                  SnackBar(content: Text('Enter room failed: $e')),
                );
              }
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
                              MeetingStatusChip(lifecycle: lifecycle),
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
                            debugPrint(
                              '[instant] card copy link joinUrl=${meeting.joinUrl}',
                            );
                            final messenger = ScaffoldMessenger.of(context);
                            try {
                              Clipboard.setData(
                                ClipboardData(text: meeting.joinUrl),
                              );
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Meeting link copied'),
                                ),
                              );
                            } catch (e, st) {
                              debugPrint('[instant][fatal] card copy: $e\n$st');
                              messenger.showSnackBar(
                                SnackBar(content: Text('Copy link failed: $e')),
                              );
                            }
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
        const SnackBar(content: Text('Unable to start meeting. Try again.')),
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
      ).showSnackBar(const SnackBar(content: Text('Unable to cancel meeting. Try again.')));
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
    if (label == 'View summary') {
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

class _OpenCommitmentsSection extends ConsumerWidget {
  final String institutionId;
  const _OpenCommitmentsSection({required this.institutionId});

  Future<void> _markComplete(WidgetRef ref, MeetingOutcome o) async {
    try {
      await ref
          .read(meetingsRepositoryProvider)
          .updateOutcome(o.id, status: 'COMPLETED');
    } catch (_) {}
    ref.invalidate(institutionOpenOutcomesProvider(institutionId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outcomesAsync = ref.watch(institutionOpenOutcomesProvider(institutionId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Open commitments',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: const Color(0xFFE5E7EB),
          ),
        ),
        const SizedBox(height: AuraSpace.s12),
        outcomesAsync.when(
          loading: () => const SizedBox(
            height: 40,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (_, __) => const SizedBox.shrink(),
          data: (outcomes) {
            if (outcomes.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(AuraSpace.s16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  border: Border.all(color: const Color(0xFF243244)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'No open commitments across meetings.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF9CA3AF),
                  ),
                ),
              );
            }
            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                border: Border.all(color: const Color(0xFF243244)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: outcomes.map((o) {
                  final typeLabel = switch (o.type.toUpperCase()) {
                    'COMMITMENT' => 'Commitment',
                    'ACTION'     => 'Action',
                    'DECISION'   => 'Decision',
                    'ISSUE'      => 'Issue',
                    'FOLLOW_UP'  => 'Follow-up',
                    _            => o.type,
                  };
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AuraSpace.s14,
                      vertical: AuraSpace.s10,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          margin: const EdgeInsets.only(right: 8, top: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1C2B1F),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            typeLabel,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: const Color(0xFF86EFAC),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                o.text,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xFFE5E7EB),
                                ),
                              ),
                              if (o.ownerName != null || o.dueDate != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    [
                                      if (o.ownerName != null) o.ownerName!,
                                      if (o.dueDate != null)
                                        'Due ${o.dueDate!.toLocal().toString().split(' ').first}',
                                    ].join(' · '),
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: const Color(0xFF6B7280),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _markComplete(ref, o),
                          child: const Padding(
                            padding: EdgeInsets.only(left: 8, top: 1),
                            child: Tooltip(
                              message: 'Mark complete',
                              child: Icon(
                                Icons.check_circle_outline_rounded,
                                size: 18,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            );
          },
        ),
      ],
    );
  }
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
