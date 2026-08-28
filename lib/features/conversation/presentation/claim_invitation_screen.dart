import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_providers.dart';
import '../../../core/navigation/navigation_authority.dart';
import '../../../core/product/product_state.dart';
import '../../../core/product/product_state_view.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../data/conversations_repository.dart';

/// EXTERNAL INVITATION LANDING — /i/:token (public).
/// Canon (invitation §27-§30): safe preview only before identity binding;
/// the invitation survives the entire signup/verification/login journey
/// (this route IS the redirect target), binds address-verified, and after
/// acceptance the person lands IN the destination — never at generic Home.
class ClaimInvitationScreen extends ConsumerStatefulWidget {
  const ClaimInvitationScreen({super.key, required this.token});
  final String token;

  @override
  ConsumerState<ClaimInvitationScreen> createState() =>
      _ClaimInvitationScreenState();
}

class _ClaimInvitationScreenState extends ConsumerState<ClaimInvitationScreen> {
  Map<String, dynamic>? _preview;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final preview = await ref
          .read(conversationsRepositoryProvider)
          .claimPreview(widget.token);
      if (mounted) setState(() => _preview = preview);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'This invitation is no longer available. It may have expired '
            'or been withdrawn.');
      }
    }
  }

  Future<void> _acceptFlow() async {
    if (_busy) return;
    setState(() => _busy = true);
    final repo = ref.read(conversationsRepositoryProvider);
    try {
      final invitation = await repo.claimBind(widget.token);
      final accepted = await repo.acceptInvitation(invitation.id);
      if (!mounted) return;
      // THE SERVER SAYS WHERE ACCEPTING LANDED YOU.
      //
      // Not `invitation.targetId`. Accepting an invitation to a conversation
      // forms a NEW conversation for the resulting participant set, and the
      // one it was sent from stays private to the people already in it. Going
      // to the target would send this person at a conversation they are
      // deliberately not a party of.
      if (accepted.isConversation && accepted.hasDestination) {
        context.go(
          NavigationAuthority.conversationRoute(accepted.resolutionRef),
        );
      } else {
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error =
            'This invitation was addressed to a different email. Sign in '
            'with the account that holds the invited address.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAuthed = ref.watch(isAuthedProvider);
    final returnTo = Uri.encodeComponent('/i/${widget.token}');

    return AuraScaffold(
      showHeader: false,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(AuraSpace.s24),
            child: _error != null
                ? AuraProductState(
                    state: ProductState.unavailable,
                    headline: 'Invitation unavailable',
                    detail: _error,
                    icon: Icons.mail_outline_rounded,
                  )
                : _preview == null
                    ? const AuraProductState(state: ProductState.loading)
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.mail_rounded,
                              size: 40, color: AuraSurface.accentText),
                          const SizedBox(height: AuraSpace.s16),
                          Text(
                            '${_preview!['inviterName'] ?? 'An Aura member'} '
                            'invited you to '
                            '${(_preview!['preview'] as Map?)?['title'] ?? 'join them on Aura'}',
                            style: AuraText.headline,
                          ),
                          const SizedBox(height: AuraSpace.s8),
                          Text(
                            ((_preview!['preview'] as Map?)?['acceptanceMeaning'] ??
                                    '')
                                .toString(),
                            style: AuraText.body
                                .copyWith(color: AuraSurface.muted),
                          ),
                          const SizedBox(height: AuraSpace.s24),
                          if (isAuthed)
                            AuraPrimaryButton(
                              label: _busy ? 'Joining…' : 'Accept invitation',
                              onPressed: _busy ? null : _acceptFlow,
                            )
                          else ...[
                            AuraPrimaryButton(
                              label: 'Join Aura to accept',
                              onPressed: () =>
                                  context.go('/register?redirect=$returnTo'),
                            ),
                            const SizedBox(height: AuraSpace.s8),
                            AuraSecondaryButton(
                              label: 'I already have an account',
                              onPressed: () =>
                                  context.go('/login?redirect=$returnTo'),
                            ),
                          ],
                          const SizedBox(height: AuraSpace.s16),
                          Text(
                            'This invitation only works for its addressed '
                            'recipient.',
                            style: AuraText.micro
                                .copyWith(color: AuraSurface.faint),
                          ),
                        ],
                      ),
          ),
        ),
      ),
    );
  }
}
