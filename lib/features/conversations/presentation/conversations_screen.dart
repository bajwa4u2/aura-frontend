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
import '../../correspondence/data/spaces_repository.dart';
import '../../correspondence/data/threads_repository.dart';


final _conversationSpacesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final auth = ref.watch(authStatusProvider);

      if (auth != AuthStatus.authed) {
        return [];
      }

      final repo = ref.watch(spacesRepositoryProvider);
      return repo.listMySpaces();
    });

enum _ConversationFilter { all, private, spaces }

class ConversationsScreen extends ConsumerStatefulWidget {
  const ConversationsScreen({super.key});

  @override
  ConsumerState<ConversationsScreen> createState() =>
      _ConversationsScreenState();
}

class _ConversationsScreenState extends ConsumerState<ConversationsScreen> {
  _ConversationFilter _filter = _ConversationFilter.all;
  Timer? _pollTimer;
  String _openingConversationId = '';
  String _handledThreadId = '';

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      ref.invalidate(_conversationSpacesProvider);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _openConversation(_ConversationItem item) async {
    if (_openingConversationId.isNotEmpty) return;

    if (item.id.isEmpty) {
      context.push('/me/correspondence');
      return;
    }

    setState(() {
      _openingConversationId = item.id;
    });

    try {
      if (item.isPrivate) {
        var threadId = item.directThreadId;

        if (threadId.isEmpty) {
          final threads = await ref
              .read(threadsRepositoryProvider)
              .listThreads(spaceId: item.id);

          final visibleThreads = threads
              .where((thread) => thread['archived'] != true)
              .toList(growable: false);

          final target = visibleThreads.isNotEmpty
              ? visibleThreads.first
              : (threads.isNotEmpty ? threads.first : null);

          if (target != null) {
            threadId = _pickString(target, const ['id', 'threadId']);
          }
        }

        if (!mounted) return;

        if (threadId.isNotEmpty) {
          context.push('/me/correspondence/${item.id}/thread/$threadId');
          return;
        }
      }

      if (!mounted) return;
      context.push(item.route);
    } finally {
      if (mounted) {
        setState(() {
          _openingConversationId = '';
        });
      }
    }
  }

  Future<void> _openRequestedThreadIfNeeded(
    List<Map<String, dynamic>> spaces,
  ) async {
    final uri = GoRouterState.of(context).uri;
    final requestedThreadId = (uri.queryParameters['threadId'] ?? '').trim();

    if (requestedThreadId.isEmpty ||
        _handledThreadId == requestedThreadId ||
        _openingConversationId.isNotEmpty) {
      return;
    }

    _handledThreadId = requestedThreadId;

    try {
      final thread = await ref
          .read(threadsRepositoryProvider)
          .getThread(requestedThreadId);
      if (!mounted) return;

      final spaceId = _pickString(thread, const ['spaceId', 'space_id']);
      if (spaceId.isNotEmpty) {
        context.push('/me/correspondence/$spaceId/thread/$requestedThreadId');
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('That conversation is no longer available.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That conversation could not be opened.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStatusProvider);

    if (auth != AuthStatus.authed) {
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
            const _ConversationsHeader(
              subtitle: 'Ongoing direct threads and shared rooms.',
            ),
            const SizedBox(height: AuraSpace.s24),
            _StateCard(
              title: 'You are signed out',
              body:
                  'Your private conversations and shared spaces will appear here after you sign in.',
              primaryLabel: 'Sign in',
              onPrimary: () => context.go('/login'),
            ),
          ],
        ),
      );
    }

    final spacesAsync = ref.watch(_conversationSpacesProvider);

    return AuraScaffold(
      showHeader: false,
      body: RefreshIndicator(
        color: AuraSurface.accent,
        onRefresh: () async {
          ref.invalidate(_conversationSpacesProvider);
          await ref.read(_conversationSpacesProvider.future);
        },
        child: spacesAsync.when(
          loading: () => ListView(
            padding: const EdgeInsets.fromLTRB(
              AuraSpace.s16,
              AuraSpace.s20,
              AuraSpace.s16,
              AuraSpace.s32,
            ),
            children: const [
              _ConversationsHeader(subtitle: 'Loading active conversations…'),
              SizedBox(height: AuraSpace.s24),
              AuraLoadingState(message: 'Loading your inbox…'),
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
              const _ConversationsHeader(
                subtitle: 'Could not load your messages.',
              ),
              const SizedBox(height: AuraSpace.s24),
              AuraErrorState(
                title: 'Something went wrong',
                body: '$error',
                action: AuraSecondaryButton(
                  label: 'Try again',
                  onPressed: () => ref.invalidate(_conversationSpacesProvider),
                  icon: Icons.refresh_rounded,
                ),
              ),
            ],
          ),
          data: (spaces) {
            final normalized = [...spaces]..sort(_sortSpacesByActivity);

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              unawaited(_openRequestedThreadIfNeeded(normalized));
            });
            final visible = _filterSpaces(normalized, _filter);
            final items = _buildConversationItems(visible);

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AuraSpace.s16,
                AuraSpace.s20,
                AuraSpace.s16,
                AuraSpace.s32,
              ),
              children: [
                const _ConversationsHeader(
                  subtitle:
                      'Direct threads and shared rooms already in motion.',
                ),
                const SizedBox(height: AuraSpace.s20),
                const _ConversationQuickActions(),
                const SizedBox(height: AuraSpace.s16),
                _FilterRow(
                  filter: _filter,
                  onFilterChanged: (value) {
                    setState(() => _filter = value);
                  },
                ),
                const SizedBox(height: AuraSpace.s16),
                if (items.isEmpty)
                  _StateCard(
                    title: _emptyTitleForFilter(_filter),
                    body: _emptyBodyForFilter(_filter),
                    primaryLabel: 'Open messages',
                    onPrimary: () => context.go('/me/correspondence'),
                  )
                else
                  _ConversationList(
                    items: items,
                    openingConversationId: _openingConversationId,
                    onOpenConversation: _openConversation,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ConversationsHeader extends StatelessWidget {
  const _ConversationsHeader({required this.subtitle});

  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Conversations', style: AuraText.headline),
        const SizedBox(height: AuraSpace.s6),
        Text(
          subtitle,
          style: AuraText.body.copyWith(color: AuraSurface.muted, height: 1.5),
        ),
      ],
    );
  }
}

class _ConversationQuickActions extends StatelessWidget {
  const _ConversationQuickActions();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: AuraSpace.s10,
      runSpacing: AuraSpace.s10,
      children: [
        _QuickActionCard(
          label: 'New conversation',
          subtitle: 'Start direct exchange',
          icon: Icons.chat_bubble_outline,
          route: '/me/correspondence?start=private',
        ),
        _QuickActionCard(
          label: 'Create space',
          subtitle: 'Open a shared room',
          icon: Icons.groups_outlined,
          route: '/me/correspondence?start=space',
        ),
        _QuickActionCard(
          label: 'Invitations',
          subtitle: 'Manage entry paths',
          icon: Icons.inbox_outlined,
          route: '/me/invitations',
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.route,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final String route;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 200, maxWidth: 280),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => context.push(route),
            borderRadius: BorderRadius.circular(AuraRadius.card),
            child: Container(
              padding: const EdgeInsets.all(AuraSpace.s12),
              decoration: BoxDecoration(
                color: AuraSurface.card,
                borderRadius: BorderRadius.circular(AuraRadius.card),
                border: Border.all(color: AuraSurface.divider),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AuraSurface.accentSoft,
                      borderRadius: BorderRadius.circular(AuraRadius.r10),
                      border: Border.all(
                        color: AuraSurface.accent.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Icon(icon, size: 18, color: AuraSurface.accentText),
                  ),
                  const SizedBox(width: AuraSpace.s10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: AuraText.small.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AuraSpace.s2),
                        Text(
                          subtitle,
                          style: AuraText.small.copyWith(
                            color: AuraSurface.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.filter, required this.onFilterChanged});

  final _ConversationFilter filter;
  final ValueChanged<_ConversationFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AuraSpace.s8,
      runSpacing: AuraSpace.s8,
      children: [
        _FilterPill(
          label: 'All',
          selected: filter == _ConversationFilter.all,
          onTap: () => onFilterChanged(_ConversationFilter.all),
        ),
        _FilterPill(
          label: 'Direct',
          selected: filter == _ConversationFilter.private,
          onTap: () => onFilterChanged(_ConversationFilter.private),
        ),
        _FilterPill(
          label: 'Shared rooms',
          selected: filter == _ConversationFilter.spaces,
          onTap: () => onFilterChanged(_ConversationFilter.spaces),
        ),
      ],
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AuraSurface.accentText : AuraSurface.muted;
    final background = selected ? AuraSurface.accentSoft : Colors.transparent;
    final borderColor = selected
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
            color: background,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(AuraRadius.pill),
          ),
          child: Text(
            label,
            style: AuraText.small.copyWith(
              fontWeight: FontWeight.w700,
              color: foreground,
            ),
          ),
        ),
      ),
    );
  }
}

class _ConversationList extends StatelessWidget {
  const _ConversationList({
    required this.items,
    required this.openingConversationId,
    required this.onOpenConversation,
  });

  final List<_ConversationItem> items;
  final String openingConversationId;
  final ValueChanged<_ConversationItem> onOpenConversation;

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
          for (var i = 0; i < items.length; i++) ...[
            _ConversationRow(
              item: items[i],
              opening: openingConversationId == items[i].id,
              onTap: () => onOpenConversation(items[i]),
            ),
            if (i != items.length - 1)
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
    required this.item,
    required this.opening,
    required this.onTap,
  });

  final _ConversationItem item;
  final bool opening;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasUnread = item.unreadCount > 0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AuraAvatar(
                    name: item.title,
                    imageUrl: item.avatarUrl,
                    size: 44,
                  ),
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
                          borderRadius: BorderRadius.circular(AuraRadius.pill),
                          border: Border.all(
                            color: AuraSurface.card,
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          item.unreadCount > 99
                              ? '99+'
                              : '${item.unreadCount}',
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
                        Expanded(
                          child: AuraTextBlock(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AuraText.body.copyWith(
                              fontWeight: hasUnread
                                  ? FontWeight.w800
                                  : FontWeight.w700,
                            ),
                          ),
                        ),
                        if (item.timestamp.isNotEmpty) ...[
                          const SizedBox(width: AuraSpace.s10),
                          Text(
                            item.timestamp,
                            style: AuraText.small.copyWith(
                              fontWeight: FontWeight.w600,
                              color: hasUnread
                                  ? AuraSurface.accentText
                                  : AuraSurface.muted,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (item.preview.isNotEmpty) ...[
                      const SizedBox(height: AuraSpace.s4),
                      AuraTextBlock(
                        item.preview,
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

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.title,
    required this.body,
    this.primaryLabel,
    this.onPrimary,
  });

  final String title;
  final String body;
  final String? primaryLabel;
  final VoidCallback? onPrimary;

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
          Text(
            title,
            style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AuraSpace.s8),
          Text(
            body,
            style: AuraText.small.copyWith(
              color: AuraSurface.muted,
              height: 1.45,
            ),
          ),
          if (primaryLabel != null && onPrimary != null) ...[
            const SizedBox(height: AuraSpace.s16),
            AuraPrimaryButton(
              label: primaryLabel!,
              onPressed: onPrimary!,
              icon: Icons.arrow_forward_rounded,
            ),
          ],
        ],
      ),
    );
  }
}

class _ConversationItem {
  const _ConversationItem({
    required this.id,
    required this.title,
    required this.preview,
    required this.meta,
    required this.route,
    required this.badge,
    required this.icon,
    required this.timestamp,
    required this.sortDate,
    required this.isPrivate,
    required this.directThreadId,
    this.unreadCount = 0,
    this.avatarUrl = '',
  });

  final String id;
  final String title;
  final String preview;
  final String meta;
  final String route;
  final String badge;
  final IconData icon;
  final String timestamp;
  final DateTime sortDate;
  final bool isPrivate;
  final String directThreadId;
  final int unreadCount;
  final String avatarUrl;
}

List<Map<String, dynamic>> _filterSpaces(
  List<Map<String, dynamic>> spaces,
  _ConversationFilter filter,
) {
  switch (filter) {
    case _ConversationFilter.private:
      return spaces
          .where(
            (space) =>
                _pickString(space, const ['type']).toUpperCase() == 'PRIVATE',
          )
          .toList();
    case _ConversationFilter.spaces:
      return spaces
          .where(
            (space) =>
                _pickString(space, const ['type']).toUpperCase() != 'PRIVATE',
          )
          .toList();
    case _ConversationFilter.all:
      return spaces;
  }
}

List<_ConversationItem> _buildConversationItems(
  List<Map<String, dynamic>> spaces,
) {
  final items = spaces.map((space) {
    final id = _pickString(space, const ['id', '_id', 'spaceId']);
    final title = _pickTitle(space);
    final description = _pickString(space, const ['description', 'summary']);
    final type = _pickString(space, const ['type']).toUpperCase();
    final visibility = _pickString(space, const ['visibility']);
    final memberCount = _pickInt(space, const ['memberCount', 'membersCount']);
    final threadCount = _pickInt(space, const ['threadCount', 'threadsCount']);
    final updatedRaw = _pickString(space, const [
      'updatedAt',
      'lastActivityAt',
      'lastMessageAt',
      'createdAt',
    ]);
    final updatedAt = _bestDateForSort(space);

    final directThreadId = _pickString(space, const [
      'threadId',
      'mainThreadId',
      'defaultThreadId',
      'primaryThreadId',
    ]);

    final preview = description.isNotEmpty
        ? description
        : type == 'PRIVATE'
        ? 'Direct exchange'
        : 'Shared space';

    final metaParts = <String>[];

    if (type.isNotEmpty) {
      metaParts.add(type == 'PRIVATE' ? 'Private' : type.replaceAll('_', ' '));
    }

    if (visibility.isNotEmpty && type != 'PRIVATE') {
      metaParts.add(visibility.replaceAll('_', ' '));
    }

    if (threadCount > 0) {
      metaParts.add('Threads $threadCount');
    }

    if (memberCount > 0) {
      metaParts.add('Members $memberCount');
    }

    final unreadCount = _pickInt(space, const ['unreadCount', 'unreadMessages']);
    final avatarDirect = _pickString(space, const ['avatarUrl', 'imageUrl', 'photoUrl']);
    final avatarUrl = avatarDirect.isNotEmpty
        ? avatarDirect
        : () {
            for (final m in _extractMembers(space)) {
              final u = _pickString(m, const ['avatarUrl', 'imageUrl', 'photoUrl']);
              if (u.isNotEmpty) return u;
            }
            return '';
          }();

    return _ConversationItem(
      id: id,
      title: title,
      preview: preview,
      meta: metaParts.join(' · '),
      route: id.isEmpty ? '/me/correspondence' : '/me/correspondence/$id',
      badge: type == 'PRIVATE' ? 'PR' : 'SP',
      icon: type == 'PRIVATE' ? Icons.person_outline : Icons.forum_outlined,
      timestamp: _formatTimestamp(updatedRaw),
      sortDate: updatedAt,
      isPrivate: type == 'PRIVATE',
      directThreadId: directThreadId,
      unreadCount: unreadCount,
      avatarUrl: avatarUrl,
    );
  }).toList();

  items.sort((a, b) => b.sortDate.compareTo(a.sortDate));
  return items;
}

String _pickTitle(Map<String, dynamic> space) {
  final explicit = _pickString(space, const ['name', 'title']);
  if (explicit.isNotEmpty) return explicit;

  final members = _extractMembers(space);
  if (members.isNotEmpty) {
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
        .toList();

    if (names.isNotEmpty) {
      return names.join(', ');
    }
  }

  return 'Untitled conversation';
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

int _sortSpacesByActivity(Map<String, dynamic> a, Map<String, dynamic> b) {
  final aValue = _bestDateForSort(a);
  final bValue = _bestDateForSort(b);
  return bValue.compareTo(aValue);
}

DateTime _bestDateForSort(Map<String, dynamic> map) {
  final raw = _pickString(map, const [
    'updatedAt',
    'lastActivityAt',
    'lastMessageAt',
    'createdAt',
  ]);

  if (raw.isEmpty) {
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  return DateTime.tryParse(raw)?.toUtc() ??
      DateTime.fromMillisecondsSinceEpoch(0);
}

String _formatTimestamp(String raw) {
  if (raw.trim().isEmpty) return '';

  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;

  final local = parsed.toLocal();
  final now = DateTime.now();
  final diff = now.difference(local);

  if (diff.inSeconds < 45) return 'Now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24 &&
      now.day == local.day &&
      now.month == local.month &&
      now.year == local.year) {
    return '${diff.inHours}h';
  }

  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(local.year, local.month, local.day);
  final dayDiff = today.difference(target).inDays;

  if (dayDiff == 1) return 'Yesterday';

  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  if (dayDiff >= 0 && dayDiff < 7) {
    return weekdays[local.weekday - 1];
  }

  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  return '${months[local.month - 1]} ${local.day}';
}

String _emptyTitleForFilter(_ConversationFilter filter) {
  switch (filter) {
    case _ConversationFilter.all:
      return 'No conversations yet';
    case _ConversationFilter.private:
      return 'No private conversations';
    case _ConversationFilter.spaces:
      return 'No shared spaces yet';
  }
}

String _emptyBodyForFilter(_ConversationFilter filter) {
  switch (filter) {
    case _ConversationFilter.all:
      return 'Start a conversation, open a space, or wait for the first reply. Ongoing exchange will appear here.';
    case _ConversationFilter.private:
      return 'Direct threads will appear here once you start one or someone writes to you.';
    case _ConversationFilter.spaces:
      return 'Shared spaces will appear here once you create one or join one.';
  }
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
