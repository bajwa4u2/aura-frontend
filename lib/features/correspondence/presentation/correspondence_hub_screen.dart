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
            const _PageHeading(title: 'Correspondence'),
            const SizedBox(height: AuraSpace.s16),
            _StateCard(
              title: 'Sign in required',
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
          _PageHeading(title: 'Correspondence'),
          SizedBox(height: AuraSpace.s16),
          _ActionBlock(
            title: 'New conversation',
            buttonLabel: 'Start conversation',
            icon: Icons.chat_bubble_outline,
            route: '/me/correspondence/create/conversation',
          ),
          SizedBox(height: AuraSpace.s12),
          _ActionBlock(
            title: 'Create space',
            buttonLabel: 'Create space',
            icon: Icons.groups_outlined,
            route: '/me/correspondence/create/space',
          ),
        ],
      ),
    );
  }
}

class _PageHeading extends StatelessWidget {
  const _PageHeading({
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    return AuraTextBlock(
      title,
      style: AuraText.title,
      maxLines: 2,
    );
  }
}

class _ActionBlock extends StatelessWidget {
  const _ActionBlock({
    required this.title,
    required this.buttonLabel,
    required this.icon,
    required this.route,
  });

  final String title;
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
    this.primaryLabel,
    this.onPrimary,
  });

  final String title;
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
