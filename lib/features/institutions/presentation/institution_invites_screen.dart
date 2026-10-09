import 'package:aura/core/product/temporal.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/institutions/institution_access_provider.dart';
import '../../../core/product/product_language.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../data/institution_pending_counts.dart';
import '../data/institutions_repository.dart';
import '../workspace/workspace_page.dart';
import 'institution_members_screen.dart';
import '../../../core/identity/person_identity_model.dart';

/// INVITES (DD-43, 2026-10-09): this route is the Members page on its
/// Invites tab.
class InstitutionInvitesScreen extends StatelessWidget {
  const InstitutionInvitesScreen({super.key, required this.institutionId});

  final String institutionId;

  @override
  Widget build(BuildContext context) =>
      InstitutionMembersScreen(institutionId: institutionId, initialTab: 'invites');
}

/// The Invites tab: the invite form (opened by the page's gold Invite) and
/// every invite sent, with its status.
class InstitutionInvitesPanel extends ConsumerStatefulWidget {
  const InstitutionInvitesPanel({
    super.key,
    required this.institutionId,
    required this.showCreate,
    required this.onCloseCreate,
    this.onInvite,
  });

  final String institutionId;
  final bool showCreate;
  final VoidCallback onCloseCreate;

  /// Opens the form from the empty state.
  final VoidCallback? onInvite;

  @override
  ConsumerState<InstitutionInvitesPanel> createState() => _InvitesPanelState();
}

class _InvitesPanelState extends ConsumerState<InstitutionInvitesPanel> {
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

  // GOVERNANCE V1: ownership is never granted by invite (only by transfer),
  // and EDITOR was retired. Admins invite MEMBERs; only the OWNER may invite
  // an ADMIN. Representative/Host are capabilities delegated after joining.
  List<String> get _roles {
    final isOwner = ref.read(institutionIdentityProvider)?.isOwner ?? false;
    return isOwner ? const ['MEMBER', 'ADMIN'] : const ['MEMBER'];
  }

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
      if (!mounted) return;
      setState(() {
        _invites = invites;
        _loading = false;
        _revoking = null;
      });
      ref.invalidate(institutionPendingCountsProvider(widget.institutionId));
    } catch (e) {
      if (!mounted) return;
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
      widget.onCloseCreate();
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

  Future<void> _confirmRevoke(String inviteId, String code) async {
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AuraSurface.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AuraRadius.card),
        ),
        title: const Text('Revoke invite', style: AuraText.subtitle),
        content: Text(
          'Revoke this invite? The link will stop working immediately and '
          'cannot be used to join.',
          style: AuraText.body.copyWith(color: AuraSurface.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: AuraText.small.copyWith(color: AuraSurface.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Revoke',
                style: AuraText.small.copyWith(color: AuraSurface.coRose, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok == true) await _revoke(inviteId);
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
        // Success envelope is { ok:false, error:{ message, details:{issues} } }.
        // Prefer the specific validation issue, then the error message, then a
        // top-level message — so operators see what actually failed instead of
        // a generic dead-end.
        final err = data['error'];
        if (err is Map) {
          final details = err['details'];
          if (details is Map && details['issues'] is List) {
            final issues = (details['issues'] as List)
                .map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty)
                .toList();
            if (issues.isNotEmpty) return issues.join('\n');
          }
          final em = err['message']?.toString().trim() ?? '';
          if (em.isNotEmpty) return em;
        }
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

  WorkspaceTone _statusTone(String status) => switch (status) {
        'Active' => WorkspaceTone.done,
        'Expired' => WorkspaceTone.problem,
        _ => WorkspaceTone.neutral,
      };

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    return AuraTemporal.fullShort(dt);
  }

  Widget _dropdown<T>({
    required String label,
    required T value,
    required List<T> values,
    required String Function(T) text,
    required ValueChanged<T> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AuraText.small.copyWith(color: AuraSurface.muted, fontWeight: FontWeight.w600)),
        const SizedBox(height: AuraSpace.s6),
        DropdownButton<T>(
          value: value,
          isExpanded: true,
          dropdownColor: AuraSurface.overlay,
          items: values.map((v) => DropdownMenuItem(value: v, child: Text(text(v), style: AuraText.small))).toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ],
    );
  }

  Widget _createSection() {
    return WorkspaceSection(
      title: 'Create invite',
      description: 'An invite is a code and a link. Add an email to send it as well.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                child: _dropdown<String>(
                  label: 'Role',
                  value: _selectedRole,
                  values: _roles,
                  text: (r) => r[0] + r.substring(1).toLowerCase(),
                  onChanged: (v) => setState(() => _selectedRole = v),
                ),
              ),
              const SizedBox(width: AuraSpace.s12),
              Expanded(
                child: _dropdown<int>(
                  label: 'Valid for',
                  value: _expiresInDays,
                  values: const [1, 3, 7, 14, 30],
                  text: (d) => '$d day${d == 1 ? '' : 's'}',
                  onChanged: (v) => setState(() => _expiresInDays = v),
                ),
              ),
            ],
          ),
          if (_createError != null) ...[
            const SizedBox(height: AuraSpace.s12),
            WorkspaceNotice(message: _createError!),
          ],
          const SizedBox(height: AuraSpace.s16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _creating ? null : widget.onCloseCreate,
                style: TextButton.styleFrom(foregroundColor: AuraSurface.muted),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: AuraSpace.s8),
              WorkspacePrimaryButton(
                action: WorkspaceAction(
                  label: _creating ? 'Creating…' : 'Create invite',
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

  Widget _invite(Map<String, dynamic> invite) {
    final inviteId = invite['id']?.toString() ?? '';
    final code = invite['code']?.toString() ?? '';
    final email = invite['email']?.toString().trim() ?? '';
    final role = invite['role']?.toString() ?? '';
    final created = _formatDate(invite['createdAt']?.toString());
    final expiresAt = _formatDate(invite['expiresAt']?.toString());
    final usedBy = invite['usedBy'] is Map ? Map<String, dynamic>.from(invite['usedBy'] as Map) : null;
    final status = _inviteStatus(invite);
    final isCopied = _copiedCode == code;
    final isRevoking = _revoking == inviteId;
    // Invite creation and email delivery are different truths — a valid,
    // usable invite can still have a failed send. Surface that honestly
    // rather than implying the recipient was notified when they weren't.
    final deliveryFailed = invite['emailDeliveryStatus']?.toString() == 'FAILED';

    final contextLine = [
      if (email.isNotEmpty) 'Code $code',
      if (role.isNotEmpty) role[0] + role.substring(1).toLowerCase(),
      if (created.isNotEmpty) 'sent $created',
      if (usedBy != null)
        // F053/F116 — the shared fallback order.
        'used by ${AuraPersonIdentity.fromJson(usedBy).label}'
      else if (expiresAt.isNotEmpty && status != 'Used')
        status == 'Expired' ? 'expired $expiresAt' : 'expires $expiresAt',
    ].join(' · ');

    // Clear, labelled management surface per invite. Active invites can be
    // copied or revoked; used/expired invites have no actions.
    final Widget? menu = status != 'Active'
        ? null
        : isRevoking
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 18, color: AuraSurface.muted),
                tooltip: 'Invite options',
                color: AuraSurface.overlay,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AuraSurface.divider),
                ),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'copy',
                    child: Row(
                      children: [
                        Icon(isCopied ? Icons.check_rounded : Icons.link_rounded, size: 16, color: AuraSurface.accentText),
                        const SizedBox(width: AuraSpace.s10),
                        Text(isCopied ? 'Copied' : 'Copy invite link', style: AuraText.small.copyWith(color: AuraSurface.ink)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'revoke',
                    child: Row(
                      children: [
                        const Icon(Icons.link_off_rounded, size: 16, color: AuraSurface.dangerInk),
                        const SizedBox(width: AuraSpace.s10),
                        Text('Revoke invite', style: AuraText.small.copyWith(color: AuraSurface.dangerInk)),
                      ],
                    ),
                  ),
                ],
                onSelected: (v) {
                  if (v == 'copy') {
                    _copyLink(code);
                  } else if (v == 'revoke') {
                    _confirmRevoke(inviteId, code);
                  }
                },
              );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WorkspaceRow(
          leading: WorkspaceIcon(
            email.isNotEmpty ? Icons.mail_outline_rounded : Icons.link_rounded,
            tone: status == 'Active' ? WorkspaceTone.waiting : WorkspaceTone.neutral,
          ),
          // Who it is for when an email was given; otherwise the code itself.
          title: email.isNotEmpty ? email : code,
          context: contextLine,
          pill: WorkspacePill(label: status, tone: _statusTone(status)),
          trailing: menu,
        ),
        if (deliveryFailed && email.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(62, 0, 0, AuraSpace.s8),
            child: Text(
              'Invite email could not be delivered. The code above still works — share it directly.',
              style: AuraText.small.copyWith(color: AuraSurface.dangerInk),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final form = widget.showCreate ? [_createSection()] : const <Widget>[];
    if (_loading) return Column(children: [...form, const WorkspaceLoading()]);
    if (_error != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...form,
          WorkspaceEmpty(
            icon: Icons.error_outline_rounded,
            title: 'Could not load invites',
            body: _error!,
            action: WorkspaceAction(
              label: ProductLabels.of(ProductAction.retry),
              icon: Icons.refresh_rounded,
              onPressed: _load,
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...form,
        if (_revokeError != null)
          WorkspaceNotice(message: _revokeError!, onDismiss: () => setState(() => _revokeError = null)),
        if (_invites.isEmpty)
          WorkspaceEmpty(
            icon: Icons.group_add_outlined,
            title: 'No invites yet',
            body: 'Create one with Invite.',
            action: widget.showCreate || widget.onInvite == null
                ? null
                : WorkspaceAction(label: 'Invite', icon: Icons.person_add_alt_1_rounded, onPressed: widget.onInvite),
          )
        else
          ..._invites.map(_invite),
      ],
    );
  }
}
