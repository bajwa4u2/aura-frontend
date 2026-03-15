import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_providers.dart';
import '../../../core/ui/aura_card.dart';
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

class CorrespondenceHubScreen extends ConsumerWidget {
  const CorrespondenceHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStatusProvider);

    if (auth != AuthStatus.authed) {
      return AuraScaffold(
        title: 'Correspondence',
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _HeroBand(
              eyebrow: 'Correspondence',
              title: 'A governed place for continuing exchange.',
              body:
                  'Private conversation, shared spaces, and invitations live here in one ordered surface.',
              primaryLabel: 'Sign in',
              onPrimary: () => context.go('/login'),
              secondaryLabel: 'Back to account',
              onSecondary: () => context.go('/me'),
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
              _HeroBand.loading(),
              SizedBox(height: AuraSpace.s18),
              _SectionShell.loading(title: 'Continue'),
              SizedBox(height: AuraSpace.s16),
              _SectionShell.loading(title: 'Invitations'),
              SizedBox(height: AuraSpace.s16),
              _SectionShell.loading(title: 'Spaces'),
              SizedBox(height: AuraSpace.s16),
              _SectionShell.loading(title: 'People'),
              SizedBox(height: AuraSpace.s16),
              _SectionShell.loading(title: 'Create'),
            ],
          ),
          error: (error, _) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              const _HeroBand(
                eyebrow: 'Correspondence',
                title: 'A governed place for continuing exchange.',
                body:
                    'Private conversation, shared spaces, and invitations live here in one ordered surface.',
              ),
              const SizedBox(height: AuraSpace.s18),
              _ErrorStateCard(
                title: 'Could not load correspondence',
                body: '$error',
                onRetry: () => ref.invalidate(_correspondenceSpacesProvider),
              ),
            ],
          ),
          data: (spaces) {
            final sortedSpaces = [...spaces]..sort(_sortSpacesByRecency);
            final continueItems = _buildContinueItems(sortedSpaces);
            final peopleItems = _buildPeopleItems(sortedSpaces);
            final invitationItems = _buildInvitationItems(sortedSpaces);

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                _HeroBand(
                  eyebrow: 'Correspondence',
                  title: 'Ordered continuity across people, spaces, and threads.',
                  body:
                      'This is not an inbox in identity, but it should behave with inbox-grade clarity. What is active comes forward. What is governed stays durable.',
                  primaryLabel: 'New conversation',
                  onPrimary: () =>
                      context.go('/me/correspondence/create/conversation'),
                  secondaryLabel: 'Create space',
                  onSecondary: () =>
                      context.go('/me/correspondence/create/space'),
                ),
                const SizedBox(height: AuraSpace.s18),
                _SectionShell(
                  title: 'Continue',
                  subtitle:
                      'Recent correspondence ready to reopen, across active spaces and threads.',
                  child: continueItems.isEmpty
                      ? const _EmptyStateRow(
                          title: 'Nothing active yet',
                          body:
                              'When correspondence begins, recent activity will collect here first.',
                        )
                      : Column(
                          children: [
                            for (var i = 0; i < continueItems.length; i++) ...[
                              _ContinueRow(item: continueItems[i]),
                              if (i != continueItems.length - 1)
                                const Divider(height: 1),
                            ],
                          ],
                        ),
                ),
                const SizedBox(height: AuraSpace.s16),
                _SectionShell(
                  title: 'Invitations',
                  subtitle:
                      'Pending access and membership belong near the top, not buried inside another screen.',
                  trailing: TextButton(
                    onPressed: () {
                      final firstSpaceId = _firstSpaceId(sortedSpaces);
                      if (firstSpaceId.isNotEmpty) {
                        context.go('/me/correspondence/$firstSpaceId');
                      }
                    },
                    child: const Text('Open spaces'),
                  ),
                  child: invitationItems.isEmpty
                      ? const _EmptyStateRow(
                          title: 'No invitations surfaced here yet',
                          body:
                              'The structural place is locked. Real invitation rows should be wired from live invite data in the next pass.',
                        )
                      : Column(
                          children: [
                            for (var i = 0; i < invitationItems.length; i++) ...[
                              _InvitationRow(item: invitationItems[i]),
                              if (i != invitationItems.length - 1)
                                const Divider(height: 1),
                            ],
                          ],
                        ),
                ),
                const SizedBox(height: AuraSpace.s16),
                _SectionShell(
                  title: 'Spaces',
                  subtitle:
                      'Governed places for continuing exchange, ordered by recent activity rather than by age alone.',
                  trailing: TextButton(
                    onPressed: () =>
                        context.go('/me/correspondence/create/space'),
                    child: const Text('Create'),
                  ),
                  child: sortedSpaces.isEmpty
                      ? _EmptyStateRow(
                          title: 'No spaces yet',
                          body:
                              'Create the first shared place and let correspondence gather around it.',
                          actionLabel: 'Create space',
                          onAction: () =>
                              context.go('/me/correspondence/create/space'),
                        )
                      : Column(
                          children: [
                            for (var i = 0; i < sortedSpaces.length; i++) ...[
                              _SpaceRow(space: sortedSpaces[i]),
                              if (i != sortedSpaces.length - 1)
                                const Divider(height: 1),
                            ],
                          ],
                        ),
                ),
                const SizedBox(height: AuraSpace.s16),
                _SectionShell(
                  title: 'People',
                  subtitle:
                      'Profiles should lead into correspondence. Followers, following, members, and institutes belong here as reachable identities.',
                  trailing: TextButton(
                    onPressed: () =>
                        context.go('/me/correspondence/create/conversation'),
                    child: const Text('Find people'),
                  ),
                  child: peopleItems.isEmpty
                      ? const _EmptyStateRow(
                          title: 'No people surfaced yet',
                          body:
                              'This section is ready for real members and institutes. It should be wired from live search and relationship data next.',
                        )
                      : Column(
                          children: [
                            for (var i = 0; i < peopleItems.length; i++) ...[
                              _PersonRow(item: peopleItems[i]),
                              if (i != peopleItems.length - 1)
                                const Divider(height: 1),
                            ],
                          ],
                        ),
                ),
                const SizedBox(height: AuraSpace.s16),
                _SectionShell(
                  title: 'Create',
                  subtitle:
                      'Creation stays available, but it should not dominate the screen.',
                  child: Wrap(
                    spacing: AuraSpace.s10,
                    runSpacing: AuraSpace.s10,
                    children: [
                      _ActionPill(
                        label: 'New conversation',
                        icon: Icons.chat_bubble_outline,
                        onTap: () => context
                            .go('/me/correspondence/create/conversation'),
                        primary: true,
                      ),
                      _ActionPill(
                        label: 'Create space',
                        icon: Icons.groups_outlined,
                        onTap: () =>
                            context.go('/me/correspondence/create/space'),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HeroBand extends StatelessWidget {
  const _HeroBand({
    required this.eyebrow,
    required this.title,
    required this.body,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  const _HeroBand.loading()
      : eyebrow = 'Correspondence',
        title = 'Loading correspondence...',
        body = 'Preparing your active exchange surfaces.',
        primaryLabel = null,
        onPrimary = null,
        secondaryLabel = null,
        onSecondary = null;

  final String eyebrow;
  final String title;
  final String body;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow,
            style: AuraText.small.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AuraSpace.s10),
          Text(title, style: AuraText.title),
          const SizedBox(height: AuraSpace.s10),
          Text(body, style: AuraText.body),
          if (primaryLabel != null || secondaryLabel != null) ...[
            const SizedBox(height: AuraSpace.s14),
            Wrap(
              spacing: AuraSpace.s10,
              runSpacing: AuraSpace.s10,
              children: [
                if (primaryLabel != null)
                  FilledButton(
                    onPressed: onPrimary,
                    child: Text(primaryLabel!),
                  ),
                if (secondaryLabel != null)
                  OutlinedButton(
                    onPressed: onSecondary,
                    child: Text(secondaryLabel!),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionShell extends StatelessWidget {
  const _SectionShell({
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  const _SectionShell.loading({required this.title})
      : subtitle = '',
        child = const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Center(child: CircularProgressIndicator()),
        ),
        trailing = null;

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AuraText.title),
                    if (subtitle.trim().isNotEmpty) ...[
                      const SizedBox(height: AuraSpace.s8),
                      Text(subtitle, style: AuraText.body),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AuraSpace.s12),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: AuraSpace.s14),
          child,
        ],
      ),
    );
  }
}

class _ContinueItem {
  const _ContinueItem({
    required this.id,
    required this.title,
    required this.preview,
    required this.kindLabel,
    required this.meta,
    required this.route,
  });

  final String id;
  final String title;
  final String preview;
  final String kindLabel;
  final String meta;
  final String route;
}

class _InvitationItem {
  const _InvitationItem({
    required this.title,
    required this.body,
    required this.route,
  });

  final String title;
  final String body;
  final String route;
}

class _PeopleItem {
  const _PeopleItem({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.route,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final String route;
}

class _ContinueRow extends StatelessWidget {
  const _ContinueRow({required this.item});

  final _ContinueItem item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.go(item.route),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LetterBadge(label: item.kindLabel),
            const SizedBox(width: AuraSpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: AuraSpace.s4),
                  Text(
                    item.preview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AuraText.small,
                  ),
                  const SizedBox(height: AuraSpace.s8),
                  Text(
                    item.meta,
                    style: AuraText.small.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
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

class _InvitationRow extends StatelessWidget {
  const _InvitationRow({required this.item});

  final _InvitationItem item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.go(item.route),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _LetterBadge(label: 'INV'),
            const SizedBox(width: AuraSpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: AuraSpace.s4),
                  Text(
                    item.body,
                    style: AuraText.small,
                  ),
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

class _SpaceRow extends StatelessWidget {
  const _SpaceRow({required this.space});

  final Map<String, dynamic> space;

  @override
  Widget build(BuildContext context) {
    final id = _pickString(space, const ['id', '_id', 'spaceId']);
    final name = _pickString(space, const ['name', 'title']);
    final description = _pickString(space, const ['description', 'summary']);
    final visibility = _pickString(space, const ['visibility', 'type']);
    final memberCount = _pickInt(space, const ['memberCount', 'membersCount']);
    final threadCount = _pickInt(space, const ['threadCount', 'threadsCount']);
    final updatedAt = _pickString(space, const [
      'updatedAt',
      'lastActivityAt',
      'lastMessageAt',
      'createdAt',
    ]);

    return InkWell(
      onTap: id.isEmpty ? null : () => context.go('/me/correspondence/$id'),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _LetterBadge(label: 'SP'),
            const SizedBox(width: AuraSpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: AuraSpace.s8,
                    runSpacing: AuraSpace.s8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        name.isEmpty ? 'Untitled space' : name,
                        style: AuraText.body.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (visibility.isNotEmpty)
                        _MiniPill(label: visibility.replaceAll('_', ' ')),
                    ],
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: AuraSpace.s4),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AuraText.small,
                    ),
                  ],
                  const SizedBox(height: AuraSpace.s8),
                  Wrap(
                    spacing: AuraSpace.s8,
                    runSpacing: AuraSpace.s8,
                    children: [
                      _MiniMeta(label: 'Members', value: '$memberCount'),
                      _MiniMeta(label: 'Threads', value: '$threadCount'),
                      if (updatedAt.isNotEmpty)
                        _MiniMeta(label: 'Active', value: updatedAt),
                    ],
                  ),
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

class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.item});

  final _PeopleItem item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.go(item.route),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _LetterBadge(label: 'PR'),
            const SizedBox(width: AuraSpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: AuraSpace.s4),
                  Text(
                    item.subtitle,
                    style: AuraText.small,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AuraSpace.s10),
            Text(
              item.actionLabel,
              style: AuraText.small.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: AuraSpace.s6),
            const Icon(Icons.chevron_right, size: 18),
          ],
        ),
      ),
    );
  }
}

class _EmptyStateRow extends StatelessWidget {
  const _EmptyStateRow({
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AuraText.body.copyWith(fontWeight: FontWeight.w700)),
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

class _ErrorStateCard extends StatelessWidget {
  const _ErrorStateCard({
    required this.title,
    required this.body,
    required this.onRetry,
  });

  final String title;
  final String body;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AuraText.title),
          const SizedBox(height: AuraSpace.s8),
          Text(body, style: AuraText.body),
          const SizedBox(height: AuraSpace.s12),
          OutlinedButton(
            onPressed: onRetry,
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.label,
    required this.icon,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    if (primary) {
      return FilledButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
      );
    }

    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

class _LetterBadge extends StatelessWidget {
  const _LetterBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
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

class _MiniMeta extends StatelessWidget {
  const _MiniMeta({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$label: $value',
      style: AuraText.small.copyWith(fontWeight: FontWeight.w600),
    );
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s8,
        vertical: AuraSpace.s4,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AuraText.small.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

List<_ContinueItem> _buildContinueItems(List<Map<String, dynamic>> spaces) {
  return spaces.take(6).map((space) {
    final id = _pickString(space, const ['id', '_id', 'spaceId']);
    final name = _pickString(space, const ['name', 'title']);
    final description = _pickString(space, const ['description', 'summary']);
    final threadCount = _pickInt(space, const ['threadCount', 'threadsCount']);
    final memberCount = _pickInt(space, const ['memberCount', 'membersCount']);
    final activity = _pickString(space, const [
      'updatedAt',
      'lastActivityAt',
      'lastMessageAt',
      'createdAt',
    ]);

    return _ContinueItem(
      id: id,
      title: name.isEmpty ? 'Untitled space' : name,
      preview: description.isEmpty
          ? 'Open this space to continue the thread of exchange.'
          : description,
      kindLabel: 'SP',
      meta:
          'Threads $threadCount · Members $memberCount${activity.isNotEmpty ? ' · $activity' : ''}',
      route: id.isEmpty ? '/me/correspondence' : '/me/correspondence/$id',
    );
  }).toList();
}

List<_InvitationItem> _buildInvitationItems(List<Map<String, dynamic>> spaces) {
  final items = <_InvitationItem>[];

  for (final space in spaces.take(3)) {
    final id = _pickString(space, const ['id', '_id', 'spaceId']);
    final name = _pickString(space, const ['name', 'title']);
    final memberCount = _pickInt(space, const ['memberCount', 'membersCount']);

    if (id.isEmpty || name.isEmpty) continue;

    items.add(
      _InvitationItem(
        title: 'Review access for $name',
        body:
            'Membership, invite history, and pending access should open from the space surface. This row is the long-term slot for that action.',
        route: '/me/correspondence/$id',
      ),
    );

    if (memberCount > 0) break;
  }

  return items;
}

List<_PeopleItem> _buildPeopleItems(List<Map<String, dynamic>> spaces) {
  final seen = <String>{};
  final items = <_PeopleItem>[];

  for (final space in spaces) {
    final members = _extractMembers(space);

    for (final member in members) {
      final handle = _pickString(
        member,
        const ['handle', 'username', 'userHandle'],
      );
      final name = _pickString(
        member,
        const ['name', 'displayName', 'fullName', 'username', 'handle'],
      );
      final role = _pickString(member, const ['role', 'memberRole']);

      if (handle.isEmpty || seen.contains(handle)) continue;
      seen.add(handle);

      items.add(
        _PeopleItem(
          title: name.isEmpty ? handle : name,
          subtitle: role.isEmpty ? '@$handle' : '@$handle · $role',
          actionLabel: 'Open',
          route: '/u/$handle',
        ),
      );

      if (items.length >= 8) return items;
    }
  }

  return items;
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

String _firstSpaceId(List<Map<String, dynamic>> spaces) {
  for (final space in spaces) {
    final id = _pickString(space, const ['id', '_id', 'spaceId']);
    if (id.isNotEmpty) return id;
  }
  return '';
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
