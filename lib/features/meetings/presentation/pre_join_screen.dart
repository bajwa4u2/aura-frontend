import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/session_providers.dart';
import '../../../core/errors/app_error_mapper.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/guest_shell.dart';
import '../application/meetings_provider.dart';
import '../domain/meeting.dart';
import '../domain/meeting_identity.dart';
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
  final _formKey = GlobalKey<FormState>();
  bool _joining = false;
  bool _identityPrefilled = false;

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

      if (result.guestSessionId != null &&
          result.guestSessionId!.trim().isNotEmpty) {
        final guestAuth = await repo.exchangeGuestAuth(
          result.guestSessionId!.trim(),
        );
        if (!mounted) return;
        await ref
            .read(tokenStoreProvider)
            .setSession(
              accessToken: guestAuth.accessToken,
              refreshToken: guestAuth.refreshToken,
            );
        if (!mounted) return;
      }

      if (result.shouldWait) {
        context.push(
          '/meetings/${result.meetingId}/waiting'
          '?sessionId=${result.sessionId ?? ''}'
          '&code=${Uri.encodeComponent(widget.meetingCode)}',
        );
        return;
      }

      if (result.sessionId != null) {
        context.push(
          '/meetings/${result.meetingId}/room'
          '?sessionId=${result.sessionId}'
          '&code=${Uri.encodeComponent(widget.meetingCode)}',
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
      final message = AppErrorMapper.from(e).message;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not join: $message')));
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  void _applyIdentity(MeetingIdentityRef? identity) {
    if (_identityPrefilled || identity == null) return;
    _identityPrefilled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_nameCtrl.text.trim().isEmpty &&
          identity.displayName.trim().isNotEmpty) {
        _nameCtrl.text = identity.displayName.trim();
      }
      if (_emailCtrl.text.trim().isEmpty && identity.email.trim().isNotEmpty) {
        _emailCtrl.text = identity.email.trim();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final meetingAsync = ref.watch(meetingByCodeProvider(widget.meetingCode));
    final identityAsync = ref.watch(currentBookingIdentityProvider);
    final theme = Theme.of(context);
    identityAsync.whenData(_applyIdentity);

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
        formKey: _formKey,
        joining: _joining,
        identity: identityAsync.valueOrNull,
        onJoin: () => _join(meeting),
      ),
    );
  }
}

class _PreJoinBody extends ConsumerWidget {
  final Meeting meeting;
  final TextEditingController nameCtrl;
  final TextEditingController emailCtrl;
  final GlobalKey<FormState> formKey;
  final bool joining;
  final MeetingIdentityRef? identity;
  final VoidCallback onJoin;

  const _PreJoinBody({
    required this.meeting,
    required this.nameCtrl,
    required this.emailCtrl,
    required this.formKey,
    required this.joining,
    required this.identity,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final lifecycle = MeetingLifecyclePresenter.present(meeting);
    final isAuthed = ref.watch(isAuthedProvider);

    final institution = meeting.booking?.institution;
    final host = meeting.host;

    return GuestShell(
      institutionName: institution?.name ?? host?.name,
      institutionLogoUrl: institution?.logoUrl ?? host?.avatarUrl,
      showBackButton: true,
      body: ListView(
        padding: const EdgeInsets.all(AuraSpace.s24),
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Form(
                key: formKey,
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
                        padding: const EdgeInsets.all(AuraSpace.s16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (institution != null)
                              _IdentityAvatar(
                                name: institution.name,
                                logoUrl: institution.logoUrl,
                                icon: Icons.business_rounded,
                              ),
                            if (institution != null && host != null)
                              const SizedBox(width: AuraSpace.s10),
                            if (host != null)
                              _IdentityAvatar(
                                name: host.name,
                                logoUrl: host.avatarUrl,
                                icon: Icons.person_outline_rounded,
                              ),
                            const SizedBox(width: AuraSpace.s14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    institution?.name ??
                                        host?.name ??
                                        meeting.title,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    host == null
                                        ? 'Host details unavailable'
                                        : host.title?.trim().isNotEmpty == true
                                        ? host.title!.trim()
                                        : host.name,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: const Color(0xFFCBD5E1),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AuraSpace.s20),
                    Text(
                      meeting.title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (identity != null) ...[
                      const SizedBox(height: AuraSpace.s12),
                      _BookingIdentityCard(identity: identity!),
                    ],
                    if ((meeting.description ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: AuraSpace.s8),
                      Text(
                        meeting.description!.trim(),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFFCBD5E1),
                          height: 1.45,
                        ),
                      ),
                    ],
                    if ((meeting.preparationNotes ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: AuraSpace.s16),
                      Text(
                        'Agenda',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: const Color(0xFF9CA3AF),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: AuraSpace.s8),
                      ...meeting.preparationNotes!.trim().split('\n').where((l) => l.trim().isNotEmpty).map(
                        (line) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('· ', style: TextStyle(color: Color(0xFF6C63FF))),
                              Expanded(
                                child: Text(
                                  line.trim(),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: const Color(0xFFCBD5E1),
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
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
                    _MeetingMetaRow(
                      icon: Icons.public_rounded,
                      text: meeting.timezone,
                    ),
                    if (host?.title?.trim().isNotEmpty == true)
                      _MeetingMetaRow(
                        icon: Icons.badge_outlined,
                        text: host!.title!.trim(),
                      ),
                    const SizedBox(height: AuraSpace.s24),
                    Text(
                      isAuthed
                          ? 'Join with your Aura account'
                          : 'Join as a guest',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AuraSpace.s6),
                    TextFormField(
                      controller: nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        hintText: 'Enter your name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter your name to join';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AuraSpace.s12),
                    TextFormField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        hintText: 'your@email.com',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.mail_outline_rounded),
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) return null;
                        if (!text.contains('@')) {
                          return 'Enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AuraSpace.s24),
                    SizedBox(
                      height: 50,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.video_call_rounded),
                        label: Text(_buttonLabel(lifecycle)),
                        onPressed: joining || lifecycle.isTerminal
                            ? null
                            : () {
                                if (!formKey.currentState!.validate()) return;
                                onJoin();
                              },
                      ),
                    ),
                    if (!isAuthed) ...[
                      const SizedBox(height: AuraSpace.s12),
                      TextButton.icon(
                        icon: const Icon(Icons.login_rounded),
                        label: const Text('Sign in with Aura'),
                        onPressed: () => context.go(
                          '/login?redirect=${Uri.encodeComponent('/meetings/join/${meeting.meetingCode}')}',
                        ),
                      ),
                    ],
                    const SizedBox(height: AuraSpace.s32),
                  ],
                ),
              ),
            ),
          ),
        ],
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
    return CircleAvatar(
      radius: 22,
      backgroundColor: const Color(0xFF111827),
      backgroundImage: (logoUrl != null && logoUrl!.trim().isNotEmpty)
          ? NetworkImage(logoUrl!)
          : null,
      child: logoUrl == null || logoUrl!.trim().isEmpty
          ? Icon(icon, color: const Color(0xFFE5E7EB), size: 18)
          : null,
    );
  }
}

class _BookingIdentityCard extends StatelessWidget {
  final MeetingIdentityRef identity;

  const _BookingIdentityCard({required this.identity});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: const Color(0xFF243244)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AuraSpace.s12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: const Color(0xFF6C63FF).withValues(alpha: 0.18),
              backgroundImage:
                  identity.avatarUrl != null &&
                      identity.avatarUrl!.trim().isNotEmpty
                  ? NetworkImage(identity.avatarUrl!)
                  : null,
              child:
                  identity.avatarUrl == null ||
                      identity.avatarUrl!.trim().isEmpty
                  ? Text(
                      identity.displayName.trim().isEmpty
                          ? 'G'
                          : identity.displayName.trim()[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: AuraSpace.s10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    identity.displayName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (identity.email.trim().isNotEmpty)
                    Text(
                      identity.email.trim(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF9CA3AF),
                      ),
                    ),
                ],
              ),
            ),
          ],
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
