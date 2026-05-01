import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_providers.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../realtime/application/realtime_providers.dart';
import '../../updates/providers.dart';
import '../data/correspondence_identity.dart';
import '../data/spaces_repository.dart';
import '../../create/presentation/new_conversation_screen.dart';

final _correspondenceHubDataProvider =
    FutureProvider.autoDispose<_CorrespondenceHubData>((ref) async {
      final auth = ref.watch(authStatusProvider);
      if (auth != AuthStatus.authed) {
        return const _CorrespondenceHubData(
          spaces: <Map<String, dynamic>>[],
          invites: <Map<String, dynamic>>[],
        );
      }

      final repo = ref.watch(spacesRepositoryProvider);
      final results = await Future.wait([
        repo.listMySpaces(),
        repo.listInvites(),
      ]);

      return _CorrespondenceHubData(
        spaces: List<Map<String, dynamic>>.from(results[0] as List),
        invites: List<Map<String, dynamic>>.from(results[1] as List),
      );
    });

class CorrespondenceHubScreen extends ConsumerWidget {
  const CorrespondenceHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStatusProvider);
    final uri = GoRouterState.of(context).uri;
    final start = (uri.queryParameters['start'] ?? '').trim().toLowerCase();

    if (auth != AuthStatus.authed) {
      return AuraScaffold(
        showHeader: false,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AuraSpace.s16,
                AuraSpace.s20,
                AuraSpace.s16,
                AuraSpace.s32,
              ),
              children: [
                const _HubHeader(),
                const SizedBox(height: AuraSpace.s24),
                _SignInCard(onSignIn: () => context.go('/login')),
              ],
            ),
          ),
        ),
      );
    }

    if (start == 'private' || start == 'space') {
      return NewConversationScreen(
        isSharedSpaceMode: start == 'space',
        initialUserId: uri.queryParameters['userId'],
        initialHandle: uri.queryParameters['handle'],
        initialName: uri.queryParameters['name'],
      );
    }

    final hubAsync = ref.watch(_correspondenceHubDataProvider);
    final notifications = ref.watch(notificationsControllerProvider);
    final liveState = ref.watch(realtimeControllerProvider);
    final unreadCount = notifications.unreadCount;
    final liveSignalCount = _liveSignalCount(notifications.items);

    return AuraScaffold(
      showHeader: false,
      body: RefreshIndicator(
        color: AuraSurface.accent,
        onRefresh: () async {
          ref.invalidate(_correspondenceHubDataProvider);
          await ref.read(_correspondenceHubDataProvider.future);
        },
        child: hubAsync.when(
          loading: () => ListView(
            padding: const EdgeInsets.fromLTRB(
              AuraSpace.s16,
              AuraSpace.s20,
              AuraSpace.s16,
              AuraSpace.s32,
            ),
            children: const [
              _HubHeader(),
              SizedBox(height: AuraSpace.s24),
              AuraLoadingState(message: 'Loading messages…'),
            ],
          ),
          error: (error, _) => ListView(
            padding: const EdgeInsets.fromLTRB(
              AuraSpace.s16,
              AuraSpace.s20,
              AuraSpace.s16,
              AuraSpace.s32,
            ),
            children: [
              const _HubHeader(),
              const SizedBox(height: AuraSpace.s24),
              AuraErrorState(
                title: 'Could not load messages',
                body: '$error',
              ),
            ],
          ),
          data: (data) {
            final spaces = [...data.spaces]..sort(_sortSpacesByActivity);
            final invites = [...data.invites]..sort(_sortInvitesByActivity);
            final activeInvites = invites.where(_inviteIsActive).toList();
            final liveLabel = liveState.isJoined
                ? 'Live now'
                : liveSignalCount > 0
                    ? '$liveSignalCount live signal${liveSignalCount == 1 ? '' : 's'}'
                    : 'Idle';

            if (spaces.isEmpty && activeInvites.isEmpty) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(
                  AuraSpace.s16,
                  AuraSpace.s20,
                  AuraSpace.s16,
                  AuraSpace.s32,
                ),
                children: [
                  _HubHeader(
                    unreadCount: unreadCount,
                    inviteCount: activeInvites.length,
                    liveLabel: liveLabel,
                  ),
                  const SizedBox(height: AuraSpace.s24),
                  AuraEmptyState(
                    title: 'Start your first conversation',
                    body:
                        'Create a private conversation or shared space and your messages home will begin to fill with live activity.',
                    icon: Icons.forum_outlined,
                    action: Wrap(
                      spacing: AuraSpace.s10,
                      runSpacing: AuraSpace.s10,
                      alignment: WrapAlignment.center,
                      children: [
                        AuraPrimaryButton(
                          label: 'Start conversation',
                          icon: Icons.chat_bubble_outline_rounded,
                          onPressed: () =>
                              context.push('/me/correspondence?start=private'),
                        ),
                        AuraSecondaryButton(
                          label: 'Create space',
                          icon: Icons.groups_outlined,
                          onPressed: () =>
                              context.push('/me/correspondence?start=space'),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AuraSpace.s16,
                AuraSpace.s20,
                AuraSpace.s16,
                AuraSpace.s32,
              ),
              children: [
                _HubHeader(
                  unreadCount: unreadCount,
                  inviteCount: activeInvites.length,
                  liveLabel: liveLabel,
                ),
                const SizedBox(height: AuraSpace.s16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 1080;

                    final recentPanel = _RecentConversationsPanel(
                      spaces: spaces,
                      onOpenConversation: (space) {
                        final route = _spaceRoute(space);
                        if (route.isEmpty) return;
                        context.push(route);
                      },
                    );
                    final attentionPanel = _AttentionRail(
                      unreadCount: unreadCount,
                      inviteCount: activeInvites.length,
                      liveLabel: liveLabel,
                      invites: invites,
                    );
                    final quickActions = _QuickActionsCard(
                      onStartPrivate: () =>
                          context.push('/me/correspondence?start=private'),
                      onCreateSpace: () =>
                          context.push('/me/correspondence?start=space'),
                      onOpenConversations: () => context.push('/conversations'),
                      onOpenInvitations: () => context.push('/me/invitations'),
                    );

                    if (wide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 7, child: recentPanel),
                          const SizedBox(width: AuraSpace.s16),
                          SizedBox(
                            width: 352,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                attentionPanel,
                                const SizedBox(height: AuraSpace.s12),
                                quickActions,
                              ],
                            ),
                          ),
                        ],
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        recentPanel,
                        const SizedBox(height: AuraSpace.s12),
                        attentionPanel,
                        const SizedBox(height: AuraSpace.s12),
                        quickActions,
                      ],
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HubHeader extends StatelessWidget {
  const _HubHeader({
    this.unreadCount = 0,
    this.inviteCount = 0,
    this.liveLabel = 'Idle',
  });

  final int unreadCount;
  final int inviteCount;
  final String liveLabel;

  @override
  Widget build(BuildContext context) {
    return AuraGradientHeader(
      title: 'Messages',
      subtitle:
          'Private exchange, shared rooms, and invitations in one place.',
      trailing: Wrap(
        spacing: AuraSpace.s8,
        runSpacing: AuraSpace.s8,
        children: [
          AuraStatusChip(
            label: unreadCount > 0 ? '$unreadCount unread' : 'All read',
            backgroundColor: unreadCount > 0
                ? AuraSurface.accentSoft
                : AuraSurface.subtle,
            textColor: unreadCount > 0
                ? AuraSurface.accentText
                : AuraSurface.muted,
          ),
          AuraStatusChip(
            label: inviteCount > 0
                ? '$inviteCount invite${inviteCount == 1 ? '' : 's'}'
                : 'No invites',
            backgroundColor: inviteCount > 0
                ? AuraSurface.goodBg
                : AuraSurface.subtle,
            textColor: inviteCount > 0
                ? AuraSurface.goodInk
                : AuraSurface.muted,
          ),
          AuraStatusChip(
            label: liveLabel,
            backgroundColor: liveLabel == 'Live now'
                ? AuraSurface.warnBg
                : AuraSurface.subtle,
            textColor: liveLabel == 'Live now'
                ? AuraSurface.warnInk
                : AuraSurface.muted,
          ),
        ],
      ),
    );
  }
}

class _RecentConversationsPanel extends StatelessWidget {
  const _RecentConversationsPanel({
    required this.spaces,
    required this.onOpenConversation,
  });

  final List<Map<String, dynamic>> spaces;
  final void Function(Map<String, dynamic> space) onOpenConversation;

  @override
  Widget build(BuildContext context) {
    if (spaces.isEmpty) {
      return const AuraCard(
        padding: EdgeInsets.all(18),
        child: AuraEmptyState(
          title: 'No conversations yet',
          body:
              'Your private threads and shared spaces will appear here once you start one.',
          icon: Icons.forum_outlined,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AuraSectionHeader(
          title: 'Recent conversations',
          subtitle: 'Keep the active threads moving.',
        ),
        const SizedBox(height: AuraSpace.s12),
        AuraCard(
          padding: const EdgeInsets.all(4),
          child: Column(
            children: [
              for (var i = 0; i < spaces.length; i++) ...[
                _ConversationRow(
                  space: spaces[i],
                  onTap: () => onOpenConversation(spaces[i]),
                ),
                if (i != spaces.length - 1)
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: AuraSurface.divider,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ConversationRow extends StatelessWidget {
  const _ConversationRow({
    required this.space,
    required this.onTap,
  });

  final Map<String, dynamic> space;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = _conversationTitle(space);
    final subtitle = _conversationSubtitle(space);
    final meta = _conversationMeta(space);
    final badge = _conversationBadge(space);
    final avatarUrl = _conversationAvatarUrl(space);
    final unread = _conversationUnreadTone(space);

    return AuraConversationTile(
      title: title,
      subtitle: subtitle,
      leading: AuraAvatar(name: title, imageUrl: avatarUrl, size: 42),
      badge: AuraStatusChip(
        label: badge,
        backgroundColor: unread ? AuraSurface.accentSoft : AuraSurface.subtle,
        textColor: unread ? AuraSurface.accentText : AuraSurface.muted,
      ),
      trailing: Text(
        meta,
        style: AuraText.small.copyWith(
          color: AuraSurface.muted,
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: onTap,
    );
  }
}

class _AttentionRail extends StatelessWidget {
  const _AttentionRail({
    required this.unreadCount,
    required this.inviteCount,
    required this.liveLabel,
    required this.invites,
  });

  final int unreadCount;
  final int inviteCount;
  final String liveLabel;
  final List<Map<String, dynamic>> invites;

  @override
  Widget build(BuildContext context) {
    final activeInvites = invites.where(_inviteIsActive).take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuraMetricCard(
          label: 'Unread',
          value: '$unreadCount',
          subtext: unreadCount > 0 ? 'Messages and updates waiting.' : 'You are caught up.',
          icon: Icons.mark_chat_unread_outlined,
        ),
        const SizedBox(height: AuraSpace.s12),
        AuraMetricCard(
          label: 'Invites',
          value: '$inviteCount',
          subtext: inviteCount > 0
              ? 'Review active entry paths.'
              : 'No pending invites right now.',
          icon: Icons.mail_outline_rounded,
        ),
        const SizedBox(height: AuraSpace.s12),
        AuraMetricCard(
          label: 'Live',
          value: liveLabel,
          subtext: 'Calls and live sessions surface here.',
          icon: Icons.call_rounded,
        ),
        if (activeInvites.isNotEmpty) ...[
          const SizedBox(height: AuraSpace.s12),
          AuraCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Attention', style: AuraText.title),
                const SizedBox(height: AuraSpace.s10),
                for (final invite in activeInvites) ...[
                  AuraNotificationTile(
                    title: CorrespondenceIdentity.inviteTitle(invite),
                    body: CorrespondenceIdentity.inviteSubtitle(invite),
                    icon: Icons.mail_outline_rounded,
                    onTap: () {
                      final route = CorrespondenceIdentity.inviteDestinationRoute(
                        invite,
                      );
                      if (route.isEmpty) return;
                      context.push(route);
                    },
                  ),
                  const SizedBox(height: AuraSpace.s10),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _QuickActionsCard extends StatelessWidget {
  const _QuickActionsCard({
    required this.onStartPrivate,
    required this.onCreateSpace,
    required this.onOpenConversations,
    required this.onOpenInvitations,
  });

  final VoidCallback onStartPrivate;
  final VoidCallback onCreateSpace;
  final VoidCallback onOpenConversations;
  final VoidCallback onOpenInvitations;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Quick actions', style: AuraText.title),
          const SizedBox(height: AuraSpace.s10),
          Wrap(
            spacing: AuraSpace.s10,
            runSpacing: AuraSpace.s10,
            children: [
              AuraSecondaryButton(
                label: 'Start private',
                icon: Icons.chat_bubble_outline_rounded,
                onPressed: onStartPrivate,
              ),
              AuraSecondaryButton(
                label: 'Create space',
                icon: Icons.groups_outlined,
                onPressed: onCreateSpace,
              ),
              AuraSecondaryButton(
                label: 'Open conversations',
                icon: Icons.forum_outlined,
                onPressed: onOpenConversations,
              ),
              AuraSecondaryButton(
                label: 'Invitations',
                icon: Icons.inbox_outlined,
                onPressed: onOpenInvitations,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SignInCard extends StatelessWidget {
  const _SignInCard({required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sign in required', style: AuraText.subtitle),
          const SizedBox(height: AuraSpace.s8),
          Text(
            'Your private conversations, shared spaces, and invitations will appear here once you are signed in.',
            style: AuraText.body.copyWith(color: AuraSurface.muted),
          ),
          const SizedBox(height: AuraSpace.s16),
          AuraPrimaryButton(
            label: 'Sign in',
            onPressed: onSignIn,
            icon: Icons.login_rounded,
          ),
        ],
      ),
    );
  }
}

class _CorrespondenceHubData {
  const _CorrespondenceHubData({
    required this.spaces,
    required this.invites,
  });

  final List<Map<String, dynamic>> spaces;
  final List<Map<String, dynamic>> invites;
}

String _conversationTitle(Map<String, dynamic> space) {
  final title = _pickString(space, const ['name', 'title']);
  if (title.isNotEmpty) return title;

  final members = _extractMembers(space);
  final names = members
      .map(
        (member) => _pickString(member, const [
          'displayName',
          'name',
          'fullName',
          'handle',
          'username',
        ]),
      )
      .where((value) => value.isNotEmpty)
      .take(2)
      .toList(growable: false);

  if (names.isNotEmpty) return names.join(', ');
  return 'Conversation';
}

String _conversationSubtitle(Map<String, dynamic> space) {
  final description = _pickString(space, const ['description', 'summary']);
  if (description.isNotEmpty) return description;

  final type = _pickString(space, const ['type']).toUpperCase();
  if (type == 'PRIVATE') return 'Direct exchange';
  return 'Shared space';
}

String _conversationMeta(Map<String, dynamic> space) {
  final parts = <String>[];
  final type = _pickString(space, const ['type']).toUpperCase();
  final visibility = _pickString(space, const ['visibility']);
  final memberCount = _pickInt(space, const ['memberCount', 'membersCount']);
  final threadCount = _pickInt(space, const ['threadCount', 'threadsCount']);

  if (type.isNotEmpty) {
    parts.add(type == 'PRIVATE' ? 'Private' : type.replaceAll('_', ' '));
  }
  if (visibility.isNotEmpty && type != 'PRIVATE') {
    parts.add(visibility.replaceAll('_', ' '));
  }
  if (threadCount > 0) {
    parts.add('Threads $threadCount');
  }
  if (memberCount > 0) {
    parts.add('Members $memberCount');
  }

  return parts.isEmpty ? '' : parts.join(' · ');
}

String _conversationBadge(Map<String, dynamic> space) {
  final type = _pickString(space, const ['type']).toUpperCase();
  return type == 'PRIVATE' ? 'Private' : 'Shared';
}

String _conversationAvatarUrl(Map<String, dynamic> space) {
  final direct = _pickString(space, const ['avatarUrl', 'imageUrl', 'photoUrl']);
  if (direct.isNotEmpty) return direct;

  for (final member in _extractMembers(space)) {
    final url = _pickString(member, const ['avatarUrl', 'imageUrl', 'photoUrl']);
    if (url.isNotEmpty) return url;
  }

  return '';
}

bool _conversationUnreadTone(Map<String, dynamic> space) {
  final unreadCount = _pickInt(space, const ['unreadCount', 'unreadMessages']);
  final hasUnread = _pickString(space, const ['hasUnread']).toLowerCase();
  return unreadCount > 0 || hasUnread == 'true';
}

bool _inviteIsActive(Map<String, dynamic> invite) {
  final status = _pickString(invite, const ['status']).toUpperCase();
  return status.isEmpty ||
      status == 'PENDING' ||
      status == 'SENT' ||
      status == 'CREATED' ||
      status == 'OPEN' ||
      status == 'OPENED';
}

int _liveSignalCount(List<Map<String, dynamic>> items) {
  return items.where((item) {
    final type = _pickString(item, const ['type']).toUpperCase();
    final data = _pickMap(item['data']);
    final live = _pickString(data, const ['realtimeType', 'communicationType'])
        .toUpperCase();
    final attention = _pickString(data, const ['attention']).toUpperCase();
    return (type == 'LIVE' || live == 'LIVE') && attention == 'INTERRUPT';
  }).length;
}

List<Map<String, dynamic>> _extractMembers(Map<String, dynamic> space) {
  const candidateKeys = [
    'members',
    'participants',
    'memberList',
    'participantList',
    'users',
  ];

  for (final key in candidateKeys) {
    final value = space[key];
    if (value is List) {
      return value
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
  }

  return const [];
}

Map<String, dynamic> _pickMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

String _spaceRoute(Map<String, dynamic> space) {
  final id = _pickString(space, const ['id', '_id', 'spaceId']);
  if (id.isEmpty) return '';

  final directThreadId = _pickString(space, const [
    'threadId',
    'mainThreadId',
    'defaultThreadId',
    'primaryThreadId',
  ]);

  if (directThreadId.isNotEmpty) {
    return '/me/correspondence/$id/thread/$directThreadId';
  }

  return '/me/correspondence/$id';
}

int _sortInvitesByActivity(
  Map<String, dynamic> a,
  Map<String, dynamic> b,
) {
  return _inviteSortDate(b).compareTo(_inviteSortDate(a));
}

DateTime _inviteSortDate(Map<String, dynamic> invite) {
  final raw = _pickString(invite, const [
    'updatedAt',
    'lastActivityAt',
    'createdAt',
    'sentAt',
  ]);
  if (raw.isEmpty) return DateTime.fromMillisecondsSinceEpoch(0);
  return DateTime.tryParse(raw)?.toUtc() ??
      DateTime.fromMillisecondsSinceEpoch(0);
}

int _sortSpacesByActivity(
  Map<String, dynamic> a,
  Map<String, dynamic> b,
) {
  final cmp = _spaceSortDate(b).compareTo(_spaceSortDate(a));
  if (cmp != 0) return cmp;
  // Stable tie-breaker: newer id lexicographically last, so compare b→a.
  final idA = (a['id'] ?? a['spaceId'] ?? '').toString();
  final idB = (b['id'] ?? b['spaceId'] ?? '').toString();
  return idB.compareTo(idA);
}

DateTime _spaceSortDate(Map<String, dynamic> space) {
  final raw = _pickString(space, const [
    'lastMessageAt',
    'lastActivityAt',
    'updatedAt',
    'createdAt',
  ]);
  if (raw.isEmpty) return DateTime.fromMillisecondsSinceEpoch(0);
  return DateTime.tryParse(raw)?.toUtc() ??
      DateTime.fromMillisecondsSinceEpoch(0);
}

String _pickString(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = (map[key] ?? '').toString().trim();
    if (value.isNotEmpty) return value;
  }
  return '';
}

int _pickInt(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value.trim());
      if (parsed != null) return parsed;
    }
  }
  return 0;
}
