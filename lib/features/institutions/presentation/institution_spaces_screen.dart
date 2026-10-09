import '../../../core/navigation/navigation_authority.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/directory/directory_entry.dart';
import '../../../core/directory/member_picker_field.dart';
import '../../../core/authority/capability_projection.dart';
import '../../../core/authority/authority_providers.dart';
import '../../../core/net/dio_provider.dart';
import '../../../core/product/product_language.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../data/institutions_repository.dart';
import '../workspace/workspace_page.dart';
import '../workspace/workspace_row_menu.dart';

class InstitutionSpacesScreen extends ConsumerStatefulWidget {
  const InstitutionSpacesScreen({
    super.key,
    required this.institutionId,
  });

  final String institutionId;

  @override
  ConsumerState<InstitutionSpacesScreen> createState() =>
      _InstitutionSpacesScreenState();
}

class _InstitutionSpacesScreenState extends ConsumerState<InstitutionSpacesScreen> {
  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _spaces = const [];

  bool _creating = false;
  String? _createError;
  bool _showCreate = false;

  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  String _visibility = 'INVITE_ONLY';
  List<DirectoryEntry> _selectedMembers = const [];
  String? _currentUserId;
  // Bumped after every successful create so MemberPickerField remounts
  // with fresh internal selection state instead of retaining stale
  // selections from the just-completed create.
  int _pickerResetToken = 0;

  String? _actingOn;
  String? _actionError;

  // Domain 13 — archived Institution Spaces are institutional lifecycle
  // state; browsing them is admin-only, same authority as archive/restore.
  bool _showArchived = false;

  InstitutionsRepository get _repo => ref.read(institutionsRepositoryProvider);

  /// Single source of truth for admin gating — never trust route query params.
  /// MAY THIS VIEWER MANAGE SPACES?
  ///
  /// The canonical question, asked of the canonical authority. The previous
  /// `identity.isAdmin` was a role label standing in for MANAGE_SPACES — which
  /// the backend actually enforces (`assertCapability(MANAGE_SPACES)`), and
  /// which an OWNER may delegate to a member who is not an admin at all.
  bool get _canManageSpaces =>
      ref.watch(capabilityProjectionProvider).presentationFor(
            ConsequentialAct.manageSpaces,
          ) ==
      ControlPresentation.available;

  @override
  void initState() {
    super.initState();
    _load();
    _loadCurrentUserId();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final spaces = await _repo.listInstitutionSpaces(
        widget.institutionId,
        scope: _showArchived ? 'archived' : 'active',
      );
      setState(() { _spaces = spaces; _loading = false; });
    } catch (e) {
      setState(() { _error = _message(e, 'Could not load spaces.'); _loading = false; });
    }
  }

  Future<void> _create() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) { setState(() => _createError = 'Space name is required.'); return; }
    setState(() { _creating = true; _createError = null; });
    try {
      await _repo.createInstitutionSpace(
        widget.institutionId,
        title: title,
        description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
        visibility: _visibility,
        participantIds: _selectedMembers
            .map((e) => e.userId)
            .where((id) => id.trim().isNotEmpty)
            .toSet()
            .toList(growable: false),
      );
      _titleController.clear();
      _descController.clear();
      setState(() {
        _creating = false;
        _showCreate = false;
        _visibility = 'INVITE_ONLY';
        _selectedMembers = const [];
        _pickerResetToken++;
      });
      await _load();
    } catch (e) {
      setState(() { _createError = _message(e, 'Could not create space.'); _creating = false; });
    }
  }

  /// Loads the institution's own active roster and resolves it through the
  /// canonical identity resolver -- the same `memberEntryFromMap` fix
  /// applied to Thread/personal-space creation. There is no server-side
  /// member search endpoint (`GET /institutions/:id/members` returns the
  /// full roster), so filtering is client-side, matching how
  /// `MemberPickerField`/`NewConversationScreen` already filter locally.
  Future<List<DirectoryEntry>> _loadInstitutionMemberCandidates() async {
    final raw = await _repo.listMembers(widget.institutionId);
    final members = raw['members'];
    if (members is! List) return const [];

    return members
        .whereType<Map>()
        .map((m) {
          final row = Map<String, dynamic>.from(m);
          final user = row['user'];
          return memberEntryFromMap({
            'userId': row['userId'],
            if (user is Map) ...Map<String, dynamic>.from(user),
          });
        })
        .whereType<DirectoryEntry>()
        .toList(growable: false);
  }

  Future<void> _loadCurrentUserId() async {
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/users/me');
      final data = res.data;
      final id = data is Map ? (data['id'] ?? data['data']?['id']) : null;
      if (mounted && id is String && id.trim().isNotEmpty) {
        setState(() => _currentUserId = id.trim());
      }
    } catch (_) {
      // Non-fatal: the backend already excludes the creating admin from
      // participantIds server-side, so this is purely a UX nicety (hiding
      // "yourself" from the picker), not a correctness requirement.
    }
  }

  Future<void> _join(String spaceId) async {
    if (_actingOn != null) return;
    setState(() { _actingOn = spaceId; _actionError = null; });
    try {
      await _repo.joinInstitutionSpace(widget.institutionId, spaceId);
      await _load();
    } catch (e) {
      setState(() { _actionError = _message(e, 'Could not join space.'); _actingOn = null; });
    }
  }

  Future<void> _archive(String spaceId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AuraSurface.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AuraRadius.card)),
        title: const Text('Archive space', style: AuraText.subtitle),
        content: Text('This space will be archived and members will lose access.', style: AuraText.body.copyWith(color: AuraSurface.muted)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text('Cancel', style: AuraText.small.copyWith(color: AuraSurface.muted))),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Archive', style: AuraText.small.copyWith(color: AuraSurface.coRose, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (_actingOn != null) return;
    setState(() { _actingOn = spaceId; _actionError = null; });
    try {
      await _repo.archiveInstitutionSpace(widget.institutionId, spaceId);
      await _load();
    } catch (e) {
      setState(() { _actionError = _message(e, 'Could not archive space.'); _actingOn = null; });
    }
  }

  // Domain 13 — governed restore, same institution-admin authority as
  // archive. No confirmation dialog: restoring is the safe direction.
  Future<void> _restore(String spaceId) async {
    if (_actingOn != null) return;
    setState(() { _actingOn = spaceId; _actionError = null; });
    try {
      await _repo.restoreInstitutionSpace(widget.institutionId, spaceId);
      await _load();
    } catch (e) {
      setState(() { _actionError = _message(e, 'Could not restore space.'); _actingOn = null; });
    }
  }

  String _message(Object error, String fallback) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        final msg = data['message']?.toString().trim() ?? '';
        if (msg.isNotEmpty) return msg;
      }
    }
    return fallback;
  }

  String _visibilityLabel(String v) {
    switch (v.toUpperCase()) {
      case 'DISCOVERABLE': return 'Public';
      case 'INVITE_ONLY': return 'Members';
      case 'PRIVATE': return 'Private';
      default: return v;
    }
  }

  void _closeCreate() => setState(() {
        _showCreate = false;
        _createError = null;
        // MemberPickerField unmounts when the form is hidden and
        // remounts empty (no initialSelected passed) next time --
        // clear the parent's mirror too so it can never go stale
        // relative to what the picker will visibly show.
        _selectedMembers = const [];
        _pickerResetToken++;
      });

  Widget _buildCreateForm() {
    return WorkspaceSection(
      title: 'New space',
      description: 'A room for a group, a team or a piece of work.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _titleController,
            style: AuraText.body,
            decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. General, Updates, Staff'),
          ),
          const SizedBox(height: AuraSpace.s12),
          TextFormField(
            controller: _descController,
            style: AuraText.body,
            maxLines: null,
            decoration: const InputDecoration(labelText: 'Description (optional)', hintText: 'What is this space for?'),
          ),
          const SizedBox(height: AuraSpace.s12),
          Row(
            children: [
              Text('Visibility', style: AuraText.small.copyWith(color: AuraSurface.muted, fontWeight: FontWeight.w600)),
              const SizedBox(width: AuraSpace.s16),
              Expanded(
                child: DropdownButton<String>(
                  value: _visibility,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'DISCOVERABLE', child: Text('Public')),
                    DropdownMenuItem(value: 'INVITE_ONLY', child: Text('Members only')),
                    DropdownMenuItem(value: 'PRIVATE', child: Text('Admins only')),
                  ],
                  onChanged: (v) { if (v != null) setState(() => _visibility = v); },
                ),
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s14),
          Text(
            'Add members (optional)',
            style: AuraText.small.copyWith(color: AuraSurface.muted, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AuraSpace.s8),
          // Identity Foundation Phase 1 -- institution-space member
          // selection. Scoped to this institution's own active roster
          // (not the whole platform), keeping creation-time membership
          // consistent with the existing INVITE_ONLY join rule. Reuses the
          // same canonical DirectoryEntry/memberEntryFromMap resolver
          // Thread/personal-space creation already uses.
          MemberPickerField(
            key: ValueKey('institution-space-picker-${widget.institutionId}-$_pickerResetToken'),
            loadCandidates: _loadInstitutionMemberCandidates,
            excludeUserIds: _currentUserId == null ? const {} : {_currentUserId!},
            onSelectionChanged: (entries) => setState(() => _selectedMembers = entries),
            searchHintText: 'Search this institution\'s members',
            emptyLabel: 'No other institution members yet.',
            errorLabel: 'Could not load institution members.',
          ),
          if (_createError != null) ...[
            const SizedBox(height: AuraSpace.s8),
            Text(_createError!, style: AuraText.small.copyWith(color: AuraSurface.dangerInk)),
          ],
          const SizedBox(height: AuraSpace.s16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _creating ? null : _closeCreate,
                style: TextButton.styleFrom(foregroundColor: AuraSurface.muted),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: AuraSpace.s8),
              WorkspacePrimaryButton(
                action: WorkspaceAction(
                  label: _creating ? 'Creating…' : 'Create space',
                  icon: Icons.add_rounded,
                  onPressed: _creating ? null : _create,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// One row per space (DD-43): name; description, members and threads;
  /// who can see it; every other act under the row's menu.
  Widget _buildSpaceRow(Map<String, dynamic> space) {
    final id = space['id']?.toString() ?? '';
    final title = space['title']?.toString().trim() ?? '';
    final description = space['description']?.toString().trim() ?? '';
    final visibility = space['visibility']?.toString() ?? 'INVITE_ONLY';
    final memberCount = space['memberCount'] as int? ?? 0;
    final threadCount = space['threadCount'] as int? ?? 0;
    final isMember = space['viewerIsMember'] == true;
    void open() => context.push(
          NavigationAuthority.institutionSpaceRoute(
            widget.institutionId,
            // The Space's product address, falling back to its id only
            // when it has none — an id still resolves and canonicalizes
            // on arrival, so the link works either way.
            (space['slug']?.toString().trim().isNotEmpty ?? false) ? space['slug'].toString() : id,
          ),
        );

    final actions = <WorkspaceAction>[
      // Archived is institutional lifecycle state, not deleted — restore is
      // the only action offered; opening or joining an archived space isn't
      // ordinary active operation.
      if (_showArchived)
        WorkspaceAction(label: 'Restore', icon: Icons.unarchive_outlined, onPressed: () => _restore(id))
      else ...[
        WorkspaceAction(label: 'Open', icon: Icons.open_in_new_rounded, onPressed: open),
        // JOIN IS RESOURCE MEMBERSHIP, NOT AUTHORITY: the server reports
        // whether this viewer belongs to the space.
        if (!isMember) WorkspaceAction(label: 'Join', icon: Icons.login_rounded, onPressed: () => _join(id)),
        if (_canManageSpaces)
          WorkspaceAction(label: 'Archive', icon: Icons.archive_outlined, destructive: true, onPressed: () => _archive(id)),
      ],
    ];

    return WorkspaceRow(
      leading: WorkspaceIcon(_showArchived ? Icons.archive_outlined : Icons.forum_outlined),
      title: title.isNotEmpty ? title : 'Unnamed space',
      context: [
        if (description.isNotEmpty) description,
        memberCount == 1 ? '1 member' : '$memberCount members',
        threadCount == 1 ? '1 thread' : '$threadCount threads',
      ].join(' · '),
      pill: _showArchived
          ? const WorkspacePill(label: 'Archived')
          : WorkspacePill(label: _visibilityLabel(visibility)),
      trailing: _actingOn == id
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : WorkspaceRowMenu(actions: actions),
      onTap: _showArchived ? null : open,
    );
  }

  List<Widget> _content() {
    if (_error != null) {
      return [
        WorkspaceEmpty(
          icon: Icons.error_outline_rounded,
          title: 'Could not load spaces',
          body: _error!,
          action: WorkspaceAction(label: ProductLabels.of(ProductAction.retry), icon: Icons.refresh_rounded, onPressed: _load),
        ),
      ];
    }
    return [
      if (_actionError != null)
        WorkspaceRow(
          leading: const WorkspaceIcon(Icons.error_outline_rounded, tone: WorkspaceTone.problem),
          title: _actionError!,
          emphasis: WorkspaceTone.problem,
          trailing: IconButton(
            tooltip: 'Dismiss',
            icon: const Icon(Icons.close_rounded, size: 18, color: AuraSurface.muted),
            onPressed: () => setState(() => _actionError = null),
          ),
        ),
      if (_showCreate && _canManageSpaces) _buildCreateForm(),
      if (_spaces.isEmpty && !_showCreate)
        _showArchived
            ? const WorkspaceEmpty(
                icon: Icons.archive_outlined,
                title: 'No archived spaces',
                body: 'Spaces you archive show up here, restorable any time.',
              )
            : WorkspaceEmpty(
                icon: Icons.forum_outlined,
                title: 'No spaces yet',
                body: 'Spaces are rooms for a group, a team or a piece of work.',
                action: _canManageSpaces
                    ? WorkspaceAction(label: 'New space', icon: Icons.add_rounded, onPressed: _openCreate)
                    : null,
              )
      else
        ..._spaces.map(_buildSpaceRow),
    ];
  }

  void _openCreate() => setState(() {
        _showCreate = true;
        _selectedMembers = const [];
        _pickerResetToken++;
      });

  @override
  Widget build(BuildContext context) {
    final tab = _showArchived ? 'archived' : 'active';
    return WorkspacePage(
      type: WorkspacePageType.collection,
      title: 'Spaces',
      purpose: 'Rooms for internal groups, teams and working conversations.',
      // While the form is open its own Create is the one gold action.
      primary: _canManageSpaces && !_showCreate
          ? WorkspaceAction(label: 'New space', icon: Icons.add_rounded, onPressed: _openCreate)
          : null,
      // Domain 13 — archived spaces are lifecycle state; browsing them is
      // the same authority as archive and restore.
      tabs: _canManageSpaces
          ? [
              WorkspaceTab(id: 'active', label: 'Active', count: !_loading && !_showArchived ? _spaces.length : null),
              WorkspaceTab(id: 'archived', label: 'Archived', count: !_loading && _showArchived ? _spaces.length : null),
            ]
          : const [],
      selectedTab: tab,
      onTab: (id) {
        if (id == tab) return;
        setState(() => _showArchived = id == 'archived');
        _load();
      },
      loading: _loading,
      children: _content(),
    );
  }
}
