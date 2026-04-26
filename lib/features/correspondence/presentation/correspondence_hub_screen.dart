import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_providers.dart';
import '../../../core/ui/aura_design_system.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../create/presentation/new_conversation_screen.dart';

class CorrespondenceHubScreen extends ConsumerWidget {
  const CorrespondenceHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStatusProvider);
    final uri = GoRouterState.of(context).uri;
    final start = (uri.queryParameters['start'] ?? '').trim().toLowerCase();

    if (auth != AuthStatus.authed) {
      return AuraScaffold(
        showHeader: false,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  AuraSpace.s16, AuraSpace.s20, AuraSpace.s16, AuraSpace.s32),
              children: [
                _CorrespondenceHeader(),
                const SizedBox(height: AuraSpace.s24),
                _SignInCard(
                  onSignIn: () => context.go('/login'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (start == 'private' || start == 'space') {
      return NewConversationScreen(
        isSharedSpaceMode: start == 'space',
        initialUserId: uri.queryParameters['userId'],
        initialHandle: uri.queryParameters['handle'],
        initialName: uri.queryParameters['name'],
      );
    }

    return AuraScaffold(
      showHeader: false,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                AuraSpace.s16, AuraSpace.s20, AuraSpace.s16, AuraSpace.s32),
            children: [
              _CorrespondenceHeader(),
              const SizedBox(height: AuraSpace.s24),
              _CorrespondenceActionCard(
                title: 'Start a private conversation',
                body: 'Choose one member and begin a direct exchange.',
                icon: Icons.chat_bubble_outline_rounded,
                label: 'Start privately',
                route: '/me/correspondence?start=private',
              ),
              const SizedBox(height: AuraSpace.s12),
              _CorrespondenceActionCard(
                title: 'Create a shared space',
                body:
                    'Bring together a circle, workroom, or salon with clear membership.',
                icon: Icons.groups_outlined,
                label: 'Create space',
                route: '/me/correspondence?start=space',
              ),
              const SizedBox(height: AuraSpace.s12),
              _CorrespondenceActionCard(
                title: 'Open conversations',
                body:
                    'Return to active private and shared continuity already underway.',
                icon: Icons.forum_outlined,
                label: 'Open conversations',
                route: '/conversations',
              ),
              const SizedBox(height: AuraSpace.s12),
              _CorrespondenceActionCard(
                title: 'Invitation center',
                body:
                    'Review, create, and manage invitations for existing spaces and threads.',
                icon: Icons.mail_outline_rounded,
                label: 'Open invitations',
                route: '/me/invitations',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CorrespondenceHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Correspondence', style: AuraText.headline),
        const SizedBox(height: AuraSpace.s6),
        Text(
          'Private exchange, shared rooms, and invitations — one unified system.',
          style: AuraText.body
              .copyWith(color: AuraSurface.muted, height: 1.5),
        ),
      ],
    );
  }
}

class _SignInCard extends StatelessWidget {
  const _SignInCard({required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AuraSpace.s20),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.xl),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sign in required', style: AuraText.subtitle),
          const SizedBox(height: AuraSpace.s8),
          Text(
            'Your conversations, spaces, and invitations will appear here once you are signed in.',
            style: AuraText.body.copyWith(color: AuraSurface.muted),
          ),
          const SizedBox(height: AuraSpace.s16),
          AuraPrimaryButton(
            label: 'Sign in',
            onPressed: onSignIn,
            icon: Icons.login_rounded,
          ),
        ],
      ),
    );
  }
}

class _CorrespondenceActionCard extends StatelessWidget {
  const _CorrespondenceActionCard({
    required this.title,
    required this.body,
    required this.icon,
    required this.label,
    required this.route,
  });

  final String title;
  final String body;
  final IconData icon;
  final String label;
  final String route;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push(route),
        borderRadius: BorderRadius.circular(AuraRadius.card),
        child: Container(
          padding: const EdgeInsets.all(AuraSpace.s16),
          decoration: BoxDecoration(
            color: AuraSurface.card,
            borderRadius: BorderRadius.circular(AuraRadius.card),
            border: Border.all(color: AuraSurface.divider),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AuraSurface.subtle,
                  borderRadius: BorderRadius.circular(AuraRadius.r10),
                  border: Border.all(color: AuraSurface.divider),
                ),
                child: Icon(icon, size: AuraIconSize.sm, color: AuraSurface.muted),
              ),
              const SizedBox(width: AuraSpace.s14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style:
                          AuraText.body.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: AuraSpace.s6),
                    Text(
                      body,
                      style: AuraText.small
                          .copyWith(color: AuraSurface.muted, height: 1.45),
                    ),
                    const SizedBox(height: AuraSpace.s12),
                    Row(
                      children: [
                        Text(
                          label,
                          style: AuraText.small.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AuraSurface.accentText,
                          ),
                        ),
                        const SizedBox(width: AuraSpace.s4),
                        const Icon(Icons.arrow_forward_rounded,
                            size: 14, color: AuraSurface.accentText),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
