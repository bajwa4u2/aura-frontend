import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/ui/aura_text_block.dart';
import '../data/invitations_client.dart';
import '../../correspondence/data/correspondence_identity.dart';
import '../../correspondence/data/correspondence_live_service.dart';

final _inviteInboxProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(invitationsClientProvider).loadInbox();
});

final _inviteSentProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(invitationsClientProvider).loadSent();
});

final _inviteApprovalsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(invitationsClientProvider).loadApprovals();
});

class InvitationsScreen extends ConsumerStatefulWidget {
  const InvitationsScreen({super.key});

  @override
  ConsumerState<InvitationsScreen> createState() => _InvitationsScreenState();
}

class _InvitationsScreenState extends ConsumerState<InvitationsScreen> {
  StreamSubscription<CorrespondenceLiveEvent>? _liveSubscription;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final live = ref.read(correspondenceLiveServiceProvider);
      await live.ensureConnected();
      _liveSubscription = live.events.listen((event) {
        if (!mounted) return;
        if (event.name.startsWith('invite:') || event.name.startsWith('thread:') || event.name.startsWith('space:member.')) {
          ref.invalidate(_inviteInboxProvider);
          ref.invalidate(_inviteSentProvider);
          ref.invalidate(_inviteApprovalsProvider);
        }
      });
    });
  }

  @override
  void dispose() {
    _liveSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
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
                    'See what is waiting on you, what you have already sent, and anything that still needs a decision.',
                    style: AuraText.body,
                  ),
                  const SizedBox(height: AuraSpace.s12),
                  Wrap(
                    spacing: AuraSpace.s8,
                    runSpacing: AuraSpace.s8,
                    children: [
                      AuraPrimaryButton(
                        label: 'New invite',
                        onPressed: () => context.push('/invite'),
                      ),
                      AuraSecondaryButton(
                        label: 'Open correspondence',
                        onPressed: () => context.push('/me/correspondence'),
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
              borderRadius: BorderRadius.circular(AuraRadius.pill),
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
    final status = _inviteStateLabel(invite);

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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IdentityAvatar(label: title, imageUrl: _inviteAvatarUrl(invite)),
              const SizedBox(width: AuraSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AuraTextBlock(title, style: AuraText.title, maxLines: 2),
                    const SizedBox(height: AuraSpace.s6),
                    AuraTextBlock(subtitle, style: AuraText.body),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s10),
          Wrap(
            spacing: AuraSpace.s8,
            runSpacing: AuraSpace.s8,
            children: [
              _StatusPill(label: status, tone: _inviteTone(invite)),
              _Pill(label: _humanizeLabel(_pickString(invite, const ['destinationType', 'destination_type']))),
            ],
          ),
          const SizedBox(height: AuraSpace.s12),
          Wrap(
            spacing: AuraSpace.s10,
            runSpacing: AuraSpace.s10,
            children: [
              AuraPrimaryButton(
                label: 'Accept',
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
              ),
              AuraSecondaryButton(
                label: 'Decline',
                onPressed: () async {
                  try {
                    await respond('DECLINE');
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                    }
                  }
                },
              ),
              if (token.isNotEmpty)
                AuraSecondaryButton(
                  label: 'Open invite',
                  onPressed: () => context.push('/invite/accept?token=${Uri.encodeComponent(token)}'),
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IdentityAvatar(label: title, imageUrl: _inviteAvatarUrl(invite)),
              const SizedBox(width: AuraSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AuraTextBlock(title, style: AuraText.title, maxLines: 2),
                    const SizedBox(height: AuraSpace.s6),
                    AuraTextBlock(subtitle, style: AuraText.body),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s10),
          Wrap(
            spacing: AuraSpace.s8,
            runSpacing: AuraSpace.s8,
            children: [
              _StatusPill(label: _inviteStateLabel(invite), tone: _inviteTone(invite)),
              if (_pickString(invite, const ['deliveryChannel', 'delivery_channel']).isNotEmpty)
                _Pill(label: _humanizeLabel(_pickString(invite, const ['deliveryChannel', 'delivery_channel']))),
            ],
          ),
          const SizedBox(height: AuraSpace.s12),
          Wrap(
            spacing: AuraSpace.s10,
            runSpacing: AuraSpace.s10,
            children: [
              if (token.isNotEmpty && _inviteIsActive(invite))
                AuraSecondaryButton(
                  label: 'Copy link',
                  icon: Icons.link_outlined,
                  onPressed: () async {
                    final link = Uri.base.origin + '/invite/accept?token=${Uri.encodeComponent(token)}';
                    await Clipboard.setData(ClipboardData(text: link));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invite link copied.')),
                    );
                  },
                ),
              AuraGhostButton(
                label: 'Cancel invite',
                onPressed: inviteId.isEmpty || !_inviteIsActive(invite)
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IdentityAvatar(label: _inviteTitle(invite), imageUrl: _inviteAvatarUrl(invite)),
              const SizedBox(width: AuraSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AuraTextBlock(_inviteTitle(invite), style: AuraText.title, maxLines: 2),
                    const SizedBox(height: AuraSpace.s6),
                    AuraTextBlock(_inviteSubtitle(invite), style: AuraText.body),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s10),
          Wrap(
            spacing: AuraSpace.s8,
            runSpacing: AuraSpace.s8,
            children: [
              _StatusPill(label: _inviteStateLabel(invite), tone: _inviteTone(invite)),
              if (_pickString(invite, const ['accessPolicy', 'access_policy']).isNotEmpty)
                _Pill(label: _humanizeLabel(_pickString(invite, const ['accessPolicy', 'access_policy']))),
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
        borderRadius: BorderRadius.circular(AuraRadius.pill),
      ),
      child: Text(text, style: AuraText.small.copyWith(fontWeight: FontWeight.w600)),
    );
  }
}

enum _StatusTone { neutral, accent, positive, negative }

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.tone});

  final String label;
  final _StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final palette = switch (tone) {
      _StatusTone.positive => (border: Colors.green.shade200, text: Colors.green.shade800, fill: Colors.green.shade50),
      _StatusTone.negative => (border: Colors.red.shade200, text: Colors.red.shade800, fill: Colors.red.shade50),
      _StatusTone.accent => (border: Colors.blue.shade200, text: Colors.blue.shade800, fill: Colors.blue.shade50),
      _StatusTone.neutral => (border: Colors.black12, text: Colors.black87, fill: Colors.transparent),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AuraSpace.s10, vertical: AuraSpace.s6),
      decoration: BoxDecoration(
        color: palette.fill,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(AuraRadius.pill),
      ),
      child: Text(label, style: AuraText.small.copyWith(fontWeight: FontWeight.w700, color: palette.text)),
    );
  }
}

class _IdentityAvatar extends StatelessWidget {
  const _IdentityAvatar({required this.label, this.imageUrl = '', this.radius = 20});

  final String label;
  final String imageUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(label);
    if (imageUrl.trim().isNotEmpty) {
      return CircleAvatar(radius: radius, backgroundImage: NetworkImage(imageUrl.trim()));
    }
    return CircleAvatar(
      radius: radius,
      child: Text(initials, style: AuraText.small.copyWith(fontWeight: FontWeight.w700)),
    );
  }
}

String _inviteTitle(Map<String, dynamic> invite) {
  return CorrespondenceIdentity.inviteTitle(invite);
}

String _inviteSubtitle(Map<String, dynamic> invite) {
  return CorrespondenceIdentity.inviteSubtitle(invite);
}


String _inviteStateLabel(Map<String, dynamic> invite) {
  return CorrespondenceIdentity.inviteStateLabel(invite);
}

bool _inviteIsActive(Map<String, dynamic> invite) {
  return CorrespondenceIdentity.inviteIsActive(invite);
}

_StatusTone _inviteTone(Map<String, dynamic> invite) {
  final status = _pickString(invite, const ['status']).toUpperCase();
  switch (status) {
    case 'ACCEPTED':
      return _StatusTone.positive;
    case 'REVOKED':
    case 'DECLINED':
    case 'EXPIRED':
      return _StatusTone.negative;
    case 'OPENED':
      return _StatusTone.accent;
    default:
      return _StatusTone.neutral;
  }
}

String _humanizeLabel(String value) {
  return CorrespondenceIdentity.humanize(value);
}

String _inviteAvatarUrl(Map<String, dynamic> invite) {
  return CorrespondenceIdentity.inviteAvatarUrl(invite);
}

String _initials(String value) {
  return CorrespondenceIdentity.initials(value);
}

String _destinationRoute(Map<String, dynamic> invite) {
  return CorrespondenceIdentity.inviteDestinationRoute(invite);
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
