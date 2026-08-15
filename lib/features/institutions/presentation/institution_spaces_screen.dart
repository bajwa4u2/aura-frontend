import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/directory/directory_entry.dart';
import '../../../core/directory/member_picker_field.dart';
import '../../../core/institutions/institution_access_provider.dart';
import '../../../core/net/dio_provider.dart';
import '../../../core/product/product_language.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../data/institutions_repository.dart';
import '../ui/institution_ds.dart';
import 'institution_page.dart';

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
  bool get _isAdmin =>
      ref.watch(institutionIdentityProvider)?.isAdmin ?? false;

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

  Color _visibilityColor(String v) {
    switch (v.toUpperCase()) {
      case 'DISCOVERABLE': return AuraSurface.coVerdant;
      case 'INVITE_ONLY': return AuraSurface.accentText;
      case 'PRIVATE': return AuraSurface.muted;
      default: return AuraSurface.muted;
    }
  }

  Color _visibilityBg(String v) {
    switch (v.toUpperCase()) {
      case 'DISCOVERABLE': return AuraSurface.coVerdant.withValues(alpha: 0.16);
      case 'INVITE_ONLY': return AuraSurface.accentSoft;
      case 'PRIVATE': return AuraSurface.subtle;
      default: return AuraSurface.subtle;
    }
  }

  Widget _buildCreateForm() {
    return Container(
      margin: const EdgeInsets.only(bottom: AuraSpace.s16),
      padding: const EdgeInsets.all(AuraSpace.s16),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(color: AuraSurface.accentText.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Text('New space', style: AuraText.subtitle)),
              GestureDetector(
                onTap: () => setState(() {
                  _showCreate = false;
                  _createError = null;
                  // MemberPickerField unmounts when the form is hidden and
                  // remounts empty (no initialSelected passed) next time --
                  // clear the parent's mirror too so it can never go stale
                  // relative to what the picker will visibly show.
                  _selectedMembers = const [];
                  _pickerResetToken++;
                }),
                child: const Icon(Icons.close, size: 18, color: AuraSurface.muted),
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s14),
          TextFormField(
            controller: _titleController,
            style: AuraText.body,
            decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. General, Updates, Staff'),
          ),
          const SizedBox(height: AuraSpace.s12),
          TextFormField(
            controller: _descController,
            style: AuraText.body,
            maxLines: 2,
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
            Text(_createError!, style: AuraText.small.copyWith(color: AuraSurface.coRose)),
          ],
          const SizedBox(height: AuraSpace.s16),
          AuraPrimaryButton(
            label: _creating ? 'Creating…' : 'Create space',
            onPressed: _creating ? null : _create,
            icon: Icons.add_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildSpaceTile(Map<String, dynamic> space) {
    final id = space['id']?.toString() ?? '';
    final title = space['title']?.toString().trim() ?? '';
    final description = space['description']?.toString().trim() ?? '';
    final visibility = space['visibility']?.toString() ?? 'INVITE_ONLY';
    final memberCount = space['memberCount'] as int? ?? 0;
    final threadCount = space['threadCount'] as int? ?? 0;
    final isActing = _actingOn == id;

    return Container(
      margin: const EdgeInsets.only(bottom: AuraSpace.s10),
      padding: const EdgeInsets.all(AuraSpace.s16),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title.isNotEmpty ? title : 'Unnamed space', style: AuraText.body.copyWith(fontWeight: FontWeight.w700)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AuraSpace.s8, vertical: AuraSpace.s4),
                decoration: BoxDecoration(
                  color: _visibilityBg(visibility),
                  borderRadius: BorderRadius.circular(AuraRadius.pill),
                ),
                child: Text(
                  _visibilityLabel(visibility),
                  style: AuraText.micro.copyWith(color: _visibilityColor(visibility), fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s6),
            Text(description, style: AuraText.small.copyWith(color: AuraSurface.muted, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: AuraSpace.s10),
          Row(
            children: [
              const Icon(Icons.people_outline, size: 12, color: AuraSurface.faint),
              const SizedBox(width: AuraSpace.s4),
              Text('$memberCount', style: AuraText.micro.copyWith(color: AuraSurface.faint)),
              const SizedBox(width: AuraSpace.s12),
              const Icon(Icons.chat_bubble_outline, size: 12, color: AuraSurface.faint),
              const SizedBox(width: AuraSpace.s4),
              Text('$threadCount threads', style: AuraText.micro.copyWith(color: AuraSurface.faint)),
              const Spacer(),
              if (isActing)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              else if (_showArchived) ...[
                // Archived is institutional lifecycle state, not deleted —
                // restore is the only action offered here; opening/joining
                // an archived space isn't ordinary active operation.
                GestureDetector(
                  onTap: () => _restore(id),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.unarchive_outlined, size: 14, color: AuraSurface.coVerdant),
                      const SizedBox(width: AuraSpace.s4),
                      Text('Restore', style: AuraText.small.copyWith(color: AuraSurface.coVerdant, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ] else ...[
                GestureDetector(
                  onTap: () => context.push(
                    '/institution/${widget.institutionId}/spaces/$id',
                  ),
                  child: Text('Open', style: AuraText.small.copyWith(color: AuraSurface.accentText, fontWeight: FontWeight.w700)),
                ),
                if (!_isAdmin) ...[
                  const SizedBox(width: AuraSpace.s12),
                  GestureDetector(
                    onTap: () => _join(id),
                    child: Text('Join', style: AuraText.small.copyWith(color: AuraSurface.coVerdant, fontWeight: FontWeight.w700)),
                  ),
                ],
                if (_isAdmin) ...[
                  const SizedBox(width: AuraSpace.s12),
                  GestureDetector(
                    onTap: () => _archive(id),
                    child: const Icon(Icons.archive_outlined, size: 16, color: AuraSurface.coRose),
                  ),
                ],
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const AuraLoadingState(message: 'Loading spaces…');
    if (_error != null) {
      return AuraErrorState(
        title: 'Could not load spaces',
        body: _error!,
        action: AuraSecondaryButton(label: ProductLabels.of(ProductAction.retry), onPressed: _load, icon: Icons.refresh_rounded),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_actionError != null) ...[
          Container(
            margin: const EdgeInsets.only(bottom: AuraSpace.s12),
            padding: const EdgeInsets.all(AuraSpace.s12),
            decoration: BoxDecoration(
              color: AuraSurface.coRose.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AuraRadius.md),
              border: Border.all(color: AuraSurface.coRose.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, size: 16, color: AuraSurface.coRose),
                const SizedBox(width: AuraSpace.s8),
                Expanded(child: Text(_actionError!, style: AuraText.small.copyWith(color: AuraSurface.coRose))),
                GestureDetector(onTap: () => setState(() => _actionError = null), child: const Icon(Icons.close, size: 16, color: AuraSurface.coRose)),
              ],
            ),
          ),
        ],
        if (_showCreate && _isAdmin) _buildCreateForm(),
        if (_isAdmin) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: AuraSpace.s12),
            child: GestureDetector(
              onTap: () {
                setState(() => _showArchived = !_showArchived);
                _load();
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _showArchived ? Icons.forum_outlined : Icons.archive_outlined,
                    size: 14,
                    color: AuraSurface.accentText,
                  ),
                  const SizedBox(width: AuraSpace.s6),
                  Text(
                    _showArchived ? 'Back to active spaces' : 'View archived spaces',
                    style: AuraText.small.copyWith(color: AuraSurface.accentText, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (_spaces.isEmpty && !_showCreate)
          InsEmptyState(
            icon: _showArchived ? Icons.archive_outlined : Icons.forum_outlined,
            title: _showArchived ? 'No archived spaces' : 'No spaces yet',
            description: _showArchived
                ? 'Spaces you archive show up here, restorable any time.'
                : 'Create one with New Space.',
          )
        else
          ..._spaces.map(_buildSpaceTile),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return InstitutionPage(
      title: 'Spaces',
      subtitle:
          'Coordinate internal groups, teams, and working rooms.',
      trailing: _isAdmin
          ? AuraPrimaryButton(
              label: _showCreate ? 'Hide form' : 'New Space',
              onPressed: () => setState(() {
                _showCreate = !_showCreate;
                _selectedMembers = const [];
                _pickerResetToken++;
              }),
              icon: _showCreate ? Icons.close_rounded : Icons.add_rounded,
            )
          : null,
      body: _buildBody(),
    );
  }
}
