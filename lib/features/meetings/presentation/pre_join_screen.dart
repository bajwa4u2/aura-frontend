import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/errors/app_error_mapper.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/guest_shell.dart';
import '../application/meetings_provider.dart';
import '../domain/meeting.dart';
import '../domain/meeting_entry_resolution.dart';
import 'widgets/meeting_device_check.dart';
import 'widgets/meeting_preparation_panel.dart';

// Pre-join — RESOLVER-DRIVEN (Participation Architecture).
//
// The backend's canonical Participation Resolver decides who this entrant is
// and what they may do next; this screen renders EXACTLY that outcome. It
// never infers policy from local conditions (auth state, token presence):
//   * guest identity fields appear ONLY on GUEST_IDENTITY_REQUIRED
//   * members/bookers/invitees see their recognized identity, never a prompt
//   * LOGIN_REQUIRED preserves every entry token through the auth return
//   * FORBIDDEN / IDENTITY_CONFLICT / MEETING_UNAVAILABLE are terminal
class PreJoinScreen extends ConsumerStatefulWidget {
  final String meetingCode;

  /// Booking confirmation token (the `bt` link param).
  final String? bookerToken;

  /// Invitation token (the `in` link param) — participation proof for an
  /// invited entrant.
  final String? invitationToken;

  const PreJoinScreen({
    super.key,
    required this.meetingCode,
    this.bookerToken,
    this.invitationToken,
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

  MeetingEntryKey get _entryKey => MeetingEntryKey(
        widget.meetingCode,
        bookerToken: _clean(widget.bookerToken),
        invitationToken: _clean(widget.invitationToken),
      );

  static String? _clean(String? v) {
    final t = (v ?? '').trim();
    return t.isEmpty ? null : t;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _join(MeetingEntryResolution resolution) async {
    setState(() => _joining = true);
    try {
      final repo = ref.read(meetingsRepositoryProvider);
      final isMember = ref.read(tokenStoreProvider).isMemberSession;
      final needsIdentity = resolution.guestIdentityRequired;
      final result = await repo.joinMeeting(
        widget.meetingCode,
        guestName: needsIdentity ? _nameCtrl.text.trim() : null,
        guestEmail: needsIdentity ? _emailCtrl.text.trim() : null,
        bookerToken: _clean(widget.bookerToken),
        invitationToken: _clean(widget.invitationToken),
        asMember: isMember,
      );

      if (!mounted) return;

      // Never downgrade a logged-in MEMBER to a guest token. Only a true
      // guest (unauthed) exchanges the guest session for a guest JWT.
      final tokenStore = ref.read(tokenStoreProvider);
      if (!tokenStore.isMemberSession &&
          (result.guestSessionId ?? '').trim().isNotEmpty) {
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

      final guestId = (result.guestSessionId ?? '').trim();
      final guestIdSuffix = guestId.isNotEmpty
          ? '&guestId=${Uri.encodeComponent(guestId)}'
          : '';

      if (result.shouldWait) {
        final target = '/meetings/${result.meetingId}/waiting'
            '?sessionId=${result.sessionId ?? ''}'
            '&code=${Uri.encodeComponent(widget.meetingCode)}'
            '$guestIdSuffix';
        _logEntry(target, result);
        await _deviceCheck.release();
        if (!mounted) return;
        context.push(target);
        return;
      }

      if (result.sessionId != null) {
        final target = '/meetings/${result.meetingId}/live'
            '?sessionId=${result.sessionId}'
            '&code=${Uri.encodeComponent(widget.meetingCode)}'
            '$guestIdSuffix';
        _logEntry(target, result);
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
      // The server re-ran resolution at admission; its verdict may have
      // changed since ours. Re-resolve so the screen shows the current truth.
      ref.invalidate(meetingEntryResolutionProvider(_entryKey));
      final message = AppErrorMapper.from(e).message;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not join: $message')));
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  // P0 entry telemetry — proves entry resolves to meeting routes, never the
  // generic `/realtime/` transport screen.
  void _logEntry(String target, JoinMeetingResult result) {
    debugPrint(
      '[guest-join-click] PreJoinScreen'
      ' currentUrl=${GoRouterState.of(context).uri} targetUrl=$target'
      ' meetingId=${result.meetingId} sessionId=${result.sessionId ?? ''}'
      ' code=${widget.meetingCode}'
      ' outcome=${result.outcome ?? ''} reason=${result.reasonCode ?? ''}',
    );
  }

  void _goToLogin() {
    final params = <String>[
      if (_clean(widget.bookerToken) != null)
        'bt=${Uri.encodeComponent(widget.bookerToken!.trim())}',
      if (_clean(widget.invitationToken) != null)
        'in=${Uri.encodeComponent(widget.invitationToken!.trim())}',
    ].join('&');
    final target =
        '/meetings/join/${widget.meetingCode}${params.isEmpty ? '' : '?$params'}';
    context.go('/login?redirect=${Uri.encodeComponent(target)}');
  }

  @override
  Widget build(BuildContext context) {
    final resolutionAsync = ref.watch(meetingEntryResolutionProvider(_entryKey));
    final theme = Theme.of(context);

    return resolutionAsync.when(
      loading: () => const GuestShell(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => GuestShell(
        showBackButton: true,
        body: _TerminalMessage(
          icon: Icons.error_outline_rounded,
          title: 'Meeting not found',
          detail: 'Check the meeting code and try again.',
          action: FilledButton.icon(
            icon: const Icon(Icons.keyboard_rounded, size: 18),
            label: const Text('Enter a meeting code'),
            onPressed: () => context.go('/meetings/join'),
          ),
        ),
      ),
      data: (resolution) => _buildForResolution(context, theme, resolution),
    );
  }

  Widget _buildForResolution(
    BuildContext context,
    ThemeData theme,
    MeetingEntryResolution resolution,
  ) {
    switch (resolution.outcome) {
      case MeetingEntryOutcome.meetingUnavailable:
        return GuestShell(
          showBackButton: true,
          body: _TerminalMessage(
            icon: Icons.event_busy_rounded,
            title: switch (resolution.reasonCode) {
              'MEETING_CANCELLED' => 'This meeting was cancelled',
              'MEETING_ENDED' => 'This meeting has ended',
              'MEETING_DRAFT' => 'This meeting is not open yet',
              _ => 'Meeting not available',
            },
            detail: 'Contact the meeting host if you believe this is a mistake.',
            action: FilledButton.icon(
              icon: const Icon(Icons.keyboard_rounded, size: 18),
              label: const Text('Enter a meeting code'),
              onPressed: () => context.go('/meetings/join'),
            ),
          ),
        );

      case MeetingEntryOutcome.forbidden:
        return GuestShell(
          showBackButton: true,
          body: _TerminalMessage(
            icon: Icons.lock_outline_rounded,
            title: switch (resolution.reasonCode) {
              'PARTICIPANT_DENIED' => 'The host did not admit you',
              'INVITATION_REVOKED' => 'Your invitation was withdrawn',
              'INVITATION_EXPIRED' => 'Your invitation has expired',
              'BOOKING_CANCELLED' => 'This booking was cancelled',
              'NOT_INSTITUTION_MEMBER' =>
                'This meeting is for institution members',
              _ => 'You don\'t have access to this meeting',
            },
            detail:
                'Ask the meeting host for an invitation if you should be here.',
          ),
        );

      case MeetingEntryOutcome.identityConflict:
        return const GuestShell(
          showBackButton: true,
          body: _TerminalMessage(
            icon: Icons.person_off_rounded,
            title: 'This link belongs to someone else',
            detail:
                'The invitation or booking you opened was issued for a different '
                'person. Open the link from your own email, or ask the host to '
                'invite this account.',
          ),
        );

      case MeetingEntryOutcome.loginRequired:
        return GuestShell(
          showBackButton: true,
          body: _TerminalMessage(
            icon: Icons.login_rounded,
            title: 'Sign in to join this meeting',
            detail: resolution.presentation?.title.trim().isNotEmpty == true
                ? '"${resolution.presentation!.title.trim()}" is for signed-in '
                    'participants.'
                : 'This meeting is for signed-in participants.',
            action: FilledButton.icon(
              icon: const Icon(Icons.login_rounded, size: 18),
              label: const Text('Sign in with Aura'),
              onPressed: _goToLogin,
            ),
          ),
        );

      case MeetingEntryOutcome.requestAccess:
      case MeetingEntryOutcome.waitingForAdmission:
      case MeetingEntryOutcome.guestIdentityRequired:
      case MeetingEntryOutcome.hostDirect:
      case MeetingEntryOutcome.participantDirect:
      case MeetingEntryOutcome.bookerDirect:
      case MeetingEntryOutcome.invitedDirect:
      case MeetingEntryOutcome.institutionMemberDirect:
      case MeetingEntryOutcome.guestDirect:
        return _PreJoinBody(
          resolution: resolution,
          meetingCode: widget.meetingCode,
          nameCtrl: _nameCtrl,
          emailCtrl: _emailCtrl,
          formKey: _formKey,
          joining: _joining,
          onJoin: () => _join(resolution),
          onLogin: _goToLogin,
          deviceCheck: MeetingDeviceCheck(
            controller: _deviceCheck,
            displayName:
                resolution.identityName ?? resolution.prefillName,
          ),
        );
    }
  }
}

class _PreJoinBody extends ConsumerWidget {
  final MeetingEntryResolution resolution;
  final String meetingCode;
  final TextEditingController nameCtrl;
  final TextEditingController emailCtrl;
  final GlobalKey<FormState> formKey;
  final bool joining;
  final VoidCallback onJoin;
  final VoidCallback onLogin;
  final Widget deviceCheck;

  const _PreJoinBody({
    required this.resolution,
    required this.meetingCode,
    required this.nameCtrl,
    required this.emailCtrl,
    required this.formKey,
    required this.joining,
    required this.onJoin,
    required this.onLogin,
    required this.deviceCheck,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // Preparation materials still travel to the pre-join surface (public,
    // guest-visible assets) — presentation only, no policy.
    final meetingAsync = ref.watch(meetingByCodeProvider(meetingCode));
    final needsGuestIdentity = resolution.guestIdentityRequired;
    final waiting =
        resolution.outcome == MeetingEntryOutcome.waitingForAdmission;

    return GuestShell(
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
                    // First-class preparation brief (shared with host lobby).
                    if (meetingAsync.valueOrNull != null)
                      MeetingPreparationPanel(
                        meeting: meetingAsync.valueOrNull as Meeting,
                      ),
                    const SizedBox(height: AuraSpace.s12),
                    _EntryStatusPill(resolution: resolution),
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
                    if (needsGuestIdentity)
                      ..._guestIdentityFields(theme)
                    else
                      _RecognizedIdentity(resolution: resolution),
                    const SizedBox(height: AuraSpace.s16),
                    if (resolution.approvalRequired && !waiting) ...[
                      Text(
                        'The host reviews who joins — you may wait briefly '
                        'after asking to join.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF9CA3AF),
                        ),
                      ),
                      const SizedBox(height: AuraSpace.s10),
                    ],
                    SizedBox(
                      height: 50,
                      child: FilledButton.icon(
                        icon: Icon(
                          waiting
                              ? Icons.hourglass_top_rounded
                              : Icons.video_call_rounded,
                          size: 20,
                        ),
                        label: Text(
                          waiting
                              ? 'Return to waiting room'
                              : resolution.approvalRequired
                                  ? 'Ask to join'
                                  : 'Join meeting',
                        ),
                        onPressed: joining
                            ? null
                            : () {
                                if (needsGuestIdentity &&
                                    !formKey.currentState!.validate()) {
                                  return;
                                }
                                onJoin();
                              },
                      ),
                    ),
                    if (resolution.identityKind == 'ANONYMOUS') ...[
                      const SizedBox(height: AuraSpace.s12),
                      // Participant continuity: signing in preserves the
                      // entry tokens so the meeting attaches to the member's
                      // account the moment they join.
                      TextButton.icon(
                        icon: const Icon(Icons.login_rounded),
                        label: const Text('Sign in with Aura'),
                        onPressed: onLogin,
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

  List<Widget> _guestIdentityFields(ThemeData theme) {
    return [
      Text(
        'Join as a guest',
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
          helperText: 'The meeting summary and follow-ups arrive here.',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.mail_outline_rounded),
        ),
        validator: (value) {
          // Identity continuity: a guest without an email cannot receive
          // summaries or follow-ups — email is required, like a booking.
          final text = value?.trim() ?? '';
          if (text.isEmpty) return 'Email is required to join';
          if (!text.contains('@')) return 'Enter a valid email';
          return null;
        },
      ),
    ];
  }
}

/// The backend-recognized identity — DISPLAYED, never re-asked.
class _RecognizedIdentity extends StatelessWidget {
  final MeetingEntryResolution resolution;
  const _RecognizedIdentity({required this.resolution});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name =
        (resolution.identityName ?? resolution.prefillName ?? '').trim();
    final email =
        (resolution.identityEmail ?? resolution.prefillEmail ?? '').trim();
    final label = switch (resolution.outcome) {
      MeetingEntryOutcome.hostDirect => 'Hosting this meeting',
      MeetingEntryOutcome.bookerDirect =>
        name.isNotEmpty ? 'Joining as $name' : 'Joining with your booking',
      MeetingEntryOutcome.invitedDirect =>
        name.isNotEmpty ? 'Invited: $name' : 'Joining with your invitation',
      MeetingEntryOutcome.institutionMemberDirect =>
        name.isNotEmpty ? 'Joining as $name' : 'Joining as an institution member',
      _ => name.isNotEmpty ? 'Joining as $name' : 'Joining with your account',
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.verified_user_rounded,
            size: 18, color: Color(0xFF10B981)),
        const SizedBox(width: AuraSpace.s10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (email.isNotEmpty)
                Text(
                  email,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF9CA3AF),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EntryStatusPill extends StatelessWidget {
  final MeetingEntryResolution resolution;
  const _EntryStatusPill({required this.resolution});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (resolution.outcome) {
      MeetingEntryOutcome.waitingForAdmission => (
        'Waiting for the host to admit you',
        const Color(0xFFF59E0B),
      ),
      _ when resolution.meetingLive => ('Live now', const Color(0xFF10B981)),
      _ => ('Scheduled', const Color(0xFF6C63FF)),
    };

    return Row(
      children: [
        if (resolution.meetingLive)
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

class _TerminalMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;
  final Widget? action;

  const _TerminalMessage({
    required this.icon,
    required this.title,
    required this.detail,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AuraSpace.s24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: const Color(0xFF9CA3AF)),
            const SizedBox(height: AuraSpace.s16),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: AuraSpace.s8),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF6B7280),
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: AuraSpace.s16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
