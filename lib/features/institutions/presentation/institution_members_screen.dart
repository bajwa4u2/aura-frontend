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
    // PLATFORM_ADMIN is what listMembers returns when the caller is a platform
    // admin — the service short-circuits on the platform-admin check before it
    // ever reads their institution membership role. Such a caller has full
    // member-management authority on the backend (updateMemberRole/removeMember
    // both honor the platform-admin bypass), so the workspace controls must be
    // visible to them too. Without this, an operator who is also a platform
    // admin (the common case for a verified institution's founder) sees a
    // read-only member list and cannot change roles from the workspace.
    return r == 'ADMIN' || r == 'OWNER' || r == 'PLATFORM_ADMIN';
  }

  bool get _isOwner {
    final r = _callerRole.toUpperCase();
    // Platform admins outrank owners, so they get the owner-tier options too.
    return r == 'OWNER' || r == 'PLATFORM_ADMIN';
  }

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
    final caps = <String>{
      if (member['capabilities'] is List)
        ...(member['capabilities'] as List)
            .map((e) => e.toString().trim().toUpperCase()),
    };
    final isRepresentative = caps.contains('OFFICIAL_REPRESENTATION');
    final isHost = caps.contains('HOST_MEETINGS');
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
          Wrap(
            spacing: AuraSpace.s4,
            children: [
              _pill(_roleBadge(role), _roleColor(role), _roleBg(role)),
              // Capabilities that read as institutional STANDING carry a
              // visible badge — responsibility is visible to everyone.
              if (isRepresentative)
                _pill('Representative', AuraSurface.accentText,
                    AuraSurface.accentSoft),
                if (isHost)
                _pill('Host', AuraSurface.coSun,
                    AuraSurface.coSun.withValues(alpha: 0.16)),
            ],
          ),
          if (_canManageThisMember(role)) ...[
            const SizedBox(width: AuraSpace.s4),
            if (isBusy)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
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
                  // GOVERNANCE: appointing/removing admins and transferring
                  // ownership are OWNER-exclusive; delegating Representative
                  // and Host is available to admins.
                  if (_isOwner && role.toUpperCase() == 'MEMBER')
                    PopupMenuItem(
                      value: 'PROMOTE',
                      child: Text('Promote to Admin',
                          style: AuraText.small
                              .copyWith(color: AuraSurface.accentText)),
                    ),
                  if (_isOwner && role.toUpperCase() == 'ADMIN')
                    PopupMenuItem(
                      value: 'DEMOTE',
                      child: Text('Demote to Member',
                          style:
                              AuraText.small.copyWith(color: AuraSurface.coSun)),
                    ),
                  if (_isOwner && role.toUpperCase() != 'OWNER')
                    PopupMenuItem(
                      value: 'TRANSFER',
                      child: Text('Transfer ownership…',
                          style: AuraText.small
                              .copyWith(color: AuraSurface.coVerdant)),
                    ),
                  if (role.toUpperCase() == 'MEMBER')
                    PopupMenuItem(
                      value: isRepresentative ? 'REVOKE_REP' : 'GRANT_REP',
                      child: Text(
                          isRepresentative
                              ? 'Remove Representative'
                              : 'Make Representative',
                          style: AuraText.small),
                    ),
                  if (role.toUpperCase() == 'MEMBER')
                    PopupMenuItem(
                      value: isHost ? 'REVOKE_HOST' : 'GRANT_HOST',
                      child: Text(isHost ? 'Remove Host' : 'Make Host',
                          style: AuraText.small),
                    ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'REMOVE',
                    child: Text('Remove',
                        style:
                            AuraText.small.copyWith(color: AuraSurface.coRose)),
                  ),
                ],
                onSelected: (value) {
                  switch (value) {
                    case 'REMOVE':
                      _confirmRemove(memberId, nameOrHandle);
                      break;
                    case 'PROMOTE':
                      _changeRole(memberId, 'ADMIN');
                      break;
                    case 'DEMOTE':
                      _changeRole(memberId, 'MEMBER');
                      break;
                    case 'TRANSFER':
                      _confirmTransfer(memberId, nameOrHandle);
                      break;
                    case 'GRANT_REP':
                      _changeCapability(memberId, 'OFFICIAL_REPRESENTATION', true);
                      break;
                    case 'REVOKE_REP':
                      _changeCapability(
                          memberId, 'OFFICIAL_REPRESENTATION', false);
                      break;
                    case 'GRANT_HOST':
                      _changeCapability(memberId, 'HOST_MEETINGS', true);
                      break;
                    case 'REVOKE_HOST':
                      _changeCapability(memberId, 'HOST_MEETINGS', false);
                      break;
                  }
                },
              ),
          ],
        ],
      ),
    );
  }

  /// Only owners may act on the admin tier; owners/admins may act on members.
  bool _canManageThisMember(String role) {
    final r = role.toUpperCase();
    if (r == 'OWNER') return false;
    if (r == 'ADMIN') return _isOwner;
    return _isAdmin;
  }

  Widget _pill(String label, Color fg, Color bg) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.s8,
          vertical: AuraSpace.s4,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AuraRadius.pill),
        ),
        child: Text(
          label,
          style: AuraText.micro.copyWith(color: fg, fontWeight: FontWeight.w700),
        ),
      );

  Future<void> _changeCapability(
    String userId,
    String capability,
    bool grant,
  ) async {
    if (_updating != null) return;
    setState(() {
      _updating = userId;
      _updateError = null;
    });
    try {
      if (grant) {
        await _repo.grantCapability(widget.institutionId, userId, capability);
      } else {
        await _repo.revokeCapability(widget.institutionId, userId, capability);
      }
      await _load();
    } catch (e) {
      setState(() {
        _updateError = _message(e, 'Could not update capability.');
        _updating = null;
      });
    }
  }

  Future<void> _confirmTransfer(String userId, String name) async {
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AuraSurface.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AuraRadius.card),
        ),
        title: const Text('Transfer ownership', style: AuraText.subtitle),
        content: Text(
          'Make $name the owner of this institution? You will become an admin. '
          'This is irreversible without the new owner transferring it back.',
          style: AuraText.body.copyWith(color: AuraSurface.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel',
                style: AuraText.small.copyWith(color: AuraSurface.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Transfer',
                style: AuraText.small.copyWith(
                    color: AuraSurface.coVerdant,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _updating = userId;
      _updateError = null;
    });
    try {
      await _repo.transferOwnership(widget.institutionId, userId);
      await _load();
    } catch (e) {
      setState(() {
        _updateError = _message(e, 'Could not transfer ownership.');
        _updating = null;
      });
    }
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
            description: 'Invite colleagues with Invite.',
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
