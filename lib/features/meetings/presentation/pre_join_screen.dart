import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../application/meetings_provider.dart';
import '../domain/meeting.dart';

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
  bool _joining = false;

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

      if (result.shouldWait) {
        _showWaitingRoomMessage();
        return;
      }

      if (result.sessionId != null) {
        context.push(
          '/realtime/${result.sessionId}?action=join'
          '${result.guestToken != null ? '&guestToken=${result.guestToken}' : ''}',
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Meeting is not yet live. Check back later.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not join: $e')));
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  void _showWaitingRoomMessage() {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Waiting room'),
        content: const Text(
            'The host has not yet admitted you. '
            'You will be notified when your request is approved.'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final meetingAsync = ref.watch(meetingByCodeProvider(widget.meetingCode));
    final theme = Theme.of(context);

    return meetingAsync.when(
      loading: () => AuraScaffold(
        title: '',
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => AuraScaffold(
        title: '',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 48, color: Color(0xFF9CA3AF)),
              const SizedBox(height: AuraSpace.s16),
              Text('Meeting not found',
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: AuraSpace.s8),
              Text('Check the meeting code and try again.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF6B7280))),
            ],
          ),
        ),
      ),
      data: (meeting) => _PreJoinBody(
        meeting: meeting,
        nameCtrl: _nameCtrl,
        emailCtrl: _emailCtrl,
        joining: _joining,
        onJoin: () => _join(meeting),
      ),
    );
  }
}

class _PreJoinBody extends ConsumerWidget {
  final Meeting meeting;
  final TextEditingController nameCtrl;
  final TextEditingController emailCtrl;
  final bool joining;
  final VoidCallback onJoin;

  const _PreJoinBody({
    required this.meeting,
    required this.nameCtrl,
    required this.emailCtrl,
    required this.joining,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    // Is the authenticated user already a participant?
    // If so we skip name/email fields. For now we detect by checking
    // if the meeting has participants — the backend join endpoint will
    // handle the actual auth check. We always show the guest fields
    // as optional so unauthenticated visitors can identify themselves.

    return AuraScaffold(
      title: '',
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => context.pop(),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(AuraSpace.s24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Host context — org/host info before any platform mention
                if (meeting.host != null) ...[
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: const Color(0xFF6C63FF),
                        child: Text(
                          meeting.host!.name.isNotEmpty
                              ? meeting.host!.name[0].toUpperCase()
                              : 'H',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18),
                        ),
                      ),
                      const SizedBox(width: AuraSpace.s12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(meeting.host!.name,
                              style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600)),
                          const Text('has invited you to a meeting',
                              style: TextStyle(
                                  color: Color(0xFF6B7280),
                                  fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: AuraSpace.s20),
                  const Divider(),
                  const SizedBox(height: AuraSpace.s20),
                ],

                // Meeting info
                Text(meeting.title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700)),
                if (meeting.description != null) ...[
                  const SizedBox(height: AuraSpace.s8),
                  Text(meeting.description!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF6B7280))),
                ],
                const SizedBox(height: AuraSpace.s6),
                _StatusPill(state: meeting.state),

                const SizedBox(height: AuraSpace.s24),

                // Guest identification (optional for signed-in users)
                Text('Your name',
                    style: theme.textTheme.labelMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: AuraSpace.s6),
                TextField(
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'Enter your name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                ),
                const SizedBox(height: AuraSpace.s12),
                Text('Email (optional)',
                    style: theme.textTheme.labelMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: AuraSpace.s6),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    hintText: 'your@email.com',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.mail_outline_rounded),
                  ),
                ),

                const SizedBox(height: AuraSpace.s24),

                SizedBox(
                  height: 50,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.video_call_rounded),
                    label: const Text('Join meeting'),
                    onPressed: joining ? null : onJoin,
                  ),
                ),

                const SizedBox(height: AuraSpace.s20),

                // Platform attribution — present, not promotional
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Powered by ',
                        style: TextStyle(
                            color: Color(0xFF9CA3AF), fontSize: 12)),
                    Text('Aura',
                        style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String state;
  const _StatusPill({required this.state});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (state) {
      'ACTIVE' => ('Live now', const Color(0xFF10B981)),
      'SCHEDULED' => ('Scheduled', const Color(0xFF6C63FF)),
      'ENDED' => ('Meeting ended', const Color(0xFF9CA3AF)),
      'CANCELLED' => ('Cancelled', const Color(0xFFEF4444)),
      _ => ('Pending', const Color(0xFF9CA3AF)),
    };

    return Row(
      children: [
        if (state == 'ACTIVE')
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
        Text(label,
            style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}
