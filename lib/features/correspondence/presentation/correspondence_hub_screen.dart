import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_providers.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/ui/aura_text_block.dart';

class CorrespondenceHubScreen extends ConsumerWidget {
  const CorrespondenceHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStatusProvider);

    if (auth != AuthStatus.authed) {
      return AuraScaffold(
        title: 'Correspondence',
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            const _HeroCard(
              title: 'Correspondence',
              body:
                  'Private exchange, shared rooms, and invitations should feel like one system. Sign in to continue where your conversations already live.',
            ),
            const SizedBox(height: AuraSpace.s16),
            _StateCard(
              title: 'Sign in required',
              body:
                  'Your conversations, spaces, and invitations will appear here once you are signed in.',
              primaryLabel: 'Sign in',
              onPrimary: () => context.go('/login'),
            ),
          ],
        ),
      );
    }

    return AuraScaffold(
      title: 'Correspondence',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: const [
          _HeroCard(
            title: 'Correspondence',
            body:
                'Start privately, gather people into a shared room, or bring someone into an existing exchange. Invitations belong to what already exists. They are not a second conversation system.',
          ),
          SizedBox(height: AuraSpace.s16),
          _ActionBlock(
            title: 'Start a private conversation',
            body: 'Choose one member and begin directly.',
            buttonLabel: 'Start privately',
            icon: Icons.chat_bubble_outline,
            route: '/me/correspondence/create/conversation',
          ),
          SizedBox(height: AuraSpace.s12),
          _ActionBlock(
            title: 'Create a shared space',
            body: 'Bring together a circle, workroom, or salon with clear membership from the start.',
            buttonLabel: 'Create space',
            icon: Icons.groups_outlined,
            route: '/me/correspondence/create/space',
          ),
          SizedBox(height: AuraSpace.s12),
          _ActionBlock(
            title: 'Open conversations',
            body: 'Return to active private and shared continuity already underway.',
            buttonLabel: 'Open conversations',
            icon: Icons.forum_outlined,
            route: '/conversations',
          ),
          SizedBox(height: AuraSpace.s12),
          _ActionBlock(
            title: 'Invitation center',
            body: 'Review, create, and manage invitations for existing spaces and threads.',
            buttonLabel: 'Open invitations',
            icon: Icons.mail_outline,
            route: '/me/invitations',
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuraTextBlock(
            title,
            style: AuraText.title,
            maxLines: 2,
          ),
          const SizedBox(height: AuraSpace.s8),
          AuraTextBlock(
            body,
            style: AuraText.body,
            maxLines: 6,
          ),
        ],
      ),
    );
  }
}

class _ActionBlock extends StatelessWidget {
  const _ActionBlock({
    required this.title,
    required this.body,
    required this.buttonLabel,
    required this.icon,
    required this.route,
  });

  final String title;
  final String body;
  final String buttonLabel;
  final IconData icon;
  final String route;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Icon(icon, size: 18),
          ),
          const SizedBox(width: AuraSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AuraTextBlock(
                  title,
                  style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 2,
                ),
                const SizedBox(height: AuraSpace.s6),
                AuraTextBlock(
                  body,
                  style: AuraText.body,
                  maxLines: 4,
                ),
                const SizedBox(height: AuraSpace.s12),
                OutlinedButton(
                  onPressed: () => context.push(route),
                  child: Text(buttonLabel),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.title,
    required this.body,
    this.primaryLabel,
    this.onPrimary,
  });

  final String title;
  final String body;
  final String? primaryLabel;
  final VoidCallback? onPrimary;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuraTextBlock(
            title,
            style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
            maxLines: 3,
          ),
          const SizedBox(height: AuraSpace.s8),
          AuraTextBlock(body, style: AuraText.body, maxLines: 5),
          if (primaryLabel != null && onPrimary != null) ...[
            const SizedBox(height: AuraSpace.s12),
            OutlinedButton(
              onPressed: onPrimary,
              child: Text(primaryLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
