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
            const _PageHeading(
              title: 'Correspondence',
              body:
                  'Start private exchange, create shared space, and manage entry without losing your place.',
            ),
            const SizedBox(height: AuraSpace.s16),
            _StateCard(
              title: 'Sign in required',
              body:
                  'Correspondence opens once you are signed in. Your conversations, spaces, and invitations stay together here.',
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
        children: [
          const _PageHeading(
            title: 'Correspondence',
            body:
                'One calm place to continue what is active, begin something new, and bring others in when needed.',
          ),
          const SizedBox(height: AuraSpace.s16),
          const _SectionHeading(
            title: 'Continue',
            body: 'Ongoing threads, spaces, and anything waiting on you.',
          ),
          const SizedBox(height: AuraSpace.s12),
          const _ActionBlock(
            title: 'Conversations',
            body:
                'Open private threads and shared spaces already in motion.',
            buttonLabel: 'Open conversations',
            icon: Icons.forum_outlined,
            route: '/conversations',
          ),
          const SizedBox(height: AuraSpace.s12),
          const _ActionBlock(
            title: 'Invitations',
            body:
                'Review invites you sent, what is still pending, and what reached you.',
            buttonLabel: 'Open invitations',
            icon: Icons.inbox_outlined,
            route: '/me/invitations',
          ),
          const SizedBox(height: AuraSpace.s18),
          const _SectionHeading(
            title: 'Start',
            body: 'Begin direct exchange or open a new shared room for a group.',
          ),
          const SizedBox(height: AuraSpace.s12),
          const _ActionBlock(
            title: 'New conversation',
            body: 'Start a direct thread with one Aura member.',
            buttonLabel: 'Start conversation',
            icon: Icons.chat_bubble_outline,
            route: '/me/correspondence/create/conversation',
          ),
          const SizedBox(height: AuraSpace.s12),
          const _ActionBlock(
            title: 'Create space',
            body: 'Open a shared space for a circle, project, or ongoing group exchange.',
            buttonLabel: 'Create space',
            icon: Icons.groups_outlined,
            route: '/me/correspondence/create/space',
          ),
          const SizedBox(height: AuraSpace.s18),
          const _SectionHeading(
            title: 'Bring someone in',
            body: 'Use invites only when you need to open a path for someone specific.',
          ),
          const SizedBox(height: AuraSpace.s12),
          const _ActionBlock(
            title: 'Create invitation',
            body:
                'Invite someone into Aura, a space, or a conversation with the right level of access.',
            buttonLabel: 'Open invite options',
            icon: Icons.outbound_outlined,
            route: '/invite',
          ),
        ],
      ),
    );
  }
}

class _PageHeading extends StatelessWidget {
  const _PageHeading({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AuraTextBlock(
          title,
          style: AuraText.title,
          maxLines: 2,
        ),
        if (body.trim().isNotEmpty) ...[
          const SizedBox(height: AuraSpace.s6),
          AuraTextBlock(body, style: AuraText.body),
        ],
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AuraTextBlock(
          title,
          style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
          maxLines: 1,
        ),
        const SizedBox(height: AuraSpace.s4),
        AuraTextBlock(body, style: AuraText.small.copyWith(color: Colors.black54)),
      ],
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
                AuraTextBlock(body, style: AuraText.body),
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
          const SizedBox(height: AuraSpace.s6),
          AuraTextBlock(body, style: AuraText.body),
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
