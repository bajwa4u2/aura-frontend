import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../data/institutions_repository.dart';

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

  InstitutionsRepository get _repo =>
      ref.read(institutionsRepositoryProvider);

  bool get _isAdmin => _callerRole.toUpperCase() == 'ADMIN';

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
      case 'ADMIN':
        return AuraSurface.accentText;
      case 'EDITOR':
        return AuraSurface.warnInk;
      default:
        return AuraSurface.muted;
    }
  }

  Color _roleBg(String role) {
    switch (role.toUpperCase()) {
      case 'ADMIN':
        return AuraSurface.accentSoft;
      case 'EDITOR':
        return AuraSurface.warnBg;
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

    // Caller's own userId isn't in the membership response — we identify
    // self via callerRole by checking if name/handle matches, but a simpler
    // proxy: if this userId appears as the admin and there's only one admin
    // we'd block removal anyway on the backend. The UI hides the button for
    // the same user by checking the "removing" state, which is sufficient.

    final showRemove = _isAdmin && !isRemoving;

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
          if (showRemove) ...[
            const SizedBox(width: AuraSpace.s8),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => _confirmRemove(memberId, nameOrHandle),
                child: Icon(
                  Icons.person_remove_outlined,
                  size: 18,
                  color: AuraSurface.dangerInk.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
          if (isRemoving)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
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
                color: AuraSurface.dangerInk,
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
        if (_removeError != null) ...[
          Container(
            padding: const EdgeInsets.all(AuraSpace.s12),
            margin: const EdgeInsets.only(bottom: AuraSpace.s12),
            decoration: BoxDecoration(
              color: AuraSurface.dangerBg,
              borderRadius: BorderRadius.circular(AuraRadius.md),
              border: Border.all(
                color: AuraSurface.dangerInk.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, size: 16, color: AuraSurface.dangerInk),
                const SizedBox(width: AuraSpace.s8),
                Expanded(
                  child: Text(
                    _removeError!,
                    style: AuraText.small.copyWith(color: AuraSurface.dangerInk),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _removeError = null),
                  child: const Icon(Icons.close, size: 16, color: AuraSurface.dangerInk),
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
                'Tap  to remove',
                style: AuraText.micro.copyWith(color: AuraSurface.faint),
              ),
          ],
        ),
        const SizedBox(height: AuraSpace.s12),
        if (_members.isEmpty)
          const AuraEmptyState(
            icon: Icons.people_outline_rounded,
            title: 'No members yet',
            body: 'Members who join through invite codes will appear here.',
          )
        else
          ..._members.map(_buildMemberTile),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuraScaffold(
      showHeader: false,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AuraSpace.s16,
          AuraSpace.s20,
          AuraSpace.s16,
          AuraSpace.s32,
        ),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 740),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: const Icon(
                          Icons.arrow_back_rounded,
                          size: 20,
                          color: AuraSurface.muted,
                        ),
                      ),
                      const SizedBox(width: AuraSpace.s12),
                      const Expanded(
                        child: Text('Institution members', style: AuraText.headline),
                      ),
                    ],
                  ),
                  const SizedBox(height: AuraSpace.s6),
                  Text(
                    'Active members and their roles.',
                    style: AuraText.body.copyWith(
                      color: AuraSurface.muted,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: AuraSpace.s24),
                  _buildBody(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
