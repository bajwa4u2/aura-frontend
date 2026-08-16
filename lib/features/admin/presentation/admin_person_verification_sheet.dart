import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/product/product_state.dart';
import '../../../core/product/product_state_view.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../data/admin_providers.dart';

/// C2 — Person Verification administration (§19 admin/governance
/// experience).
///
/// The governed layered record, presented in full: class, state, reason,
/// issuer, provenance, revocation and expiry. REVOKED and EXPIRED are
/// first-class states here — never flattened into "not verified" — because
/// governance is the audience for whom that history is the point.
/// `evidenceRef` stays server-side by design (least disclosure).
class AdminPersonVerificationSheet extends ConsumerStatefulWidget {
  const AdminPersonVerificationSheet({
    super.key,
    required this.userId,
    required this.userLabel,
  });

  final String userId;
  final String userLabel;

  static Future<void> show(
    BuildContext context, {
    required String userId,
    required String userLabel,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AuraSurface.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AuraRadius.card)),
      ),
      builder: (_) => AdminPersonVerificationSheet(
        userId: userId,
        userLabel: userLabel,
      ),
    );
  }

  @override
  ConsumerState<AdminPersonVerificationSheet> createState() =>
      _AdminPersonVerificationSheetState();
}

/// Canonical admin wording for the frozen backend taxonomy. Kept in the
/// admin layer (wire names are the contract here); public presentation
/// wording lives in the canonical trust layer.
const Map<String, String> _classLabels = {
  'IDENTITY': 'Identity',
  'INSTITUTION_AFFILIATION': 'Institution affiliation',
  'ROLE_OR_CREDENTIAL': 'Role or credential',
};

class _AdminPersonVerificationSheetState
    extends ConsumerState<AdminPersonVerificationSheet> {
  AdminPersonVerification? _data;
  Object? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _data = null;
      _error = null;
    });
    try {
      final data = await ref
          .read(adminRepositoryProvider)
          .fetchPersonVerification(widget.userId);
      if (mounted) setState(() => _data = data);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _grant() async {
    final data = _data;
    if (data == null) return;
    final available = _classLabels.keys
        .where((c) => !data.activeClasses.contains(c))
        .toList();
    if (available.isEmpty) return;
    final result = await _GrantDialog.show(context, available);
    if (result == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(adminRepositoryProvider).grantPersonVerification(
            widget.userId,
            verificationClass: result.verificationClass,
            reason: result.reason,
            issuingAuthority: result.issuingAuthority,
            issuingInstitutionId: result.issuingInstitutionId,
            classSubtype: result.classSubtype,
          );
      await _load();
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _revoke(String verificationClass) async {
    final reason = await _ReasonDialog.show(
      context,
      title: 'Revoke ${_classLabels[verificationClass] ?? verificationClass} '
          'verification',
      hint: 'Why is this verification being revoked?',
      confirmLabel: 'Revoke',
    );
    if (reason == null || reason.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      await ref.read(adminRepositoryProvider).revokePersonVerification(
            widget.userId,
            verificationClass: verificationClass,
            reason: reason.trim(),
          );
      await _load();
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Verification update failed: $e')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AuraSpace.s16,
          right: AuraSpace.s16,
          top: AuraSpace.s16,
          bottom: MediaQuery.of(context).viewInsets.bottom + AuraSpace.s16,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Verification — ${widget.userLabel}',
                  style: AuraText.headline),
              const SizedBox(height: AuraSpace.s4),
              Text(
                'Layered governed record. Classes are independent; granting '
                'one says nothing about the others.',
                style: AuraText.small.copyWith(color: AuraSurface.muted),
              ),
              const SizedBox(height: AuraSpace.s12),
              if (_error != null)
                Expanded(
                  child: AuraProductState(
                    state: ProductState.retryableError,
                    headline: 'Could not load the verification record',
                    onRecover: _load,
                  ),
                )
              else if (data == null)
                const Expanded(
                  child: AuraProductState(
                    state: ProductState.loading,
                    headline: 'Loading verification record…',
                  ),
                )
              else
                Flexible(child: _buildLoaded(data)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoaded(AdminPersonVerification data) {
    final grantable = _classLabels.keys
        .where((c) => !data.activeClasses.contains(c))
        .toList();
    return ListView(
      shrinkWrap: true,
      children: [
        Text('ACTIVE', style: AuraText.micro.copyWith(color: AuraSurface.faint)),
        const SizedBox(height: AuraSpace.s6),
        if (data.activeClasses.isEmpty)
          Text(
            'No active verification. Absence is not suspicion — nothing is '
            'presented publicly.',
            style: AuraText.small.copyWith(color: AuraSurface.muted),
          )
        else
          for (final c in data.activeClasses)
            Padding(
              padding: const EdgeInsets.only(bottom: AuraSpace.s6),
              child: Row(
                children: [
                  const Icon(Icons.verified_rounded,
                      size: 14, color: AuraSurface.coVerdant),
                  const SizedBox(width: AuraSpace.s6),
                  Expanded(
                    child: Text(
                      '${_classLabels[c] ?? c} verified',
                      style: AuraText.body,
                    ),
                  ),
                  TextButton(
                    onPressed: _busy ? null : () => _revoke(c),
                    child: const Text('Revoke'),
                  ),
                ],
              ),
            ),
        const SizedBox(height: AuraSpace.s8),
        if (grantable.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _grant,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Grant verification'),
            ),
          ),
        const SizedBox(height: AuraSpace.s16),
        Text('HISTORY', style: AuraText.micro.copyWith(color: AuraSurface.faint)),
        const SizedBox(height: AuraSpace.s6),
        if (data.history.isEmpty)
          Text(
            'No verification events.',
            style: AuraText.small.copyWith(color: AuraSurface.muted),
          )
        else
          for (final row in data.history) _HistoryRow(row: row),
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.row});

  final AdminPersonVerificationRecord row;

  Color _stateColor(String state) {
    switch (state.toUpperCase()) {
      case 'VERIFIED':
        return AuraSurface.coVerdant;
      case 'REVOKED':
        return AuraSurface.coRose;
      case 'EXPIRED':
        return AuraSurface.faint;
      default:
        return AuraSurface.muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = _classLabels[row.verificationClass] ?? row.verificationClass;
    final details = <String>[
      if ((row.classSubtype ?? '').isNotEmpty) 'Subtype: ${row.classSubtype}',
      if ((row.issuingAuthority ?? '').isNotEmpty)
        'Issued by ${row.issuingAuthority}',
      'Reason: ${row.reason}',
      if ((row.revocationReason ?? '').isNotEmpty)
        'Revocation: ${row.revocationReason}',
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.s10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label,
                    style: AuraText.body.copyWith(fontWeight: FontWeight.w600)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AuraSpace.s6, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AuraRadius.pill),
                  border: Border.all(color: _stateColor(row.state)),
                ),
                child: Text(
                  row.state.toUpperCase(),
                  style: AuraText.micro.copyWith(
                    color: _stateColor(row.state),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            details.join(' · '),
            style: AuraText.small.copyWith(color: AuraSurface.muted),
          ),
        ],
      ),
    );
  }
}

class _GrantResult {
  const _GrantResult({
    required this.verificationClass,
    required this.reason,
    this.issuingAuthority,
    this.issuingInstitutionId,
    this.classSubtype,
  });

  final String verificationClass;
  final String reason;
  final String? issuingAuthority;
  final String? issuingInstitutionId;
  final String? classSubtype;
}

class _GrantDialog extends StatefulWidget {
  const _GrantDialog({required this.availableClasses});

  final List<String> availableClasses;

  static Future<_GrantResult?> show(
    BuildContext context,
    List<String> availableClasses,
  ) {
    return showDialog<_GrantResult>(
      context: context,
      builder: (_) => _GrantDialog(availableClasses: availableClasses),
    );
  }

  @override
  State<_GrantDialog> createState() => _GrantDialogState();
}

class _GrantDialogState extends State<_GrantDialog> {
  late String _verificationClass = widget.availableClasses.first;
  final _reason = TextEditingController();
  final _issuingAuthority = TextEditingController();
  final _issuingInstitutionId = TextEditingController();
  final _classSubtype = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    _issuingAuthority.dispose();
    _issuingInstitutionId.dispose();
    _classSubtype.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAffiliation = _verificationClass == 'INSTITUTION_AFFILIATION';
    final isRole = _verificationClass == 'ROLE_OR_CREDENTIAL';
    return AlertDialog(
      title: const Text('Grant verification'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _verificationClass,
              decoration: const InputDecoration(labelText: 'Class'),
              items: [
                for (final c in widget.availableClasses)
                  DropdownMenuItem(value: c, child: Text(_classLabels[c] ?? c)),
              ],
              onChanged: (v) =>
                  setState(() => _verificationClass = v ?? _verificationClass),
            ),
            TextField(
              controller: _reason,
              decoration: const InputDecoration(
                labelText: 'Reason (required)',
                helperText: 'Recorded on the governed record.',
              ),
            ),
            if (isAffiliation)
              TextField(
                controller: _issuingInstitutionId,
                decoration: const InputDecoration(
                  labelText: 'Institution ID (required)',
                  helperText:
                      'Affiliation must name the institution it affiliates '
                      'the person with.',
                ),
              ),
            if (isRole)
              TextField(
                controller: _classSubtype,
                decoration: const InputDecoration(
                  labelText: 'Subtype (optional)',
                  helperText: 'e.g. a specific professional designation.',
                ),
              ),
            TextField(
              controller: _issuingAuthority,
              decoration: const InputDecoration(
                labelText: 'Issuing authority (optional)',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_reason.text.trim().isEmpty) return;
            Navigator.of(context).pop(
              _GrantResult(
                verificationClass: _verificationClass,
                reason: _reason.text.trim(),
                issuingAuthority: _issuingAuthority.text.trim().isEmpty
                    ? null
                    : _issuingAuthority.text.trim(),
                issuingInstitutionId: _issuingInstitutionId.text.trim().isEmpty
                    ? null
                    : _issuingInstitutionId.text.trim(),
                classSubtype: _classSubtype.text.trim().isEmpty
                    ? null
                    : _classSubtype.text.trim(),
              ),
            );
          },
          child: const Text('Grant'),
        ),
      ],
    );
  }
}

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({
    required this.title,
    required this.hint,
    required this.confirmLabel,
  });

  final String title;
  final String hint;
  final String confirmLabel;

  static Future<String?> show(
    BuildContext context, {
    required String title,
    required String hint,
    required String confirmLabel,
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) =>
          _ReasonDialog(title: title, hint: hint, confirmLabel: confirmLabel),
    );
  }

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _reason,
        decoration: InputDecoration(labelText: widget.hint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_reason.text.trim().isEmpty) return;
            Navigator.of(context).pop(_reason.text.trim());
          },
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
