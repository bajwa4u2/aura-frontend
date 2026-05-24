import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../data/institutions_repository.dart';
import '../ui/institution_ds.dart';
import 'institution_page.dart';

class InstitutionMembersScreen extends ConsumerStatefulWidget {
  const InstitutionMembersScreen({super.key, required this.institutionId});

  final String institutionId;

  @override
  ConsumerState<InstitutionMembersScreen> createState() =>
      _InstitutionMembersScreenState();
}

class _InstitutionMembersScreenState
    extends ConsumerState<InstitutionMembersScreen> {
  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _members = const [];
  String _callerRole = '';
  String? _removing;
  String? _removeError;
  String? _updating;
  String? _updateError;

  InstitutionsRepository get _repo =>
      ref.read(institutionsRepositoryProvider);

  bool get _isAdmin {
    final r = _callerRole.toUpperCase();
    return r == 'ADMIN' || r == 'OWNER';
  }

  bool get _isOwner => _callerRole.toUpperCase() == 'OWNER';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await _repo.listMembers(widget.institutionId);
      final rawMembers = data['members'];
      final members = rawMembers is List
          ? rawMembers.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];
      setState(() {
        _members = members;
        _callerRole = (data['callerRole'] ?? '').toString().trim();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = _message(e, 'Could not load members.');
        _loading = false;
      });
    }
  }

  Future<void> _remove(String userId) async {
    if (_removing != null) return;
    setState(() {
      _removing = userId;
      _removeError = null;
    });

    try {
      await _repo.removeMember(widget.institutionId, userId);
      await _load();
    } catch (e) {
      setState(() {
        _removeError = _message(e, 'Could not remove member.');
        _removing = null;
      });
    }
  }

  Future<void> _changeRole(String userId, String newRole) async {
    if (_updating != null) return;
    setState(() {
      _updating = userId;
      _updateError = null;
    });

    try {
      await _repo.updateMemberRole(widget.institutionId, userId, newRole);
      await _load();
    } catch (e) {
      setState(() {
        _updateError = _message(e, 'Could not update role.');
        _updating = null;
      });
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

  String _roleBadge(String role) {
    switch (role.toUpperCase()) {
      case 'OWNER':
        return 'Owner';
      case 'ADMIN':
        return 'Admin';
      case 'EDITOR':
        return 'Editor';
      default:
        return 'Member';
    }
  }

  Color _roleColor(String role) {
    switch (role.toUpperCase()) {
      case 'OWNER':
        return AuraSurface.coVerdant;
      case 'ADMIN':
        return AuraSurface.accentText;
      case 'EDITOR':
        return AuraSurface.coSun;
      default:
        return AuraSurface.muted;
    }
  }

  Color _roleBg(String role) {
    switch (role.toUpperCase()) {
      case 'OWNER':
        return AuraSurface.coVerdant.withValues(alpha: 0.16);
      case 'ADMIN':
        return AuraSurface.accentSoft;
      case 'EDITOR':
        return AuraSurface.coSun.withValues(alpha: 0.16);
      default:
        return AuraSurface.subtle;
    }
  }

  Widget _buildMemberTile(Map<String, dynamic> member) {
    final user = member['user'] is Map
        ? Map<String, dynamic>.from(member['user'] as Map)
        : <String, dynamic>{};
    final memberId = member['userId']?.toString() ?? '';
    final displayName = user['displayName']?.toString().trim() ?? '';
    final handle = user['handle']?.toString().trim() ?? '';
    final role = member['role']?.toString().trim() ?? 'MEMBER';
    final isRemoving = _removing == memberId;
    final isUpdating = _updating == memberId;
    final isBusy = isRemoving || isUpdating;

    final nameOrHandle = displayName.isNotEmpty ? displayName : (handle.isNotEmpty ? '@$handle' : 'Unknown');

    return Container(
      margin: const EdgeInsets.only(bottom: AuraSpace.s8),
      padding: const EdgeInsets.all(AuraSpace.s14),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Row(
        children: [
          AuraAvatar(name: nameOrHandle, size: 36),
          const SizedBox(width: AuraSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nameOrHandle,
                  style: AuraText.small.copyWith(fontWeight: FontWeight.w700),
                ),
                if (handle.isNotEmpty)
                  Text(
                    '@$handle',
                    style: AuraText.micro.copyWith(color: AuraSurface.muted),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AuraSpace.s8,
              vertical: AuraSpace.s4,
            ),
            decoration: BoxDecoration(
              color: _roleBg(role),
              borderRadius: BorderRadius.circular(AuraRadius.pill),
            ),
            child: Text(
              _roleBadge(role),
              style: AuraText.micro.copyWith(
                color: _roleColor(role),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (_isAdmin) ...[
            const SizedBox(width: AuraSpace.s4),
            if (isBusy)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (role.toUpperCase() == 'OWNER')
              // OWNER is the highest tier; cannot be demoted in UI.
              const Tooltip(
                message: 'Owners cannot be demoted from the workspace UI',
                child: Icon(
                  Icons.lock_outline_rounded,
                  size: 16,
                  color: AuraSurface.faint,
                ),
              )
            else
              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert,
                  size: 18,
                  color: AuraSurface.muted,
                ),
                tooltip: 'Member options',
                color: AuraSurface.card,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AuraRadius.md),
                  side: const BorderSide(color: AuraSurface.divider),
                ),
                itemBuilder: (_) => [
                  if (_isOwner && role.toUpperCase() != 'OWNER')
                    PopupMenuItem(
                      value: 'MAKE_OWNER',
                      child: Text(
                        'Promote to Owner',
                        style: AuraText.small
                            .copyWith(color: AuraSurface.coVerdant),
                      ),
                    ),
                  if (role.toUpperCase() != 'ADMIN' &&
                      role.toUpperCase() != 'OWNER')
                    PopupMenuItem(
                      value: 'PROMOTE',
                      child: Text(
                        'Promote to Admin',
                        style: AuraText.small.copyWith(color: AuraSurface.accentText),
                      ),
                    ),
                  if (role.toUpperCase() == 'ADMIN')
                    PopupMenuItem(
                      value: 'DEMOTE',
                      child: Text(
                        'Demote to Member',
                        style: AuraText.small.copyWith(color: AuraSurface.coSun),
                      ),
                    ),
                  if (role.toUpperCase() == 'MEMBER')
                    const PopupMenuItem(
                      value: 'MAKE_EDITOR',
                      child: Text('Make Editor', style: AuraText.small),
                    ),
                  if (role.toUpperCase() == 'EDITOR')
                    const PopupMenuItem(
                      value: 'MAKE_MEMBER',
                      child: Text('Demote to Member', style: AuraText.small),
                    ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'REMOVE',
                    child: Text(
                      'Remove',
                      style: AuraText.small.copyWith(color: AuraSurface.coRose),
                    ),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'REMOVE') {
                    _confirmRemove(memberId, nameOrHandle);
                  } else if (value == 'MAKE_OWNER') {
                    _changeRole(memberId, 'OWNER');
                  } else if (value == 'PROMOTE') {
                    _changeRole(memberId, 'ADMIN');
                  } else if (value == 'DEMOTE' || value == 'MAKE_MEMBER') {
                    _changeRole(memberId, 'MEMBER');
                  } else if (value == 'MAKE_EDITOR') {
                    _changeRole(memberId, 'EDITOR');
                  }
                },
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmRemove(String userId, String name) async {
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AuraSurface.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AuraRadius.card),
        ),
        title: const Text('Remove member', style: AuraText.subtitle),
        content: Text(
          'Remove $name from this institution? This cannot be undone.',
          style: AuraText.body.copyWith(color: AuraSurface.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: AuraText.small.copyWith(color: AuraSurface.muted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Remove',
              style: AuraText.small.copyWith(
                color: AuraSurface.coRose,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) await _remove(userId);
  }

  Widget _buildBody() {
    if (_loading) {
      return const AuraLoadingState(message: 'Loading members…');
    }

    if (_error != null) {
      return AuraErrorState(
        title: 'Could not load members',
        body: _error!,
        action: AuraSecondaryButton(
          label: 'Try again',
          onPressed: _load,
          icon: Icons.refresh_rounded,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final err in [_removeError, _updateError].whereType<String>()) ...[
          Container(
            padding: const EdgeInsets.all(AuraSpace.s12),
            margin: const EdgeInsets.only(bottom: AuraSpace.s12),
            decoration: BoxDecoration(
              color: AuraSurface.coRose.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AuraRadius.md),
              border: Border.all(
                color: AuraSurface.coRose.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, size: 16, color: AuraSurface.coRose),
                const SizedBox(width: AuraSpace.s8),
                Expanded(
                  child: Text(
                    err,
                    style: AuraText.small.copyWith(color: AuraSurface.coRose),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() {
                    _removeError = null;
                    _updateError = null;
                  }),
                  child: const Icon(Icons.close, size: 16, color: AuraSurface.coRose),
                ),
              ],
            ),
          ),
        ],
        Row(
          children: [
            Text(
              '${_members.length} member${_members.length == 1 ? '' : 's'}',
              style: AuraText.small.copyWith(color: AuraSurface.muted),
            ),
            const Spacer(),
            if (_isAdmin)
              Text(
                'Tap ⋮ for options',
                style: AuraText.micro.copyWith(color: AuraSurface.faint),
              ),
          ],
        ),
        const SizedBox(height: AuraSpace.s12),
        if (_members.isEmpty)
          const InsEmptyState(
            icon: Icons.people_outline_rounded,
            title: 'No members yet',
            description:
                'Use the action above to invite people. They will appear here once they accept.',
          )
        else
          ..._members.map(_buildMemberTile),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return InstitutionPage(
      title: 'Members',
      // Subtitle is shown to every member who can see this screen, not
      // just operators. The previous "institutional access" wording read
      // as admin-panel language in a regular workspace surface; use the
      // plain product terms (people who belong, what they can do).
      subtitle: 'People who belong to this institution, what they can do, and pending join requests.',
      trailing: _isAdmin
          ? AuraPrimaryButton(
              label: 'Invite',
              icon: Icons.person_add_alt_1_rounded,
              onPressed: () =>
                  context.push('/institution/${widget.institutionId}/invites'),
            )
          : null,
      body: _buildBody(),
    );
  }
}
