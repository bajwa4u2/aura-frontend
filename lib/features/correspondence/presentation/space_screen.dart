import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/ui/aura_text_block.dart';
import '../data/spaces_repository.dart';
import '../data/threads_repository.dart';

final _spaceDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, spaceId) async {
  final repo = ref.watch(spacesRepositoryProvider);
  return repo.getSpace(spaceId);
});

final _threadsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, spaceId) async {
    final repo = ref.watch(threadsRepositoryProvider);
    return repo.listThreads(spaceId: spaceId);
  },
);

final _invitesProvider = FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, spaceId) async {
    final repo = ref.watch(spacesRepositoryProvider);
    final invites = await repo.listInvites();

    return invites.where((invite) {
      final inviteSpaceId = _pickString(invite, const [
        'spaceId',
        'space_id',
      ]);

      if (inviteSpaceId == spaceId) return true;

      final nestedSpace = invite['space'];
      if (nestedSpace is Map) {
        final nestedId = _pickString(
          Map<String, dynamic>.from(nestedSpace),
          const ['id', 'spaceId'],
        );
        return nestedId == spaceId;
      }

      return false;
    }).toList();
  },
);

class SpaceScreen extends ConsumerStatefulWidget {
  const SpaceScreen({super.key, required this.spaceId});

  final String spaceId;

  @override
  ConsumerState<SpaceScreen> createState() => _SpaceScreenState();
}

class _SpaceScreenState extends ConsumerState<SpaceScreen> {
  bool _redirectingToThread = false;

  @override
  Widget build(BuildContext context) {
    final spaceId = widget.spaceId;
    final ref = this.ref;
    final spaceAsync = ref.watch(_spaceDetailProvider(spaceId));
    final threadsAsync = ref.watch(_threadsProvider(spaceId));
    final invitesAsync = ref.watch(_invitesProvider(spaceId));

    final spaceData = spaceAsync.valueOrNull;
    final threadsData = threadsAsync.valueOrNull;
    final isPrivateSpace = _pickString(
          spaceData ?? const <String, dynamic>{},
          const ['type'],
        ).toUpperCase() == 'PRIVATE';

    if (!_redirectingToThread &&
        isPrivateSpace &&
        threadsData != null &&
        threadsData.length == 1) {
      final threadId = _pickString(threadsData.first, const ['id', 'threadId']);
      if (threadId.isNotEmpty) {
        _redirectingToThread = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          context.go('/me/correspondence/$spaceId/thread/$threadId');
        });
      }
    }

    if (_redirectingToThread) {
      return AuraScaffold(
        title: 'Conversation',
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return DefaultTabController(
      length: 4,
      child: AuraScaffold(
        title: 'Space',
        body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(_spaceDetailProvider(widget.spaceId));
            ref.invalidate(_threadsProvider(widget.spaceId));
            ref.invalidate(_invitesProvider(spaceId));
            await Future.wait([
              ref.read(_spaceDetailProvider(spaceId).future),
              ref.read(_threadsProvider(spaceId).future),
              ref.read(_invitesProvider(spaceId).future),
            ]);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              spaceAsync.when(
                loading: () => const AuraCard(
                  child: _LoadingBlock(label: 'Loading space...'),
                ),
                error: (error, _) => AuraCard(
                  child: _ErrorBlock(
                    title: 'Could not load space',
                    body: '$error',
                    onRetry: () => ref.invalidate(_spaceDetailProvider(spaceId)),
                  ),
                ),
                data: (space) => _SpaceHeaderCard(
                  space: space,
                  onCreateThread: () => _showCreateThreadDialog(context, ref),
                  onInviteMember: () => _openInviteScreen(context),
                ),
              ),
              const SizedBox(height: AuraSpace.s14),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const TabBar(
                  isScrollable: true,
                  tabs: [
                    Tab(text: 'Threads'),
                    Tab(text: 'Members'),
                    Tab(text: 'Invites'),
                    Tab(text: 'Media'),
                  ],
                ),
              ),
              const SizedBox(height: AuraSpace.s14),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 520),
                child: SizedBox(
                  height: 620,
                  child: TabBarView(
                    children: [
                      _ThreadsTab(
                        spaceId: spaceId,
                        threadsAsync: threadsAsync,
                        onCreateThread: () => _showCreateThreadDialog(context, ref),
                      ),
                      _MembersTab(spaceAsync: spaceAsync),
                      _InvitesTab(
                        invitesAsync: invitesAsync,
                        onInviteMember: () => _openInviteScreen(context),
                        onRevokeInvite: (inviteId) async {
                          await ref
                              .read(spacesRepositoryProvider)
                              .revokeInvite(inviteId);
                          ref.invalidate(_invitesProvider(spaceId));
                        },
                      ),
                      _MediaTab(spaceAsync: spaceAsync),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCreateThreadDialog(BuildContext context, WidgetRef ref) async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => _CreateThreadDialog(spaceId: widget.spaceId),
    );

    if (created == true) {
      ref.invalidate(_threadsProvider(widget.spaceId));
      ref.invalidate(_spaceDetailProvider(widget.spaceId));
    }
  }

  Future<void> _openInviteScreen(BuildContext context) async {
    await context.push(
      '/invite/create?destinationType=JOIN_SPACE'
      '&spaceId=${Uri.encodeComponent(widget.spaceId)}'
      '&returnTo=${Uri.encodeComponent('/me/correspondence/${widget.spaceId}')}',
    );
  }
}

class _ThreadsTab extends StatelessWidget {
  const _ThreadsTab({
    required this.spaceId,
    required this.threadsAsync,
    required this.onCreateThread,
  });

  final String spaceId;
  final AsyncValue<List<Map<String, dynamic>>> threadsAsync;
  final VoidCallback onCreateThread;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Text('Threads', style: AuraText.title),
        const SizedBox(height: AuraSpace.s10),
        threadsAsync.when(
          loading: () => const AuraCard(
            child: _LoadingBlock(label: 'Loading threads...'),
          ),
          error: (error, _) => AuraCard(
            child: _ErrorBlock(
              title: 'Could not load threads',
              body: '$error',
              onRetry: () {},
            ),
          ),
          data: (threads) {
            if (threads.isEmpty) {
              return AuraCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('No threads yet', style: AuraText.title),
                    const SizedBox(height: AuraSpace.s8),
                    Text(
                      'Create the first thread in this space.',
                      style: AuraText.body,
                    ),
                    const SizedBox(height: AuraSpace.s12),
                    OutlinedButton(
                      onPressed: onCreateThread,
                      child: const Text('Create thread'),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: [
                for (var i = 0; i < threads.length; i++) ...[
                  _ThreadTile(
                    spaceId: spaceId,
                    thread: threads[i],
                  ),
                  if (i != threads.length - 1)
                    const SizedBox(height: AuraSpace.s10),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _MembersTab extends StatelessWidget {
  const _MembersTab({
    required this.spaceAsync,
  });

  final AsyncValue<Map<String, dynamic>> spaceAsync;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Text('Members', style: AuraText.title),
        const SizedBox(height: AuraSpace.s10),
        spaceAsync.when(
          loading: () => const AuraCard(
            child: _LoadingBlock(label: 'Loading members...'),
          ),
          error: (error, _) => AuraCard(
            child: _ErrorBlock(
              title: 'Could not load members',
              body: '$error',
              onRetry: () {},
            ),
          ),
          data: (space) {
            final members = _extractMembers(space);
            final memberCount = _pickInt(
              space,
              const ['memberCount', 'membersCount'],
            );

            if (members.isEmpty) {
              return AuraCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Members', style: AuraText.title),
                    const SizedBox(height: AuraSpace.s8),
                    Text(
                      memberCount > 0
                          ? 'This space reports $memberCount member${memberCount == 1 ? '' : 's'}, but the member list is not yet exposed in the current response shape.'
                          : 'No member list is available yet in the current response.',
                      style: AuraText.body,
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: [
                for (var i = 0; i < members.length; i++) ...[
                  _MemberTile(member: members[i]),
                  if (i != members.length - 1)
                    const SizedBox(height: AuraSpace.s10),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _InvitesTab extends StatelessWidget {
  const _InvitesTab({
    required this.invitesAsync,
    required this.onInviteMember,
    required this.onRevokeInvite,
  });

  final AsyncValue<List<Map<String, dynamic>>> invitesAsync;
  final VoidCallback onInviteMember;
  final Future<void> Function(String inviteId) onRevokeInvite;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Text('Invites', style: AuraText.title),
        const SizedBox(height: AuraSpace.s10),
        invitesAsync.when(
          loading: () => const AuraCard(
            child: _LoadingBlock(label: 'Loading invites...'),
          ),
          error: (error, _) => AuraCard(
            child: _ErrorBlock(
              title: 'Could not load invites',
              body: '$error',
              onRetry: () {},
            ),
          ),
          data: (invites) {
            if (invites.isEmpty) {
              return AuraCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('No invites yet', style: AuraText.title),
                    const SizedBox(height: AuraSpace.s8),
                    Text(
                      'Create or review invitations connected to this space.',
                      style: AuraText.body,
                    ),
                    const SizedBox(height: AuraSpace.s12),
                    OutlinedButton(
                      onPressed: onInviteMember,
                      child: const Text('Add member'),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: [
                for (var i = 0; i < invites.length; i++) ...[
                  _InviteTile(
                    invite: invites[i],
                    onRevoke: () async {
                      final inviteId = _pickString(
                        invites[i],
                        const ['id', 'inviteId'],
                      );
                      if (inviteId.isEmpty) return;
                      await onRevokeInvite(inviteId);
                    },
                  ),
                  if (i != invites.length - 1)
                    const SizedBox(height: AuraSpace.s10),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _MediaTab extends StatelessWidget {
  const _MediaTab({
    required this.spaceAsync,
  });

  final AsyncValue<Map<String, dynamic>> spaceAsync;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Text('Media', style: AuraText.title),
        const SizedBox(height: AuraSpace.s10),
        spaceAsync.when(
          loading: () => const AuraCard(
            child: _LoadingBlock(label: 'Loading media...'),
          ),
          error: (error, _) => AuraCard(
            child: _ErrorBlock(
              title: 'Could not load media',
              body: '$error',
              onRetry: () {},
            ),
          ),
          data: (space) {
            final summary = _extractMediaSummary(space);

            return Column(
              children: [
                _MediaGroupCard(
                  title: 'Images',
                  icon: Icons.image_outlined,
                  count: summary.images,
                  emptyText: 'No images surfaced in this space yet.',
                ),
                const SizedBox(height: AuraSpace.s10),
                _MediaGroupCard(
                  title: 'Documents',
                  icon: Icons.description_outlined,
                  count: summary.documents,
                  emptyText: 'No documents surfaced in this space yet.',
                ),
                const SizedBox(height: AuraSpace.s10),
                _MediaGroupCard(
                  title: 'Audio',
                  icon: Icons.graphic_eq_outlined,
                  count: summary.audio,
                  emptyText: 'No audio surfaced in this space yet.',
                ),
                const SizedBox(height: AuraSpace.s10),
                _MediaGroupCard(
                  title: 'Files',
                  icon: Icons.attach_file_outlined,
                  count: summary.files,
                  emptyText: 'No other files surfaced in this space yet.',
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _MediaGroupCard extends StatelessWidget {
  const _MediaGroupCard({
    required this.title,
    required this.icon,
    required this.count,
    required this.emptyText,
  });

  final String title;
  final IconData icon;
  final int count;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final hasItems = count > 0;

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: AuraSpace.s8),
              Expanded(
                child: Text(title, style: AuraText.title),
              ),
              _MetaChip(label: 'Count', value: '$count'),
            ],
          ),
          const SizedBox(height: AuraSpace.s10),
          Text(
            hasItems
                ? '$count item${count == 1 ? '' : 's'} detected in this space.'
                : emptyText,
            style: AuraText.body,
          ),
        ],
      ),
    );
  }
}

class _SpaceHeaderCard extends StatelessWidget {
  const _SpaceHeaderCard({
    required this.space,
    required this.onCreateThread,
    required this.onInviteMember,
  });

  final Map<String, dynamic> space;
  final VoidCallback onCreateThread;
  final VoidCallback onInviteMember;

  @override
  Widget build(BuildContext context) {
    final name = _pickString(space, const ['name', 'title']);
    final description = _pickString(space, const ['description', 'summary']);
    final visibility = _pickString(space, const ['visibility', 'type']);
    final memberCount = _pickInt(space, const ['memberCount', 'membersCount']);
    final threadCount = _pickInt(space, const ['threadCount', 'threadsCount']);

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AuraSpace.s8,
            runSpacing: AuraSpace.s8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AuraTextBlock(
                name.isEmpty ? 'Untitled space' : name,
                style: AuraText.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (visibility.isNotEmpty)
                _Pill(label: visibility.replaceAll('_', ' ')),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s8),
            AuraTextBlock(
              description,
              style: AuraText.body,
            ),
          ],
          const SizedBox(height: AuraSpace.s12),
          Wrap(
            spacing: AuraSpace.s8,
            runSpacing: AuraSpace.s8,
            children: [
              _MetaChip(label: 'Members', value: '$memberCount'),
              _MetaChip(label: 'Threads', value: '$threadCount'),
            ],
          ),
          const SizedBox(height: AuraSpace.s14),
          Wrap(
            spacing: AuraSpace.s10,
            runSpacing: AuraSpace.s10,
            children: [
              FilledButton(
                onPressed: onCreateThread,
                child: const Text('New thread'),
              ),
              OutlinedButton(
                onPressed: onInviteMember,
                child: const Text('Add member'),
              ),
  
            ],
          ),
        ],
      ),
    );
  }
}

class _CreateThreadDialog extends ConsumerStatefulWidget {
  const _CreateThreadDialog({required this.spaceId});

  final String spaceId;

  @override
  ConsumerState<_CreateThreadDialog> createState() => _CreateThreadDialogState();
}

class _CreateThreadDialogState extends ConsumerState<_CreateThreadDialog> {
  final _titleController = TextEditingController();
  String _kind = 'DIRECT';
  bool _submitting = false;
  String? _errorText;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final spaceId = widget.spaceId.trim();

    if (spaceId.isEmpty || title.isEmpty) {
      setState(() {
        _errorText = 'Please enter a thread title.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _errorText = null;
    });

    try {
      await ref.read(threadsRepositoryProvider).createThread(
            spaceId: spaceId,
            title: title,
            kind: _kind,
          );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _errorText = '$e';
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create thread'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Thread title',
                  hintText: 'General, Family, Review',
                ),
              ),
              const SizedBox(height: AuraSpace.s12),
              DropdownButtonFormField<String>(
                value: _kind,
                items: const [
                  DropdownMenuItem(value: 'DIRECT', child: Text('Direct')),
                  DropdownMenuItem(value: 'GROUP', child: Text('Group')),
                ],
                onChanged: _submitting
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() => _kind = value);
                      },
                decoration: const InputDecoration(labelText: 'Kind'),
              ),
              if (_errorText != null) ...[
                const SizedBox(height: AuraSpace.s12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _errorText!,
                    style: AuraText.small.copyWith(
                      color: Colors.red.shade700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: Text(_submitting ? 'Creating...' : 'Create'),
        ),
      ],
    );
  }
}

class _ThreadTile extends StatelessWidget {
  const _ThreadTile({
    required this.spaceId,
    required this.thread,
  });

  final String spaceId;
  final Map<String, dynamic> thread;

  @override
  Widget build(BuildContext context) {
    final id = _pickString(thread, const ['id', 'threadId']);
    final title = _threadDisplayTitle(thread);
    final kind = _pickString(thread, const ['kind', 'type']);
    final archived =
        thread['archived'] == true || thread['archivedAt'] != null;
    final preview = _pickString(
      thread,
      const ['lastMessage', 'lastMessageText', 'preview', 'description'],
    );

    return AuraCard(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: id.isEmpty
            ? null
            : () => context.push('/me/correspondence/$spaceId/thread/$id'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: AuraSpace.s8,
                runSpacing: AuraSpace.s8,
                children: [
                  AuraTextBlock(
title,
                    style: AuraText.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (kind.isNotEmpty) _Pill(label: kind),
                  if (archived) _Pill(label: 'ARCHIVED'),
                ],
              ),
              if (preview.isNotEmpty) ...[
                const SizedBox(height: AuraSpace.s8),
                AuraTextBlock(
                  preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AuraText.body,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}


class _InviteTile extends StatelessWidget {
  const _InviteTile({
    required this.invite,
    required this.onRevoke,
  });

  final Map<String, dynamic> invite;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final title = _inviteDisplayTitle(invite);
    final subtitle = _inviteDisplaySubtitle(invite);
    final role = _pickString(invite, const ['roleOffered', 'role']);
    final status = _pickString(invite, const ['status']);
    final token = _pickString(invite, const ['token', 'inviteToken']);
    final delivery = _pickString(invite, const ['deliveryChannel', 'delivery_channel']);
    final canCopyLink = token.isNotEmpty;
    final canRevoke = _canRevokeInvite(invite);

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuraTextBlock(
            title,
            style: AuraText.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AuraSpace.s8),
          AuraTextBlock(
            subtitle,
            style: AuraText.body,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AuraSpace.s10),
          Wrap(
            spacing: AuraSpace.s8,
            runSpacing: AuraSpace.s8,
            children: [
              if (role.isNotEmpty) _MetaChip(label: 'Role', value: role),
              if (status.isNotEmpty) _MetaChip(label: 'Status', value: status.replaceAll('_', ' ')),
              if (delivery.isNotEmpty) _MetaChip(label: 'Delivery', value: delivery.replaceAll('_', ' ')),
            ],
          ),
          if (canCopyLink || canRevoke) ...[
            const SizedBox(height: AuraSpace.s12),
            Wrap(
              spacing: AuraSpace.s10,
              runSpacing: AuraSpace.s10,
              children: [
                if (canCopyLink)
                  OutlinedButton(
                    onPressed: () {
                      final link = '${Uri.base.origin}/invite/accept?token=${Uri.encodeComponent(token)}';
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Invite link ready: $link')),
                      );
                    },
                    child: const Text('Copy link'),
                  ),
                if (canRevoke)
                  OutlinedButton(
                    onPressed: onRevoke,
                    child: const Text('Cancel invite'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}


class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
  });

  final Map<String, dynamic> member;

  @override
  Widget build(BuildContext context) {
    final name = _memberDisplayName(member);
    final handle = _pickString(member, const ['handle', 'username', 'userHandle']);
    final role = _pickString(member, const ['role', 'memberRole']);
    final subtitle = _memberSubtitle(member);

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuraTextBlock(
            name,
            style: AuraText.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (handle.isNotEmpty || subtitle.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s6),
            AuraTextBlock(
              [
                if (handle.isNotEmpty) '@$handle',
                if (subtitle.isNotEmpty) subtitle,
              ].join(' · '),
              style: AuraText.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: AuraSpace.s8),
          Wrap(
            spacing: AuraSpace.s8,
            runSpacing: AuraSpace.s8,
            children: [
              if (role.isNotEmpty) _MetaChip(label: 'Role', value: role),
            ],
          ),
        ],
      ),
    );
  }
}


String _threadDisplayTitle(Map<String, dynamic> thread) {
  final explicit = _pickString(thread, const ['title', 'name']);
  if (explicit.isNotEmpty) return explicit;

  final participantNames = _extractDisplayNames(
    thread,
    const ['participants', 'members', 'participantList', 'memberList', 'users'],
  );
  if (participantNames.isNotEmpty) {
    if (participantNames.length == 1) return participantNames.first;
    if (participantNames.length == 2) return '${participantNames.first} and ${participantNames.last}';
    return '${participantNames.first}, ${participantNames[1]} +${participantNames.length - 2}';
  }

  final preview = _pickString(
    thread,
    const ['lastMessage', 'lastMessageText', 'preview', 'description', 'summary'],
  );
  if (preview.isNotEmpty) return _truncateLabel(preview, max: 42);

  return 'Conversation';
}

String _memberDisplayName(Map<String, dynamic> member) {
  final value = _pickString(
    member,
    const ['displayName', 'fullName', 'name', 'username', 'handle'],
  );
  return value.isEmpty ? 'Member' : value;
}

String _memberSubtitle(Map<String, dynamic> member) {
  final parts = <String>[
    _pickString(member, const ['headline', 'bio', 'summary']),
    _pickString(member, const ['email']),
  ].where((e) => e.isNotEmpty).toList(growable: false);
  return parts.isEmpty ? '' : parts.first;
}

String _inviteDisplayTitle(Map<String, dynamic> invite) {
  final targetName = _pickNested(
    invite,
    const [
      ['recipient', 'displayName'],
      ['recipient', 'fullName'],
      ['recipient', 'name'],
      ['recipientUser', 'displayName'],
      ['recipientUser', 'name'],
      ['invitedUser', 'displayName'],
      ['invitedUser', 'name'],
      ['recipientProfile', 'displayName'],
    ],
  );
  if (targetName.isNotEmpty) return targetName;

  final handle = _pickString(
    invite,
    const ['recipientHandle', 'recipient_handle', 'handle'],
  );
  if (handle.isNotEmpty) return '@$handle';

  final destination = _pickString(invite, const ['destinationType', 'destination_type']).replaceAll('_', ' ');
  if (destination.isNotEmpty) return destination;

  return 'Invite';
}

String _inviteDisplaySubtitle(Map<String, dynamic> invite) {
  final note = _pickString(invite, const ['message']);
  if (note.isNotEmpty) return note;

  final inviter = _pickNested(
    invite,
    const [
      ['invitedBy', 'displayName'],
      ['inviter', 'displayName'],
      ['createdBy', 'displayName'],
      ['sender', 'displayName'],
    ],
  );
  final recipientId = _pickString(
    invite,
    const ['recipientUserId', 'invitedUserId', 'userId'],
  );
  final parts = <String>[
    if (inviter.isNotEmpty) 'From $inviter',
    if (recipientId.isNotEmpty && _inviteDisplayTitle(invite) == 'Invite') 'Member ${_truncateLabel(recipientId, max: 18)}',
  ];
  return parts.isEmpty ? 'Pending invitation.' : parts.join(' · ');
}

bool _canRevokeInvite(Map<String, dynamic> invite) {
  final status = _pickString(invite, const ['status']).toUpperCase();
  return status.isEmpty ||
      status == 'PENDING' ||
      status == 'SENT' ||
      status == 'CREATED' ||
      status == 'OPEN';
}

List<String> _extractDisplayNames(Map<String, dynamic> source, List<String> keys) {
  final out = <String>[];
  for (final key in keys) {
    final value = source[key];
    if (value is! List) continue;
    for (final raw in value) {
      if (raw is! Map) continue;
      final map = Map<String, dynamic>.from(raw);
      final name = _pickString(
        map,
        const ['displayName', 'fullName', 'name', 'username', 'handle'],
      );
      if (name.isNotEmpty && !out.contains(name)) out.add(name);
    }
  }
  return out;
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

String _truncateLabel(String value, {int max = 40}) {
  final text = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (text.length <= max) return text;
  return '${text.substring(0, max - 1).trimRight()}…';
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

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({
    required this.title,
    required this.body,
    required this.onRetry,
  });

  final String title;
  final String body;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
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
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s10,
        vertical: AuraSpace.s6,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: AuraText.small.copyWith(fontWeight: FontWeight.w600),
      ),
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
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AuraText.small.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _MediaSummary {
  const _MediaSummary({
    required this.images,
    required this.documents,
    required this.audio,
    required this.files,
  });

  final int images;
  final int documents;
  final int audio;
  final int files;
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

_MediaSummary _extractMediaSummary(Map<String, dynamic> space) {
  final nested = _extractNestedMediaMap(space);

  return _MediaSummary(
    images: _pickInt(
      nested ?? space,
      const ['imagesCount', 'imageCount', 'images'],
    ),
    documents: _pickInt(
      nested ?? space,
      const ['documentsCount', 'documentCount', 'documents', 'docsCount'],
    ),
    audio: _pickInt(
      nested ?? space,
      const ['audioCount', 'audiosCount', 'audio'],
    ),
    files: _pickInt(
      nested ?? space,
      const ['filesCount', 'fileCount', 'files'],
    ),
  );
}

Map<String, dynamic>? _extractNestedMediaMap(Map<String, dynamic> space) {
  const candidateKeys = [
    'media',
    'mediaSummary',
    'assets',
    'attachmentsSummary',
  ];

  for (final key in candidateKeys) {
    final value = space[key];
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
  }

  return null;
}