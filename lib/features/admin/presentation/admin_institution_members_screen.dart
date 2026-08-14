import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_responsive.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../data/admin_providers.dart';
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
  InstitutionOwnershipRecoveryState _ownership =
      const InstitutionOwnershipRecoveryState.notRequired();
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
      // Institution Ownership Continuity — the recovery condition is
      // resolved by the backend from canonical ownership truth. A failure
      // to read it must not blank out the members list, which is this
      // screen's primary job: fall back to "no recovery required", which
      // is the non-destructive default (it hides an action, never invents
      // one).
      InstitutionOwnershipRecoveryState ownership =
          const InstitutionOwnershipRecoveryState.notRequired();
      try {
        ownership = await repo.fetchOwnershipRecoveryState(widget.institutionId);
      } catch (_) {
        ownership = const InstitutionOwnershipRecoveryState.notRequired();
      }
      if (mounted) {
        setState(() {
          _members = members;
          _ownership = ownership;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e; });
    }
  }

  /// Institution Ownership Continuity — governed emergency recovery.
  ///
  /// Reachable ONLY while the institution has no actionable owner. Requires
  /// an explicit reason (permanent governance evidence) and an explicit
  /// confirmation naming the institution, the prior owner-of-record, the
  /// proposed replacement, and the privileged nature of the act. Candidates
  /// come from the backend's own eligibility authority, and the acting
  /// platform administrator is excluded from that list server-side.
  Future<void> _recoverOwnership() async {
    final candidates = _ownership.candidates;
    if (candidates.isEmpty) return;

    final decision = await showDialog<_OwnershipRecoveryDecision>(
      context: context,
      builder: (ctx) => _OwnershipRecoveryDialog(
        institutionName: widget.institutionName,
        ownerOfRecordLabel: _ownership.ownerOfRecordLabel,
        candidates: candidates,
      ),
    );

    if (decision == null) return;
    final target = decision.candidate;
    final reason = decision.reason;

    setState(() => _actionLoading = true);
    try {
      await ref.read(adminRepositoryProvider).emergencyRecoverOwnership(
            widget.institutionId,
            target.userId,
            reason,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${target.label} is now the owner.'),
            backgroundColor: AuraSurface.coVerdant.withValues(alpha: 0.16),
          ),
        );
        // Reload so the restored, ordinary state replaces the recovery
        // affordance — which the backend will now report as unnecessary.
        await _load();
        if (mounted) setState(() => _actionLoading = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(adminErrorMessage(e)),
            backgroundColor: AuraSurface.coRose.withValues(alpha: 0.16),
          ),
        );
        setState(() => _actionLoading = false);
      }
    }
  }

  Future<void> _changeRole(String userId, String newRole) async {
    setState(() => _actionLoading = true);
    try {
      await ref.read(adminRepositoryProvider)
          .updateInstitutionMemberRole(widget.institutionId, userId, newRole);
      if (mounted) {
        await _load();
        // The blocking overlay must be cleared on the SUCCESS path too —
        // it was previously only cleared when the action failed, which
        // left the screen permanently covered by a spinner after every
        // successful role change.
        if (mounted) setState(() => _actionLoading = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(adminErrorMessage(e)),
            backgroundColor: AuraSurface.coRose.withValues(alpha: 0.16),
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
            child: const Text('Remove', style: TextStyle(color: AuraSurface.coRose)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _actionLoading = true);
    try {
      await ref.read(adminRepositoryProvider)
          .removeInstitutionMember(widget.institutionId, userId);
      if (mounted) {
        await _load();
        if (mounted) setState(() => _actionLoading = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(adminErrorMessage(e)),
            backgroundColor: AuraSurface.coRose.withValues(alpha: 0.16),
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
      return const Center(
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
        if (_ownership.recoveryRequired)
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: kWorkspaceWidth),
              child: Padding(
                padding: const EdgeInsets.only(bottom: AuraSpace.s16),
                child: _OwnershipRecoveryBanner(
                  ownerOfRecordLabel: _ownership.ownerOfRecordLabel,
                  hasCandidates: _ownership.candidates.isNotEmpty,
                  onRecover: _recoverOwnership,
                ),
              ),
            ),
          ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kWorkspaceWidth),
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

/// The operator's explicit, complete recovery decision. Only produced when
/// BOTH a replacement owner and a reason were supplied.
class _OwnershipRecoveryDecision {
  const _OwnershipRecoveryDecision(this.candidate, this.reason);

  final OwnershipRecoveryCandidate candidate;
  final String reason;
}

/// The governed confirmation step for emergency ownership recovery.
///
/// Owns its own `TextEditingController` lifecycle — the controller must
/// outlive the dialog's exit animation, which still rebuilds the field
/// after `Navigator.pop`, so it can only be disposed by this widget's own
/// `dispose()`, never by the caller immediately after `showDialog`
/// returns.
class _OwnershipRecoveryDialog extends StatefulWidget {
  const _OwnershipRecoveryDialog({
    required this.institutionName,
    required this.ownerOfRecordLabel,
    required this.candidates,
  });

  final String? institutionName;
  final String? ownerOfRecordLabel;
  final List<OwnershipRecoveryCandidate> candidates;

  @override
  State<_OwnershipRecoveryDialog> createState() =>
      _OwnershipRecoveryDialogState();
}

class _OwnershipRecoveryDialogState extends State<_OwnershipRecoveryDialog> {
  final TextEditingController _reason = TextEditingController();
  OwnershipRecoveryCandidate? _selected;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _selected != null && _reason.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Restore institution ownership'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This is a privileged platform action. It restores governance of '
              '${widget.institutionName ?? 'this institution'} to an existing '
              'member, and is permanently recorded.',
              style: AuraText.small,
            ),
            const SizedBox(height: AuraSpace.s12),
            Text(
              widget.ownerOfRecordLabel != null
                  ? 'Owner on record: ${widget.ownerOfRecordLabel} '
                      '(no longer able to act)'
                  : 'This institution has no owner on record.',
              style: AuraText.small.copyWith(color: AuraSurface.muted),
            ),
            const SizedBox(height: AuraSpace.s16),
            DropdownButtonFormField<OwnershipRecoveryCandidate>(
              initialValue: _selected,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'New owner',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final c in widget.candidates)
                  DropdownMenuItem(
                    value: c,
                    child: Text('${c.label} · ${c.role}'),
                  ),
              ],
              onChanged: (value) => setState(() => _selected = value),
            ),
            const SizedBox(height: AuraSpace.s12),
            TextField(
              controller: _reason,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Reason (required)',
                hintText: 'Why ownership must be restored by the platform.',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _canSubmit
              ? () => Navigator.pop(
                    context,
                    _OwnershipRecoveryDecision(_selected!, _reason.text.trim()),
                  )
              : null,
          child: const Text('Restore ownership'),
        ),
      ],
    );
  }
}

/// Institution Ownership Continuity — the truthful recovery-required
/// state. Rendered ONLY when the backend reports that this institution has
/// no actionable owner. It names the condition in plain governance terms
/// and never exposes internal lifecycle enum names or moderation rationale.
class _OwnershipRecoveryBanner extends StatelessWidget {
  const _OwnershipRecoveryBanner({
    required this.ownerOfRecordLabel,
    required this.hasCandidates,
    required this.onRecover,
  });

  final String? ownerOfRecordLabel;
  final bool hasCandidates;
  final VoidCallback onRecover;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AuraSpace.s16),
      decoration: BoxDecoration(
        color: AuraSurface.coSun.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(color: AuraSurface.coSun.withValues(alpha: 0.40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.gavel_rounded, size: 18, color: AuraSurface.coSun),
              const SizedBox(width: AuraSpace.s8),
              Text(
                'Ownership recovery required',
                style: AuraText.body.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s8),
          Text(
            ownerOfRecordLabel != null
                ? 'This institution has no owner who can act. $ownerOfRecordLabel is '
                    'still recorded as owner but can no longer exercise authority.'
                : 'This institution has no owner who can act.',
            style: AuraText.small.copyWith(color: AuraSurface.muted),
          ),
          const SizedBox(height: AuraSpace.s12),
          if (hasCandidates)
            AuraSecondaryButton(
              label: 'Restore ownership…',
              onPressed: onRecover,
            )
          else
            Text(
              'No eligible member is currently available to receive ownership.',
              style: AuraText.small.copyWith(color: AuraSurface.muted),
            ),
        ],
      ),
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

  bool get _isOwner => member.role.toUpperCase() == 'OWNER';

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
          // AXR-1 identity precedence — photo first, initials only as
          // the true fallback (AuraAvatar owns that rule).
          AuraAvatar(
            name: name,
            imageUrl: member.avatarUrl,
            size: 40,
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
          if (_isOwner)
            const Tooltip(
              message: 'Owners cannot be demoted from this UI',
              child: Icon(
                Icons.lock_outline_rounded,
                size: 16,
                color: AuraSurface.faint,
              ),
            )
          else
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
                // Institution Ownership Continuity — there is deliberately
                // NO generic "Promote to Owner" control here. Ownership is
                // not an ordinary role assignment: it changes hands only
                // through the owner's own transfer, or through governed
                // emergency recovery (surfaced above, and only while the
                // institution has no actionable owner). The backend has
                // always refused OWNER through this endpoint, so this
                // control could never have succeeded.
                if (member.role != 'ADMIN' && member.role != 'OWNER')
                  const PopupMenuItem(
                    value: 'ADMIN',
                    child: Text('Promote to Admin'),
                  ),
                if (member.role != 'MEMBER')
                  const PopupMenuItem(
                    value: 'MEMBER',
                    child: Text('Demote to Member'),
                  ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'REMOVE',
                  child: Text(
                    'Remove from institution',
                    style: TextStyle(color: AuraSurface.coRose),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
