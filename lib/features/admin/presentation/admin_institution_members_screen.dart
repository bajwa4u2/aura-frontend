import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../data/admin_providers.dart';
import '../data/admin_repository.dart';
import 'admin_error.dart';

class AdminInstitutionMembersScreen extends ConsumerStatefulWidget {
  const AdminInstitutionMembersScreen({
    super.key,
    required this.institutionId,
    this.institutionName,
  });

  final String institutionId;
  final String? institutionName;

  @override
  ConsumerState<AdminInstitutionMembersScreen> createState() =>
      _AdminInstitutionMembersScreenState();
}

class _AdminInstitutionMembersScreenState
    extends ConsumerState<AdminInstitutionMembersScreen> {
  List<AdminInstitutionMember> _members = [];
  bool _loading = false;
  bool _actionLoading = false;
  Object? _error;

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
      final repo = ref.read(adminRepositoryProvider);
      final members = await repo.fetchInstitutionMembers(widget.institutionId);
      if (mounted) {
        setState(() {
          _members = members;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e; });
    }
  }

  Future<void> _changeRole(String userId, String newRole) async {
    setState(() => _actionLoading = true);
    try {
      await ref.read(adminRepositoryProvider)
          .updateInstitutionMemberRole(widget.institutionId, userId, newRole);
      if (mounted) await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(adminErrorMessage(e)),
            backgroundColor: AuraSurface.dangerBg,
          ),
        );
        setState(() => _actionLoading = false);
      }
    }
  }

  Future<void> _removeMember(String userId, String displayName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove member'),
        content: Text('Remove $displayName from this institution?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Remove', style: TextStyle(color: AuraSurface.dangerInk)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _actionLoading = true);
    try {
      await ref.read(adminRepositoryProvider)
          .removeInstitutionMember(widget.institutionId, userId);
      if (mounted) await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(adminErrorMessage(e)),
            backgroundColor: AuraSurface.dangerBg,
          ),
        );
        setState(() => _actionLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.institutionName != null
        ? '${widget.institutionName} — Members'
        : 'Institution Members';

    return AuraScaffold(
      title: title,
      body: Stack(
        children: [
          _buildBody(),
          if (_actionLoading)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x55000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _members.isEmpty) {
      return const Center(child: AuraLoadingState(message: 'Loading members…'));
    }
    if (_error != null && _members.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AuraSpace.s16),
          child: AuraErrorState(
            title: 'Failed to load members',
            body: adminErrorMessage(_error!),
            action: AuraSecondaryButton(
              label: 'Retry',
              onPressed: _load,
            ),
          ),
        ),
      );
    }
    if (!_loading && _members.isEmpty) {
      return Center(
        child: AuraEmptyState(
          title: 'No members',
          body: 'This institution has no active members.',
          icon: Icons.group_outlined,
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.s16,
        AuraSpace.s16,
        AuraSpace.s16,
        AuraSpace.s32,
      ),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Container(
              decoration: BoxDecoration(
                color: AuraSurface.card,
                borderRadius: BorderRadius.circular(AuraRadius.card),
                border: Border.all(color: AuraSurface.divider),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < _members.length; i++) ...[
                    _MemberRow(
                      member: _members[i],
                      onChangeRole: (role) => _changeRole(_members[i].userId, role),
                      onRemove: () => _removeMember(
                        _members[i].userId,
                        _members[i].displayName ?? _members[i].handle ?? _members[i].userId,
                      ),
                    ),
                    if (i < _members.length - 1)
                      Container(
                        height: 1,
                        margin: const EdgeInsets.symmetric(horizontal: AuraSpace.s16),
                        color: AuraSurface.divider,
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.onChangeRole,
    required this.onRemove,
  });

  final AdminInstitutionMember member;
  final ValueChanged<String> onChangeRole;
  final VoidCallback onRemove;

  Color _roleColor(String role) {
    return role.toUpperCase() == 'ADMIN' ? AuraSurface.accentText : AuraSurface.muted;
  }

  @override
  Widget build(BuildContext context) {
    final name = member.displayName ?? member.handle ?? member.userId;
    final handle = member.handle != null ? '@${member.handle}' : null;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s16,
        vertical: AuraSpace.s12,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AuraSurface.overlay,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: AuraText.body,
            ),
          ),
          const SizedBox(width: AuraSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AuraText.body.copyWith(fontWeight: FontWeight.w600)),
                if (handle != null)
                  Text(handle, style: AuraText.small.copyWith(color: AuraSurface.muted)),
                if (member.title != null)
                  Text(member.title!, style: AuraText.micro.copyWith(color: AuraSurface.muted)),
              ],
            ),
          ),
          const SizedBox(width: AuraSpace.s8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _roleColor(member.role).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              member.role,
              style: AuraText.micro.copyWith(color: _roleColor(member.role)),
            ),
          ),
          const SizedBox(width: AuraSpace.s8),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 18),
            onSelected: (value) {
              if (value == 'REMOVE') {
                onRemove();
              } else {
                onChangeRole(value);
              }
            },
            itemBuilder: (_) => [
              if (member.role != 'ADMIN')
                const PopupMenuItem(value: 'ADMIN', child: Text('Promote to Admin')),
              if (member.role != 'MEMBER')
                const PopupMenuItem(value: 'MEMBER', child: Text('Demote to Member')),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'REMOVE',
                child: Text(
                  'Remove from institution',
                  style: TextStyle(color: AuraSurface.dangerInk),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
