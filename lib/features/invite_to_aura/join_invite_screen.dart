import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/session_providers.dart';
import '../../core/navigation/navigation_authority.dart';
import '../../core/product/product_state.dart';
import '../../core/product/product_state_view.dart';
import '../../core/ui/aura_card.dart';
import '../../core/ui/aura_platform_components.dart';
import '../../core/ui/aura_scaffold.dart';
import '../../core/ui/aura_space.dart';
import '../../core/ui/aura_text.dart';
import '../../core/ui/aura_text_block.dart';
import '../profile/domain/profile.dart';
import '../profile/providers.dart';
import 'invite_to_aura.dart';

final _inviterProvider = FutureProvider.autoDispose.family<Profile?, String>(
  (ref, handle) async {
    try {
      return await ref.read(profileRepositoryProvider).fetchProfile(handle);
    } catch (_) {
      return null;
    }
  },
);

/// `/join/<handle>?via=<channel>` — what a person invited by a member sees.
///
/// It answers the invitation's questions (canon): WHO invited me, WHAT Aura
/// is, and what joining does. After joining, the newcomer lands on the
/// inviter's profile and decides for themselves whether to follow.
class JoinInviteScreen extends ConsumerWidget {
  const JoinInviteScreen({super.key, required this.handle, this.via});

  final String handle;
  final String? via;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final h = handle.trim().toLowerCase();
    final auth = ref.watch(authStatusProvider);
    final profileRoute = NavigationAuthority.personRoute(Uri.encodeComponent(h));
    final channel = normalizedInviteChannel(via);

    // A member who opens an invitation is already here: take them to the
    // person who sent it.
    if (auth == AuthStatus.authed && h.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go(profileRoute);
      });
    }

    final inviter = ref.watch(_inviterProvider(h));

    return AuraScaffold(
      title: 'Invitation',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          AuraCard(
            child: inviter.when(
              loading: () => const AuraProductState(
                state: ProductState.loading,
                headline: 'Opening the invitation',
              ),
              error: (_, __) => _body(context, null, profileRoute, channel),
              data: (p) => _body(context, p, profileRoute, channel),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(
    BuildContext context,
    Profile? inviter,
    String profileRoute,
    String? channel,
  ) {
    final name = (inviter?.displayName.trim().isNotEmpty ?? false)
        ? inviter!.displayName.trim()
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (inviter != null) ...[
          Row(
            children: [
              AuraAvatar(
                name: inviter.displayName,
                imageUrl: inviter.avatarUrl,
                size: 56,
              ),
              const SizedBox(width: AuraSpace.s12),
              Expanded(
                child: Text('@${inviter.handle}', style: AuraText.small),
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s16),
        ],
        Text(
          name == null ? 'You are invited to Aura' : '$name invited you to Aura',
          style: AuraText.title,
        ),
        const SizedBox(height: AuraSpace.s8),
        const AuraTextBlock(
          'Aura is a public-first place to take part in conversations that keep '
          'their context, with people and institutions you can identify. What '
          'you write stays yours, with your name on it.',
          style: AuraText.body,
        ),
        const SizedBox(height: AuraSpace.s16),
        Wrap(
          spacing: AuraSpace.s10,
          runSpacing: AuraSpace.s10,
          children: [
            AuraPrimaryButton(
              label: 'Join Aura',
              onPressed: () => context.push(
                NavigationAuthority.joinRoute(returnTo: profileRoute, via: channel),
              ),
            ),
            AuraSecondaryButton(
              label: 'Sign in',
              onPressed: () => context.push(
                NavigationAuthority.signInRoute(returnTo: profileRoute),
              ),
            ),
          ],
        ),
        if (name != null) ...[
          const SizedBox(height: AuraSpace.s12),
          Text(
            'After you join you will see $name’s profile, and you can '
            'choose whether to follow.',
            style: AuraText.small,
          ),
        ],
      ],
    );
  }
}
