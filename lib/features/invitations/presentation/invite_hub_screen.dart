import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
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
          _HeroCard(
            title: _hasThreadContext
                ? 'Bring someone into this exact thread.'
                : _hasSpaceContext
                    ? 'Open a clean path into this shared room.'
                    : 'Choose how someone should arrive.',
            body: _contextBody(),
            pills: [
              if (_hasSpaceContext) 'Space context',
              if (_hasThreadContext) 'Thread context',
              if (!_hasSpaceContext && !_hasThreadContext) 'Aura entry',
            ],
          ),
          const SizedBox(height: AuraSpace.s16),
          _InviteOptionCard(
            title: 'Direct conversation',
            subtitle: 'Start a one-to-one path with a specific member.',
            icon: Icons.chat_outlined,
            tag: 'Direct',
            onTap: () => context.push('/invite/create?destinationType=START_1_TO_1'),
          ),
          const SizedBox(height: AuraSpace.s12),
          _InviteOptionCard(
            title: 'Shared space',
            subtitle: _hasSpaceContext
                ? 'Invite someone into this room with the right role from the beginning.'
                : 'Open a path into a shared room without dropping them into the wrong place.',
            icon: Icons.groups_outlined,
            tag: 'Room',
            onTap: () => context.push(
              '/invite/create?destinationType=JOIN_SPACE${_hasSpaceContext ? '&spaceId=${Uri.encodeComponent(spaceId!.trim())}' : ''}',
            ),
          ),
          const SizedBox(height: AuraSpace.s12),
          _InviteOptionCard(
            title: 'Specific thread',
            subtitle: _hasThreadContext
                ? 'Send someone into this live thread instead of making them hunt for it.'
                : 'Use this when the exact conversation matters more than the room around it.',
            icon: Icons.forum_outlined,
            tag: 'Exact',
            onTap: () => context.push(
              '/invite/create?destinationType=JOIN_THREAD'
              '${_hasSpaceContext ? '&spaceId=${Uri.encodeComponent(spaceId!.trim())}' : ''}'
              '${_hasThreadContext ? '&threadId=${Uri.encodeComponent(threadId!.trim())}' : ''}',
            ),
          ),
          const SizedBox(height: AuraSpace.s12),
          _InviteOptionCard(
            title: 'Into Aura',
            subtitle: 'Create a clean entry path for someone who is still outside the platform.',
            icon: Icons.public_outlined,
            tag: 'Platform',
            onTap: () => context.push('/invite/create?destinationType=JOIN_AURA'),
          ),
          const SizedBox(height: AuraSpace.s14),
          AuraCard(
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Invitation history', style: AuraText.body),
                      SizedBox(height: AuraSpace.s6),
                      Text(
                        'See what is pending, accepted, declined, or no longer active.',
                        style: AuraText.small,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AuraSpace.s12),
                OutlinedButton(
                  onPressed: () => context.push('/me/invitations'),
                  child: const Text('Open'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _contextBody() {
    if (_hasThreadContext) {
      return 'You are inviting someone into an existing conversation. Choose the clearest entry and keep the thread intact.';
    }
    if (_hasSpaceContext) {
      return 'You are inviting someone into a shared room. Decide how they should arrive and what kind of access they should receive.';
    }
    return 'Choose the kind of entry you need. Direct conversation, shared room, exact thread, or Aura itself.';
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.title,
    required this.body,
    required this.pills,
  });

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
            'INVITE',
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
          if (pills.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s14),
            Wrap(
              spacing: AuraSpace.s8,
              runSpacing: AuraSpace.s8,
              children: pills.map((label) => _ContextPill(label: label)).toList(),
            ),
          ],
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
    required this.tag,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String tag;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      onTap: onTap,
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
                    _ContextPill(label: tag),
                  ],
                ),
                const SizedBox(height: AuraSpace.s6),
                AuraTextBlock(subtitle, style: AuraText.body),
              ],
            ),
          ),
          const SizedBox(width: AuraSpace.s8),
          const Icon(Icons.chevron_right, size: 18, color: AuraSurface.muted),
        ],
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
        color: AuraSurface.accentSoft,
        border: Border.all(color: AuraSurface.accentSoft),
        borderRadius: BorderRadius.circular(999),
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
