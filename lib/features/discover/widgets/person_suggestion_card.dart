import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/interactions/follow_invalidation.dart';
import '../../../core/navigation/navigation_authority.dart';
import '../../../core/trust/trust_marks.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../profile/providers.dart';
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

  /// FOLLOWING A PERSON IS A REQUEST, NOT A FOLLOW.
  ///
  /// Person-to-person following is CONSENT-REQUIRED by frozen product design:
  /// request, then accept. `POST /follows` refuses USER -> USER outright and
  /// names the endpoint that does not — "Aura follow requires a request. Use
  /// POST /users/:handle/follow/request". Institutions are different, which is
  /// why following one from Discover works through the follows repository
  /// while this does not.
  ///
  /// This card previously hand-rolled `POST /follows` with no actor at all, so
  /// every tap was a 400 twice over — wrong shape AND wrong authority. It was
  /// extracted from the People screen, so Follow had been broken there for as
  /// long, on a surface whose tests all passed.
  ///
  /// The state that comes back is REQUESTED, not FOLLOWING, and the button
  /// says so. Showing "Following" for something the other person has not
  /// accepted would be a lie about a relationship that does not exist yet.
  Future<void> _requestFollow() async {
    if (_busy) return;
    final handle = widget.suggestion.handle;
    if (handle == null) return; // guarded by the control not being offered

    setState(() => _busy = true);
    try {
      await ref.read(profileRepositoryProvider).follow(handle);
      if (!mounted) return;
      setState(() => _localState = 'REQUESTED');

      // The follow graph did not change yet — a request is pending, not an
      // edge — but the request lists did, so the surfaces that read them
      // re-read.
      invalidateFollowSurfaces(ref);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send that request — try again.')),
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

  /// The follow request is addressed by HANDLE. A person who has not chosen
  /// one cannot be reached through that endpoint, so no control is offered —
  /// a button that cannot succeed is worse than its absence. Their profile is
  /// still open from the card.
  Widget _action(String state) {
    if (widget.suggestion.handle == null) return const SizedBox.shrink();
    return switch (state) {
      'FOLLOWING' => Text('Following',
          style: AuraText.small.copyWith(color: AuraSurface.muted)),
      'REQUESTED' => Text('Requested',
          style: AuraText.small.copyWith(color: AuraSurface.muted)),
      _ => AuraSecondaryButton(
          label: _busy ? '…' : 'Follow',
          onPressed: _busy ? null : _requestFollow,
        ),
    };
  }

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
