import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_providers.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/ui/aura_text_block.dart';
import '../../correspondence/data/correspondence_identity.dart';
import '../../correspondence/data/spaces_repository.dart';
import '../../correspondence/data/threads_repository.dart';
import '../../realtime/application/realtime_providers.dart';
import '../../updates/providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DATA PROVIDER
// ─────────────────────────────────────────────────────────────────────────────

final _messagesDataProvider =
    FutureProvider.autoDispose<_MessagesData>((ref) async {
  final auth = ref.watch(authStatusProvider);
  if (auth != AuthStatus.authed) {
    return const _MessagesData(spaces: [], invites: []);
  }
  final repo = ref.watch(spacesRepositoryProvider);
  final results = await Future.wait([
    repo.listMySpaces(),
    repo.listInvites(),
  ]);
  return _MessagesData(
    spaces: List<Map<String, dynamic>>.from(results[0] as List),
    invites: List<Map<String, dynamic>>.from(results[1] as List),
  );
});

class _MessagesData {
  const _MessagesData({required this.spaces, required this.invites});
  final List<Map<String, dynamic>> spaces;
  final List<Map<String, dynamic>> invites;
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB ENUM
// ─────────────────────────────────────────────────────────────────────────────

enum _MessageTab { all, direct, spaces, invites }

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class MessagesHubScreen extends ConsumerStatefulWidget {
  const MessagesHubScreen({super.key});

  @override
  ConsumerState<MessagesHubScreen> createState() => _MessagesHubScreenState();
}

class _MessagesHubScreenState extends ConsumerState<MessagesHubScreen> {
  _MessageTab _tab = _MessageTab.all;
  Timer? _pollTimer;
  String _openingConversationId = '';

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(seconds: 120), (_) {
      if (!mounted) return;
      ref.invalidate(_messagesDataProvider);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStatusProvider);

    if (auth != AuthStatus.authed) {
      return _buildSignedOut(context);
    }

    ref.listen(
      realtimeControllerProvider.select((s) => s.lastSocketEvent),
      (prev, next) {
        if (next != null && next != prev && mounted) {
          ref.invalidate(_messagesDataProvider);
        }
      },
    );

    final dataAsync = ref.watch(_messagesDataProvider);
    final liveState = ref.watch(realtimeControllerProvider);
    final notifications = ref.watch(notificationsControllerProvider);

    return AuraScaffold(
      showHeader: false,
      body: RefreshIndicator(
        color: AuraSurface.accent,
        onRefresh: () async {
          ref.invalidate(_messagesDataProvider);
          await ref.read(_messagesDataProvider.future);
        },
        child: dataAsync.when(
          loading: _buildLoading,
          error: (error, _) => _buildError(error),
          data: (data) =>
              _buildContent(context, data, liveState, notifications),
        ),
      ),
    );
  }

  Widget _buildSignedOut(BuildContext context) {
    return AuraScaffold(
      showHeader: false,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AuraSpace.s16,
          AuraSpace.s20,
          AuraSpace.s16,
          AuraSpace.s32,
        ),
        children: [
          const _MessagesHeader(),
          const SizedBox(height: AuraSpace.s24),
          _SignInPrompt(onTap: () => context.go('/login')),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.s16,
        AuraSpace.s20,
        AuraSpace.s16,
        AuraSpace.s32,
      ),
      children: const [
        _MessagesHeader(),
        SizedBox(height: AuraSpace.s24),
        AuraLoadingState(message: 'Loading messages…'),
      ],
    );
  }

  Widget _buildError(Object error) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.s16,
        AuraSpace.s20,
        AuraSpace.s16,
        AuraSpace.s32,
      ),
      children: [
        const _MessagesHeader(),
        const SizedBox(height: AuraSpace.s24),
        AuraErrorState(
          title: 'Could not load messages',
          body: '$error',
          action: AuraSecondaryButton(
            label: 'Try again',
            icon: Icons.refresh_rounded,
            onPressed: () => ref.invalidate(_messagesDataProvider),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(
    BuildContext context,
    _MessagesData data,
    dynamic liveState,
    dynamic notifications,
  ) {
    final spaces = [...data.spaces]..sort(_sortByActivity);
    final invites = [...data.invites]..sort(_sortByActivity);
    final activeInvites = invites.where(_inviteIsActive).toList();

    final directSpaces = spaces
        .where(
          (s) =>
              _pickString(s, const ['type']).toUpperCase() == 'PRIVATE',
        )
        .toList();
    final sharedSpaces = spaces
        .where(
          (s) =>
              _pickString(s, const ['type']).toUpperCase() != 'PRIVATE',
        )
        .toList();

    final liveSessions = _extractLiveSessions(spaces);
    final unreadCount = (notifications?.unreadCount as int?) ?? 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.s16,
        AuraSpace.s20,
        AuraSpace.s16,
        AuraSpace.s32,
      ),
      children: [
        _MessagesHeader(
          unreadCount: unreadCount,
          inviteCount: activeInvites.length,
        ),
        const SizedBox(height: AuraSpace.s12),
        _DirectInboxLink(
          onTap: () => context.push('/messages/direct'),
        ),
        const SizedBox(height: AuraSpace.s16),
        _TabRow(
          tab: _tab,
          inviteCount: activeInvites.length,
          onTabChanged: (t) => setState(() => _tab = t),
        ),
        const SizedBox(height: AuraSpace.s16),
        _buildTabContent(
          context,
          allSpaces: spaces,
          directSpaces: directSpaces,
          sharedSpaces: sharedSpaces,
          activeInvites: activeInvites,
          liveSessions: liveSessions,
        ),
      ],
    );
  }

  Widget _buildTabContent(
    BuildContext context, {
    required List<Map<String, dynamic>> allSpaces,
    required List<Map<String, dynamic>> directSpaces,
    required List<Map<String, dynamic>> sharedSpaces,
    required List<Map<String, dynamic>> activeInvites,
    required List<_LiveSessionItem> liveSessions,
  }) {
    switch (_tab) {
      case _MessageTab.all:
        return _AllTab(
          spaces: allSpaces,
          activeInvites: activeInvites,
          liveSessions: liveSessions,
          openingId: _openingConversationId,
          onOpenConversation: _openConversation,
        );
      case _MessageTab.direct:
        return _ConversationListTab(
          spaces: directSpaces,
          emptyTitle: 'No direct messages',
          emptyBody:
              'Direct private threads will appear here once you start one.',
          openingId: _openingConversationId,
          onOpenConversation: _openConversation,
        );
      case _MessageTab.spaces:
        return _ConversationListTab(
          spaces: sharedSpaces,
          emptyTitle: 'No shared spaces',
          emptyBody: 'Spaces you create or join will appear here.',
          openingId: _openingConversationId,
          onOpenConversation: _openConversation,
        );
      case _MessageTab.invites:
        return _InvitesTab(invites: activeInvites);
    }
  }

  Future<void> _openConversation(Map<String, dynamic> space) async {
    final id = _pickString(space, const ['id', '_id', 'spaceId']);
    if (id.isEmpty) {
      context.push('/me/correspondence');
      return;
    }
    if (_openingConversationId.isNotEmpty) return;
    setState(() => _openingConversationId = id);

    try {
      final type = _pickString(space, const ['type']).toUpperCase();
      if (type == 'PRIVATE') {
        var threadId = _pickString(space, const [
          'threadId',
          'mainThreadId',
          'defaultThreadId',
          'primaryThreadId',
        ]);

        if (threadId.isEmpty) {
          final threads = await ref
              .read(threadsRepositoryProvider)
              .listThreads(spaceId: id);
          final visible =
              threads.where((t) => t['archived'] != true).toList();
          final target = visible.isNotEmpty
              ? visible.first
              : (threads.isNotEmpty ? threads.first : null);
          if (target != null) {
            threadId = _pickString(target, const ['id', 'threadId']);
          }
        }

        if (!mounted) return;
        if (threadId.isNotEmpty) {
          context.push('/me/correspondence/$id/thread/$threadId');
          return;
        }
      }

      if (!mounted) return;
      context.push('/me/correspondence/$id');
    } finally {
      if (mounted) setState(() => _openingConversationId = '');
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER
// ─────────────────────────────────────────────────────────────────────────────

class _MessagesHeader extends StatelessWidget {
  const _MessagesHeader({
    this.unreadCount = 0,
    this.inviteCount = 0,
  });

  final int unreadCount;
  final int inviteCount;

  @override
  Widget build(BuildContext context) {
    return AuraGradientHeader(
      title: 'Messages',
      subtitle: 'Direct conversations, shared spaces, and invitations.',
      trailing: Wrap(
        spacing: AuraSpace.s8,
        runSpacing: AuraSpace.s8,
        children: [
          if (unreadCount > 0)
            AuraStatusChip(
              label: '$unreadCount unread',
              backgroundColor: AuraSurface.accentSoft,
              textColor: AuraSurface.accentText,
            ),
          if (inviteCount > 0)
            AuraStatusChip(
              label:
                  '$inviteCount invite${inviteCount == 1 ? '' : 's'}',
              backgroundColor: AuraSurface.goodBg,
              textColor: AuraSurface.goodInk,
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB ROW
// ─────────────────────────────────────────────────────────────────────────────

class _TabRow extends StatelessWidget {
  const _TabRow({
    required this.tab,
    required this.inviteCount,
    required this.onTabChanged,
  });

  final _MessageTab tab;
  final int inviteCount;
  final ValueChanged<_MessageTab> onTabChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _TabPill(
            label: 'All',
            selected: tab == _MessageTab.all,
            onTap: () => onTabChanged(_MessageTab.all),
          ),
          const SizedBox(width: AuraSpace.s8),
          _TabPill(
            label: 'Direct',
            selected: tab == _MessageTab.direct,
            onTap: () => onTabChanged(_MessageTab.direct),
          ),
          const SizedBox(width: AuraSpace.s8),
          _TabPill(
            label: 'Spaces',
            selected: tab == _MessageTab.spaces,
            onTap: () => onTabChanged(_MessageTab.spaces),
          ),
          const SizedBox(width: AuraSpace.s8),
          _TabPill(
            label: inviteCount > 0 ? 'Invites ($inviteCount)' : 'Invites',
            selected: tab == _MessageTab.invites,
            badge: inviteCount > 0,
            onTap: () => onTabChanged(_MessageTab.invites),
          ),
        ],
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AuraSurface.accentText : AuraSurface.muted;
    final bg = selected ? AuraSurface.accentSoft : Colors.transparent;
    final border = selected
        ? AuraSurface.accent.withValues(alpha: 0.4)
        : AuraSurface.divider;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s12,
            vertical: AuraSpace.s8,
          ),
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(AuraRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: AuraText.small.copyWith(
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
              if (badge && !selected) ...[
                const SizedBox(width: AuraSpace.s4),
                const SizedBox(
                  width: 6,
                  height: 6,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AuraSurface.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ALL TAB
// ─────────────────────────────────────────────────────────────────────────────

class _AllTab extends StatelessWidget {
  const _AllTab({
    required this.spaces,
    required this.activeInvites,
    required this.liveSessions,
    required this.openingId,
    required this.onOpenConversation,
  });

  final List<Map<String, dynamic>> spaces;
  final List<Map<String, dynamic>> activeInvites;
  final List<_LiveSessionItem> liveSessions;
  final String openingId;
  final Future<void> Function(Map<String, dynamic>) onOpenConversation;

  @override
  Widget build(BuildContext context) {
    if (spaces.isEmpty && activeInvites.isEmpty && liveSessions.isEmpty) {
      return AuraEmptyState(
        title: 'Nothing here yet',
        body:
            'Start a conversation or create a space to see activity here.',
        icon: Icons.forum_outlined,
        action: AuraPrimaryButton(
          label: 'Start conversation',
          icon: Icons.chat_bubble_outline_rounded,
          onPressed: () =>
              context.push('/me/correspondence?start=private'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (liveSessions.isNotEmpty) ...[
          const _SectionLabel(label: 'LIVE NOW'),
          const SizedBox(height: AuraSpace.s8),
          _LiveSessionList(sessions: liveSessions),
          const SizedBox(height: AuraSpace.s20),
        ],
        if (activeInvites.isNotEmpty) ...[
          const _SectionLabel(label: 'PENDING INVITES'),
          const SizedBox(height: AuraSpace.s8),
          _InviteCardList(invites: activeInvites.take(3).toList()),
          const SizedBox(height: AuraSpace.s20),
        ],
        if (spaces.isNotEmpty) ...[
          const _SectionLabel(label: 'RECENT ACTIVITY'),
          const SizedBox(height: AuraSpace.s8),
          _ConversationCardList(
            spaces: spaces,
            openingId: openingId,
            onOpen: onOpenConversation,
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CONVERSATION LIST TAB
// ─────────────────────────────────────────────────────────────────────────────

class _ConversationListTab extends StatelessWidget {
  const _ConversationListTab({
    required this.spaces,
    required this.emptyTitle,
    required this.emptyBody,
    required this.openingId,
    required this.onOpenConversation,
  });

  final List<Map<String, dynamic>> spaces;
  final String emptyTitle;
  final String emptyBody;
  final String openingId;
  final Future<void> Function(Map<String, dynamic>) onOpenConversation;

  @override
  Widget build(BuildContext context) {
    if (spaces.isEmpty) {
      return AuraEmptyState(
        title: emptyTitle,
        body: emptyBody,
        icon: Icons.forum_outlined,
      );
    }

    return _ConversationCardList(
      spaces: spaces,
      openingId: openingId,
      onOpen: onOpenConversation,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INVITES TAB
// ─────────────────────────────────────────────────────────────────────────────

class _InvitesTab extends StatelessWidget {
  const _InvitesTab({required this.invites});

  final List<Map<String, dynamic>> invites;

  @override
  Widget build(BuildContext context) {
    if (invites.isEmpty) {
      return const AuraEmptyState(
        title: 'No pending invites',
        body:
            'Invitations to spaces and conversations will appear here.',
        icon: Icons.inbox_outlined,
      );
    }

    return _InviteCardList(invites: invites);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CONVERSATION CARD LIST
// ─────────────────────────────────────────────────────────────────────────────

class _ConversationCardList extends StatelessWidget {
  const _ConversationCardList({
    required this.spaces,
    required this.openingId,
    required this.onOpen,
  });

  final List<Map<String, dynamic>> spaces;
  final String openingId;
  final Future<void> Function(Map<String, dynamic>) onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(color: AuraSurface.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < spaces.length; i++) ...[
            _ConversationRow(
              space: spaces[i],
              opening:
                  openingId == _pickString(spaces[i], const ['id', '_id', 'spaceId']),
              onTap: () => onOpen(spaces[i]),
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
    );
  }
}

class _ConversationRow extends StatelessWidget {
  const _ConversationRow({
    required this.space,
    required this.opening,
    required this.onTap,
  });

  final Map<String, dynamic> space;
  final bool opening;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = _spaceTitle(space);
    final preview = _conversationPreview(space);
    final timestamp = _formatTimestamp(
      _pickString(space, const [
        'lastMessageAt',
        'lastActivityAt',
        'updatedAt',
        'createdAt',
      ]),
    );
    final avatarUrl = _conversationAvatarUrl(space);
    final unreadCount =
        _pickInt(space, const ['unreadCount', 'unreadMessages']);
    final hasUnread = unreadCount > 0 ||
        _pickString(space, const ['hasUnread']).toLowerCase() == 'true';
    final type = _pickString(space, const ['type']).toUpperCase();
    final isShared = type != 'PRIVATE';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AuraAvatar(name: title, imageUrl: avatarUrl, size: 44),
                  if (hasUnread)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AuraSurface.accent,
                          borderRadius:
                              BorderRadius.circular(AuraRadius.pill),
                          border: Border.all(
                            color: AuraSurface.card,
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          unreadCount > 99 ? '99+' : '$unreadCount',
                          style: AuraText.micro.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: AuraSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (isShared)
                          const Padding(
                            padding:
                                EdgeInsets.only(right: AuraSpace.s6),
                            child: Icon(
                              Icons.groups_outlined,
                              size: 14,
                              color: AuraSurface.faint,
                            ),
                          ),
                        Expanded(
                          child: AuraTextBlock(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AuraText.body.copyWith(
                              fontWeight: hasUnread
                                  ? FontWeight.w800
                                  : FontWeight.w700,
                            ),
                          ),
                        ),
                        if (timestamp.isNotEmpty) ...[
                          const SizedBox(width: AuraSpace.s8),
                          Text(
                            timestamp,
                            style: AuraText.small.copyWith(
                              color: hasUnread
                                  ? AuraSurface.accentText
                                  : AuraSurface.muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (preview.isNotEmpty) ...[
                      const SizedBox(height: AuraSpace.s4),
                      AuraTextBlock(
                        preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AuraText.small.copyWith(
                          color: hasUnread
                              ? AuraSurface.ink
                              : AuraSurface.muted,
                          fontWeight: hasUnread
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AuraSpace.s8),
              opening
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AuraSurface.accent,
                      ),
                    )
                  : Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: hasUnread
                          ? AuraSurface.accentText
                          : AuraSurface.faint,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INVITE CARD LIST
// ─────────────────────────────────────────────────────────────────────────────

class _InviteCardList extends StatelessWidget {
  const _InviteCardList({required this.invites});

  final List<Map<String, dynamic>> invites;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(color: AuraSurface.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < invites.length; i++) ...[
            _InviteRow(invite: invites[i]),
            if (i != invites.length - 1)
              const Divider(
                height: 1,
                thickness: 1,
                color: AuraSurface.divider,
              ),
          ],
        ],
      ),
    );
  }
}

class _InviteRow extends StatelessWidget {
  const _InviteRow({required this.invite});

  final Map<String, dynamic> invite;

  @override
  Widget build(BuildContext context) {
    final title = CorrespondenceIdentity.inviteTitle(invite);
    final subtitle = CorrespondenceIdentity.inviteSubtitle(invite);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: () {
          final route =
              CorrespondenceIdentity.inviteDestinationRoute(invite);
          if (route.isEmpty) return;
          context.push(route);
        },
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AuraSurface.accentSoft,
                  borderRadius:
                      BorderRadius.circular(AuraRadius.r10),
                  border: Border.all(
                    color: AuraSurface.accent.withValues(alpha: 0.25),
                  ),
                ),
                child: const Icon(
                  Icons.mail_outline_rounded,
                  size: 18,
                  color: AuraSurface.accentText,
                ),
              ),
              const SizedBox(width: AuraSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AuraText.body.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: AuraSpace.s2),
                      Text(
                        subtitle,
                        style: AuraText.small.copyWith(
                          color: AuraSurface.muted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AuraSurface.faint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LIVE SESSION LIST
// ─────────────────────────────────────────────────────────────────────────────

class _LiveSessionItem {
  const _LiveSessionItem({
    required this.id,
    required this.title,
    required this.sessionId,
    required this.spaceId,
    required this.threadId,
  });

  final String id;
  final String title;
  final String sessionId;
  final String spaceId;
  final String threadId;
}

class _LiveSessionList extends StatelessWidget {
  const _LiveSessionList({required this.sessions});

  final List<_LiveSessionItem> sessions;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(
          color: AuraSurface.warnInk.withValues(alpha: 0.3),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < sessions.length; i++) ...[
            _LiveSessionRow(session: sessions[i]),
            if (i != sessions.length - 1)
              const Divider(
                height: 1,
                thickness: 1,
                color: AuraSurface.divider,
              ),
          ],
        ],
      ),
    );
  }
}

class _LiveSessionRow extends ConsumerWidget {
  const _LiveSessionRow({required this.session});

  final _LiveSessionItem session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: () {
          if (session.sessionId.isNotEmpty) {
            context.push('/realtime/${session.sessionId}?action=join');
          }
        },
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AuraSurface.warnBg,
                  borderRadius:
                      BorderRadius.circular(AuraRadius.r10),
                ),
                child: const Icon(
                  Icons.videocam_rounded,
                  size: 18,
                  color: AuraSurface.warnInk,
                ),
              ),
              const SizedBox(width: AuraSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.title,
                      style: AuraText.body.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Live now',
                      style: AuraText.small.copyWith(
                        color: AuraSurface.warnInk,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AuraSpace.s10,
                  vertical: AuraSpace.s6,
                ),
                decoration: BoxDecoration(
                  color: AuraSurface.warnBg,
                  borderRadius:
                      BorderRadius.circular(AuraRadius.pill),
                ),
                child: Text(
                  'Join',
                  style: AuraText.small.copyWith(
                    color: AuraSurface.warnInk,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION LABEL
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AuraText.micro.copyWith(
        color: AuraSurface.faint,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SIGN-IN PROMPT
// ─────────────────────────────────────────────────────────────────────────────

class _SignInPrompt extends StatelessWidget {
  const _SignInPrompt({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AuraSpace.s20),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(color: AuraSurface.divider),
      ),
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
            onPressed: onTap,
            icon: Icons.login_rounded,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

List<_LiveSessionItem> _extractLiveSessions(
  List<Map<String, dynamic>> spaces,
) {
  final sessions = <_LiveSessionItem>[];
  for (final space in spaces) {
    final sessionId = _pickString(space, const [
      'liveSessionId',
      'activeSessionId',
      'currentSessionId',
    ]);
    if (sessionId.isEmpty) continue;
    final id = _pickString(space, const ['id', '_id', 'spaceId']);
    final threadId = _pickString(space, const [
      'threadId',
      'mainThreadId',
      'defaultThreadId',
    ]);
    sessions.add(
      _LiveSessionItem(
        id: id,
        title: _spaceTitle(space),
        sessionId: sessionId,
        spaceId: id,
        threadId: threadId,
      ),
    );
  }
  return sessions;
}

String _spaceTitle(Map<String, dynamic> space) {
  final direct = _pickString(space, const ['name', 'title']);
  if (direct.isNotEmpty) return direct;
  final members = _extractMembers(space);
  final names = members
      .map(
        (m) => _pickString(m, const ['displayName', 'name', 'handle']),
      )
      .where((v) => v.isNotEmpty)
      .take(2)
      .toList();
  if (names.isNotEmpty) return names.join(', ');
  return 'Conversation';
}

String _conversationPreview(Map<String, dynamic> space) {
  final desc = _pickString(space, const [
    'description',
    'summary',
    'lastMessage',
    'lastMessagePreview',
  ]);
  if (desc.isNotEmpty) return desc;
  final type = _pickString(space, const ['type']).toUpperCase();
  return type == 'PRIVATE' ? 'Direct exchange' : 'Shared space';
}

String _conversationAvatarUrl(Map<String, dynamic> space) {
  final direct = _pickString(
    space,
    const ['avatarUrl', 'imageUrl', 'photoUrl'],
  );
  if (direct.isNotEmpty) return direct;
  for (final m in _extractMembers(space)) {
    final url = _pickString(m, const ['avatarUrl', 'imageUrl', 'photoUrl']);
    if (url.isNotEmpty) return url;
  }
  return '';
}

bool _inviteIsActive(Map<String, dynamic> invite) {
  final status =
      _pickString(invite, const ['status']).toUpperCase();
  return status.isEmpty ||
      status == 'PENDING' ||
      status == 'SENT' ||
      status == 'CREATED' ||
      status == 'OPEN' ||
      status == 'OPENED';
}

int _sortByActivity(
  Map<String, dynamic> a,
  Map<String, dynamic> b,
) {
  return _sortDate(b).compareTo(_sortDate(a));
}

DateTime _sortDate(Map<String, dynamic> map) {
  final raw = _pickString(map, const [
    'lastMessageAt',
    'lastActivityAt',
    'updatedAt',
    'createdAt',
    'sentAt',
  ]);
  if (raw.isEmpty) return DateTime.fromMillisecondsSinceEpoch(0);
  return DateTime.tryParse(raw)?.toUtc() ??
      DateTime.fromMillisecondsSinceEpoch(0);
}

String _formatTimestamp(String raw) {
  if (raw.trim().isEmpty) return '';
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return '';
  final local = parsed.toLocal();
  final now = DateTime.now();
  final diff = now.difference(local);
  if (diff.inSeconds < 45) return 'Now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24 && now.day == local.day) {
    return '${diff.inHours}h';
  }
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(local.year, local.month, local.day);
  final dayDiff = today.difference(target).inDays;
  if (dayDiff == 1) return 'Yesterday';
  if (dayDiff < 7) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[local.weekday - 1];
  }
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[local.month - 1]} ${local.day}';
}

List<Map<String, dynamic>> _extractMembers(
  Map<String, dynamic> space,
) {
  for (final key in const [
    'members',
    'participants',
    'memberList',
    'users',
  ]) {
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

/// Small entry point to the new actor-aware direct inbox. Lives ABOVE the
/// existing tab system — Direct is an *addition* to the existing
/// conversations / spaces / invites system, not a replacement.
class _DirectInboxLink extends StatelessWidget {
  const _DirectInboxLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AuraRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.s14,
          vertical: AuraSpace.s12,
        ),
        decoration: BoxDecoration(
          color: AuraSurface.accentSoft,
          borderRadius: BorderRadius.circular(AuraRadius.md),
          border: Border.all(color: AuraSurface.divider),
        ),
        child: Row(
          children: [
            const Icon(Icons.forum_outlined,
                size: 18, color: AuraSurface.accentText),
            const SizedBox(width: AuraSpace.s10),
            Expanded(
              child: Text(
                'Direct messages',
                style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: AuraSurface.muted),
          ],
        ),
      ),
    );
  }
}
