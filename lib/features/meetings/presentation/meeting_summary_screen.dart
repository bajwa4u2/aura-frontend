import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../application/meetings_provider.dart';
import '../domain/meeting.dart';
import '../domain/meeting_conversation_message.dart';
import 'meeting_lifecycle_presenter.dart';
import 'meeting_status_chip.dart';

class MeetingSummaryScreen extends ConsumerWidget {
  final String meetingId;
  final String? institutionId;

  const MeetingSummaryScreen({
    super.key,
    required this.meetingId,
    this.institutionId,
  });

  String get _postMeetingPath => institutionId == null
      ? '/meetings/$meetingId/post-meeting'
      : '/institution/$institutionId/meetings/$meetingId/post-meeting';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meetingAsync = ref.watch(meetingProvider(meetingId));
    final summaryAsync = ref.watch(meetingSummaryProvider(meetingId));
    final outcomesAsync = ref.watch(meetingOutcomesProvider(meetingId));
    // Phase 4 — conversation transcript (renders nothing when empty or when
    // the caller is not a participant).
    final conversationAsync = ref.watch(meetingConversationProvider(meetingId));
    final conversation =
        conversationAsync.valueOrNull ?? const <MeetingConversationMessage>[];

    return meetingAsync.when(
      loading: () => AuraScaffold(
        title: 'Meeting summary',
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => AuraScaffold(
        title: 'Meeting summary',
        body: const Center(child: Text('Unable to load meeting summary.')),
      ),
      data: (meeting) {
        final room = meeting.room;
        final lifecycle = MeetingLifecyclePresenter.present(
          meeting,
          room: room,
          isHost: true,
        );
        final summary = summaryAsync.valueOrNull ?? meeting.summary;
        final outcomes = outcomesAsync.valueOrNull ?? <MeetingOutcome>[];
        final outcomeStatusByText = {
          for (final o in outcomes) o.text: o.status,
        };
        // OPEN outcome id keyed by text — used to wire the mark-complete tap.
        final openOutcomeIdByText = {
          for (final o in outcomes)
            if (o.status == OutcomeStatus.open) o.text: o.id,
        };

        Future<void> markComplete(String outcomeId) async {
          try {
            await ref
                .read(meetingsRepositoryProvider)
                .updateOutcome(outcomeId, status: 'COMPLETED');
          } catch (_) {}
          ref.invalidate(meetingOutcomesProvider(meetingId));
        }
        final booking = meeting.booking;
        final institutionName =
            booking?.institution?.name ??
            booking?.bookingPageName ??
            meeting.host?.name ??
            'Meeting';

        return AuraScaffold(
          title: 'Meeting summary',
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
          body: ListView(
            padding: const EdgeInsets.all(AuraSpace.s16),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1040),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SummaryHeader(
                        meeting: meeting,
                        lifecycle: lifecycle,
                        institutionName: institutionName,
                        onCopy: () => _copyLink(context, meeting),
                        onOpenWorkspace: () => context.push(_postMeetingPath),
                        onOpenDetails: () => context.push(
                          institutionId == null
                              ? '/meetings/$meetingId'
                              : '/institution/$institutionId/meetings/$meetingId',
                        ),
                        onOpenRoom:
                            !meeting.isEnded && meeting.sessionId != null
                            ? () => context.push(
                                institutionId == null
                                    ? '/meetings/$meetingId/room?sessionId=${meeting.sessionId}'
                                    : '/institution/$institutionId/meetings/$meetingId/room?sessionId=${meeting.sessionId}',
                              )
                            : null,
                      ),
                      const SizedBox(height: AuraSpace.s16),
                      Wrap(
                        spacing: AuraSpace.s16,
                        runSpacing: AuraSpace.s16,
                        children: [
                          _SummaryPanel(
                            title: 'Attendance',
                            width: 510,
                            children: [
                              _AttendanceRow(
                                label: 'Host',
                                value: meeting.host?.name ?? 'Host',
                                status: 'Host present',
                              ),
                              ...meeting.participants
                                  .where((p) => !p.isHost)
                                  .map((participant) {
                                    String status;
                                    if (!participant.attended) {
                                      status = 'Not joined';
                                    } else {
                                      final dur = participant.durationMinutes;
                                      status = dur != null
                                          ? 'Joined · ${dur}m'
                                          : 'Joined';
                                    }
                                    return _AttendanceRow(
                                      label: participant.isGuest
                                          ? 'Guest'
                                          : 'Participant',
                                      value: participant.displayName,
                                      status: status,
                                    );
                                  }),
                            ],
                          ),
                          _SummaryPanel(
                            title: 'Meeting context',
                            width: 510,
                            children: [
                              _InfoRow(
                                icon: Icons.schedule_rounded,
                                label: 'Scheduled',
                                value: _scheduledLabel(context, meeting),
                              ),
                              _InfoRow(
                                icon: Icons.timer_outlined,
                                label: 'Duration',
                                value: '${meeting.durationMinutes} minutes',
                              ),
                              _InfoRow(
                                icon: Icons.public_rounded,
                                label: 'Timezone',
                                value: meeting.timezone,
                              ),
                              _InfoRow(
                                icon: Icons.business_rounded,
                                label: 'Institution',
                                value: institutionName,
                              ),
                              _InfoRow(
                                icon: Icons.link_rounded,
                                label: 'Join link',
                                value: meeting.joinUrl,
                              ),
                            ],
                          ),
                          if ((meeting.preparationNotes ?? '').trim().isNotEmpty)
                            _SummaryPanel(
                              title: 'Agenda',
                              width: 510,
                              children: meeting.preparationNotes!
                                  .trim()
                                  .split('\n')
                                  .where((l) => l.trim().isNotEmpty)
                                  .map(
                                    (line) => Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            '·  ',
                                            style: TextStyle(
                                              color: Color(0xFF6C63FF),
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          Expanded(
                                            child: Text(
                                              line.trim(),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          if ((meeting.liveNotes ?? '').trim().isNotEmpty)
                            _SummaryPanel(
                              title: 'Live notes',
                              width: 510,
                              children: meeting.liveNotes!
                                  .trim()
                                  .split('\n')
                                  .where((l) => l.trim().isNotEmpty)
                                  .map(
                                    (line) => Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            '·  ',
                                            style: TextStyle(
                                              color: Color(0xFF10B981),
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          Expanded(
                                            child: Text(
                                              line.trim(),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          if (conversation.isNotEmpty)
                            _SummaryPanel(
                              title: 'Conversation',
                              width: 510,
                              children: conversation
                                  .map(
                                    (msg) => Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '·  ',
                                            style: TextStyle(
                                              color: _messageTypeColor(
                                                msg.messageType,
                                              ),
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          Expanded(
                                            child: Text.rich(
                                              TextSpan(
                                                children: [
                                                  TextSpan(
                                                    text: msg.senderName,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                  if (msg.messageType !=
                                                      MeetingMessageType.chat)
                                                    TextSpan(
                                                      text:
                                                          ' · ${msg.messageType.label}',
                                                      style: TextStyle(
                                                        color:
                                                            _messageTypeColor(
                                                          msg.messageType,
                                                        ),
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  TextSpan(
                                                    text: '  ${msg.body}',
                                                  ),
                                                  if (msg.isPromoted)
                                                    const TextSpan(
                                                      text: '   ✓ outcome',
                                                      style: TextStyle(
                                                        color:
                                                            Color(0xFF10B981),
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                        ],
                      ),
                      const SizedBox(height: AuraSpace.s16),
                      _SummaryPanel(
                        title: 'Meeting summary',
                        fullWidth: true,
                        children: [
                          if (summary?.summaryText?.trim().isNotEmpty == true)
                            _InfoRow(
                              icon: Icons.subject_rounded,
                              label: 'Summary',
                              value: summary!.summaryText!.trim(),
                            )
                          else
                            const _EmptyState(
                              title: 'No summary recorded yet',
                              body:
                                  'Open the workspace to capture the meeting summary, decisions, commitments, actions, issues, and follow-ups.',
                            ),
                        ],
                      ),
                      const SizedBox(height: AuraSpace.s16),
                      _SummaryTile(
                        title: 'Booking source and notes',
                        children: [
                          _InfoRow(
                            icon: Icons.calendar_today_rounded,
                            label: 'Booking page',
                            value:
                                booking?.bookingPageName?.trim().isNotEmpty ==
                                    true
                                ? booking!.bookingPageName!
                                : 'Not created from a booking page',
                          ),
                          if (booking?.bookerNotes?.trim().isNotEmpty == true)
                            _InfoRow(
                              icon: Icons.notes_rounded,
                              label: 'Guest note',
                              value: booking!.bookerNotes!.trim(),
                            ),
                          if ((meeting.description ?? '').trim().isNotEmpty)
                            _InfoRow(
                              icon: Icons.description_outlined,
                              label: 'Meeting description',
                              value: meeting.description!.trim(),
                            ),
                        ],
                      ),
                      const SizedBox(height: AuraSpace.s16),
                      _SummaryTile(
                        title: 'Follow-up',
                        initiallyExpanded: true,
                        children: [
                          _FollowUpBlock(
                            title: 'Decisions',
                            values: summary?.decisions ?? const [],
                            fallback:
                                'Record the decision you reached in the meeting.',
                            statusByText: outcomeStatusByText,
                            openIdByText: openOutcomeIdByText,
                            onMarkComplete: markComplete,
                          ),
                          const SizedBox(height: AuraSpace.s12),
                          _FollowUpBlock(
                            title: 'Commitments',
                            values: summary?.commitments ?? const [],
                            fallback:
                                'Capture anything the host or guest agreed to do next.',
                            statusByText: outcomeStatusByText,
                            openIdByText: openOutcomeIdByText,
                            onMarkComplete: markComplete,
                          ),
                          const SizedBox(height: AuraSpace.s12),
                          _FollowUpBlock(
                            title: 'Actions and next steps',
                            values: summary?.actions ?? const [],
                            fallback:
                                'Track the work that should continue after the meeting.',
                            statusByText: outcomeStatusByText,
                            openIdByText: openOutcomeIdByText,
                            onMarkComplete: markComplete,
                          ),
                          const SizedBox(height: AuraSpace.s12),
                          _FollowUpBlock(
                            title: 'Issues',
                            values: summary?.issues ?? const [],
                            fallback: 'Record any blockers or open questions.',
                            statusByText: outcomeStatusByText,
                            openIdByText: openOutcomeIdByText,
                            onMarkComplete: markComplete,
                          ),
                          const SizedBox(height: AuraSpace.s12),
                          _FollowUpBlock(
                            title: 'Follow-ups',
                            values: summary?.followUps ?? const [],
                            fallback:
                                'Record the next check-in, reply, or milestone.',
                            statusByText: outcomeStatusByText,
                            openIdByText: openOutcomeIdByText,
                            onMarkComplete: markComplete,
                          ),
                        ],
                      ),
                      const SizedBox(height: AuraSpace.s16),
                      if (!meeting.isEnded)
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            border: Border.all(color: const Color(0xFF243244)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(AuraSpace.s16),
                            child: Text(
                              'This meeting is still active. The summary will continue to update while the room remains open.',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: const Color(0xFF9CA3AF)),
                            ),
                          ),
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

  void _copyLink(BuildContext context, Meeting meeting) {
    Clipboard.setData(ClipboardData(text: meeting.joinUrl));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Meeting link copied')));
  }
}

// Phase 4 — bullet/badge colour per conversation message type (chat stays
// neutral; continuity types match the outcome palette).
Color _messageTypeColor(MeetingMessageType type) {
  switch (type) {
    case MeetingMessageType.decision:
      return const Color(0xFF10B981);
    case MeetingMessageType.commitment:
      return const Color(0xFFF59E0B);
    case MeetingMessageType.action:
      return const Color(0xFF38BDF8);
    case MeetingMessageType.issue:
      return const Color(0xFFF43F5E);
    case MeetingMessageType.followUp:
      return const Color(0xFF8B5CF6);
    case MeetingMessageType.chat:
    case MeetingMessageType.system:
      return const Color(0xFF6C63FF);
  }
}

class _SummaryHeader extends StatelessWidget {
  final Meeting meeting;
  final MeetingLifecycleViewModel lifecycle;
  final String institutionName;
  final VoidCallback onCopy;
  final VoidCallback onOpenWorkspace;
  final VoidCallback onOpenDetails;
  final VoidCallback? onOpenRoom;

  const _SummaryHeader({
    required this.meeting,
    required this.lifecycle,
    required this.institutionName,
    required this.onCopy,
    required this.onOpenWorkspace,
    required this.onOpenDetails,
    required this.onOpenRoom,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: const Color(0xFF243244)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AuraSpace.s20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: AuraSpace.s10,
              runSpacing: AuraSpace.s8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                MeetingStatusChip(lifecycle: lifecycle),
                if (meeting.booking != null)
                  const _SmallChip(
                    icon: Icons.calendar_today_rounded,
                    label: 'Guest booking',
                  ),
              ],
            ),
            const SizedBox(height: AuraSpace.s12),
            Text(
              meeting.title,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AuraSpace.s8),
            Text(
              institutionName,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF9CA3AF)),
            ),
            if ((meeting.description ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: AuraSpace.s8),
              Text(
                meeting.description!.trim(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFFCBD5E1),
                ),
              ),
            ],
            const SizedBox(height: AuraSpace.s16),
            Wrap(
              spacing: AuraSpace.s10,
              runSpacing: AuraSpace.s10,
              children: [
                FilledButton.icon(
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('Open post-meeting workspace'),
                  onPressed: onOpenWorkspace,
                ),
                if (onOpenRoom != null)
                  FilledButton.icon(
                    icon: const Icon(Icons.meeting_room_rounded),
                    label: const Text('Open room'),
                    onPressed: onOpenRoom,
                  ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.info_outline_rounded),
                  label: const Text('View details'),
                  onPressed: onOpenDetails,
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.content_copy_rounded),
                  label: const Text('Copy meeting link'),
                  onPressed: onCopy,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryPanel extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final double? width;
  final bool fullWidth;

  const _SummaryPanel({
    required this.title,
    required this.children,
    this.width,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final panelWidth = fullWidth ? double.infinity : width ?? 480;
    return SizedBox(
      width: panelWidth,
      child: DecoratedBox(
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
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AuraSpace.s12),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final bool initiallyExpanded;

  const _SummaryTile({
    required this.title,
    required this.children,
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
        childrenPadding: const EdgeInsets.fromLTRB(
          AuraSpace.s18,
          0,
          AuraSpace.s18,
          AuraSpace.s18,
        ),
        collapsedIconColor: const Color(0xFF9CA3AF),
        iconColor: const Color(0xFF9CA3AF),
        title: Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        children: children,
      ),
    );
  }
}

class _AttendanceRow extends StatelessWidget {
  final String label;
  final String value;
  final String status;

  const _AttendanceRow({
    required this.label,
    required this.value,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.s10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$label · $value',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Text(
            status,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: const Color(0xFF9CA3AF)),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String body;

  const _EmptyState({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Text(
      '$title: $body',
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF9CA3AF)),
    );
  }
}

class _FollowUpBlock extends StatelessWidget {
  final String title;
  final List<String> values;
  final String fallback;
  final Map<String, OutcomeStatus> statusByText;
  // text → outcomeId for OPEN items only; present means item is tappable.
  final Map<String, String> openIdByText;
  final Future<void> Function(String outcomeId)? onMarkComplete;

  const _FollowUpBlock({
    required this.title,
    required this.values,
    required this.fallback,
    this.statusByText = const {},
    this.openIdByText = const {},
    this.onMarkComplete,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        border: Border.all(color: const Color(0xFF243244)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AuraSpace.s14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AuraSpace.s6),
            if (values.isEmpty)
              Text(
                fallback,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF9CA3AF),
                ),
              )
            else
              ...values.map((value) {
                final outcomeId = openIdByText[value];
                final canComplete =
                    outcomeId != null && onMarkComplete != null;
                return Padding(
                  padding: const EdgeInsets.only(bottom: AuraSpace.s6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          '• $value',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFFE5E7EB),
                              ),
                        ),
                      ),
                      if (statusByText.containsKey(value))
                        _OutcomeStatusBadge(statusByText[value]!),
                      if (canComplete)
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onMarkComplete!(outcomeId),
                          child: const Padding(
                            padding: EdgeInsets.only(left: 6, top: 1),
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
              }),
          ],
        ),
      ),
    );
  }
}

class _OutcomeStatusBadge extends StatelessWidget {
  final OutcomeStatus status;
  const _OutcomeStatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      OutcomeStatus.completed => ('Done', const Color(0xFF064E3B), const Color(0xFF6EE7B7)),
      OutcomeStatus.deferred  => ('Deferred', const Color(0xFF1E3A5F), const Color(0xFF93C5FD)),
      OutcomeStatus.cancelled => ('Cancelled', const Color(0xFF3B1F1F), const Color(0xFFFCA5A5)),
      OutcomeStatus.open      => ('Open', const Color(0xFF1C2B1F), const Color(0xFF86EFAC)),
    };
    return Container(
      margin: const EdgeInsets.only(left: 6, top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SmallChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SmallChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.s10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF9CA3AF)),
          const SizedBox(width: AuraSpace.s10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: const Color(0xFF9CA3AF),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(value),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _scheduledLabel(BuildContext context, Meeting meeting) {
  final scheduledAt = meeting.scheduledAt;
  if (scheduledAt == null) return 'Time will be confirmed by the host';
  final local = scheduledAt.toLocal();
  return '${MaterialLocalizations.of(context).formatFullDate(local)} · ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
}
