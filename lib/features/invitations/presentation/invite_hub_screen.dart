import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/ui/aura_text_block.dart';

class InviteHubScreen extends StatelessWidget {
  const InviteHubScreen({
    super.key,
    this.spaceId,
    this.threadId,
  });

  final String? spaceId;
  final String? threadId;

  bool get _hasSpaceContext => (spaceId ?? '').trim().isNotEmpty;
  bool get _hasThreadContext => (threadId ?? '').trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return AuraScaffold(
      title: 'Invite',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          AuraCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Invite', style: AuraText.title),
                const SizedBox(height: AuraSpace.s8),
                AuraTextBlock(
                  'Choose how someone should enter. You can invite them into Aura, into a shared space, or into a specific conversation without losing structure.',
                  style: AuraText.body,
                ),
              ],
            ),
          ),
          const SizedBox(height: AuraSpace.s14),
          _InviteOptionCard(
            title: 'Invite to Aura',
            subtitle: 'Bring someone into Aura with a clean entry path.',
            icon: Icons.public_outlined,
            onTap: () => context.push('/invite/create?destinationType=JOIN_AURA'),
          ),
          const SizedBox(height: AuraSpace.s12),
          _InviteOptionCard(
            title: 'Invite to 1:1',
            subtitle: 'Start a direct conversation with a specific member.',
            icon: Icons.chat_outlined,
            onTap: () => context.push('/invite/create?destinationType=START_1_TO_1'),
          ),
          const SizedBox(height: AuraSpace.s12),
          _InviteOptionCard(
            title: 'Invite to space',
            subtitle: _hasSpaceContext
                ? 'Create an invitation into this space.'
                : 'Bring someone into a shared space with the right access from the start.',
            icon: Icons.groups_outlined,
            onTap: () => context.push(
              '/invite/create?destinationType=JOIN_SPACE${_hasSpaceContext ? '&spaceId=${Uri.encodeComponent(spaceId!.trim())}' : ''}',
            ),
          ),
          const SizedBox(height: AuraSpace.s12),
          _InviteOptionCard(
            title: 'Invite to thread',
            subtitle: _hasThreadContext
                ? 'Create an invitation into this thread.'
                : 'Bring someone straight into a specific ongoing conversation.',
            icon: Icons.forum_outlined,
            onTap: () => context.push(
              '/invite/create?destinationType=JOIN_THREAD'
              '${_hasSpaceContext ? '&spaceId=${Uri.encodeComponent(spaceId!.trim())}' : ''}'
              '${_hasThreadContext ? '&threadId=${Uri.encodeComponent(threadId!.trim())}' : ''}',
            ),
          ),
          const SizedBox(height: AuraSpace.s14),
          OutlinedButton(
            onPressed: () => context.push('/me/invitations'),
            child: const Text('Open invitations'),
          ),
        ],
      ),
    );
  }
}

class _InviteOptionCard extends StatelessWidget {
  const _InviteOptionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(2),
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
                      subtitle,
                      style: AuraText.body,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AuraSpace.s8),
              const Icon(Icons.chevron_right, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
