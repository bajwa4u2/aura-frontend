import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../data/institutions_repository.dart';

class InstitutionInvitesScreen extends ConsumerStatefulWidget {
  const InstitutionInvitesScreen({super.key, required this.institutionId});

  final String institutionId;

  @override
  ConsumerState<InstitutionInvitesScreen> createState() =>
      _InstitutionInvitesScreenState();
}

class _InstitutionInvitesScreenState
    extends ConsumerState<InstitutionInvitesScreen> {
  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _invites = const [];

  final _emailController = TextEditingController();
  String _selectedRole = 'MEMBER';
  int _expiresInDays = 7;

  bool _creating = false;
  String? _createError;
  String? _copiedCode;
  String? _revoking;
  String? _revokeError;

  static const _roles = ['MEMBER', 'EDITOR', 'ADMIN'];

  InstitutionsRepository get _repo => ref.read(institutionsRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final invites = await _repo.listInvites(widget.institutionId);
      setState(() {
        _invites = invites;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = _message(e, 'Could not load invites.');
        _loading = false;
      });
    }
  }

  Future<void> _create() async {
    if (_creating) return;
    setState(() {
      _creating = true;
      _createError = null;
    });

    try {
      await _repo.createInvite(
        widget.institutionId,
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        role: _selectedRole,
        expiresInDays: _expiresInDays,
      );
      _emailController.clear();
      setState(() {
        _selectedRole = 'MEMBER';
        _expiresInDays = 7;
        _creating = false;
      });
      await _load();
    } catch (e) {
      setState(() {
        _createError = _message(e, 'Could not create invite.');
        _creating = false;
      });
    }
  }

  Future<void> _revoke(String inviteId) async {
    if (_revoking != null) return;
    setState(() {
      _revoking = inviteId;
      _revokeError = null;
    });
    try {
      await _repo.revokeInvite(widget.institutionId, inviteId);
      await _load();
    } catch (e) {
      setState(() {
        _revokeError = _message(e, 'Could not revoke invite.');
        _revoking = null;
      });
    }
  }

  Future<void> _copyLink(String code) async {
    final origin = Uri.base.origin;
    final link = '$origin/institutions/get-started?mode=join&code=$code';
    await Clipboard.setData(ClipboardData(text: link));
    setState(() => _copiedCode = code);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copiedCode = null);
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

  String _inviteStatus(Map<String, dynamic> invite) {
    if (invite['usedAt'] != null) return 'Used';
    final expiresAtStr = invite['expiresAt']?.toString().trim() ?? '';
    if (expiresAtStr.isNotEmpty) {
      final exp = DateTime.tryParse(expiresAtStr);
      if (exp != null && exp.isBefore(DateTime.now())) return 'Expired';
    }
    return 'Active';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Active':
        return AuraSurface.goodInk;
      case 'Expired':
        return AuraSurface.dangerInk;
      default:
        return AuraSurface.muted;
    }
  }

  Color _statusBg(String status) {
    switch (status) {
      case 'Active':
        return AuraSurface.goodBg;
      case 'Expired':
        return AuraSurface.dangerBg;
      default:
        return AuraSurface.subtle;
    }
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    final local = dt.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }

  Widget _buildCreateSection() {
    return Container(
      padding: const EdgeInsets.all(AuraSpace.s16),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Create invite',
            style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AuraSpace.s14),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: AuraText.body,
            decoration: const InputDecoration(
              labelText: 'Email (optional)',
              hintText: 'colleague@institution.edu',
            ),
          ),
          const SizedBox(height: AuraSpace.s12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Role',
                      style: AuraText.small.copyWith(
                        color: AuraSurface.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AuraSpace.s6),
                    DropdownButton<String>(
                      value: _selectedRole,
                      isExpanded: true,
                      items: _roles
                          .map((r) => DropdownMenuItem(
                                value: r,
                                child: Text(
                                  r[0] + r.substring(1).toLowerCase(),
                                  style: AuraText.small,
                                ),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedRole = v);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AuraSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Valid for',
                      style: AuraText.small.copyWith(
                        color: AuraSurface.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AuraSpace.s6),
                    DropdownButton<int>(
                      value: _expiresInDays,
                      isExpanded: true,
                      items: [1, 3, 7, 14, 30]
                          .map((d) => DropdownMenuItem(
                                value: d,
                                child: Text(
                                  '$d day${d == 1 ? '' : 's'}',
                                  style: AuraText.small,
                                ),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _expiresInDays = v);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_createError != null) ...[
            const SizedBox(height: AuraSpace.s12),
            Container(
              padding: const EdgeInsets.all(AuraSpace.s10),
              decoration: BoxDecoration(
                color: AuraSurface.dangerBg,
                borderRadius: BorderRadius.circular(AuraRadius.md),
                border: Border.all(
                  color: AuraSurface.dangerInk.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                _createError!,
                style: AuraText.small.copyWith(color: AuraSurface.dangerInk),
              ),
            ),
          ],
          const SizedBox(height: AuraSpace.s16),
          AuraPrimaryButton(
            label: _creating ? 'Creating…' : 'Create invite',
            onPressed: _creating ? null : _create,
            icon: Icons.add_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildInviteTile(Map<String, dynamic> invite) {
    final inviteId = invite['id']?.toString() ?? '';
    final code = invite['code']?.toString() ?? '';
    final email = invite['email']?.toString().trim() ?? '';
    final role = invite['role']?.toString() ?? '';
    final expiresAt = _formatDate(invite['expiresAt']?.toString());
    final usedBy = invite['usedBy'] is Map
        ? Map<String, dynamic>.from(invite['usedBy'] as Map)
        : null;
    final status = _inviteStatus(invite);
    final isCopied = _copiedCode == code;
    final isRevoking = _revoking == inviteId;

    return Container(
      margin: const EdgeInsets.only(bottom: AuraSpace.s8),
      padding: const EdgeInsets.all(AuraSpace.s14),
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
                child: Text(
                  code,
                  style: AuraText.small.copyWith(
                    fontFamily: 'monospace',
                    color: AuraSurface.ink,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AuraSpace.s8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AuraSpace.s8,
                  vertical: AuraSpace.s4,
                ),
                decoration: BoxDecoration(
                  color: _statusBg(status),
                  borderRadius: BorderRadius.circular(AuraRadius.pill),
                ),
                child: Text(
                  status,
                  style: AuraText.micro.copyWith(
                    color: _statusColor(status),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AuraSpace.s8),
              if (status == 'Active') ...[
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => _copyLink(code),
                    child: Icon(
                      isCopied ? Icons.check_rounded : Icons.copy_rounded,
                      size: 16,
                      color: isCopied ? AuraSurface.goodInk : AuraSurface.accentText,
                    ),
                  ),
                ),
                const SizedBox(width: AuraSpace.s8),
                if (isRevoking)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => _revoke(inviteId),
                      child: Icon(
                        Icons.link_off_rounded,
                        size: 16,
                        color: AuraSurface.dangerInk.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
              ] else
                const Icon(
                  Icons.copy_rounded,
                  size: 16,
                  color: AuraSurface.faint,
                ),
            ],
          ),
          const SizedBox(height: AuraSpace.s8),
          Wrap(
            spacing: AuraSpace.s16,
            children: [
              if (email.isNotEmpty)
                _MetaChip(label: email, icon: Icons.email_outlined),
              if (role.isNotEmpty)
                _MetaChip(label: role[0] + role.substring(1).toLowerCase(), icon: Icons.badge_outlined),
              if (expiresAt.isNotEmpty)
                _MetaChip(
                  label: status == 'Used' ? 'Used' : 'Expires $expiresAt',
                  icon: Icons.schedule_rounded,
                ),
              if (usedBy != null) ...[
                _MetaChip(
                  label: usedBy['displayName']?.toString().trim().isNotEmpty == true
                      ? usedBy['displayName']!.toString().trim()
                      : '@${usedBy['handle'] ?? '?'}',
                  icon: Icons.person_rounded,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const AuraLoadingState(message: 'Loading invites…');
    }

    if (_error != null) {
      return AuraErrorState(
        title: 'Could not load invites',
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
        _buildCreateSection(),
        if (_revokeError != null) ...[
          const SizedBox(height: AuraSpace.s12),
          Container(
            padding: const EdgeInsets.all(AuraSpace.s12),
            decoration: BoxDecoration(
              color: AuraSurface.dangerBg,
              borderRadius: BorderRadius.circular(AuraRadius.md),
              border: Border.all(color: AuraSurface.dangerInk.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, size: 16, color: AuraSurface.dangerInk),
                const SizedBox(width: AuraSpace.s8),
                Expanded(
                  child: Text(
                    _revokeError!,
                    style: AuraText.small.copyWith(color: AuraSurface.dangerInk),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _revokeError = null),
                  child: const Icon(Icons.close, size: 16, color: AuraSurface.dangerInk),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AuraSpace.s24),
        Padding(
          padding: const EdgeInsets.only(left: AuraSpace.s4, bottom: AuraSpace.s12),
          child: Text(
            'Existing invites',
            style: AuraText.label.copyWith(
              color: AuraSurface.faint,
              letterSpacing: 0.8,
            ),
          ),
        ),
        if (_invites.isEmpty)
          const AuraEmptyState(
            icon: Icons.group_add_outlined,
            title: 'No invites yet',
            body: 'Create an invite above to give colleagues access.',
          )
        else
          ..._invites.map(_buildInviteTile),
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
                        child: Text('Institution invites', style: AuraText.headline),
                      ),
                    ],
                  ),
                  const SizedBox(height: AuraSpace.s6),
                  Text(
                    'Create and manage invite codes for your institution.',
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

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AuraSurface.muted),
        const SizedBox(width: AuraSpace.s4),
        Text(
          label,
          style: AuraText.micro.copyWith(color: AuraSurface.muted),
        ),
      ],
    );
  }
}
