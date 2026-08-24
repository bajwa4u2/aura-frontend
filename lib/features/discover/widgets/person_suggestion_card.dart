import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/interactions/follow_invalidation.dart';
import '../../../core/interactions/follows_repository.dart';
import '../../../core/navigation/navigation_authority.dart';
import '../../../core/trust/trust_marks.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../conversation/presentation/conversation_identity.dart';
import '../data/people_discovery.dart';

/// A suggested person, with the one control that matters on them.
///
/// Shared by the People domain screen and the Discover landing strip so a
/// suggested person looks and behaves identically in both, and so the follow
/// action has one implementation rather than one per surface.
///
/// [dense] is the landing-strip presentation: a fixed-width card that reads
/// well in a horizontal run. The default is the full-width row the domain
/// screen uses.
class PersonSuggestionCard extends ConsumerStatefulWidget {
  const PersonSuggestionCard({
    super.key,
    required this.suggestion,
    this.dense = false,
  });

  final PersonSuggestion suggestion;
  final bool dense;

  @override
  ConsumerState<PersonSuggestionCard> createState() =>
      _PersonSuggestionCardState();
}

class _PersonSuggestionCardState extends ConsumerState<PersonSuggestionCard> {
  String? _localState;
  bool _busy = false;

  /// FOLLOW, THROUGH THE CANONICAL AUTHORITY.
  ///
  /// This used to hand-roll `POST /follows` with `{targetType, targetUserId}`
  /// and no actor. `actorType` is REQUIRED by the endpoint's contract, so every
  /// tap was a 400 and the button silently did nothing — on the People screen
  /// as well as here, since this card was extracted from it.
  ///
  /// The follows repository is the one place that knows how to address a
  /// follow. C1 — acting context is per-act: following someone from Discover
  /// is a PERSONAL act, so the viewer follows as themselves and never on
  /// behalf of an institution they happen to speak for.
  ///
  /// The card re-renders from the SERVER's answer, never an optimistic guess:
  /// a private account turns a follow into a request, and showing "Following"
  /// for something still pending is a lie the person would act on.
  Future<void> _follow() async {
    if (_busy) return;
    final viewerId = ref.read(myUserIdProvider);
    if (viewerId.isEmpty) return;

    setState(() => _busy = true);
    try {
      final state = await ref.read(followsRepositoryProvider).follow(
            actor: ActorRef.user(viewerId),
            target: ActorRef.user(widget.suggestion.userId),
          );
      if (!mounted) return;
      setState(() => _localState = state.isPending ? 'REQUESTED' : 'FOLLOWING');

      // Every surface that reads the follow graph re-reads: the pair cache,
      // and the feeds whose composition changed the moment this edge existed.
      invalidateFollowSurfaces(
        ref,
        key: FollowStateKey(
          actor: ActorRef.user(viewerId),
          target: ActorRef.user(widget.suggestion.userId),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not follow — try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _open() {
    final handle = widget.suggestion.handle;
    if (handle != null) context.push(NavigationAuthority.personRoute(handle));
  }

  Widget _name(PersonSuggestion s, {required bool center}) => Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment:
            center ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Text(
              s.displayName,
              maxLines: 1,
              textAlign: center ? TextAlign.center : TextAlign.start,
              overflow: TextOverflow.ellipsis,
              style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          // Choosing whom to follow is a trust decision, so the canonical
          // verification travels with the name.
          if (s.person.verification.hasAny) ...[
            const SizedBox(width: AuraSpace.s4),
            PersonVerificationMarks(
              verification: s.person.verification,
              size: TrustMarkSize.micro,
            ),
          ],
        ],
      );

  Widget _action(String state) => switch (state) {
        'FOLLOWING' => Text('Following',
            style: AuraText.small.copyWith(color: AuraSurface.muted)),
        'REQUESTED' => Text('Requested',
            style: AuraText.small.copyWith(color: AuraSurface.muted)),
        _ => AuraSecondaryButton(
            label: _busy ? '…' : 'Follow',
            onPressed: _busy ? null : _follow,
          ),
      };

  @override
  Widget build(BuildContext context) {
    final s = widget.suggestion;
    final state = _localState ?? s.followState;

    if (widget.dense) {
      return Container(
        width: 168,
        margin: const EdgeInsets.only(right: AuraSpace.s10),
        padding: const EdgeInsets.all(AuraSpace.s14),
        decoration: BoxDecoration(
          color: AuraSurface.card,
          borderRadius: BorderRadius.circular(AuraRadius.card),
          border: Border.all(color: AuraSurface.divider),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: s.handle == null ? null : _open,
              borderRadius: BorderRadius.circular(AuraRadius.card),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AuraAvatar(
                    name: s.displayName,
                    imageUrl: s.person.avatarUrl,
                    size: 56,
                  ),
                  const SizedBox(height: AuraSpace.s10),
                  _name(s, center: true),
                  if (s.reasons.isNotEmpty) ...[
                    const SizedBox(height: AuraSpace.s2),
                    Text(
                      s.reasons.first,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style:
                          AuraText.micro.copyWith(color: AuraSurface.muted),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AuraSpace.s10),
            _action(state),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AuraSpace.s8),
      padding: const EdgeInsets.all(AuraSpace.s12),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Row(
        children: [
          AuraAvatar(
            name: s.displayName,
            imageUrl: s.person.avatarUrl,
            size: 44,
          ),
          const SizedBox(width: AuraSpace.s12),
          Expanded(
            child: InkWell(
              onTap: s.handle == null ? null : _open,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _name(s, center: false),
                  if (s.reasons.isNotEmpty)
                    Text(
                      s.reasons.first,
                      style:
                          AuraText.micro.copyWith(color: AuraSurface.muted),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AuraSpace.s8),
          _action(state),
        ],
      ),
    );
  }
}
