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
import 'widgets/meeting_device_check.dart';
import 'widgets/meeting_preparation_panel.dart';

// Pre-join: shows meeting context (host, org, purpose) before entering.
// Applies the "organization first, Aura second" principle — the guest
// sees WHO is hosting before they encounter any platform branding.
class PreJoinScreen extends ConsumerStatefulWidget {
  final String meetingCode;

  /// Booking confirmation token (the `bt` link param). Present when the BOOKER
  /// of a scheduled meeting opens their identity-bound link — we then resolve
  /// their identity from the booking and skip the name/email prompt.
  final String? bookerToken;

  const PreJoinScreen({
    super.key,
    required this.meetingCode,
    this.bookerToken,
  });

  @override
  ConsumerState<PreJoinScreen> createState() => _PreJoinScreenState();
}

class _PreJoinScreenState extends ConsumerState<PreJoinScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _deviceCheck = MeetingDeviceCheckController();
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
        bookerToken: widget.bookerToken,
      );

      if (!mounted) return;

      // Never downgrade a logged-in MEMBER to a guest token. If the host (or any
      // member) opens a join/booker link in their signed-in browser, keep their
      // member session — the realtime socket authenticates them as themselves,
      // and their host-only actions (cancel, etc.) keep working. Only a true
      // guest (unauthed, or already a guest token) exchanges the guest session.
      // The room's own _ensureGuestAuth is already isAuthed-guarded, so it won't
      // re-clobber either.
      final tokenStore = ref.read(tokenStoreProvider);
      if (!tokenStore.isMemberSession &&
          result.guestSessionId != null &&
          result.guestSessionId!.trim().isNotEmpty) {
        final guestAuth = await repo.exchangeGuestAuth(
          result.guestSessionId!.trim(),
        );
        if (!mounted) return;
        await tokenStore.setSession(
          accessToken: guestAuth.accessToken,
          refreshToken: guestAuth.refreshToken,
        );
        if (!mounted) return;
      }

      final guestIdSuffix = (result.guestSessionId ?? '').trim().isNotEmpty
          ? '&guestId=${Uri.encodeComponent(result.guestSessionId!.trim())}'
          : '';

      final guestId = (result.guestSessionId ?? '').trim();

      if (result.shouldWait) {
        final target = '/meetings/${result.meetingId}/waiting'
            '?sessionId=${result.sessionId ?? ''}'
            '&code=${Uri.encodeComponent(widget.meetingCode)}'
            '$guestIdSuffix';
        _logGuestJoin(
          context,
          target: target,
          meetingId: result.meetingId,
          sessionId: result.sessionId,
          guestId: guestId,
        );
        // Free the preview camera before entering so the room can acquire it.
        await _deviceCheck.release();
        if (!mounted) return;
        context.push(target);
        return;
      }

      if (result.sessionId != null) {
        final target = '/meetings/${result.meetingId}/room'
            '?sessionId=${result.sessionId}'
            '&code=${Uri.encodeComponent(widget.meetingCode)}'
            '$guestIdSuffix';
        _logGuestJoin(
          context,
          target: target,
          meetingId: result.meetingId,
          sessionId: result.sessionId,
          guestId: guestId,
        );
        await _deviceCheck.release();
        if (!mounted) return;
        context.push(target);
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

  // P0 guest-join telemetry — proves guest links resolve to meeting routes,
  // never the generic `/realtime/` transport screen. Kept deliberately loud
  // so a regression is visible in the trace without a repro.
  void _logGuestJoin(
    BuildContext context, {
    required String target,
    required String? meetingId,
    required String? sessionId,
    required String guestId,
  }) {
    // Production-visible (not kDebugMode-gated): proves the guest routes to a
    // meeting surface, never the generic `/realtime/` transport screen.
    debugPrint(
      '[guest-join-click] PreJoinScreen'
      ' currentUrl=${GoRouterState.of(context).uri} targetUrl=$target'
      ' meetingId=${meetingId ?? ''} sessionId=${sessionId ?? ''}'
      ' code=${widget.meetingCode} guestId=$guestId',
    );
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
        isBooker: (widget.bookerToken ?? '').trim().isNotEmpty,
        deviceCheck: MeetingDeviceCheck(
          controller: _deviceCheck,
          displayName: identityAsync.valueOrNull?.displayName ??
              meeting.booking?.bookerName,
        ),
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
  final Widget deviceCheck;
  final bool isBooker;

  const _PreJoinBody({
    required this.meeting,
    required this.nameCtrl,
    required this.emailCtrl,
    required this.formKey,
    required this.joining,
    required this.identity,
    required this.onJoin,
    required this.deviceCheck,
    required this.isBooker,
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
                    // First-class preparation brief (shared with the host lobby).
                    MeetingPreparationPanel(meeting: meeting),
                    const SizedBox(height: AuraSpace.s12),
                    _StatusPill(lifecycle: lifecycle),
                    if (identity != null) ...[
                      const SizedBox(height: AuraSpace.s12),
                      _BookingIdentityCard(identity: identity!),
                    ],
                    const SizedBox(height: AuraSpace.s24),
                    Text(
                      'Camera & microphone',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: const Color(0xFF9CA3AF),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: AuraSpace.s10),
                    deviceCheck,
                    const SizedBox(height: AuraSpace.s24),
                    if (isBooker) ...[
                      // Booker joins with the identity from their booking — no
                      // name/email prompt, and one stable participant.
                      Row(
                        children: [
                          const Icon(Icons.verified_user_rounded,
                              size: 18, color: Color(0xFF10B981)),
                          const SizedBox(width: AuraSpace.s10),
                          Expanded(
                            child: Text(
                              meeting.booking?.bookerName.trim().isNotEmpty ==
                                      true
                                  ? 'Joining as ${meeting.booking!.bookerName.trim()}'
                                  : 'Joining with your booking',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AuraSpace.s16),
                    ] else ...[
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
                    ],
                    SizedBox(
                      height: 50,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.video_call_rounded),
                        label: Text(_buttonLabel(lifecycle)),
                        onPressed: joining || lifecycle.isTerminal
                            ? null
                            : () {
                                if (!isBooker &&
                                    !formKey.currentState!.validate()) {
                                  return;
                                }
                                onJoin();
                              },
                      ),
                    ),
                    if (!isAuthed && !isBooker) ...[
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

