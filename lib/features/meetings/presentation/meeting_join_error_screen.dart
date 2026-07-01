import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_space.dart';
import '../../../core/ui/guest_shell.dart';

// Terminal, guest-safe fallback for a meeting join that could not be resolved
// to a meeting live room. The hard rule is: a MEETING context must NEVER render
// the generic RealtimeRoomScreen. When the router kill switch sees a `/realtime/`
// deep link that carries a guest identity (a meeting signal) but cannot resolve
// the session surface (transport error, expired guest token, unknown session),
// it routes here instead of falling through to RealtimeRoomScreen. Shows the
// route/session diagnostic and a recovery path via the meeting code.
class MeetingJoinErrorScreen extends StatelessWidget {
  final String? meetingId;
  final String? sessionId;
  final String? code;
  final String? guestId;
  final String? reason;

  const MeetingJoinErrorScreen({
    super.key,
    this.meetingId,
    this.sessionId,
    this.code,
    this.guestId,
    this.reason,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasCode = (code ?? '').trim().isNotEmpty;
    final hasMeeting = (meetingId ?? '').trim().isNotEmpty;

    return GuestShell(
      showBackButton: true,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AuraSpace.s24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.link_off_rounded,
                  size: 44,
                  color: Color(0xFF9CA3AF),
                ),
                const SizedBox(height: AuraSpace.s16),
                Text(
                  "We couldn't open this meeting",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AuraSpace.s8),
                Text(
                  'This meeting link could not be resolved. Your session may '
                  'have expired, or the meeting may not be available yet. Use '
                  'the meeting code from your email to try again.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF9CA3AF),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: AuraSpace.s24),
                if (hasCode)
                  SizedBox(
                    height: 50,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.meeting_room_rounded),
                      label: const Text('Open pre-join'),
                      onPressed: () => context.go(
                        '/meetings/join/${Uri.encodeComponent(code!.trim())}',
                      ),
                    ),
                  )
                else
                  SizedBox(
                    height: 50,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.vpn_key_outlined),
                      label: const Text('Enter meeting code'),
                      onPressed: () => context.go('/meetings/join'),
                    ),
                  ),
                if (hasMeeting) ...[
                  const SizedBox(height: AuraSpace.s12),
                  OutlinedButton(
                    onPressed: () =>
                        context.go('/meetings/${meetingId!.trim()}/waiting'),
                    child: const Text('Go to waiting room'),
                  ),
                ],
                const SizedBox(height: AuraSpace.s24),
                _DiagnosticBlock(
                  meetingId: meetingId,
                  sessionId: sessionId,
                  code: code,
                  guestId: guestId,
                  reason: reason,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DiagnosticBlock extends StatelessWidget {
  final String? meetingId;
  final String? sessionId;
  final String? code;
  final String? guestId;
  final String? reason;

  const _DiagnosticBlock({
    this.meetingId,
    this.sessionId,
    this.code,
    this.guestId,
    this.reason,
  });

  @override
  Widget build(BuildContext context) {
    String v(String? s) => (s ?? '').trim().isEmpty ? '—' : s!.trim();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: const Color(0xFF243244)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AuraSpace.s12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Diagnostic',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: const Color(0xFF9CA3AF),
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            SelectableText(
              'reason: ${v(reason)}\n'
              'meetingId: ${v(meetingId)}\n'
              'sessionId: ${v(sessionId)}\n'
              'code: ${v(code)}\n'
              'guestId: ${v(guestId)}',
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 12,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
