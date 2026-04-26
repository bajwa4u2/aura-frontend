import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_providers.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/ui/aura_text_block.dart';
import '../data/invitations_client.dart';

final _inviteInspectProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, token) async {
      return ref.watch(invitationsClientProvider).inspectToken(token);
    });

class InviteAcceptScreen extends ConsumerWidget {
  const InviteAcceptScreen({super.key, required this.token});

  final String token;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStatusProvider);
    final trimmedToken = token.trim();

    return AuraScaffold(
      title: 'Invitation',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          if (trimmedToken.isEmpty)
            const AuraCard(
              child: _StaticStateCard(
                title: 'Invite link is incomplete',
                body: 'The token is missing from this invitation link.',
              ),
            )
          else if (auth != AuthStatus.authed)
            AuraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Invitation', style: AuraText.title),
                  const SizedBox(height: AuraSpace.s8),
                  const AuraTextBlock(
                    'Sign in or join Aura first, then this invitation will continue from the same link.',
                    style: AuraText.body,
                  ),
                  const SizedBox(height: AuraSpace.s12),
                  Wrap(
                    spacing: AuraSpace.s10,
                    runSpacing: AuraSpace.s10,
                    children: [
                      AuraPrimaryButton(
                        label: 'Sign in',
                        onPressed: () => context.push(
                          '/login?redirect=${Uri.encodeComponent('/invite/accept?token=$trimmedToken')}',
                        ),
                      ),
                      AuraSecondaryButton(
                        label: 'Join Aura',
                        onPressed: () => context.push(
                          '/register?redirect=${Uri.encodeComponent('/invite/accept?token=$trimmedToken')}',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          else
            Consumer(
              builder: (context, ref, _) {
                final inspectAsync = ref.watch(
                  _inviteInspectProvider(trimmedToken),
                );
                return inspectAsync.when(
                  loading: () => const AuraCard(
                    child: _LoadingBlock(label: 'Reading invitation...'),
                  ),
                  error: (error, _) => AuraCard(
                    child: _StaticStateCard(
                      title: 'Could not open invitation',
                      body: '$error',
                    ),
                  ),
                  data: (invite) =>
                      _InviteAcceptCard(invite: invite, token: trimmedToken),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _InviteAcceptCard extends ConsumerStatefulWidget {
  const _InviteAcceptCard({required this.invite, required this.token});

  final Map<String, dynamic> invite;
  final String token;

  @override
  ConsumerState<_InviteAcceptCard> createState() => _InviteAcceptCardState();
}

class _InviteAcceptCardState extends ConsumerState<_InviteAcceptCard> {
  bool _busy = false;

  Future<void> _respond(String action) async {
    setState(() => _busy = true);
    try {
      final result = await ref
          .read(invitationsClientProvider)
          .respond(
            token: widget.token,
            inviteId: _pickString(widget.invite, const ['id', 'inviteId']),
            action: action,
          );
      if (!mounted) return;
      if (action.toUpperCase() == 'ACCEPT') {
        final route = _destinationRoute(
          result.isEmpty ? widget.invite : result,
        );
        context.go(route.isEmpty ? '/home' : route);
      } else {
        context.go('/me/invitations');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final invite = widget.invite;
    final title = _pickString(invite, const ['title', 'name']).isNotEmpty
        ? _pickString(invite, const ['title', 'name'])
        : 'Invitation';
    final message = _pickString(invite, const ['message']);
    final policy = _pickString(invite, const [
      'accessPolicy',
      'access_policy',
    ]).replaceAll('_', ' ');
    final destinationType = _pickString(invite, const [
      'destinationType',
      'destination_type',
    ]).replaceAll('_', ' ');
    final inviter = _pickNested(invite, const [
      ['invitedBy', 'displayName'],
      ['inviter', 'displayName'],
      ['invitedBy', 'handle'],
      ['inviter', 'handle'],
    ]);

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AuraText.title),
          const SizedBox(height: AuraSpace.s8),
          if (inviter.isNotEmpty)
            AuraTextBlock('From $inviter', style: AuraText.body),
          if (message.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s8),
            AuraTextBlock(message, style: AuraText.body),
          ],
          const SizedBox(height: AuraSpace.s12),
          Wrap(
            spacing: AuraSpace.s8,
            runSpacing: AuraSpace.s8,
            children: [
              if (destinationType.isNotEmpty) _Pill(label: destinationType),
              if (policy.isNotEmpty) _Pill(label: 'Access: $policy'),
              _Pill(
                label: _pickString(invite, const [
                  'status',
                ]).replaceAll('_', ' '),
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s14),
          const AuraTextBlock(
            'Accepting will continue into the destination if the entry rules are satisfied. If follow or approval is still required, Aura will hold you at the correct state instead of forcing entry.',
            style: AuraText.body,
          ),
          const SizedBox(height: AuraSpace.s14),
          Wrap(
            spacing: AuraSpace.s10,
            runSpacing: AuraSpace.s10,
            children: [
              AuraPrimaryButton(
                label: _busy ? 'Working...' : 'Accept',
                onPressed: _busy ? null : () => _respond('ACCEPT'),
              ),
              AuraSecondaryButton(
                label: 'Decline',
                onPressed: _busy ? null : () => _respond('DECLINE'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StaticStateCard extends StatelessWidget {
  const _StaticStateCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AuraText.title),
        const SizedBox(height: AuraSpace.s8),
        AuraTextBlock(body, style: AuraText.body),
      ],
    );
  }
}

class _LoadingBlock extends StatelessWidget {
  const _LoadingBlock({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          height: 18,
          width: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: AuraSpace.s10),
        Text(label, style: AuraText.body),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});

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
        borderRadius: BorderRadius.circular(AuraRadius.pill),
      ),
      child: Text(
        label,
        style: AuraText.small.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

String _pickString(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = (map[key] ?? '').toString().trim();
    if (value.isNotEmpty) return value;
  }
  return '';
}

String _pickNested(Map<String, dynamic> map, List<List<String>> paths) {
  for (final path in paths) {
    dynamic current = map;
    for (final key in path) {
      if (current is Map && current[key] != null) {
        current = current[key];
      } else {
        current = null;
        break;
      }
    }
    final text = (current ?? '').toString().trim();
    if (text.isNotEmpty) return text;
  }
  return '';
}

String _destinationRoute(Map<String, dynamic> invite) {
  final destinationType = _pickString(invite, const [
    'destinationType',
    'destination_type',
  ]).toUpperCase();
  final spaceId =
      _pickNested(invite, const [
        ['space', 'id'],
        ['destination', 'spaceId'],
      ]).isNotEmpty
      ? _pickNested(invite, const [
          ['space', 'id'],
          ['destination', 'spaceId'],
        ])
      : _pickString(invite, const ['spaceId', 'space_id']);

  final threadId =
      _pickNested(invite, const [
        ['thread', 'id'],
        ['destination', 'threadId'],
      ]).isNotEmpty
      ? _pickNested(invite, const [
          ['thread', 'id'],
          ['destination', 'threadId'],
        ])
      : _pickString(invite, const [
          'threadId',
          'thread_id',
          'destinationId',
          'destination_id',
        ]);

  switch (destinationType) {
    case 'JOIN_THREAD':
    case 'START_1_TO_1':
      if (spaceId.isNotEmpty && threadId.isNotEmpty) {
        return '/me/correspondence/$spaceId/thread/$threadId';
      }
      if (threadId.isNotEmpty) return '/me/invitations';
      return '/me/invitations';
    case 'JOIN_SPACE':
      if (spaceId.isNotEmpty) return '/me/correspondence/$spaceId';
      return '/me/correspondence';
    case 'JOIN_AURA':
      return '/home';
    default:
      if (spaceId.isNotEmpty && threadId.isNotEmpty) {
        return '/me/correspondence/$spaceId/thread/$threadId';
      }
      if (spaceId.isNotEmpty) return '/me/correspondence/$spaceId';
      return '/home';
  }
}
