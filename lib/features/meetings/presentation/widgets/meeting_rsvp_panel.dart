import 'package:flutter/material.dart';

import '../../../../core/ui/aura_card.dart';
import '../../../../core/ui/aura_space.dart';
import '../../../../core/ui/aura_surface.dart';

/// ACCEPT OR DECLINE, ON THE MEETING ITSELF (6 Nov 2026).
///
/// A member added to a meeting arrives as PENDING, and the server has always
/// had `POST /meetings/:id/rsvp` to answer it. Nothing in the app called it,
/// so nobody could say yes or no, and the host never knew who was coming.
///
/// The panel asks while the answer is open, then states the answer and lets
/// the person change it.
class MeetingRsvpPanel extends StatefulWidget {
  const MeetingRsvpPanel({
    super.key,
    required this.rsvpStatus,
    required this.onAnswer,
  });

  /// The participant's current answer: PENDING, ACCEPTED or DECLINED.
  final String rsvpStatus;

  /// Sends the answer. Throws when it was not saved.
  final Future<void> Function(bool accept) onAnswer;

  @override
  State<MeetingRsvpPanel> createState() => _MeetingRsvpPanelState();
}

class _MeetingRsvpPanelState extends State<MeetingRsvpPanel> {
  /// The answer just given, shown until the reloaded meeting carries it.
  String? _answered;
  bool _sending = false;
  String? _problem;

  @override
  void didUpdateWidget(MeetingRsvpPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rsvpStatus != widget.rsvpStatus) _answered = null;
  }

  Future<void> _answer(bool accept) async {
    setState(() {
      _sending = true;
      _problem = null;
    });
    try {
      await widget.onAnswer(accept);
      if (!mounted) return;
      setState(() => _answered = accept ? 'ACCEPTED' : 'DECLINED');
    } catch (_) {
      if (!mounted) return;
      setState(() => _problem = 'Your answer was not saved. Try again.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = (_answered ?? widget.rsvpStatus).toUpperCase();

    final String headline;
    final List<Widget> actions;
    switch (status) {
      case 'ACCEPTED':
        headline = 'You accepted. You are expected at this meeting.';
        actions = [
          OutlinedButton.icon(
            icon: const Icon(Icons.close_rounded),
            label: const Text("I can't attend"),
            onPressed: _sending ? null : () => _answer(false),
          ),
        ];
      case 'DECLINED':
        headline = 'You declined this meeting.';
        actions = [
          OutlinedButton.icon(
            icon: const Icon(Icons.check_rounded),
            label: const Text('I can attend after all'),
            onPressed: _sending ? null : () => _answer(true),
          ),
        ];
      default:
        headline = 'You are invited. Will you attend?';
        actions = [
          FilledButton.icon(
            icon: const Icon(Icons.check_rounded),
            label: const Text('Accept'),
            onPressed: _sending ? null : () => _answer(true),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.close_rounded),
            label: const Text('Decline'),
            onPressed: _sending ? null : () => _answer(false),
          ),
        ];
    }

    return AuraCard(
      padding: const EdgeInsets.all(AuraSpace.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            headline,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AuraSpace.s12),
          Wrap(
            spacing: AuraSpace.s10,
            runSpacing: AuraSpace.s10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ...actions,
              if (_sending)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          if (_problem != null) ...[
            const SizedBox(height: AuraSpace.s8),
            Text(
              _problem!,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AuraSurface.dangerInk),
            ),
          ],
        ],
      ),
    );
  }
}
