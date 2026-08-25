import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/navigation/navigation_authority.dart';
import '../../../../core/ui/aura_card.dart';
import '../../../../core/ui/aura_space.dart';
import '../../../../core/ui/aura_surface.dart';
import '../../application/meetings_provider.dart';
import '../../domain/meeting.dart';
import '../meeting_semantics.dart';

/// CONTINUING THE CONVERSATION — R-3, founder ruling 2026-08-25.
///
/// §III names the opportunity plainly: in the fragmented industry pattern,
/// scheduling lives in one product, the call in another, and whatever anybody
/// says afterwards in a third. Aura's advantage is that they can be one thing.
///
/// This is the seam where that becomes visible. The meeting has a durable
/// Conversation — one canonical Aura Conversation, not a meeting-local chat —
/// and this is how a person reaches it.
///
/// ─────────────────────────────────────────────────────────────────────────
/// WHY IT IS A DOOR AND NOT A PANEL
/// ─────────────────────────────────────────────────────────────────────────
///
/// The temptation is to embed the conversation here, and it is the wrong
/// instinct twice over. It would build a second reader for canonical
/// Conversation content — which §XXIX forbids — and it would put a live
/// message list inside a page whose subject is a meeting, competing with it.
/// The Conversation surface already exists, is already governed, and is
/// already better at this. So: a door.
///
/// ─────────────────────────────────────────────────────────────────────────
/// WHY IT CREATES ON TAP
/// ─────────────────────────────────────────────────────────────────────────
///
/// Creation is lazy. Most meetings never need a conversation, and every
/// meeting that predates this ruling has none. Bringing one into existence for
/// everybody who opens a record would leave people with a list of empty
/// conversations they never asked for. The first person who actually wants to
/// keep talking is the one who makes it.
class MeetingContinuitySection extends ConsumerStatefulWidget {
  const MeetingContinuitySection({super.key, required this.meeting});

  final Meeting meeting;

  @override
  ConsumerState<MeetingContinuitySection> createState() =>
      _MeetingContinuitySectionState();
}

class _MeetingContinuitySectionState
    extends ConsumerState<MeetingContinuitySection> {
  bool _opening = false;
  String? _error;

  Future<void> _open() async {
    if (_opening) return;
    setState(() {
      _opening = true;
      _error = null;
    });
    try {
      final id = await ref
          .read(meetingsRepositoryProvider)
          .openMeetingConversation(widget.meeting.id);
      if (!mounted) return;
      if (id == null || id.trim().isEmpty) {
        setState(() {
          _opening = false;
          // Honest about which of the two things went wrong. §XXXI: an error
          // should explain the state, and "this server does not do this yet"
          // is a different state from "something broke".
          _error = 'This meeting does not have a conversation yet. '
              'Try again in a moment.';
        });
        return;
      }
      setState(() => _opening = false);
      if (!mounted) return;
      // push, not go: the person came from the meeting record and expects to
      // be able to come back to it. The address comes from the Navigation
      // Authority rather than a literal — C3's ratchet, and the reason a
      // conversation route can be changed in one place.
      context.push(NavigationAuthority.conversationRoute(id));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _opening = false;
        _error = 'Could not open the conversation. Check your connection '
            'and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final existing = (widget.meeting.conversationId ?? '').trim();
    final hasConversation = existing.isNotEmpty;

    return AuraCard(
      padding: const EdgeInsets.all(AuraSpace.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              'Keep talking',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: AuraSpace.s6),
          Text(
            hasConversation
                ? 'This meeting has a conversation. Anything said there '
                    'stays with the people who were here.'
                : 'Start a conversation that outlives this meeting — the '
                    'people here can pick it up afterwards.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: AuraSurface.muted),
          ),
          if (_error != null) ...[
            const SizedBox(height: AuraSpace.s10),
            Semantics(
              liveRegion: true,
              child: Text(
                _error!,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error),
              ),
            ),
          ],
          const SizedBox(height: AuraSpace.s12),
          Align(
            alignment: Alignment.centerLeft,
            child: MeetingAction(
              label: hasConversation
                  ? 'Open this meeting\'s conversation'
                  : 'Start a conversation for this meeting',
              hint: 'Opens in Messages',
              enabled: !_opening,
              child: FilledButton.tonalIcon(
                icon: _opening
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.forum_outlined, size: 18),
                label: Text(
                  hasConversation ? 'Open conversation' : 'Start conversation',
                ),
                onPressed: _opening ? null : _open,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
