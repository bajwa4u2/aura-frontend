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

    return AuraScaffold(
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
              ),
            ),
            const SizedBox(height: AuraSpace.s14),
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
                  onRetry: () => ref.invalidate(_threadsProvider(spaceId)),
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
                          onPressed: () => _showCreateThreadDialog(context, ref),
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
            const SizedBox(height: AuraSpace.s18),
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
                  onRetry: () => ref.invalidate(_invitesProvider(spaceId)),
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
                          'Invite someone into this space by user ID when you are ready.',
                          style: AuraText.body,
                        ),
                        const SizedBox(height: AuraSpace.s12),
                        OutlinedButton(
                          onPressed: () => _showInviteDialog(context, ref),
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

                          await ref
                              .read(spacesRepositoryProvider)
                              .revokeInvite(inviteId);
                          ref.invalidate(_invitesProvider(spaceId));
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
        ),
      ),
    );
  }

  Future<void> _showCreateThreadDialog(BuildContext context, WidgetRef ref) async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => const _CreateThreadDialog(),
    );

    if (created == true) {
      ref.invalidate(_threadsProvider(spaceId));
    }
  }

  Future<void> _showInviteDialog(BuildContext context, WidgetRef ref) async {
    final invited = await showDialog<bool>(
      context: context,
      builder: (_) => const _InviteMemberDialog(),
    );

    if (invited == true) {
      ref.invalidate(_invitesProvider(spaceId));
    }
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
              Text(
                name.isEmpty ? 'Untitled space' : name,
                style: AuraText.title,
              ),
              if (visibility.isNotEmpty) _Pill(label: visibility),
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
            ],
          ),
        ],
      ),
    );
  }
}

class _CreateThreadDialog extends ConsumerStatefulWidget {
  const _CreateThreadDialog();

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
    final route = GoRouterState.of(context).uri.path;
    final segments = Uri.parse(route).pathSegments;
    final spaceId = segments.length >= 3 ? segments[2] : '';

    final title = _titleController.text.trim();
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
  const _InviteMemberDialog();

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
    final route = GoRouterState.of(context).uri.path;
    final segments = Uri.parse(route).pathSegments;
    final spaceId = segments.length >= 3 ? segments[2] : '';

    final userId = _userIdController.text.trim();
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
    final archived = thread['archived'] == true;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: id.isEmpty
          ? null
          : () => context.go('/me/correspondence/$spaceId/thread/$id'),
      child: AuraCard(
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
          ],
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
    final userId = _pickString(invite, const ['userId', 'recipientUserId']);
    final role = _pickString(invite, const ['role']);
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