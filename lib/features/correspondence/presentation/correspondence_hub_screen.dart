import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_providers.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
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
              eyebrow: 'Aura correspondence',
              title: 'A calmer place for private exchange.',
              body:
                  'Threads, shared rooms, and invitations belong to one system. Enter once and stay oriented.',
              pills: ['Direct threads', 'Shared spaces', 'Invitations'],
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
          const _HeroCard(
            eyebrow: 'Aura correspondence',
            title: 'One communication system, held in order.',
            body:
                'Continue what is active, begin what matters, and bring others in without losing the thread.',
            pills: ['Continue', 'Begin', 'Bring someone in'],
          ),
          const SizedBox(height: AuraSpace.s18),
          const _SectionHeading(
            title: 'Continue',
            body: 'Ongoing exchange, pending invitations, and active rooms.',
          ),
          const SizedBox(height: AuraSpace.s12),
          const _ActionPanel(
            title: 'Conversations',
            body:
                'Open direct threads and shared rooms already carrying weight.',
            buttonLabel: 'Open conversations',
            icon: Icons.forum_outlined,
            route: '/conversations',
            tag: 'Active',
          ),
          const SizedBox(height: AuraSpace.s12),
          const _ActionPanel(
            title: 'Invitations',
            body:
                'See what reached you, what is pending, and what still needs a response.',
            buttonLabel: 'Review invitations',
            icon: Icons.mark_email_unread_outlined,
            route: '/me/invitations',
            tag: 'Pending',
          ),
          const SizedBox(height: AuraSpace.s18),
          const _SectionHeading(
            title: 'Begin',
            body: 'Start direct exchange or open a durable room for a group.',
          ),
          const SizedBox(height: AuraSpace.s12),
          const _ActionPanel(
            title: 'New conversation',
            body: 'Start a direct thread with one Aura member.',
            buttonLabel: 'Start conversation',
            icon: Icons.chat_bubble_outline,
            route: '/me/correspondence/create/conversation',
            tag: 'Direct',
          ),
          const SizedBox(height: AuraSpace.s12),
          const _ActionPanel(
            title: 'Create space',
            body:
                'Open a shared room for a circle, project, or continuing group exchange.',
            buttonLabel: 'Create space',
            icon: Icons.groups_2_outlined,
            route: '/me/correspondence/create/space',
            tag: 'Shared',
          ),
          const SizedBox(height: AuraSpace.s18),
          const _SectionHeading(
            title: 'Bring someone in',
            body: 'Use invitations when a specific path of entry matters.',
          ),
          const SizedBox(height: AuraSpace.s12),
          const _ActionPanel(
            title: 'Create invitation',
            body:
                'Open a clean path into Aura, a space, or a direct thread with the right access from the start.',
            buttonLabel: 'Open invite flow',
            icon: Icons.outbound_outlined,
            route: '/invite',
            tag: 'Entry',
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.pills,
  });

  final String eyebrow;
  final String title;
  final String body;
  final List<String> pills;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      color: AuraSurface.elevated,
      borderColor: AuraSurface.accentSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow.toUpperCase(),
            style: AuraText.small.copyWith(
              color: AuraSurface.muted,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: AuraSpace.s10),
          AuraTextBlock(
            title,
            style: AuraText.title.copyWith(fontSize: 24, height: 1.2),
            maxLines: 3,
          ),
          const SizedBox(height: AuraSpace.s8),
          AuraTextBlock(body, style: AuraText.body),
          const SizedBox(height: AuraSpace.s14),
          Wrap(
            spacing: AuraSpace.s8,
            runSpacing: AuraSpace.s8,
            children: pills.map((label) => _SignalPill(label: label)).toList(),
          ),
        ],
      ),
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
        AuraTextBlock(body, style: AuraText.small),
      ],
    );
  }
}

class _ActionPanel extends StatelessWidget {
  const _ActionPanel({
    required this.title,
    required this.body,
    required this.buttonLabel,
    required this.icon,
    required this.route,
    required this.tag,
  });

  final String title;
  final String body;
  final String buttonLabel;
  final IconData icon;
  final String route;
  final String tag;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      onTap: () => context.push(route),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AuraSurface.accentSoft,
              border: Border.all(color: AuraSurface.accentSoft),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Icon(icon, size: 20, color: AuraSurface.ink),
          ),
          const SizedBox(width: AuraSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: AuraTextBlock(
                        title,
                        style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
                        maxLines: 2,
                      ),
                    ),
                    const SizedBox(width: AuraSpace.s8),
                    _SignalPill(label: tag),
                  ],
                ),
                const SizedBox(height: AuraSpace.s6),
                AuraTextBlock(body, style: AuraText.body),
                const SizedBox(height: AuraSpace.s12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton(
                    onPressed: () => context.push(route),
                    child: Text(buttonLabel),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SignalPill extends StatelessWidget {
  const _SignalPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s10,
        vertical: AuraSpace.s6,
      ),
      decoration: BoxDecoration(
        color: AuraSurface.accentSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AuraSurface.accentSoft),
      ),
      child: Text(
        label,
        style: AuraText.small.copyWith(
          color: AuraSurface.ink,
          fontWeight: FontWeight.w700,
        ),
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
