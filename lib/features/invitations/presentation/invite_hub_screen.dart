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
                Text('Bring someone in', style: AuraText.title),
                const SizedBox(height: AuraSpace.s8),
                AuraTextBlock(
                  _contextBody(),
                  style: AuraText.body,
                ),
                if (_hasSpaceContext || _hasThreadContext) ...[
                  const SizedBox(height: AuraSpace.s12),
                  Wrap(
                    spacing: AuraSpace.s8,
                    runSpacing: AuraSpace.s8,
                    children: [
                      if (_hasSpaceContext) _ContextPill(label: 'Space ready'),
                      if (_hasThreadContext) _ContextPill(label: 'Thread ready'),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AuraSpace.s14),
          _InviteOptionCard(
            title: 'Direct conversation',
            subtitle: 'Open a path into a 1:1 exchange with one member.',
            icon: Icons.chat_outlined,
            onTap: () => context.push('/invite/create?destinationType=START_1_TO_1'),
          ),
          const SizedBox(height: AuraSpace.s12),
          _InviteOptionCard(
            title: 'Shared space',
            subtitle: _hasSpaceContext
                ? 'Invite someone into this space with the right role from the start.'
                : 'Invite someone into a shared space without sending them into the wrong room.',
            icon: Icons.groups_outlined,
            onTap: () => context.push(
              '/invite/create?destinationType=JOIN_SPACE${_hasSpaceContext ? '&spaceId=${Uri.encodeComponent(spaceId!.trim())}' : ''}',
            ),
          ),
          const SizedBox(height: AuraSpace.s12),
          _InviteOptionCard(
            title: 'Specific thread',
            subtitle: _hasThreadContext
                ? 'Send someone into this thread instead of making them hunt for it.'
                : 'Invite someone into a live thread when the exact conversation matters.',
            icon: Icons.forum_outlined,
            onTap: () => context.push(
              '/invite/create?destinationType=JOIN_THREAD'
              '${_hasSpaceContext ? '&spaceId=${Uri.encodeComponent(spaceId!.trim())}' : ''}'
              '${_hasThreadContext ? '&threadId=${Uri.encodeComponent(threadId!.trim())}' : ''}',
            ),
          ),
          const SizedBox(height: AuraSpace.s12),
          _InviteOptionCard(
            title: 'Into Aura',
            subtitle: 'Create an entry path for someone who is still outside the platform.',
            icon: Icons.public_outlined,
            onTap: () => context.push('/invite/create?destinationType=JOIN_AURA'),
          ),
          const SizedBox(height: AuraSpace.s14),
          OutlinedButton(
            onPressed: () => context.push('/me/invitations'),
            child: const Text('Open invitation history'),
          ),
        ],
      ),
    );
  }

  String _contextBody() {
    if (_hasThreadContext) {
      return 'You are inviting someone into an existing conversation. Choose the cleanest entry point and keep the thread intact.';
    }
    if (_hasSpaceContext) {
      return 'You are inviting someone into a shared space. Choose how they should arrive and what kind of access they should receive.';
    }
    return 'Choose the kind of entry you need. Direct conversation, shared space, exact thread, or Aura itself.';
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

class _ContextPill extends StatelessWidget {
  const _ContextPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s10,
        vertical: AuraSpace.s6,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AuraText.small.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}
