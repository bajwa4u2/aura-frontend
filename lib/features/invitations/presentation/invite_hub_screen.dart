import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/ui/aura_text_block.dart';

class InviteHubScreen extends StatelessWidget {
  const InviteHubScreen({
    super.key,
    this.spaceId,
    this.threadId,
    this.returnTo,
  });

  final String? spaceId;
  final String? threadId;
  final String? returnTo;

  bool get _hasSpaceContext => (spaceId ?? '').trim().isNotEmpty;
  bool get _hasThreadContext => (threadId ?? '').trim().isNotEmpty;
  String get _returnTo {
    final explicit = (returnTo ?? '').trim();
    if (explicit.isNotEmpty) return explicit;
    if (_hasThreadContext && _hasSpaceContext) {
      return '/me/correspondence/${spaceId!.trim()}/thread/${threadId!.trim()}';
    }
    if (_hasSpaceContext) return '/me/correspondence/${spaceId!.trim()}';
    return '/me/invitations';
  }

  String _withReturnTo(String path) {
    final uri = Uri.parse(path);
    final query = <String, String>{
      ...uri.queryParameters,
      'returnTo': _returnTo,
    };
    return Uri(path: uri.path, queryParameters: query).toString();
  }

  @override
  Widget build(BuildContext context) {
    final options = <_InviteOptionData>[];

    if (_hasThreadContext) {
      options.add(
        _InviteOptionData(
          title: 'Bring someone into this thread',
          subtitle:
              'Invite a specific Aura member directly into this conversation.',
          icon: Icons.forum_outlined,
          onTap: () => context.push(
            _withReturnTo(
              '/invite/create?destinationType=JOIN_THREAD'
              '${_hasSpaceContext ? '&spaceId=${Uri.encodeComponent(spaceId!.trim())}' : ''}'
              '&threadId=${Uri.encodeComponent(threadId!.trim())}',
            ),
          ),
        ),
      );
    }

    if (_hasSpaceContext) {
      options.add(
        _InviteOptionData(
          title: 'Bring someone into this space',
          subtitle:
              'Invite into the shared room instead of a single thread when they should belong more broadly.',
          icon: Icons.groups_outlined,
          onTap: () => context.push(
            _withReturnTo(
              '/invite/create?destinationType=JOIN_SPACE&spaceId=${Uri.encodeComponent(spaceId!.trim())}',
            ),
          ),
        ),
      );
    }

    if (!_hasSpaceContext && !_hasThreadContext) {
      options.addAll([
        _InviteOptionData(
          title: 'Invite into Aura',
          subtitle: 'Send an invitation to someone not yet on the platform.',
          icon: Icons.public_outlined,
          onTap: () => context.push(
            _withReturnTo('/invite/create?destinationType=JOIN_AURA'),
          ),
        ),
        _InviteOptionData(
          title: 'Import contacts & invite',
          subtitle: 'Add emails, paste a list, or upload a CSV to invite in bulk.',
          icon: Icons.contact_mail_outlined,
          onTap: () => context.push('/invite/import'),
        ),
      ]);
    }

    return AuraScaffold(
      title: 'Invite',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          AuraCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Invite', style: AuraText.title),
                const SizedBox(height: AuraSpace.s8),
                AuraTextBlock(_introText, style: AuraText.body),
              ],
            ),
          ),
          const SizedBox(height: AuraSpace.s14),
          for (var i = 0; i < options.length; i++) ...[
            _InviteOptionCard(data: options[i]),
            if (i != options.length - 1) const SizedBox(height: AuraSpace.s12),
          ],
          const SizedBox(height: AuraSpace.s14),
          AuraSecondaryButton(
            label: 'Open invitations',
            onPressed: () => context.push('/me/invitations'),
          ),
        ],
      ),
    );
  }

  String get _introText {
    if (_hasThreadContext) return 'Invite into this thread or the space around it.';
    if (_hasSpaceContext) return 'Invite someone into this space.';
    return 'Bring people into Aura or into a specific context.';
  }
}

class _InviteOptionData {
  const _InviteOptionData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
}

class _InviteOptionCard extends StatelessWidget {
  const _InviteOptionCard({required this.data});

  final _InviteOptionData data;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: data.onTap,
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
                  borderRadius: BorderRadius.circular(AuraRadius.pill),
                ),
                child: Icon(data.icon, size: 18),
              ),
              const SizedBox(width: AuraSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AuraTextBlock(
                      data.title,
                      style: AuraText.body.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: AuraSpace.s6),
                    AuraTextBlock(data.subtitle, style: AuraText.body),
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
