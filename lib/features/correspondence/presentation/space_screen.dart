import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/product/product_language.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/substrate_chip.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/ui/aura_text_block.dart';
import '../data/spaces_repository.dart';
import '../data/threads_repository.dart';
import '../data/correspondence_identity.dart';
import '../data/correspondence_live_service.dart';
import '../../realtime/application/realtime_providers.dart';
import '../../institutions/data/institutions_repository.dart';

final _spaceDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, spaceId) async {
      final repo = ref.watch(spacesRepositoryProvider);
      return repo.getSpace(spaceId);
    });

/// Cross-System Institutional Identity Coherence -- the institution-aware
/// read. `SpaceScreen` previously called `_spaceDetailProvider` (the
/// PERSONAL correspondence endpoint) unconditionally, even for institution
/// spaces -- so the institution-aware backend endpoint (which resolves
/// real institution identity) was simply never reached. This provider is
/// used instead whenever the route carried an `institutionId`.
final _institutionSpaceDetailProvider =
    FutureProvider.family<Map<String, dynamic>, ({String institutionId, String spaceId})>(
  (ref, args) async {
    final repo = ref.watch(institutionsRepositoryProvider);
    return repo.getInstitutionSpace(args.institutionId, args.spaceId);
  },
);

final _threadsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      spaceId,
    ) async {
      final repo = ref.watch(threadsRepositoryProvider);
      return repo.listThreads(spaceId: spaceId);
    });

final _invitesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      spaceId,
    ) async {
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

class SpaceScreen extends ConsumerStatefulWidget {
  const SpaceScreen({super.key, required this.spaceId, this.institutionId});

  final String spaceId;

  /// Present only when this Space is owned by an institution (routed via
  /// `/institution/:institutionId/spaces/:spaceId`) -- absent for personal
  /// correspondence Spaces (`/me/correspondence/:spaceId`). Governs which
  /// backend authority/endpoint this screen reads through.
  final String? institutionId;

  @override
  ConsumerState<SpaceScreen> createState() => _SpaceScreenState();
}

class _SpaceScreenState extends ConsumerState<SpaceScreen> {
  bool _redirectingToThread = false;
  Timer? _pollTimer;
  StreamSubscription<CorrespondenceLiveEvent>? _liveSubscription;
  bool _handledLiveRoute = false;
  DateTime? _lastSocketEventAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _joinFromRouteIfNeeded(),
    );
    _pollTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (!mounted) return;
      // Skip the poll if a socket event was received recently — the socket
      // subscription already invalidated the providers on that event.
      final last = _lastSocketEventAt;
      if (last != null && DateTime.now().difference(last) < const Duration(seconds: 45)) {
        return;
      }
      _invalidateSpaceDetail();
      ref.invalidate(_threadsProvider(widget.spaceId));
      ref.invalidate(_invitesProvider(widget.spaceId));
    });

    Future.microtask(() async {
      final live = ref.read(correspondenceLiveServiceProvider);
      await live.joinSpace(widget.spaceId);
      _liveSubscription = live.events.listen((event) {
        if (!mounted) return;
        if (event.matchesSpace(widget.spaceId) ||
            event.name.startsWith('invite:') ||
            event.name.startsWith('thread:')) {
          _lastSocketEventAt = DateTime.now();
          _invalidateSpaceDetail();
          ref.invalidate(_threadsProvider(widget.spaceId));
          ref.invalidate(_invitesProvider(widget.spaceId));
        }
      });
    });
  }

  Future<void> _joinFromRouteIfNeeded() async {
    if (!mounted || _handledLiveRoute) return;

    String sessionId = '';
    try {
      final state = GoRouterState.of(context);
      sessionId =
          state.pathParameters['sessionId']?.trim() ??
          state.uri.queryParameters['sessionId']?.trim() ??
          '';
      final shouldJoin =
          sessionId.isNotEmpty ||
          ((state.uri.queryParameters['join'] ?? '').trim().toLowerCase() ==
              '1');
      if (!shouldJoin || sessionId.isEmpty) return;
    } catch (_) {
      return;
    }

    _handledLiveRoute = true;
    await ref.read(realtimeControllerProvider.notifier).join(sessionId);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    unawaited(
      ref.read(correspondenceLiveServiceProvider).leaveSpace(widget.spaceId),
    );
    _liveSubscription?.cancel();
    super.dispose();
  }

  void _invalidateSpaceDetail() {
    final institutionId = widget.institutionId;
    if (institutionId != null) {
      ref.invalidate(_institutionSpaceDetailProvider((
        institutionId: institutionId,
        spaceId: widget.spaceId,
      )));
    } else {
      _invalidateSpaceDetail();
    }
  }

  Future<Map<String, dynamic>> _refreshSpaceDetail() {
    final institutionId = widget.institutionId;
    if (institutionId != null) {
      return ref.read(_institutionSpaceDetailProvider((
        institutionId: institutionId,
        spaceId: widget.spaceId,
      )).future);
    }
    return ref.read(_spaceDetailProvider(widget.spaceId).future);
  }

  @override
  Widget build(BuildContext context) {
    final spaceId = widget.spaceId;
    final institutionId = widget.institutionId;
    final ref = this.ref;
    final spaceAsync = institutionId != null
        ? ref.watch(_institutionSpaceDetailProvider((
            institutionId: institutionId,
            spaceId: spaceId,
          )))
        : ref.watch(_spaceDetailProvider(spaceId));
    final threadsAsync = ref.watch(_threadsProvider(spaceId));
    final invitesAsync = ref.watch(_invitesProvider(spaceId));

    final spaceData = spaceAsync.valueOrNull;
    final threadsData = threadsAsync.valueOrNull;
    final isPrivateSpace =
        _pickString(spaceData ?? const <String, dynamic>{}, const [
          'type',
        ]).toUpperCase() ==
        'PRIVATE';

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
          child: AuraLoadingState(message: 'Opening conversation…'),
        ),
      );
    }

    return DefaultTabController(
      length: 4,
      child: AuraScaffold(
        title: 'Space',
        body: RefreshIndicator(
          onRefresh: () async {
            _invalidateSpaceDetail();
            ref.invalidate(_threadsProvider(widget.spaceId));
            ref.invalidate(_invitesProvider(spaceId));
            await Future.wait([
              _refreshSpaceDetail(),
              ref.read(_threadsProvider(spaceId).future),
              ref.read(_invitesProvider(spaceId).future),
            ]);
          },
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
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
                    onRetry: () =>
                        _invalidateSpaceDetail(),
                  ),
                ),
                data: (space) => _SpaceHeaderCard(
                  space: space,
                  onCreateThread: () => _showCreateThreadDialog(context, ref),
                  onInviteMember: () => _openInviteScreen(context),
                  onAddMember: institutionId != null
                      ? () => _showAddInstitutionMemberDialog(
                            context,
                            institutionId,
                          )
                      : null,
                  onRename: () => _renameSpace(context, ref, space),
                  onArchive: () => _archiveSpace(context, ref),
                ),
              ),
              const SizedBox(height: AuraSpace.s14),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AuraSurface.divider),
                  borderRadius: BorderRadius.circular(AuraRadius.card),
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
                constraints: const BoxConstraints(minHeight: 400),
                child: SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.55 > 400
                      ? MediaQuery.sizeOf(context).height * 0.55
                      : 400,
                  child: TabBarView(
                    children: [
                      _ThreadsTab(
                        spaceId: spaceId,
                        institutionId: widget.institutionId,
                        threadsAsync: threadsAsync,
                        onCreateThread: () =>
                            _showCreateThreadDialog(context, ref),
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
        ),
      ),
    );
  }

  Future<void> _showCreateThreadDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => _CreateThreadDialog(spaceId: widget.spaceId),
    );

    if (created == true) {
      ref.invalidate(_threadsProvider(widget.spaceId));
      _invalidateSpaceDetail();
    }
  }

  Future<void> _renameSpace(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> space,
  ) async {
    final currentName = _pickString(space, const ['name', 'title']);
    final controller = TextEditingController(text: currentName);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename space'),
        content: SizedBox(
          width: 400,
          child: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Space name'),
          ),
        ),
        actions: [
          AuraGhostButton(
            label: 'Cancel',
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          AuraPrimaryButton(
            label: 'Rename',
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: Icons.check_rounded,
          ),
        ],
      ),
    );
    controller.dispose();
    if (confirmed != true || !mounted) return;
    final newName = controller.text.trim();
    if (newName.isEmpty || newName == currentName) return;
    try {
      await ref.read(spacesRepositoryProvider).updateSpace(
            widget.spaceId,
            name: newName,
          );
      _invalidateSpaceDetail();
    } catch (e) {
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not rename space: $e')),
      );
    }
  }

  Future<void> _archiveSpace(BuildContext context, WidgetRef ref) async {
    final institutionId = widget.institutionId;
    final isInstitutional = institutionId != null && institutionId.isNotEmpty;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archive space'),
        content: Text(
          isInstitutional
              // Institutional lifecycle action — genuinely affects every
              // member, matching INSTITUTION_SPACE_MEMBERSHIP_DOCTRINE.md.
              ? 'Archiving this space is an institutional action. It will '
                  'leave active discovery for every member and stop '
                  'accepting new activity. Its content remains an '
                  'institutional record and can be restored later.'
              // Personal organization state — affects only the caller.
              : 'Archiving hides this space from your own space list. '
                  'Other members keep seeing it in theirs. You can '
                  'unarchive it later.',
        ),
        actions: [
          AuraGhostButton(
            label: 'Cancel',
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          AuraPrimaryButton(
            label: 'Archive',
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: Icons.archive_outlined,
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      // Institution Space archive is an institutional lifecycle action,
      // governed separately from a personal Space's own archive path —
      // this must call the institution-scoped authority, never the
      // generic space PATCH (which has no institutional-archive field).
      if (isInstitutional) {
        await ref
            .read(institutionsRepositoryProvider)
            .archiveInstitutionSpace(institutionId, widget.spaceId);
      } else {
        await ref
            .read(spacesRepositoryProvider)
            .setPersonalArchived(widget.spaceId, archived: true);
      }
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      context.go('/me/correspondence');
    } catch (e) {
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not archive space: $e')),
      );
    }
  }

  Future<void> _openInviteScreen(BuildContext context) async {
    await context.push(
      '/invite/create?destinationType=JOIN_SPACE'
      '&spaceId=${Uri.encodeComponent(widget.spaceId)}'
      '&returnTo=${Uri.encodeComponent('/me/correspondence/${widget.spaceId}')}',
    );
    if (!mounted) return;
    _invalidateSpaceDetail();
    ref.invalidate(_threadsProvider(widget.spaceId));
    ref.invalidate(_invitesProvider(widget.spaceId));
  }

  /// Institution Space Membership Doctrine -- "Add Member": lets an
  /// authorized admin pick an ELIGIBLE EXISTING institution member and
  /// grant immediate Space membership, through
  /// `InstitutionsRepository.addInstitutionSpaceMember` (the governed
  /// direct-add authority) -- never a frontend shortcut that manipulates
  /// membership state directly, and never the Invite Person lifecycle.
  Future<void> _showAddInstitutionMemberDialog(
    BuildContext context,
    String institutionId,
  ) async {
    final existingMemberIds = <String>{};
    final spaceData =
        ref.read(_institutionSpaceDetailProvider((
          institutionId: institutionId,
          spaceId: widget.spaceId,
        ))).valueOrNull;
    final members = spaceData?['members'];
    if (members is List) {
      for (final m in members) {
        if (m is Map) {
          final uid = _pickString(Map<String, dynamic>.from(m), const ['userId']);
          if (uid.isNotEmpty) existingMemberIds.add(uid);
        }
      }
    }

    final added = await showDialog<bool>(
      context: context,
      builder: (_) => _AddInstitutionMemberDialog(
        institutionId: institutionId,
        spaceId: widget.spaceId,
        excludeUserIds: existingMemberIds,
      ),
    );

    if (added == true && mounted) {
      _invalidateSpaceDetail();
    }
  }
}

class _AddInstitutionMemberDialog extends ConsumerStatefulWidget {
  const _AddInstitutionMemberDialog({
    required this.institutionId,
    required this.spaceId,
    required this.excludeUserIds,
  });

  final String institutionId;
  final String spaceId;
  final Set<String> excludeUserIds;

  @override
  ConsumerState<_AddInstitutionMemberDialog> createState() =>
      _AddInstitutionMemberDialogState();
}

class _AddInstitutionMemberDialogState
    extends ConsumerState<_AddInstitutionMemberDialog> {
  List<Map<String, dynamic>>? _candidates;
  String? _loadError;
  String? _addingUserId;
  String? _addError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final repo = ref.read(institutionsRepositoryProvider);
      final result = await repo.listMembers(widget.institutionId);
      final rows = result['members'];
      final members = rows is List
          ? rows
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .where((m) {
                final uid = _pickString(m, const ['userId', 'id']);
                return uid.isNotEmpty && !widget.excludeUserIds.contains(uid);
              })
              .toList()
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() => _candidates = members);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = 'Could not load institution members: $e');
    }
  }

  Future<void> _add(String userId) async {
    setState(() {
      _addingUserId = userId;
      _addError = null;
    });
    try {
      await ref
          .read(institutionsRepositoryProvider)
          .addInstitutionSpaceMember(widget.institutionId, widget.spaceId, userId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _addingUserId = null;
        _addError = 'Could not add member: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add member'),
      content: SizedBox(
        width: 420,
        height: 360,
        child: _buildBody(),
      ),
      actions: [
        AuraGhostButton(
          label: 'Close',
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_loadError != null) {
      return _ErrorBlock(title: 'Could not load members', body: _loadError!, onRetry: _load);
    }
    final candidates = _candidates;
    if (candidates == null) {
      return const _LoadingBlock(label: 'Loading institution members...');
    }
    if (candidates.isEmpty) {
      return const Center(
        child: Text(
          'Every eligible institution member is already in this space.',
          textAlign: TextAlign.center,
          style: AuraText.body,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_addError != null) ...[
          Text(_addError!, style: AuraText.small.copyWith(color: AuraSurface.coRose)),
          const SizedBox(height: AuraSpace.s8),
        ],
        Expanded(
          child: ListView.separated(
            itemCount: candidates.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: AuraSurface.divider),
            itemBuilder: (_, i) {
              final m = candidates[i];
              final userMap = m['user'] is Map
                  ? Map<String, dynamic>.from(m['user'] as Map)
                  : m;
              final userId = _pickString(m, const ['userId', 'id']);
              final name = _pickString(userMap, const ['displayName', 'name']);
              final handle = _pickString(userMap, const ['handle']);
              final avatarUrl = _pickString(userMap, const ['avatarUrl', 'imageUrl']);
              final busy = _addingUserId == userId;
              return ListTile(
                leading: _IdentityAvatar(label: name.isEmpty ? handle : name, imageUrl: avatarUrl),
                title: Text(name.isEmpty ? (handle.isEmpty ? userId : '@$handle') : name),
                subtitle: handle.isNotEmpty && name.isNotEmpty ? Text('@$handle') : null,
                trailing: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_circle_outline, size: 20),
                onTap: (_addingUserId != null) ? null : () => _add(userId),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ThreadsTab extends StatelessWidget {
  const _ThreadsTab({
    required this.spaceId,
    this.institutionId,
    required this.threadsAsync,
    required this.onCreateThread,
  });

  final String spaceId;
  final String? institutionId;
  final AsyncValue<List<Map<String, dynamic>>> threadsAsync;
  final VoidCallback onCreateThread;

  @override
  Widget build(BuildContext context) {
    final isInstitutional = institutionId != null && institutionId!.isNotEmpty;
    final archivedRoute = isInstitutional
        ? '/institution/$institutionId/spaces/$spaceId/archived-threads'
        : '/me/correspondence/$spaceId/archived-threads';
    return ListView(
      children: [
        Row(
          children: [
            const Expanded(child: Text('Threads', style: AuraText.title)),
            // Domain 13 — discoverability for both personally- and
            // globally-archived conversations in this Space.
            GestureDetector(
              onTap: () => context.push(archivedRoute),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.archive_outlined, size: 14, color: AuraSurface.muted),
                  const SizedBox(width: AuraSpace.s4),
                  Text('Archived', style: AuraText.small.copyWith(color: AuraSurface.muted)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AuraSpace.s10),
        threadsAsync.when(
          loading: () =>
              const AuraCard(child: _LoadingBlock(label: 'Loading threads...')),
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
                    const Text('No threads yet', style: AuraText.title),
                    const SizedBox(height: AuraSpace.s8),
                    const Text(
                      'Create the first thread in this space.',
                      style: AuraText.body,
                    ),
                    const SizedBox(height: AuraSpace.s12),
                    AuraSecondaryButton(
                      label: 'Create thread',
                      onPressed: onCreateThread,
                      icon: Icons.add_rounded,
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: [
                for (var i = 0; i < threads.length; i++) ...[
                  _ThreadTile(spaceId: spaceId, thread: threads[i]),
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
  const _MembersTab({required this.spaceAsync});

  final AsyncValue<Map<String, dynamic>> spaceAsync;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const Text('Members', style: AuraText.title),
        const SizedBox(height: AuraSpace.s10),
        spaceAsync.when(
          loading: () =>
              const AuraCard(child: _LoadingBlock(label: 'Loading members...')),
          error: (error, _) => AuraCard(
            child: _ErrorBlock(
              title: 'Could not load members',
              body: '$error',
              onRetry: () {},
            ),
          ),
          data: (space) {
            final members = _extractMembers(space);
            final memberCount = _pickInt(space, const [
              'memberCount',
              'membersCount',
            ]);

            if (members.isEmpty) {
              return AuraCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Members', style: AuraText.title),
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
        const Text('Invites', style: AuraText.title),
        const SizedBox(height: AuraSpace.s10),
        invitesAsync.when(
          loading: () =>
              const AuraCard(child: _LoadingBlock(label: 'Loading invites...')),
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
                    const Text('No invites yet', style: AuraText.title),
                    const SizedBox(height: AuraSpace.s8),
                    const Text(
                      'Create or review invitations connected to this space.',
                      style: AuraText.body,
                    ),
                    const SizedBox(height: AuraSpace.s12),
                    AuraSecondaryButton(
                      label: 'Add member',
                      onPressed: onInviteMember,
                      icon: Icons.person_add_alt_outlined,
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
                      final inviteId = _pickString(invites[i], const [
                        'id',
                        'inviteId',
                      ]);
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
  const _MediaTab({required this.spaceAsync});

  final AsyncValue<Map<String, dynamic>> spaceAsync;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const Text('Media', style: AuraText.title),
        const SizedBox(height: AuraSpace.s10),
        spaceAsync.when(
          loading: () =>
              const AuraCard(child: _LoadingBlock(label: 'Loading media...')),
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
              Expanded(child: Text(title, style: AuraText.title)),
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
    this.onAddMember,
    this.onRename,
    this.onArchive,
  });

  final Map<String, dynamic> space;
  final VoidCallback onCreateThread;
  final VoidCallback onInviteMember;

  /// Institution Space Membership Doctrine -- present only for institution
  /// spaces (a real institution identity was resolved). Direct membership
  /// grant for an eligible existing institution member; distinct from
  /// [onInviteMember]'s governed invitation lifecycle.
  final VoidCallback? onAddMember;
  final VoidCallback? onRename;
  final VoidCallback? onArchive;

  @override
  Widget build(BuildContext context) {
    final name = _pickString(space, const ['name', 'title']);
    final description = _pickString(space, const ['description', 'summary']);
    final visibility = _pickString(space, const ['visibility', 'type']);
    final memberCount = _pickInt(space, const ['memberCount', 'membersCount']);
    final threadCount = _pickInt(space, const ['threadCount', 'threadsCount']);
    // Cross-System Institutional Identity Coherence -- the owning
    // institution's canonical identity, when this is an institution space.
    final institution = space['institution'];
    final institutionName = institution is Map
        ? _pickString(Map<String, dynamic>.from(institution), const ['name'])
        : '';
    final institutionLogoUrl = institution is Map
        ? _pickString(Map<String, dynamic>.from(institution), const ['logoUrl'])
        : '';

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (institutionName.isNotEmpty) ...[
            Row(
              children: [
                _IdentityAvatar(
                  label: institutionName,
                  imageUrl: institutionLogoUrl,
                  radius: 12,
                ),
                const SizedBox(width: AuraSpace.s8),
                Text(
                  institutionName,
                  style: AuraText.small.copyWith(
                    color: AuraSurface.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AuraSpace.s8),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
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
              ),
              if (onRename != null || onArchive != null)
                PopupMenuButton<String>(
                  tooltip: 'Space options',
                  icon: const Icon(
                    Icons.more_horiz_rounded,
                    size: 18,
                    color: AuraSurface.muted,
                  ),
                  color: AuraSurface.card,
                  itemBuilder: (_) => [
                    if (onRename != null)
                      const PopupMenuItem(
                        value: 'rename',
                        child: Text('Rename space'),
                      ),
                    if (onArchive != null)
                      const PopupMenuItem(
                        value: 'archive',
                        child: Text('Archive space'),
                      ),
                  ],
                  onSelected: (value) {
                    if (value == 'rename') onRename?.call();
                    if (value == 'archive') onArchive?.call();
                  },
                ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s8),
            AuraTextBlock(description, style: AuraText.body),
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
              AuraPrimaryButton(
                label: 'New thread',
                onPressed: onCreateThread,
                icon: Icons.add_rounded,
              ),
              if (onAddMember != null)
                AuraSecondaryButton(
                  label: 'Add member',
                  onPressed: onAddMember,
                  icon: Icons.person_add_alt_outlined,
                ),
              AuraSecondaryButton(
                label: onAddMember != null ? 'Invite' : 'Add member',
                onPressed: onInviteMember,
                icon: Icons.mail_outline_rounded,
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
  ConsumerState<_CreateThreadDialog> createState() =>
      _CreateThreadDialogState();
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
      await ref
          .read(threadsRepositoryProvider)
          .createThread(spaceId: spaceId, title: title, kind: _kind);

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
                initialValue: _kind,
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
                      color: AuraSurface.coRose,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        AuraGhostButton(
          label: 'Cancel',
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
        ),
        AuraPrimaryButton(
          label: _submitting ? 'Creating…' : 'Create',
          onPressed: _submitting ? null : _submit,
          icon: Icons.add_rounded,
        ),
      ],
    );
  }
}

class _ThreadTile extends StatelessWidget {
  const _ThreadTile({required this.spaceId, required this.thread});

  final String spaceId;
  final Map<String, dynamic> thread;

  @override
  Widget build(BuildContext context) {
    final id = _pickString(thread, const ['id', 'threadId']);
    final title = _threadDisplayTitle(thread);
    final kind = _pickString(thread, const ['kind', 'type']);
    final archived = thread['archived'] == true || thread['archivedAt'] != null;
    final preview = _threadPreview(thread);
    final participantSummary = _threadParticipantSummary(thread);
    final participantRoleSummary = _threadParticipantRoleSummary(thread);
    final recentWeight = _threadRecentWeight(thread);

    return AuraCard(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: id.isEmpty
            ? null
            : () => context.push('/me/correspondence/$spaceId/thread/$id'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IdentityAvatar(
                label: title,
                imageUrl: _threadAvatarUrl(thread),
                radius: 22,
              ),
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
                        AuraTextBlock(
                          title,
                          style: AuraText.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (kind.isNotEmpty) _Pill(label: _humanizeLabel(kind)),
                        if (archived)
                          const _StatusPill(
                            label: 'Archived',
                            tone: _StatusTone.neutral,
                          ),
                        if (recentWeight.isNotEmpty)
                          _StatusPill(
                            label: recentWeight,
                            tone: _StatusTone.accent,
                          ),
                      ],
                    ),
                    if (participantSummary.isNotEmpty) ...[
                      const SizedBox(height: AuraSpace.s6),
                      AuraTextBlock(
                        participantSummary,
                        style: AuraText.small.copyWith(
                          color: AuraSurface.muted,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (participantRoleSummary.isNotEmpty) ...[
                      const SizedBox(height: AuraSpace.s4),
                      AuraTextBlock(
                        participantRoleSummary,
                        style: AuraText.small.copyWith(
                          color: AuraSurface.faint,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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
            ],
          ),
        ),
      ),
    );
  }
}

class _InviteTile extends StatelessWidget {
  const _InviteTile({required this.invite, required this.onRevoke});

  final Map<String, dynamic> invite;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final title = _inviteDisplayTitle(invite);
    final subtitle = _inviteDisplaySubtitle(invite);
    final role = _pickString(invite, const [
      'roleOffered',
      'role',
      'roleToGrant',
    ]);
    final status = _inviteStateLabel(invite);
    final token = _pickString(invite, const ['token', 'inviteToken']);
    final delivery = _pickString(invite, const [
      'deliveryChannel',
      'delivery_channel',
    ]);
    final canCopyLink = token.isNotEmpty && _inviteIsActive(invite);
    final canRevoke = _canRevokeInvite(invite);
    final tone = _inviteTone(invite);

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
                    AuraTextBlock(
                      title,
                      style: AuraText.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AuraSpace.s6),
                    AuraTextBlock(
                      subtitle,
                      style: AuraText.body,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
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
              _StatusPill(label: status, tone: tone),
              if (role.isNotEmpty)
                _MetaChip(label: 'Role', value: _humanizeLabel(role)),
              if (delivery.isNotEmpty)
                _MetaChip(label: 'Delivery', value: _humanizeLabel(delivery)),
            ],
          ),
          if (canCopyLink || canRevoke) ...[
            const SizedBox(height: AuraSpace.s12),
            Wrap(
              spacing: AuraSpace.s10,
              runSpacing: AuraSpace.s10,
              children: [
                if (canCopyLink)
                  AuraSecondaryButton(
                    label: 'Copy link',
                    icon: Icons.copy_rounded,
                    onPressed: () async {
                      final link =
                          '${Uri.base.origin}/invite/accept?token=${Uri.encodeComponent(token)}';
                      await Clipboard.setData(ClipboardData(text: link));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Invite link copied.')),
                      );
                    },
                  ),
                if (canRevoke)
                  AuraSecondaryButton(
                    label: 'Cancel invite',
                    icon: Icons.close_rounded,
                    onPressed: onRevoke,
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
  const _MemberTile({required this.member});

  final Map<String, dynamic> member;

  @override
  Widget build(BuildContext context) {
    final name = _memberDisplayName(member);
    final handle = _pickString(member, const [
      'handle',
      'username',
      'userHandle',
    ]);
    final role = _pickString(member, const ['role', 'memberRole']);
    final subtitle = _memberSubtitle(member);
    final state = _pickString(member, const [
      'status',
      'membershipStatus',
      'state',
    ]);

    return AuraCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IdentityAvatar(label: name, imageUrl: _memberAvatarUrl(member)),
          const SizedBox(width: AuraSpace.s12),
          Expanded(
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
                    if (role.isNotEmpty)
                      _MetaChip(label: 'Role', value: _humanizeLabel(role)),
                    if (state.isNotEmpty)
                      _StatusPill(
                        label: _humanizeLabel(state),
                        tone: _memberStateTone(state),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _threadDisplayTitle(Map<String, dynamic> thread) {
  return CorrespondenceIdentity.threadTitle(thread);
}

String _threadPreview(Map<String, dynamic> thread) {
  return CorrespondenceIdentity.threadPreview(thread);
}

String _threadParticipantSummary(Map<String, dynamic> thread) {
  return CorrespondenceIdentity.threadParticipantSummary(thread);
}

String _threadParticipantRoleSummary(Map<String, dynamic> thread) {
  return CorrespondenceIdentity.threadParticipantRoleSummary(thread);
}

String _threadRecentWeight(Map<String, dynamic> thread) {
  return CorrespondenceIdentity.threadRecentWeight(thread);
}

String _memberDisplayName(Map<String, dynamic> member) {
  return CorrespondenceIdentity.memberDisplayName(member);
}

String _memberSubtitle(Map<String, dynamic> member) {
  return CorrespondenceIdentity.memberSubtitle(member);
}

String _inviteDisplayTitle(Map<String, dynamic> invite) {
  return CorrespondenceIdentity.inviteTitle(invite);
}

String _inviteDisplaySubtitle(Map<String, dynamic> invite) {
  return CorrespondenceIdentity.inviteSubtitle(invite);
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

bool _canRevokeInvite(Map<String, dynamic> invite) => _inviteIsActive(invite);

List<Map<String, dynamic>> _extractParticipants(
  Map<String, dynamic> source, {
  List<String> keys = const [
    'participants',
    'members',
    'participantList',
    'memberList',
    'users',
  ],
}) {
  final out = <Map<String, dynamic>>[];
  for (final key in keys) {
    final value = source[key];
    if (value is! List) continue;
    for (final raw in value) {
      if (raw is! Map) continue;
      final map = Map<String, dynamic>.from(raw);
      if (out.any(
        (existing) =>
            _pickString(existing, const ['id', 'userId', '_id']) ==
                _pickString(map, const ['id', 'userId', '_id']) &&
            _pickString(map, const ['id', 'userId', '_id']).isNotEmpty,
      )) {
        continue;
      }
      out.add(map);
    }
  }
  return out;
}

String _humanizeLabel(String value) {
  return CorrespondenceIdentity.humanize(value);
}

String _inviteStateLabel(Map<String, dynamic> invite) {
  final status = _pickString(invite, const ['status']);
  if (status.isEmpty) return 'Pending';
  return _humanizeLabel(status);
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

_StatusTone _memberStateTone(String state) {
  switch (state.trim().toUpperCase()) {
    case 'ACTIVE':
    case 'ACCEPTED':
      return _StatusTone.positive;
    case 'INVITED':
    case 'PENDING':
      return _StatusTone.accent;
    default:
      return _StatusTone.neutral;
  }
}

String _inviteAvatarUrl(Map<String, dynamic> invite) {
  return _pickNested(invite, const [
    ['recipient', 'avatarUrl'],
    ['recipientUser', 'avatarUrl'],
    ['invitedUser', 'avatarUrl'],
    ['recipientProfile', 'avatarUrl'],
  ]);
}

String _memberAvatarUrl(Map<String, dynamic> member) {
  return _pickString(member, const ['avatarUrl', 'imageUrl', 'photoUrl']);
}

String _threadAvatarUrl(Map<String, dynamic> thread) {
  final participants = _extractParticipants(thread);
  for (final participant in participants) {
    final url = _memberAvatarUrl(participant);
    if (url.isNotEmpty) return url;
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

enum _StatusTone { neutral, accent, positive, negative }

/// Space-screen status pill — wraps canonical SubstrateChip mapping
/// the local `_StatusTone` enum to canonical chip states.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.tone});

  final String label;
  final _StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final state = switch (tone) {
      _StatusTone.positive => SubstrateChipState.verdant,
      _StatusTone.negative => SubstrateChipState.rose,
      _StatusTone.accent => SubstrateChipState.teal,
      _StatusTone.neutral => SubstrateChipState.mist,
    };
    return SubstrateChip(label: label, state: state);
  }
}

class _IdentityAvatar extends StatelessWidget {
  const _IdentityAvatar({
    required this.label,
    this.imageUrl = '',
    this.radius = 20,
  });

  final String label;
  final String imageUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    // AXR-1 identity precedence — delegate to the canonical AuraAvatar:
    // photo first, initials fallback, and (unlike the raw CircleAvatar
    // this replaced) a broken image URL degrades to initials instead of
    // a blank circle.
    return AuraAvatar(name: label, imageUrl: imageUrl, size: radius * 2);
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
        AuraSecondaryButton(
          label: ProductLabels.of(ProductAction.retry),
          icon: Icons.refresh_rounded,
          onPressed: onRetry,
        ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, required this.value});

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
        borderRadius: BorderRadius.circular(AuraRadius.pill),
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
    return SubstrateChip(label: label, state: SubstrateChipState.mist);
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
    images: _pickInt(nested ?? space, const [
      'imagesCount',
      'imageCount',
      'images',
    ]),
    documents: _pickInt(nested ?? space, const [
      'documentsCount',
      'documentCount',
      'documents',
      'docsCount',
    ]),
    audio: _pickInt(nested ?? space, const [
      'audioCount',
      'audiosCount',
      'audio',
    ]),
    files: _pickInt(nested ?? space, const [
      'filesCount',
      'fileCount',
      'files',
    ]),
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
