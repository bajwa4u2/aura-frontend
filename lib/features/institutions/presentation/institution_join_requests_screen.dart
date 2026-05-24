import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/institutions/institution_access_provider.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../data/institutions_repository.dart';
import '../ui/institution_ds.dart';
import 'institution_page.dart';

class InstitutionJoinRequestsScreen extends ConsumerStatefulWidget {
  const InstitutionJoinRequestsScreen({
    super.key,
    required this.institutionId,
  });

  final String institutionId;

  @override
  ConsumerState<InstitutionJoinRequestsScreen> createState() =>
      _InstitutionJoinRequestsScreenState();
}

class _InstitutionJoinRequestsScreenState
    extends ConsumerState<InstitutionJoinRequestsScreen> {
  bool _loading = true;
  String? _error;
  bool _initialLoadStarted = false;

  List<Map<String, dynamic>> _requests = const [];

  String? _actingOn;
  String? _actionError;

  // Non-member: request-to-join state
  bool _submittingJoin = false;
  String? _joinError;
  String? _joinSuccess;
  final _messageController = TextEditingController();

  InstitutionsRepository get _repo => ref.read(institutionsRepositoryProvider);

  /// Single source of truth for admin gating — never trust route query params.
  bool get _isAdmin =>
      ref.read(institutionIdentityProvider)?.isAdmin ?? false;

  @override
  void initState() {
    super.initState();
    // Defer the admin-only load until the first build — at initState the
    // institution identity may still be settling, so reading it here can
    // race the access provider.
  }

  void _ensureInitialLoad() {
    if (_initialLoadStarted) return;
    if (!_isAdmin) {
      _initialLoadStarted = true;
      _loading = false;
      return;
    }
    _initialLoadStarted = true;
    _load();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _repo.listJoinRequests(widget.institutionId);
      setState(() {
        _requests = items;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = _message(e, 'Could not load join requests.');
        _loading = false;
      });
    }
  }

  Future<void> _approve(String requestId) async {
    if (_actingOn != null) return;
    setState(() {
      _actingOn = requestId;
      _actionError = null;
    });
    try {
      await _repo.approveJoinRequest(widget.institutionId, requestId);
      await _load();
    } catch (e) {
      setState(() {
        _actionError = _message(e, 'Could not approve request.');
        _actingOn = null;
      });
    }
  }

  Future<void> _reject(String requestId) async {
    if (_actingOn != null) return;
    setState(() {
      _actingOn = requestId;
      _actionError = null;
    });
    try {
      await _repo.rejectJoinRequest(widget.institutionId, requestId);
      await _load();
    } catch (e) {
      setState(() {
        _actionError = _message(e, 'Could not reject request.');
        _actingOn = null;
      });
    }
  }

  Future<void> _submitJoin() async {
    if (_submittingJoin) return;
    setState(() {
      _submittingJoin = true;
      _joinError = null;
      _joinSuccess = null;
    });
    try {
      await _repo.createJoinRequest(
        widget.institutionId,
        message: _messageController.text.trim().isEmpty
            ? null
            : _messageController.text.trim(),
      );
      _messageController.clear();
      setState(() {
        _submittingJoin = false;
        _joinSuccess = 'Your request has been submitted. An admin will review it shortly.';
      });
    } catch (e) {
      setState(() {
        _joinError = _message(e, 'Could not submit join request.');
        _submittingJoin = false;
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

  Widget _buildRequestTile(Map<String, dynamic> req) {
    final reqId = req['id']?.toString() ?? '';
    final user = req['user'] is Map
        ? Map<String, dynamic>.from(req['user'] as Map)
        : <String, dynamic>{};
    final displayName = user['displayName']?.toString().trim() ?? '';
    final handle = user['handle']?.toString().trim() ?? '';
    final message = req['message']?.toString().trim() ?? '';
    final createdAt = req['createdAt']?.toString() ?? '';
    final nameOrHandle = displayName.isNotEmpty ? displayName : (handle.isNotEmpty ? '@$handle' : 'Unknown');
    final isActing = _actingOn == reqId;

    final date = () {
      final dt = DateTime.tryParse(createdAt);
      if (dt == null) return '';
      final local = dt.toLocal();
      return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
    }();

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
              if (date.isNotEmpty)
                Text(
                  date,
                  style: AuraText.micro.copyWith(color: AuraSurface.faint),
                ),
            ],
          ),
          if (message.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AuraSpace.s10),
              decoration: BoxDecoration(
                color: AuraSurface.subtle,
                borderRadius: BorderRadius.circular(AuraRadius.md),
              ),
              child: Text(
                message,
                style: AuraText.small.copyWith(
                  color: AuraSurface.ink,
                  height: 1.5,
                ),
              ),
            ),
          ],
          const SizedBox(height: AuraSpace.s12),
          if (isActing)
            const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: AuraPrimaryButton(
                    label: 'Approve',
                    onPressed: () => _approve(reqId),
                    icon: Icons.check_rounded,
                  ),
                ),
                const SizedBox(width: AuraSpace.s10),
                Expanded(
                  child: AuraSecondaryButton(
                    label: 'Reject',
                    onPressed: () => _reject(reqId),
                    icon: Icons.close_rounded,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildAdminBody() {
    if (_loading) return const AuraLoadingState(message: 'Loading requests…');

    if (_error != null) {
      return AuraErrorState(
        title: 'Could not load join requests',
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
        if (_actionError != null) ...[
          Container(
            padding: const EdgeInsets.all(AuraSpace.s12),
            margin: const EdgeInsets.only(bottom: AuraSpace.s12),
            decoration: BoxDecoration(
              color: AuraSurface.coRose.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AuraRadius.md),
              border: Border.all(color: AuraSurface.coRose.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, size: 16, color: AuraSurface.coRose),
                const SizedBox(width: AuraSpace.s8),
                Expanded(
                  child: Text(
                    _actionError!,
                    style: AuraText.small.copyWith(color: AuraSurface.coRose),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _actionError = null),
                  child: const Icon(Icons.close, size: 16, color: AuraSurface.coRose),
                ),
              ],
            ),
          ),
        ],
        Text(
          '${_requests.length} pending request${_requests.length == 1 ? '' : 's'}',
          style: AuraText.small.copyWith(color: AuraSurface.muted),
        ),
        const SizedBox(height: AuraSpace.s12),
        if (_requests.isEmpty)
          const InsEmptyState(
            icon: Icons.inbox_outlined,
            title: 'No pending requests',
            description: 'Join requests from non-members will appear here.',
          )
        else
          ..._requests.map(_buildRequestTile),
      ],
    );
  }

  Widget _buildNonMemberBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(AuraSpace.s16),
          decoration: BoxDecoration(
            color: AuraSurface.card,
            borderRadius: BorderRadius.circular(AuraRadius.card),
            border: Border.all(color: AuraSurface.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _messageController,
                maxLines: 3,
                style: AuraText.body,
                enabled: _joinSuccess == null,
                decoration: const InputDecoration(
                  labelText: 'Message (optional)',
                  hintText: 'Briefly explain why you\'d like to join…',
                  alignLabelWithHint: true,
                ),
              ),
              if (_joinError != null) ...[
                const SizedBox(height: AuraSpace.s12),
                Container(
                  padding: const EdgeInsets.all(AuraSpace.s10),
                  decoration: BoxDecoration(
                    color: AuraSurface.coRose.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(AuraRadius.md),
                    border: Border.all(color: AuraSurface.coRose.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    _joinError!,
                    style: AuraText.small.copyWith(color: AuraSurface.coRose),
                  ),
                ),
              ],
              if (_joinSuccess != null) ...[
                const SizedBox(height: AuraSpace.s12),
                Container(
                  padding: const EdgeInsets.all(AuraSpace.s10),
                  decoration: BoxDecoration(
                    color: AuraSurface.coVerdant.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(AuraRadius.md),
                    border: Border.all(color: AuraSurface.coVerdant.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, size: 16, color: AuraSurface.coVerdant),
                      const SizedBox(width: AuraSpace.s8),
                      Expanded(
                        child: Text(
                          _joinSuccess!,
                          style: AuraText.small.copyWith(color: AuraSurface.coVerdant),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Subscribe so role changes drive a rebuild and re-render the right body.
    ref.watch(institutionIdentityProvider);
    _ensureInitialLoad();

    final Widget? trailing = _isAdmin
        ? null
        : AuraPrimaryButton(
            label: _submittingJoin ? 'Submitting…' : 'Submit request',
            icon: Icons.send_rounded,
            onPressed:
                _joinSuccess != null || _submittingJoin ? null : _submitJoin,
          );

    return InstitutionPage(
      title: _isAdmin ? 'Join requests' : 'Request access',
      subtitle: _isAdmin
          ? 'Review and approve or reject member requests.'
          : 'Send a request to the institution admins. They will review and approve or reject it.',
      trailing: trailing,
      body: _isAdmin ? _buildAdminBody() : _buildNonMemberBody(),
    );
  }
}
