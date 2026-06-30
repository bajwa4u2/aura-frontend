import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/guest_shell.dart';
import '../application/meetings_provider.dart';
import '../domain/meeting.dart';
import 'meeting_lifecycle_presenter.dart';

class GuestWaitingRoomScreen extends ConsumerStatefulWidget {
  final String meetingId;
  final String? institutionId;
  final String? sessionId;
  final String? returnTo;
  final String? meetingCode;

  const GuestWaitingRoomScreen({
    super.key,
    required this.meetingId,
    this.institutionId,
    this.sessionId,
    this.returnTo,
    this.meetingCode,
  });

  @override
  ConsumerState<GuestWaitingRoomScreen> createState() =>
      _GuestWaitingRoomScreenState();
}

class _GuestWaitingRoomScreenState
    extends ConsumerState<GuestWaitingRoomScreen> {
  Timer? _poller;

  @override
  void initState() {
    super.initState();
    unawaited(_ensureGuestAuth());
    _poller = Timer.periodic(const Duration(seconds: 8), (_) {
      if (!mounted) return;
      _refresh();
    });
  }

  @override
  void dispose() {
    _poller?.cancel();
    super.dispose();
  }

  String get _summaryPath => widget.institutionId == null
      ? '/meetings/${widget.meetingId}/summary'
      : '/institution/${widget.institutionId}/meetings/${widget.meetingId}/summary';

  String get _currentSessionId => (widget.sessionId ?? '').trim();

  bool get _usePublicMeetingLookup =>
      (widget.meetingCode ?? '').trim().isNotEmpty;

  Future<void> _ensureGuestAuth() async {
    final tokenStore = ref.read(tokenStoreProvider);
    await tokenStore.load();
    // Auth is exchanged in pre_join_screen before navigation; nothing to do here.
  }

  void _refresh() {
    if (_usePublicMeetingLookup) {
      ref.invalidate(meetingByCodeProvider(widget.meetingCode!.trim()));
      return;
    }
    ref.invalidate(meetingProvider(widget.meetingId));
  }

  void _copyLink(Meeting meeting) {
    Clipboard.setData(ClipboardData(text: meeting.joinUrl));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Meeting link copied')));
  }

  Future<void> _joinRoom(Meeting meeting) async {
    await _ensureGuestAuth();
    final sessionId =
        (_currentSessionId.isNotEmpty
                ? _currentSessionId
                : meeting.sessionId ?? meeting.room?.realtimeSessionId ?? '')
            .trim();
    if (sessionId.isEmpty) return;
    if (!mounted) return;
    final livePath = widget.institutionId == null
        ? '/meetings/${widget.meetingId}/live'
        : '/institution/${widget.institutionId}/meetings/${widget.meetingId}/live';
    final code = (widget.meetingCode ?? '').trim();
    final codeParam = code.isNotEmpty ? '&code=${Uri.encodeComponent(code)}' : '';
    context.push('$livePath?sessionId=$sessionId&isHost=false$codeParam');
  }

  @override
  Widget build(BuildContext context) {
    final meetingAsync = _usePublicMeetingLookup
        ? ref.watch(meetingByCodeProvider(widget.meetingCode!.trim()))
        : ref.watch(meetingProvider(widget.meetingId));

    return meetingAsync.when(
      loading: () => const GuestShell(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => GuestShell(
        showBackButton: true,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 48, color: Color(0xFF9CA3AF)),
              const SizedBox(height: AuraSpace.s16),
              const Text('Unable to load meeting.',
                  style: TextStyle(color: Color(0xFFE2ECF5), fontSize: 16)),
              const SizedBox(height: AuraSpace.s8),
              const Text('Check your connection and try again.',
                  style: TextStyle(color: Color(0xFF9CA3AF))),
            ],
          ),
        ),
      ),
      data: (meeting) {
        final lifecycle = MeetingLifecyclePresenter.present(
          meeting,
          room: meeting.room,
          isHost: false,
        );
        final sessionId =
            (_currentSessionId.isNotEmpty
                    ? _currentSessionId
                    : meeting.sessionId ??
                          meeting.room?.realtimeSessionId ??
                          '')
                .trim();
        final isTerminal = meeting.isEnded || lifecycle.isTerminal;
        final institutionName =
            meeting.booking?.institution?.name ??
            meeting.booking?.bookingPageName ??
            meeting.host?.name ??
            'Meeting';

        return GuestShell(
          institutionName: meeting.booking?.institution?.name ?? meeting.host?.name,
          institutionLogoUrl: meeting.booking?.institution?.logoUrl ?? meeting.host?.avatarUrl,
          showBackButton: true,
          body: ListView(
            padding: const EdgeInsets.all(AuraSpace.s16),
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 860),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DecoratedBox(
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
                                runSpacing: AuraSpace.s10,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  _StatusBadge(lifecycle: lifecycle),
                                  if (meeting.booking?.institution != null)
                                    const _SmallChip(
                                      icon: Icons.business_rounded,
                                      label: 'Institution meeting',
                                    ),
                                ],
                              ),
                              const SizedBox(height: AuraSpace.s16),
                              Row(
                                children: [
                                  _IdentityAvatar(
                                    name:
                                        meeting.booking?.institution?.name ??
                                        institutionName,
                                    logoUrl:
                                        meeting.booking?.institution?.logoUrl,
                                    icon: Icons.business_rounded,
                                  ),
                                  const SizedBox(width: AuraSpace.s10),
                                  if (meeting.host != null)
                                    _IdentityAvatar(
                                      name: meeting.host!.name,
                                      logoUrl: meeting.host!.avatarUrl,
                                      icon: Icons.person_outline_rounded,
                                    ),
                                ],
                              ),
                              const SizedBox(height: AuraSpace.s16),
                              Text(
                                'You are in the right place',
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: AuraSpace.s8),
                              Text(
                                meeting.title,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: AuraSpace.s8),
                              Text(
                                institutionName,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: const Color(0xFF9CA3AF)),
                              ),
                              if (meeting.host?.title?.trim().isNotEmpty ==
                                  true)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    meeting.host!.title!.trim(),
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: const Color(0xFF9CA3AF),
                                        ),
                                  ),
                                ),
                              const SizedBox(height: AuraSpace.s16),
                              _InfoRow(
                                icon: Icons.schedule_rounded,
                                label: 'Scheduled',
                                value: _scheduledLabel(context, meeting),
                              ),
                              const SizedBox(height: AuraSpace.s10),
                              _InfoRow(
                                icon: Icons.public_rounded,
                                label: 'Timezone',
                                value: meeting.timezone,
                              ),
                              const SizedBox(height: AuraSpace.s10),
                              _InfoRow(
                                icon: Icons.person_outline_rounded,
                                label: 'Host',
                                value: meeting.host?.name ?? 'Host',
                              ),
                              if (meeting.description?.trim().isNotEmpty ==
                                  true) ...[
                                const SizedBox(height: AuraSpace.s16),
                                Text(
                                  meeting.description!.trim(),
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: const Color(0xFFCBD5E1),
                                        height: 1.45,
                                      ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AuraSpace.s16),
                      Wrap(
                        spacing: AuraSpace.s10,
                        runSpacing: AuraSpace.s10,
                        children: [
                          if (!isTerminal && sessionId.isNotEmpty)
                            FilledButton.icon(
                              icon: const Icon(Icons.meeting_room_rounded),
                              label: const Text('Join meeting'),
                              onPressed: () => _joinRoom(meeting),
                            ),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Check again'),
                            onPressed: _refresh,
                          ),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.content_copy_rounded),
                            label: const Text('Copy meeting link'),
                            onPressed: () => _copyLink(meeting),
                          ),
                          TextButton(
                            onPressed: () => context.pop(),
                            child: const Text('Leave'),
                          ),
                          if (isTerminal)
                            FilledButton.icon(
                              icon: const Icon(Icons.description_outlined),
                              label: const Text('View summary'),
                              onPressed: () => context.push(_summaryPath),
                            ),
                        ],
                      ),
                      const SizedBox(height: AuraSpace.s16),
                      _WaitingCard(lifecycle: lifecycle, meeting: meeting),
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

class _WaitingCard extends StatelessWidget {
  final Meeting meeting;
  final MeetingLifecycleViewModel lifecycle;

  const _WaitingCard({required this.meeting, required this.lifecycle});

  @override
  Widget build(BuildContext context) {
    final message = switch (lifecycle.status) {
      MeetingLifecycleStatus.inProgress =>
        'The meeting is live. You can join now.',
      MeetingLifecycleStatus.guestWaiting =>
        'Waiting for the host to start the room.',
      MeetingLifecycleStatus.hostWaiting => 'The guest is waiting in the room.',
      MeetingLifecycleStatus.startingSoon => 'The meeting is starting soon.',
      MeetingLifecycleStatus.cancelled => 'This meeting was cancelled.',
      MeetingLifecycleStatus.ended => 'This meeting has ended.',
      MeetingLifecycleStatus.missed => 'This meeting was missed.',
      MeetingLifecycleStatus.connectionIssue =>
        'The room is active but needs a reconnect.',
      MeetingLifecycleStatus.scheduled =>
        'The room will stay open until the host starts it.',
      MeetingLifecycleStatus.unknown =>
        'Waiting for the room to become available.',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AuraSpace.s20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lifecycle.label,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AuraSpace.s8),
            Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF9CA3AF)),
            ),
            const SizedBox(height: AuraSpace.s12),
            Text(
              meeting.room?.activeParticipantCount == 0
                  ? 'No one else has joined yet.'
                  : '${meeting.room?.activeParticipantCount ?? 0} participant(s) are in the meeting.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
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
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: logoUrl != null && logoUrl!.trim().isNotEmpty
          ? Image.network(
              logoUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Icon(icon, color: const Color(0xFF9CA3AF)),
            )
          : Icon(icon, color: const Color(0xFF9CA3AF)),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final MeetingLifecycleViewModel lifecycle;

  const _StatusBadge({required this.lifecycle});

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
        'In progress',
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
    return Row(
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
    );
  }
}

String _scheduledLabel(BuildContext context, Meeting meeting) {
  final scheduledAt = meeting.scheduledAt;
  if (scheduledAt == null) return 'Time will be confirmed by the host';
  final local = scheduledAt.toLocal();
  return '${MaterialLocalizations.of(context).formatFullDate(local)} · ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
}
