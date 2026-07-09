import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/guest_shell.dart';
import '../application/meetings_provider.dart';

/// Participant continuity — the moment a booking becomes part of an account.
///
/// Reached with the booking reference (`bt`) after sign-in or registration
/// (the confirmation screen and reminder emails route here). Attaches the
/// booked meeting to the signed-in member and lands on the meeting itself:
/// no separate onboarding step, no extra confirmation — continuity emerges
/// from identity resolution.
///
/// Identity only: ownership of the meeting (its institution, its host) is
/// never touched by this step.
class KeepMeetingScreen extends ConsumerStatefulWidget {
  final String? bookerToken;
  final String? meetingCode;

  const KeepMeetingScreen({super.key, this.bookerToken, this.meetingCode});

  @override
  ConsumerState<KeepMeetingScreen> createState() => _KeepMeetingScreenState();
}

class _KeepMeetingScreenState extends ConsumerState<KeepMeetingScreen> {
  String? _error;

  String get _joinPath => (widget.meetingCode ?? '').trim().isEmpty
      ? '/meetings/join'
      : '/meetings/join/${widget.meetingCode!.trim()}'
          '?bt=${Uri.encodeComponent((widget.bookerToken ?? '').trim())}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _attach());
  }

  Future<void> _attach() async {
    final token = (widget.bookerToken ?? '').trim();
    if (token.isEmpty) {
      if (mounted) context.go('/meetings');
      return;
    }

    final tokenStore = ref.read(tokenStoreProvider);
    await tokenStore.load();
    if (!mounted) return;

    // A member session is required — a guest token or signed-out visitor
    // resolves identity first and returns here with the same reference.
    if (!tokenStore.isMemberSession) {
      final self = '/meetings/keep?bt=${Uri.encodeComponent(token)}'
          '${(widget.meetingCode ?? '').trim().isEmpty ? '' : '&code=${Uri.encodeComponent(widget.meetingCode!.trim())}'}';
      context.go('/login?redirect=${Uri.encodeComponent(self)}');
      return;
    }

    try {
      final meeting =
          await ref.read(meetingsRepositoryProvider).keepBookedMeeting(token);
      ref.invalidate(upcomingMeetingsProvider);
      ref.invalidate(pastMeetingsProvider);
      if (!mounted) return;
      context.go('/meetings/${meeting.id}');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error =
            'This booking could not be added to your account. It may have '
            'been cancelled or already belong to another account.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GuestShell(
      showBackButton: _error != null,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: _error == null
              ? const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: AuraSpace.s16),
                    Text('Adding this meeting to your account…'),
                  ],
                )
              : Padding(
                  padding: const EdgeInsets.all(AuraSpace.s24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          size: 40, color: Color(0xFF9CA3AF)),
                      const SizedBox(height: AuraSpace.s12),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: const Color(0xFFCBD5E1)),
                      ),
                      const SizedBox(height: AuraSpace.s20),
                      Wrap(
                        spacing: AuraSpace.s10,
                        runSpacing: AuraSpace.s10,
                        alignment: WrapAlignment.center,
                        children: [
                          FilledButton.icon(
                            icon: const Icon(Icons.video_call_rounded),
                            label: const Text('Open join page'),
                            onPressed: () => context.go(_joinPath),
                          ),
                          OutlinedButton(
                            onPressed: () => context.go('/meetings'),
                            child: const Text('Your meetings'),
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
}
