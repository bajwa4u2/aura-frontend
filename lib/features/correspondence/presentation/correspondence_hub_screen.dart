import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_providers.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';
import '../data/spaces_repository.dart';

final _correspondenceSpacesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final auth = ref.watch(authStatusProvider);

  if (auth != AuthStatus.authed) {
    return [];
  }

  final repo = ref.watch(spacesRepositoryProvider);
  return repo.listMySpaces();
});

enum _HubFilter {
  all,
  private,
  spaces,
}

class CorrespondenceHubScreen extends ConsumerStatefulWidget {
  const CorrespondenceHubScreen({super.key});

  @override
  ConsumerState<CorrespondenceHubScreen> createState() =>
      _CorrespondenceHubScreenState();
}

class _CorrespondenceHubScreenState
    extends ConsumerState<CorrespondenceHubScreen> {
  _HubFilter _filter = _HubFilter.all;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStatusProvider);

    if (auth != AuthStatus.authed) {
      return AuraScaffold(
        title: 'Correspondence',
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            const _PageIntro(
              title: 'Correspondence',
              body: 'Sign in to open your correspondence.',
            ),
            const SizedBox(height: AuraSpace.s18),
            _StateBlock(
              title: 'You are signed out',
              body: 'Private conversations and shared spaces appear here.',
              actionLabel: 'Sign in',
              onAction: () => context.go('/login'),
            ),
          ],
        ),
      );
    }

    final spacesAsync = ref.watch(_correspondenceSpacesProvider);

    return AuraScaffold(
      title: 'Correspondence',
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(_correspondenceSpacesProvider);
          await ref.read(_correspondenceSpacesProvider.future);
        },
        child: spacesAsync.when(
          loading: () => ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: const [
              _PageIntro(
                title: 'Correspondence',
                body: 'Loading active correspondence.',
              ),
              SizedBox(height: AuraSpace.s16),
              _ToolbarSkeleton(),
              SizedBox(height: AuraSpace.s16),
              _InboxSkeleton(),
            ],
          ),
          error: (error, _) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              const _PageIntro(
                title: 'Correspondence',
                body: 'Could not load correspondence.',
              ),
              const SizedBox(height: AuraSpace.s18),
              _StateBlock(
                title: 'Something went wrong',
                body: '$error',
                actionLabel: 'Try again',
                onAction: () => ref.invalidate(_correspondenceSpacesProvider),
              ),
            ],
          ),
          data: (spaces) {
            final sortedSpaces = [...spaces]..sort(_sortSpacesByRecency);
            final visibleSpaces = _filterSpaces(sortedSpaces, _filter);
            final items = _buildHubItems(visibleSpaces);

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                const _PageIntro(
                  title: 'Correspondence',
                  body:
                      'Recent conversation across private exchange and shared spaces.',
                ),
                const SizedBox(height: AuraSpace.s14),
                _ToolbarRow(
                  filter: _filter,
                  onFilterChanged: (value) {
                    setState(() {
                      _filter = value;
                    });
                  },
                  onNewConversation: () =>
                      context.go('/me/correspondence/create/conversation'),
                  onCreateSpace: () =>
                      context.go('/me/correspondence/create/space'),
                ),
                const SizedBox(height: AuraSpace.s16),
                if (items.isEmpty)
                  _StateBlock(
                    title: _emptyTitleForFilter(_filter),
                    body: _emptyBodyForFilter(_filter),
                    actionLabel: _filter == _HubFilter.private
                        ? 'New conversation'
                        : 'Create space',
                    onAction: () {
                      if (_filter == _HubFilter.private) {
                        context.go('/me/correspondence/create/conversation');
                        return;
                      }
                      context.go('/me/correspondence/create/space');
                    },
                  )
                else
                  _InboxList(items: items),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PageIntro extends StatelessWidget {
  const _PageIntro({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AuraText.title),
        if (body.trim().isNotEmpty) ...[
          const SizedBox(height: AuraSpace.s6),
          Text(body, style: AuraText.body),
        ],
      ],
    );
  }
}

class _ToolbarRow extends StatelessWidget {
  const _ToolbarRow({
    required this.filter,
    required this.onFilterChanged,
    required this.onNewConversation,
    required this.onCreateSpace,
  });

  final _HubFilter filter;
  final ValueChanged<_HubFilter> onFilterChanged;
  final VoidCallback onNewConversation;
  final VoidCallback onCreateSpace;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AuraSpace.s8,
          runSpacing: AuraSpace.s8,
          children: [
            _FilterPill(
              label: 'All',
              selected: filter == _HubFilter.all,
              onTap: () => onFilterChanged(_HubFilter.all),
            ),
            _FilterPill(
              label: 'Private',
              selected: filter == _HubFilter.private,
              onTap: () => onFilterChanged(_HubFilter.private),
            ),
            _FilterPill(
              label: 'Spaces',
              selected: filter == _HubFilter.spaces,
              onTap: () => onFilterChanged(_HubFilter.spaces),
            ),
          ],
        ),
        const SizedBox(height: AuraSpace.s10),
        Wrap(
          spacing: AuraSpace.s8,
          runSpacing: AuraSpace.s8,
          children: [
            OutlinedButton.icon(
              onPressed: onNewConversation,
              icon: const Icon(Icons.chat_bubble_outline, size: 18),
              label: const Text('New conversation'),
            ),
            OutlinedButton.icon(
              onPressed: onCreateSpace,
              icon: const Icon(Icons.groups_outlined, size: 18),
              label: const Text('Create space'),
            ),
          ],
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
    final borderColor = selected ? Colors.black : Colors.black12;
    final backgroundColor = selected ? Colors.black : Colors.transparent;
    final textColor = selected ? Colors.white : Colors.black87;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.s12,
          vertical: AuraSpace.s8,
        ),
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: AuraText.small.copyWith(
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
      ),
    );
  }
}

class _InboxList extends StatelessWidget {
  const _InboxList({
    required this.items,
  });

  final List<_HubItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            _InboxRow(item: items[i]),
            if (i != items.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _InboxRow extends StatelessWidget {
  const _InboxRow({
    required this.item,
  });

  final _HubItem item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.go(item.route),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LeadingBadge(
              label: item.badge,
              icon: item.icon,
            ),
            const SizedBox(width: AuraSpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AuraText.body.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (item.timestamp.isNotEmpty) ...[
                        const SizedBox(width: AuraSpace.s10),
                        Text(
                          item.timestamp,
                          style: AuraText.small.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (item.preview.isNotEmpty) ...[
                    const SizedBox(height: AuraSpace.s4),
                    Text(
                      item.preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AuraText.small,
                    ),
                  ],
                  if (item.meta.isNotEmpty) ...[
                    const SizedBox(height: AuraSpace.s8),
                    Text(
                      item.meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AuraText.small.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AuraSpace.s10),
            const Icon(Icons.chevron_right, size: 18),
          ],
        ),
      ),
    );
  }
}

class _LeadingBadge extends StatelessWidget {
  const _LeadingBadge({
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: label.isNotEmpty
          ? Text(
              label,
              style: AuraText.small.copyWith(
                fontWeight: FontWeight.w700,
              ),
            )
          : Icon(icon, size: 18),
    );
  }
}

class _StateBlock extends StatelessWidget {
  const _StateBlock({
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AuraSpace.s6),
          Text(body, style: AuraText.small),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AuraSpace.s12),
            OutlinedButton(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class _ToolbarSkeleton extends StatelessWidget {
  const _ToolbarSkeleton();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AuraSpace.s8,
      runSpacing: AuraSpace.s8,
      children: const [
        _SkeletonPill(width: 52),
        _SkeletonPill(width: 70),
        _SkeletonPill(width: 64),
        _SkeletonPill(width: 136),
        _SkeletonPill(width: 108),
      ],
    );
  }
}

class _SkeletonPill extends StatelessWidget {
  const _SkeletonPill({
    required this.width,
  });

  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 34,
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _InboxSkeleton extends StatelessWidget {
  const _InboxSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: const [
          _InboxSkeletonRow(),
          Divider(height: 1),
          _InboxSkeletonRow(),
          Divider(height: 1),
          _InboxSkeletonRow(),
          Divider(height: 1),
          _InboxSkeletonRow(),
        ],
      ),
    );
  }
}

class _InboxSkeletonRow extends StatelessWidget {
  const _InboxSkeletonRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: AuraSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 14, width: 180, color: Colors.black12),
                const SizedBox(height: AuraSpace.s8),
                Container(height: 12, width: double.infinity, color: Colors.black12),
                const SizedBox(height: AuraSpace.s6),
                Container(height: 12, width: 160, color: Colors.black12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HubItem {
  const _HubItem({
    required this.id,
    required this.title,
    required this.preview,
    required this.meta,
    required this.route,
    required this.badge,
    required this.icon,
    required this.timestamp,
    required this.sortDate,
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
}

List<Map<String, dynamic>> _filterSpaces(
  List<Map<String, dynamic>> spaces,
  _HubFilter filter,
) {
  switch (filter) {
    case _HubFilter.private:
      return spaces
          .where(
            (space) =>
                _pickString(space, const ['type']).toUpperCase() == 'PRIVATE',
          )
          .toList();
    case _HubFilter.spaces:
      return spaces
          .where(
            (space) =>
                _pickString(space, const ['type']).toUpperCase() != 'PRIVATE',
          )
          .toList();
    case _HubFilter.all:
      return spaces;
  }
}

List<_HubItem> _buildHubItems(List<Map<String, dynamic>> spaces) {
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

    final preview = description.isNotEmpty
        ? description
        : type == 'PRIVATE'
            ? 'Open this conversation.'
            : 'Open this space.';

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

    return _HubItem(
      id: id,
      title: title,
      preview: preview,
      meta: metaParts.join(' · '),
      route: id.isEmpty ? '/me/correspondence' : '/me/correspondence/$id',
      badge: type == 'PRIVATE' ? 'PR' : 'SP',
      icon: type == 'PRIVATE' ? Icons.person_outline : Icons.forum_outlined,
      timestamp: _formatHubTimestamp(updatedRaw),
      sortDate: updatedAt,
    );
  }).toList();

  items.sort((a, b) => b.sortDate.compareTo(a.sortDate));
  return items;
}

String _pickTitle(Map<String, dynamic> space) {
  final explicit = _pickString(space, const ['name', 'title']);
  if (explicit.isNotEmpty) {
    return explicit;
  }

  final members = _extractMembers(space);
  if (members.isNotEmpty) {
    final names = members
        .map(
          (member) => _pickString(
            member,
            const ['displayName', 'name', 'fullName', 'handle', 'username'],
          ),
        )
        .where((value) => value.isNotEmpty)
        .take(2)
        .toList();

    if (names.isNotEmpty) {
      return names.join(', ');
    }
  }

  return 'Untitled space';
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

int _sortSpacesByRecency(Map<String, dynamic> a, Map<String, dynamic> b) {
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

String _formatHubTimestamp(String raw) {
  if (raw.trim().isEmpty) {
    return '';
  }

  final parsed = DateTime.tryParse(raw);
  if (parsed == null) {
    return raw;
  }

  final local = parsed.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(local.year, local.month, local.day);
  final dayDiff = today.difference(target).inDays;

  final hour = local.hour == 0
      ? 12
      : local.hour > 12
          ? local.hour - 12
          : local.hour;
  final minute = local.minute.toString().padLeft(2, '0');
  final ampm = local.hour >= 12 ? 'PM' : 'AM';

  if (dayDiff == 0) {
    return '$hour:$minute $ampm';
  }

  if (dayDiff == 1) {
    return 'Yesterday';
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

String _emptyTitleForFilter(_HubFilter filter) {
  switch (filter) {
    case _HubFilter.all:
      return 'No correspondence yet';
    case _HubFilter.private:
      return 'No private conversations';
    case _HubFilter.spaces:
      return 'No spaces yet';
  }
}

String _emptyBodyForFilter(_HubFilter filter) {
  switch (filter) {
    case _HubFilter.all:
      return 'Recent conversation will collect here as it begins.';
    case _HubFilter.private:
      return 'Start a private conversation and it will appear here.';
    case _HubFilter.spaces:
      return 'Create a shared space and it will appear here.';
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
