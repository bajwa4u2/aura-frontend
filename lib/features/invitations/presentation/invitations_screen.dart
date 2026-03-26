import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/ui/aura_text_block.dart';
import '../data/invitations_client.dart';

final _inviteInboxProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(invitationsClientProvider).loadInbox();
});

final _inviteSentProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(invitationsClientProvider).loadSent();
});

final _inviteApprovalsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(invitationsClientProvider).loadApprovals();
});

class InvitationsScreen extends ConsumerWidget {
  const InvitationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inboxAsync = ref.watch(_inviteInboxProvider);
    final sentAsync = ref.watch(_inviteSentProvider);
    final approvalsAsync = ref.watch(_inviteApprovalsProvider);

    return AuraScaffold(
      title: 'Invitations',
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(_inviteInboxProvider);
          ref.invalidate(_inviteSentProvider);
          ref.invalidate(_inviteApprovalsProvider);
          await Future.wait([
            ref.read(_inviteInboxProvider.future),
            ref.read(_inviteSentProvider.future),
            ref.read(_inviteApprovalsProvider.future),
          ]);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            AuraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Invitations', style: AuraText.title),
                  const SizedBox(height: AuraSpace.s8),
                  AuraTextBlock(
                    'Track the invitations you sent, the invitations waiting on you, and anything that still needs approval or response.',
                    style: AuraText.body,
                  ),
                  const SizedBox(height: AuraSpace.s12),
                  Wrap(
                    spacing: AuraSpace.s8,
                    runSpacing: AuraSpace.s8,
                    children: [
                      FilledButton(
                        onPressed: () => context.push('/invite'),
                        child: const Text('New invite'),
                      ),
                      OutlinedButton(
                        onPressed: () => context.push('/me/correspondence'),
                        child: const Text('Open correspondence'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AuraSpace.s14),
            _SectionHeader(
              title: 'Incoming',
              countAsync: inboxAsync,
            ),
            const SizedBox(height: AuraSpace.s10),
            _InviteListBlock(
              asyncValue: inboxAsync,
              emptyTitle: 'No incoming invitations',
              emptyBody: 'Nothing is waiting on you right now.',
              itemBuilder: (invite) => _IncomingInviteCard(invite: invite),
            ),
            const SizedBox(height: AuraSpace.s14),
            _SectionHeader(
              title: 'Sent',
              countAsync: sentAsync,
            ),
            const SizedBox(height: AuraSpace.s10),
            _InviteListBlock(
              asyncValue: sentAsync,
              emptyTitle: 'No sent invitations',
              emptyBody: 'Your outgoing invitations will appear here.',
              itemBuilder: (invite) => _SentInviteCard(invite: invite),
            ),
            const SizedBox(height: AuraSpace.s14),
            _SectionHeader(
              title: 'Approval requests',
              countAsync: approvalsAsync,
            ),
            const SizedBox(height: AuraSpace.s10),
            _InviteListBlock(
              asyncValue: approvalsAsync,
              emptyTitle: 'No pending approvals',
              emptyBody: 'Approval-based entry will surface here when needed.',
              itemBuilder: (invite) => _ApprovalInviteCard(invite: invite),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.countAsync,
  });

  final String title;
  final AsyncValue<List<Map<String, dynamic>>> countAsync;

  @override
  Widget build(BuildContext context) {
    final count = countAsync.maybeWhen(data: (items) => items.length, orElse: () => null);
    return Row(
      children: [
        Expanded(child: Text(title, style: AuraText.title)),
        if (count != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AuraSpace.s10, vertical: AuraSpace.s6),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text('$count', style: AuraText.small.copyWith(fontWeight: FontWeight.w700)),
          ),
      ],
    );
  }
}

class _InviteListBlock extends StatelessWidget {
  const _InviteListBlock({
    required this.asyncValue,
    required this.emptyTitle,
    required this.emptyBody,
    required this.itemBuilder,
  });

  final AsyncValue<List<Map<String, dynamic>>> asyncValue;
  final String emptyTitle;
  final String emptyBody;
  final Widget Function(Map<String, dynamic>) itemBuilder;

  @override
  Widget build(BuildContext context) {
    return asyncValue.when(
      loading: () => const AuraCard(child: _LoadingBlock(label: 'Loading...')),
      error: (error, _) => AuraCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Could not load invitations', style: AuraText.title),
            const SizedBox(height: AuraSpace.s8),
            AuraTextBlock('$error', style: AuraText.body),
          ],
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return AuraCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(emptyTitle, style: AuraText.title),
                const SizedBox(height: AuraSpace.s8),
                AuraTextBlock(emptyBody, style: AuraText.body),
              ],
            ),
          );
        }

        return Column(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              itemBuilder(items[i]),
              if (i != items.length - 1) const SizedBox(height: AuraSpace.s10),
            ],
          ],
        );
      },
    );
  }
}

class _IncomingInviteCard extends ConsumerWidget {
  const _IncomingInviteCard({required this.invite});

  final Map<String, dynamic> invite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inviteId = _pickString(invite, const ['id', 'inviteId']);
    final token = _pickString(invite, const ['token', 'inviteToken']);
    final title = _inviteTitle(invite);
    final subtitle = _inviteSubtitle(invite);
    final status = _pickString(invite, const ['status']);

    Future<void> respond(String action) async {
      await ref.read(invitationsClientProvider).respond(
            inviteId: inviteId,
            token: token,
            action: action,
          );
      ref.invalidate(_inviteInboxProvider);
      ref.invalidate(_inviteSentProvider);
      ref.invalidate(_inviteApprovalsProvider);
    }

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuraTextBlock(title, style: AuraText.title, maxLines: 2),
          const SizedBox(height: AuraSpace.s6),
          AuraTextBlock(subtitle, style: AuraText.body),
          const SizedBox(height: AuraSpace.s10),
          Wrap(
            spacing: AuraSpace.s8,
            runSpacing: AuraSpace.s8,
            children: [
              if (status.isNotEmpty) _Pill(label: status),
              _Pill(label: _pickString(invite, const ['destinationType', 'destination_type']).replaceAll('_', ' ')),
            ],
          ),
          const SizedBox(height: AuraSpace.s12),
          Wrap(
            spacing: AuraSpace.s10,
            runSpacing: AuraSpace.s10,
            children: [
              FilledButton(
                onPressed: () async {
                  try {
                    await respond('ACCEPT');
                    if (context.mounted) {
                      final route = _destinationRoute(invite);
                      if (route.isNotEmpty) context.go(route);
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                    }
                  }
                },
                child: const Text('Accept'),
              ),
              OutlinedButton(
                onPressed: () async {
                  try {
                    await respond('DECLINE');
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                    }
                  }
                },
                child: const Text('Decline'),
              ),
              if (token.isNotEmpty)
                OutlinedButton(
                  onPressed: () => context.push('/invite/accept?token=${Uri.encodeComponent(token)}'),
                  child: const Text('Open'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SentInviteCard extends ConsumerWidget {
  const _SentInviteCard({required this.invite});

  final Map<String, dynamic> invite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inviteId = _pickString(invite, const ['id', 'inviteId']);
    final title = _inviteTitle(invite);
    final subtitle = _inviteSubtitle(invite);
    final token = _pickString(invite, const ['token', 'inviteToken']);

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuraTextBlock(title, style: AuraText.title, maxLines: 2),
          const SizedBox(height: AuraSpace.s6),
          AuraTextBlock(subtitle, style: AuraText.body),
          const SizedBox(height: AuraSpace.s10),
          Wrap(
            spacing: AuraSpace.s8,
            runSpacing: AuraSpace.s8,
            children: [
              _Pill(label: _pickString(invite, const ['status']).replaceAll('_', ' ')),
              _Pill(label: _pickString(invite, const ['deliveryChannel', 'delivery_channel']).replaceAll('_', ' ')),
            ],
          ),
          const SizedBox(height: AuraSpace.s12),
          Wrap(
            spacing: AuraSpace.s10,
            runSpacing: AuraSpace.s10,
            children: [
              if (token.isNotEmpty)
                OutlinedButton(
                  onPressed: () {
                    final link = Uri.base.origin + '/invite/accept?token=${Uri.encodeComponent(token)}';
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Invite link: $link')),
                    );
                  },
                  child: const Text('Show link'),
                ),
              OutlinedButton(
                onPressed: inviteId.isEmpty
                    ? null
                    : () async {
                        try {
                          await ref.read(invitationsClientProvider).revokeInvite(inviteId);
                          ref.invalidate(_inviteInboxProvider);
                          ref.invalidate(_inviteSentProvider);
                          ref.invalidate(_inviteApprovalsProvider);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                          }
                        }
                      },
                child: const Text('Revoke'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ApprovalInviteCard extends StatelessWidget {
  const _ApprovalInviteCard({required this.invite});

  final Map<String, dynamic> invite;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuraTextBlock(_inviteTitle(invite), style: AuraText.title, maxLines: 2),
          const SizedBox(height: AuraSpace.s6),
          AuraTextBlock(_inviteSubtitle(invite), style: AuraText.body),
          const SizedBox(height: AuraSpace.s10),
          Wrap(
            spacing: AuraSpace.s8,
            runSpacing: AuraSpace.s8,
            children: [
              _Pill(label: _pickString(invite, const ['status']).replaceAll('_', ' ')),
              _Pill(label: _pickString(invite, const ['accessPolicy', 'access_policy']).replaceAll('_', ' ')),
            ],
          ),
        ],
      ),
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
          width: 18,
          height: 18,
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
    final text = label.trim().isEmpty ? '—' : label.trim();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AuraSpace.s10, vertical: AuraSpace.s6),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: AuraText.small.copyWith(fontWeight: FontWeight.w600)),
    );
  }
}

String _inviteTitle(Map<String, dynamic> invite) {
  final destinationType = _pickString(invite, const ['destinationType', 'destination_type']).toUpperCase();
  final threadTitle = _pickString(invite, const ['threadTitle', 'threadName', 'thread_title']);
  final spaceTitle = _pickString(invite, const ['spaceTitle', 'spaceName', 'space_title']);
  final inviterName = _pickNested(invite, const [
    ['invitedBy', 'displayName'],
    ['inviter', 'displayName'],
    ['invitedBy', 'handle'],
    ['inviter', 'handle'],
  ]);

  switch (destinationType) {
    case 'JOIN_SPACE':
      return spaceTitle.isNotEmpty
          ? 'Invitation to $spaceTitle'
          : inviterName.isNotEmpty
              ? '$inviterName invited you into a space'
              : 'Space invitation';
    case 'JOIN_THREAD':
      return threadTitle.isNotEmpty
          ? 'Invitation to $threadTitle'
          : 'Thread invitation';
    case 'START_1_TO_1':
      return inviterName.isNotEmpty
          ? '$inviterName invited you to correspond'
          : 'Direct invitation';
    case 'JOIN_AURA':
      return 'Invitation to Aura';
    default:
      return 'Invitation';
  }
}

String _inviteSubtitle(Map<String, dynamic> invite) {
  final message = _pickString(invite, const ['message']);
  if (message.isNotEmpty) return message;

  final policy = _pickString(invite, const ['accessPolicy', 'access_policy']).replaceAll('_', ' ');
  final recipient = _pickString(invite, const ['recipientHandle', 'recipient_handle', 'recipientUserId', 'recipient_user_id']);
  final parts = <String>[
    if (policy.isNotEmpty) 'Access: $policy',
    if (recipient.isNotEmpty) 'Recipient: $recipient',
  ];
  return parts.isEmpty ? 'Invitation in progress.' : parts.join(' · ');
}

String _destinationRoute(Map<String, dynamic> invite) {
  final threadId = _pickString(invite, const ['threadId', 'thread_id']);
  final spaceId = _pickString(invite, const ['spaceId', 'space_id']);
  final destinationType = _pickString(invite, const ['destinationType', 'destination_type']).toUpperCase();

  if (threadId.isNotEmpty && spaceId.isNotEmpty) {
    return '/me/correspondence/$spaceId/thread/$threadId';
  }
  if (spaceId.isNotEmpty) {
    return '/me/correspondence/$spaceId';
  }
  if (destinationType == 'JOIN_AURA') return '/home';
  return '/me/invitations';
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
      if (current is! Map) {
        current = null;
        break;
      }
      current = current[key];
    }
    final text = (current ?? '').toString().trim();
    if (text.isNotEmpty) return text;
  }
  return '';
}
