import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';
import '../data/spaces_repository.dart';
import '../data/threads_repository.dart';

final _spaceDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, spaceId) async {
  final repo = ref.watch(spacesRepositoryProvider);
  return repo.getSpace(spaceId);
});

final _threadsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, spaceId) async {
  final repo = ref.watch(threadsRepositoryProvider);
  return repo.listThreads(spaceId: spaceId);
});

final _invitesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, spaceId) async {
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
});

class SpaceScreen extends ConsumerWidget {
  const SpaceScreen({super.key, required this.spaceId});

  final String spaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spaceAsync = ref.watch(_spaceDetailProvider(spaceId));
    final threadsAsync = ref.watch(_threadsProvider(spaceId));
    final invitesAsync = ref.watch(_invitesProvider(spaceId));

    return DefaultTabController(
      length: 4,
      child: AuraScaffold(
        title: 'Space',
        body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(_spaceDetailProvider(spaceId));
            ref.invalidate(_threadsProvider(spaceId));
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
                  onInviteMember: () => _showInviteDialog(context, ref),
                  onNewConversation: () =>
                      context.go('/me/correspondence/create/conversation'),
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
                        onInviteMember: () => _showInviteDialog(context, ref),
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
      builder: (_) => _CreateThreadDialog(spaceId: spaceId),
    );

    if (created == true) {
      ref.invalidate(_threadsProvider(spaceId));
    }
  }

  Future<void> _showInviteDialog(BuildContext context, WidgetRef ref) async {
    final invited = await showDialog<bool>(
      context: context,
      builder: (_) => _InviteMemberDialog(spaceId: spaceId),
    );

    if (invited == true) {
      ref.invalidate(_invitesProvider(spaceId));
    }
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
                    Text('Members surface ready', style: AuraText.title),
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
                      'Invite someone into this space.',
                      style: AuraText.body,
                    ),
                    const SizedBox(height: AuraSpace.s12),
                    OutlinedButton(
                      onPressed: onInviteMember,
                      child: const Text('Invite member'),
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
    required this.onNewConversation,
  });

  final Map<String, dynamic> space;
  final VoidCallback onCreateThread;
  final VoidCallback onInviteMember;
  final VoidCallback onNewConversation;

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
              Text(
                name.isEmpty ? 'Untitled space' : name,
                style: AuraText.title,
              ),
              if (visibility.isNotEmpty)
                _Pill(label: visibility.replaceAll('_', ' ')),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s8),
            Text(description, style: AuraText.body),
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
                child: const Text('Invite member'),
              ),
              OutlinedButton(
                onPressed: onNewConversation,
                child: const Text('New conversation'),
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

class _InviteMemberDialog extends ConsumerStatefulWidget {
  const _InviteMemberDialog({required this.spaceId});

  final String spaceId;

  @override
  ConsumerState<_InviteMemberDialog> createState() => _InviteMemberDialogState();
}

class _InviteMemberDialogState extends ConsumerState<_InviteMemberDialog> {
  final _userIdController = TextEditingController();
  String _role = 'MEMBER';
  bool _submitting = false;
  String? _errorText;

  @override
  void dispose() {
    _userIdController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final userId = _userIdController.text.trim();
    final spaceId = widget.spaceId.trim();

    if (spaceId.isEmpty || userId.isEmpty) {
      setState(() {
        _errorText = 'Please enter a user ID.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _errorText = null;
    });

    try {
      await ref.read(spacesRepositoryProvider).inviteMember(
            spaceId: spaceId,
            userId: userId,
            role: _role,
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
      title: const Text('Invite member'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _userIdController,
                decoration: const InputDecoration(
                  labelText: 'User ID',
                  hintText: 'Enter the member user ID',
                ),
              ),
              const SizedBox(height: AuraSpace.s12),
              DropdownButtonFormField<String>(
                value: _role,
                items: const [
                  DropdownMenuItem(value: 'MEMBER', child: Text('Member')),
                  DropdownMenuItem(value: 'ADMIN', child: Text('Admin')),
                ],
                onChanged: _submitting
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() => _role = value);
                      },
                decoration: const InputDecoration(labelText: 'Role'),
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
          child: Text(_submitting ? 'Inviting...' : 'Invite'),
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
    final title = _pickString(thread, const ['title', 'name']);
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
            : () => context.go('/me/correspondence/$spaceId/thread/$id'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: AuraSpace.s8,
                runSpacing: AuraSpace.s8,
                children: [
                  Text(
                    title.isEmpty ? 'Untitled thread' : title,
                    style: AuraText.title,
                  ),
                  if (kind.isNotEmpty) _Pill(label: kind),
                  if (archived) _Pill(label: 'ARCHIVED'),
                ],
              ),
              if (preview.isNotEmpty) ...[
                const SizedBox(height: AuraSpace.s8),
                Text(
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
    final id = _pickString(invite, const ['id', 'inviteId']);
    final userId = _pickString(
      invite,
      const ['userId', 'recipientUserId', 'invitedUserId'],
    );
    final role = _pickString(invite, const ['role', 'roleOffered']);
    final status = _pickString(invite, const ['status']);

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            userId.isEmpty ? 'Invite' : userId,
            style: AuraText.title,
          ),
          const SizedBox(height: AuraSpace.s8),
          Wrap(
            spacing: AuraSpace.s8,
            runSpacing: AuraSpace.s8,
            children: [
              if (role.isNotEmpty) _MetaChip(label: 'Role', value: role),
              if (status.isNotEmpty) _MetaChip(label: 'Status', value: status),
              if (id.isNotEmpty) _MetaChip(label: 'ID', value: id),
            ],
          ),
          const SizedBox(height: AuraSpace.s12),
          OutlinedButton(
            onPressed: onRevoke,
            child: const Text('Revoke invite'),
          ),
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
    final name = _pickString(
      member,
      const ['name', 'fullName', 'displayName', 'username', 'handle'],
    );
    final role = _pickString(member, const ['role', 'memberRole']);
    final id = _pickString(member, const ['id', 'userId', 'memberId']);

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name.isEmpty ? 'Member' : name,
            style: AuraText.title,
          ),
          const SizedBox(height: AuraSpace.s8),
          Wrap(
            spacing: AuraSpace.s8,
            runSpacing: AuraSpace.s8,
            children: [
              if (role.isNotEmpty) _MetaChip(label: 'Role', value: role),
              if (id.isNotEmpty) _MetaChip(label: 'ID', value: id),
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
