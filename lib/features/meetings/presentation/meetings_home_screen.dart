import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config.dart';
import '../../institutions/ui/institution_ds.dart';
import '../../../core/auth/session_providers.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../application/meetings_provider.dart';
import '../domain/meeting.dart';
import '../domain/meeting_identity.dart';
import '../domain/meeting_room.dart';
import '../domain/meeting_workspace.dart';
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
    ref.invalidate(meetingWorkspaceProvider(institutionId));
  }

  @override
  Widget build(BuildContext context) {
    final institutionId = widget.institutionId;

    // F2 — Invalidate providers when a meeting.state_changed WebSocket event arrives.
    ref.listen(meetingStateChangedEventProvider, (_, next) {
      next.whenData((event) {
        ref.invalidate(meetingProvider(event.meetingId));
        ref.invalidate(meetingWorkspaceProvider(institutionId));
      });
    });

    final workspaceAsync = ref.watch(meetingWorkspaceProvider(institutionId));

    return AuraScaffold(
      title: institutionId == null ? 'Meetings' : 'Institution meetings',
      actions: [
        IconButton(
          icon: const Icon(Icons.add_rounded),
          tooltip: 'New meeting',
          onPressed: () => context.push(
            institutionId == null
                ? '/meetings/new'
                : '/institution/$institutionId/meetings/new',
          ),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(meetingWorkspaceProvider(institutionId));
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
                    _HostHeader(institutionId: institutionId),
                    const SizedBox(height: AuraSpace.s20),
                    workspaceAsync.when(
                      loading: () => const _LoadingPanel(
                        message: 'Loading meeting workspace...',
                      ),
                      error: (e, _) => _ErrorPanel(
                        message: 'Could not load meeting workspace.',
                        detail: '$e',
                      ),
                      data: (workspace) => _WorkspaceBody(
                        workspace: workspace,
                        institutionId: institutionId,
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
  /// Institution Desk context — when set, every action here creates and
  /// operates INSTITUTION meetings (ownership doctrine).
  final String? institutionId;

  const _HostHeader({this.institutionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InsModeHeader(
      title: 'Meetings',
      description:
          'Create, host, attend, and continue your institution\'s meetings.',
      primaryAction: Wrap(
        spacing: AuraSpace.s10,
        runSpacing: AuraSpace.s10,
        children: [
          FilledButton.icon(
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create meeting'),
            onPressed: () => context.push(
              institutionId == null
                  ? '/meetings/new'
                  : '/institution/$institutionId/meetings/new',
            ),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.public_rounded),
            label: const Text('Booking page'),
            onPressed: () => context.push(
              institutionId == null
                  ? '/availability'
                  : '/institution/$institutionId/availability',
            ),
          ),
          IconButton.outlined(
            icon: const Icon(Icons.tag_rounded),
            tooltip: 'Join with code',
            onPressed: () => _showJoinDialog(context),
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

class _WorkspaceBody extends StatelessWidget {
  final MeetingWorkspace workspace;
  final String? institutionId;

  const _WorkspaceBody({required this.workspace, this.institutionId});

  @override
  Widget build(BuildContext context) {
    if (workspace.isEmpty) {
      return _WorkspaceEmptyState(institutionId: institutionId);
    }

    final sections = <Widget>[
      if (workspace.needsAttention.isNotEmpty)
        _WorkspaceMeetingSection(
          title: 'Needs attention',
          items: workspace.needsAttention,
          institutionId: institutionId,
          highlight: true,
        ),
      if (workspace.todayAndNext.isNotEmpty)
        _WorkspaceMeetingSection(
          title: 'Today and next',
          items: workspace.todayAndNext,
          institutionId: institutionId,
        ),
      if (workspace.invitations.isNotEmpty)
        _WorkspaceMeetingSection(
          title: 'Invitations and requests',
          items: workspace.invitations,
          institutionId: institutionId,
        ),
      _BookingWorkspaceSection(
        booking: workspace.booking,
        institutionId: institutionId,
      ),
      if (workspace.followUp.isNotEmpty)
        _FollowUpWorkspaceSection(
          outcomes: workspace.followUp,
          institutionId: institutionId,
        ),
      if (workspace.past.isNotEmpty)
        _PastWorkspaceSection(
          items: workspace.past,
          institutionId: institutionId,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < sections.length; i++) ...[
          sections[i],
          if (i != sections.length - 1) const SizedBox(height: AuraSpace.s20),
        ],
      ],
    );
  }
}

class _WorkspaceEmptyState extends StatelessWidget {
  final String? institutionId;

  const _WorkspaceEmptyState({this.institutionId});

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      padding: const EdgeInsets.all(AuraSpace.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No meeting operations yet',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AuraSpace.s8),
          Text(
            'Create a meeting, publish a booking page, or accept an invitation.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF9CA3AF)),
          ),
          const SizedBox(height: AuraSpace.s16),
          Wrap(
            spacing: AuraSpace.s10,
            runSpacing: AuraSpace.s10,
            children: [
              FilledButton.icon(
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create meeting'),
                onPressed: () => context.push(
                  institutionId == null
                      ? '/meetings/new'
                      : '/institution/$institutionId/meetings/new',
                ),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.public_rounded),
                label: const Text('Booking page'),
                onPressed: () => context.push(
                  institutionId == null
                      ? '/availability'
                      : '/institution/$institutionId/availability',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WorkspaceMeetingSection extends StatelessWidget {
  final String title;
  final List<MeetingWorkspaceItem> items;
  final String? institutionId;
  final bool highlight;

  const _WorkspaceMeetingSection({
    required this.title,
    required this.items,
    this.institutionId,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return InsSection(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            _WorkspaceMeetingCard(
              item: items[i],
              institutionId: institutionId,
              highlight: highlight || items[i].startsSoon,
            ),
            if (i != items.length - 1)
              const SizedBox(height: InsSpacing.cardGap),
          ],
        ],
      ),
    );
  }
}

class _WorkspaceMeetingCard extends StatelessWidget {
  final MeetingWorkspaceItem item;
  final String? institutionId;
  final bool highlight;

  const _WorkspaceMeetingCard({
    required this.item,
    this.institutionId,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AuraSpace.s8,
          runSpacing: AuraSpace.s6,
          children: [
            _StatePill(
              label: item.relationship.label,
              color: const Color(0xFF6C63FF),
            ),
            if (item.pendingGuestCount > 0)
              _StatePill(
                label: '${item.pendingGuestCount} guest waiting',
                color: const Color(0xFFF59E0B),
              ),
            if (item.startsSoon)
              const _StatePill(
                label: 'Starting soon',
                color: Color(0xFF10B981),
              ),
            if (item.needsFollowUp)
              const _StatePill(
                label: 'Follow-up needed',
                color: Color(0xFF38BDF8),
              ),
          ],
        ),
        const SizedBox(height: AuraSpace.s8),
        _MeetingCard(
          meeting: item.meeting,
          institutionId: institutionId,
          compact: true,
          highlight: highlight,
        ),
      ],
    );
  }
}

class _BookingWorkspaceSection extends StatelessWidget {
  final MeetingWorkspaceBooking booking;
  final String? institutionId;

  const _BookingWorkspaceSection({required this.booking, this.institutionId});

  @override
  Widget build(BuildContext context) {
    final managePath = institutionId == null
        ? '/availability'
        : '/institution/$institutionId/availability';

    return InsSection(
      title: 'Booking',
      child: AuraCard(
        padding: const EdgeInsets.all(AuraSpace.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.public_rounded, size: 20),
                const SizedBox(width: AuraSpace.s8),
                Expanded(
                  child: Text(
                    booking.profiles.isEmpty
                        ? 'Booking not configured'
                        : '${booking.activeCount} active booking page${booking.activeCount == 1 ? '' : 's'}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: const Text('Manage'),
                  onPressed: () => context.push(managePath),
                ),
              ],
            ),
            const SizedBox(height: AuraSpace.s8),
            Text(
              booking.profiles.isEmpty
                  ? 'Set availability and publish a meeting offering to receive bookings.'
                  : booking.incompleteCount > 0
                  ? '${booking.incompleteCount} page${booking.incompleteCount == 1 ? '' : 's'} need availability or offerings before public use.'
                  : 'Public booking pages are ready to create governed meeting participation.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF9CA3AF)),
            ),
            if (booking.profiles.isNotEmpty) ...[
              const SizedBox(height: AuraSpace.s14),
              for (final profile in booking.profiles.take(3)) ...[
                _BookingProfileRow(profile: profile),
                if (profile != booking.profiles.take(3).last)
                  const Divider(height: AuraSpace.s18),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _BookingProfileRow extends StatelessWidget {
  final MeetingWorkspaceBookingProfile profile;

  const _BookingProfileRow({required this.profile});

  @override
  Widget build(BuildContext context) {
    final publicUrl = '${AppConfig.publicWebUrl}${profile.publicUrl}';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: AuraSpace.s8,
                runSpacing: AuraSpace.s6,
                children: [
                  Text(
                    profile.name,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  _StatePill(
                    label: profile.statusLabel,
                    color: profile.status == 'ACTIVE'
                        ? const Color(0xFF10B981)
                        : const Color(0xFFF59E0B),
                  ),
                ],
              ),
              const SizedBox(height: AuraSpace.s4),
              Text(
                [
                  if (profile.assignedHost?.displayName.isNotEmpty == true)
                    'Host: ${profile.assignedHost!.displayName}',
                  '${profile.defaultDuration} min',
                  '${profile.windowsCount} availability window${profile.windowsCount == 1 ? '' : 's'}',
                ].join(' · '),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: const Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Copy public booking link',
          icon: const Icon(Icons.copy_rounded, size: 18),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: publicUrl));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Booking link copied')),
            );
          },
        ),
      ],
    );
  }
}

class _FollowUpWorkspaceSection extends StatelessWidget {
  final List<MeetingOutcome> outcomes;
  final String? institutionId;

  const _FollowUpWorkspaceSection({required this.outcomes, this.institutionId});

  @override
  Widget build(BuildContext context) {
    return InsSection(
      title: 'Follow-up',
      child: AuraCard(
        padding: const EdgeInsets.symmetric(vertical: AuraSpace.s4),
        child: Column(
          children: [
            for (final outcome in outcomes.take(6))
              _FollowUpRow(outcome: outcome, institutionId: institutionId),
          ],
        ),
      ),
    );
  }
}

class _FollowUpRow extends ConsumerWidget {
  final MeetingOutcome outcome;
  final String? institutionId;

  const _FollowUpRow({required this.outcome, this.institutionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s14,
        vertical: AuraSpace.s10,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.task_alt_rounded,
            size: 18,
            color: Color(0xFF86EFAC),
          ),
          const SizedBox(width: AuraSpace.s8),
          Expanded(
            child: Text(
              outcome.text,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: const Color(0xFFE5E7EB)),
            ),
          ),
          IconButton(
            tooltip: 'Mark complete',
            icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
            onPressed: () async {
              await ref
                  .read(meetingsRepositoryProvider)
                  .updateOutcome(outcome.id, status: 'COMPLETED');
              ref.invalidate(meetingWorkspaceProvider(institutionId));
            },
          ),
        ],
      ),
    );
  }
}

class _PastWorkspaceSection extends StatelessWidget {
  final List<MeetingWorkspaceItem> items;
  final String? institutionId;

  const _PastWorkspaceSection({required this.items, this.institutionId});

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        initiallyExpanded: false,
        shape: const Border(),
        collapsedShape: const Border(),
        title: const Text('Past'),
        childrenPadding: const EdgeInsets.all(AuraSpace.s16),
        children: [
          for (var i = 0; i < items.length; i++) ...[
            _WorkspaceMeetingCard(item: items[i], institutionId: institutionId),
            if (i != items.length - 1)
              const SizedBox(height: InsSpacing.cardGap),
          ],
        ],
      ),
    );
  }
}

class _StatePill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatePill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.42)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
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

    // Participant continuity: one list, two perspectives. The viewer either
    // OPERATES this meeting (its host, or acting inside the institution
    // workspace that owns it) or PARTICIPATES in it (booked or attended).
    // The card renders truthfully for each — participation never surfaces
    // host controls, and hosting never loses them.
    final myId = ref
        .watch(authMeDataProvider)
        .maybeWhen(
          data: (me) {
            final u = me['user'];
            return (u is Map ? (u['id'] ?? '') : (me['id'] ?? ''))
                .toString()
                .trim();
          },
          orElse: () => '',
        );
    final operates =
        institutionId != null ||
        (myId.isNotEmpty && myId == (meeting.host?.id ?? ''));
    final myParticipation = myId.isEmpty
        ? null
        : meeting.participants.where((p) => p.userId == myId).firstOrNull;
    final awaitingMyConfirmation =
        !operates && myParticipation?.rsvpStatus == 'PENDING';

    final bookerIdentity = booking?.bookerIdentity;
    final guestName = operates
        ? (bookerIdentity?.displayName ??
              booking?.bookerName ??
              _guestParticipant?.displayName)
        : null;
    final guestEmail = operates
        ? (bookerIdentity?.email ??
              booking?.bookerEmail ??
              _guestParticipant?.guestEmail)
        : null;
    // The participant's anchor is who they are meeting WITH — the hosting
    // institution (owner) or the host — not their own booking identity.
    final hostAttribution = operates
        ? null
        : [
            if (booking?.institution?.name.trim().isNotEmpty == true)
              booking!.institution!.name.trim(),
            if (meeting.host?.name.trim().isNotEmpty == true)
              'Hosted by ${meeting.host!.name.trim()}',
          ].join(' · ');
    final source = _sourceLabel(meeting);
    final scheduledLabel = _scheduledLabel(context, meeting);
    final lifecycle = MeetingLifecyclePresenter.present(
      meeting,
      room: meeting.room,
      isHost: operates,
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
                          if (hostAttribution != null &&
                              hostAttribution.isNotEmpty)
                            _Line(
                              icon: Icons.apartment_rounded,
                              text: hostAttribution,
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
                if (awaitingMyConfirmation) ...[
                  const SizedBox(height: AuraSpace.s12),
                  _PendingAttachmentBanner(
                    meeting: meeting,
                    onRespond: (accepted) =>
                        _respondToMeeting(context, ref, accepted),
                  ),
                ],
                const SizedBox(height: AuraSpace.s12),
                Wrap(
                  spacing: AuraSpace.s8,
                  runSpacing: AuraSpace.s8,
                  children: [
                    _PrimaryActionButton(
                      lifecycle: lifecycle,
                      canOperate: operates,
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
                            } catch (e) {
                              messenger.showSnackBar(
                                SnackBar(content: Text('Copy link failed: $e')),
                              );
                            }
                            break;
                          case _MeetingMenuAction.leave:
                            await _respondToMeeting(context, ref, false);
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
                        // Lifecycle actions follow the viewer's role in THIS
                        // meeting: hosts/institution operators cancel the
                        // meeting itself; a participant only steps back from
                        // their own attendance — ownership stays untouched.
                        if (!meeting.isEnded && operates) ...[
                          const PopupMenuDivider(),
                          const PopupMenuItem(
                            value: _MeetingMenuAction.cancel,
                            child: Text('Cancel meeting'),
                          ),
                        ] else if (!meeting.isEnded &&
                            myParticipation != null &&
                            !awaitingMyConfirmation) ...[
                          const PopupMenuDivider(),
                          const PopupMenuItem(
                            value: _MeetingMenuAction.leave,
                            child: Text('Remove from my meetings'),
                          ),
                        ],
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

  // Ownership: inside the Institution Desk every row operates on institution
  // paths. From the personal Desk the card links to the member path — the
  // Meeting Record canonicalizes INSTITUTIONAL ACTORS to the Institution
  // Workspace, while an external participant keeps their own view of the
  // institution-owned meeting.
  String get _detailPath => institutionId == null
      ? '/meetings/${meeting.id}'
      : '/institution/$institutionId/meetings/${meeting.id}';
  String get _summaryPath => institutionId == null
      ? '/meetings/${meeting.id}/summary'
      : '/institution/$institutionId/meetings/${meeting.id}/summary';
  String get _liveBasePath => institutionId == null
      ? '/meetings/${meeting.id}/live'
      : '/institution/$institutionId/meetings/${meeting.id}/live';

  // Participant continuity: confirm (accept) or step back from (decline) the
  // viewer's OWN participation. Never a meeting-lifecycle action.
  Future<void> _respondToMeeting(
    BuildContext context,
    WidgetRef ref,
    bool accepted,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(meetingsRepositoryProvider)
          .respondToMeeting(meeting.id, accepted ? 'ACCEPTED' : 'DECLINED');
      ref.invalidate(meetingProvider(meeting.id));
      ref.invalidate(meetingWorkspaceProvider(institutionId));
      ref.invalidate(upcomingMeetingsProvider);
      ref.invalidate(pastMeetingsProvider);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            accepted
                ? 'Meeting confirmed — it stays in your meetings.'
                : 'Removed from your meetings.',
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not update. Try again.')),
      );
    }
  }

  Future<void> _startMeeting(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final updated = await ref
          .read(meetingsRepositoryProvider)
          .startMeeting(meeting.id);
      ref.invalidate(meetingProvider(meeting.id));
      ref.invalidate(meetingWorkspaceProvider(institutionId));
      if (institutionId == null) {
        ref.invalidate(upcomingMeetingsProvider);
      } else {
        ref.invalidate(institutionUpcomingMeetingsProvider(institutionId!));
      }
      if (!context.mounted) return;
      // Lobby retired: starting from the Desk goes straight into the room;
      // without a session yet, the Meeting Record is the doorway.
      if (updated.sessionId != null) {
        context.push(
          '$_liveBasePath?sessionId=${updated.sessionId}&isHost=true',
        );
      } else {
        context.push(_detailPath);
      }
    } catch (e) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Unable to start meeting. Try again.')),
      );
    }
  }

  void _joinMeeting(BuildContext context) {
    // The Desk can't know whether the viewer hosts this meeting (their list
    // includes meetings they merely attend), so joining goes through the
    // Meeting Record, which resolves the viewer's role and opens the room.
    context.push(_detailPath);
  }

  Future<void> _cancelMeeting(BuildContext context, WidgetRef ref) async {
    // Capture the messenger BEFORE any await. Cancelling invalidates the list
    // providers, which rebuilds and disposes THIS card while the method is
    // still running — reading ScaffoldMessenger.of(context) after that point
    // races a disposed element and blanks the canvas on web. The captured
    // messenger is app-scoped and survives the card's disposal.
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel meeting?'),
        content: const Text('This will cancel the meeting for everyone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep meeting'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cancel meeting'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await ref.read(meetingsRepositoryProvider).cancelMeeting(meeting.id);
      ref.invalidate(meetingProvider(meeting.id));
      ref.invalidate(meetingWorkspaceProvider(institutionId));
      if (institutionId == null) {
        ref.invalidate(upcomingMeetingsProvider);
        ref.invalidate(pastMeetingsProvider);
      } else {
        ref.invalidate(institutionUpcomingMeetingsProvider(institutionId!));
        ref.invalidate(institutionPastMeetingsProvider(institutionId!));
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('Meeting cancelled')),
      );
    } catch (e) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Unable to cancel meeting. Try again.')),
      );
    }
  }
}

enum _MeetingMenuAction { details, summary, copyLink, leave, cancel }

// Participant continuity: a booking made with the member's email attaches to
// their account awaiting THEIR word — mirroring an invitation. Confirm keeps
// it in their meetings; decline removes it. Never affects the meeting itself.
class _PendingAttachmentBanner extends StatelessWidget {
  final Meeting meeting;
  final void Function(bool accepted) onRespond;

  const _PendingAttachmentBanner({
    required this.meeting,
    required this.onRespond,
  });

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF6C63FF);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AuraSpace.s12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.event_available_rounded,
                  size: 18,
                  color: color,
                ),
                const SizedBox(width: AuraSpace.s8),
                Expanded(
                  child: Text(
                    'This meeting was booked with your email. Keep it in your meetings?',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFFE2ECF5),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AuraSpace.s10),
            Wrap(
              spacing: AuraSpace.s8,
              children: [
                FilledButton(
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => onRespond(true),
                  child: const Text('Keep meeting'),
                ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => onRespond(false),
                  child: const Text('Not mine'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

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

  /// Viewer operates this meeting (host / institution desk). A participant
  /// never sees operator actions — their forward action is joining or
  /// opening the record.
  final bool canOperate;
  final VoidCallback onStart;
  final VoidCallback onEnter;
  final VoidCallback onOpenDetails;
  final VoidCallback onOpenSummary;

  const _PrimaryActionButton({
    required this.lifecycle,
    this.canOperate = true,
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
    if (label == 'Enter room' || label == 'Join meeting') {
      return FilledButton.icon(
        icon: const Icon(Icons.video_call_rounded, size: 18),
        label: Text(label),
        onPressed: onEnter,
      );
    }
    if (!canOperate) {
      // Participant view of a not-yet-live meeting: the record is the
      // doorway — it shows schedule, agenda, and opens the room when live.
      return OutlinedButton.icon(
        icon: const Icon(Icons.event_note_rounded, size: 18),
        label: const Text('Open meeting'),
        onPressed: onOpenDetails,
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
