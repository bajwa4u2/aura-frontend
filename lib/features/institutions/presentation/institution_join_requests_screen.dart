import 'package:aura/core/product/temporal.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/authority/authority_providers.dart';
import '../../../core/authority/capability_projection.dart';
import '../../../core/institutions/institution_access_provider.dart';
import '../../../core/product/product_language.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../data/institution_pending_counts.dart';
import '../data/institutions_repository.dart';
import '../workspace/workspace_page.dart';
import 'institution_members_screen.dart';
import '../../../core/identity/person_identity_model.dart';

/// JOIN REQUESTS (DD-43, 2026-10-09).
///
/// For people who answer requests, this route is the Members page on its
/// Join requests tab. For someone outside the institution it is the request
/// form itself, a Settings page with one Submit bar.
class InstitutionJoinRequestsScreen extends ConsumerWidget {
  const InstitutionJoinRequestsScreen({
    super.key,
    required this.institutionId,
  });

  final String institutionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Single source of truth for admin gating — never trust route query
    // params. Subscribed so role changes re-render the right page.
    final adminByIdentity = ref.watch(institutionIdentityProvider)?.isAdmin ?? false;
    final mayAnswer = ref.watch(capabilityProjectionForProvider(institutionId)).presentationFor(
              ConsequentialAct.manageJoinRequests,
            ) ==
        ControlPresentation.available;
    if (adminByIdentity || mayAnswer) {
      return InstitutionMembersScreen(institutionId: institutionId, initialTab: 'requests');
    }
    return _RequestAccessPage(institutionId: institutionId);
  }
}

/// The Join requests tab: the people asking to join, answered in place.
class InstitutionJoinRequestsPanel extends ConsumerStatefulWidget {
  const InstitutionJoinRequestsPanel({super.key, required this.institutionId});

  final String institutionId;

  @override
  ConsumerState<InstitutionJoinRequestsPanel> createState() => _JoinRequestsPanelState();
}

class _JoinRequestsPanelState extends ConsumerState<InstitutionJoinRequestsPanel> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _requests = const [];
  String? _actingOn;
  String? _actionError;

  InstitutionsRepository get _repo => ref.read(institutionsRepositoryProvider);

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
      final items = await _repo.listJoinRequests(widget.institutionId);
      if (!mounted) return;
      setState(() {
        _requests = items;
        _loading = false;
        _actingOn = null;
      });
      // Keep the shared attention counts (tab count + nav badges) in sync
      // with what this tab just loaded / changed.
      ref.invalidate(institutionPendingCountsProvider(widget.institutionId));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _joinRequestMessage(e, 'Could not load join requests.');
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
        _actionError = _joinRequestMessage(e, 'Could not approve request.');
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
        _actionError = _joinRequestMessage(e, 'Could not reject request.');
        _actingOn = null;
      });
    }
  }

  Widget _request(Map<String, dynamic> req) {
    final reqId = req['id']?.toString() ?? '';
    final user = req['user'] is Map ? Map<String, dynamic>.from(req['user'] as Map) : <String, dynamic>{};
    // F053/F116 — canonical read; 'Unknown' was this screen's own invented
    // label for a person it failed to resolve.
    final person = AuraPersonIdentity.fromJson(user);
    final message = req['message']?.toString().trim() ?? '';
    final created = DateTime.tryParse(req['createdAt']?.toString() ?? '');
    final isActing = _actingOn == reqId;

    final actions = isActing
        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () => _reject(reqId),
                style: TextButton.styleFrom(foregroundColor: AuraSurface.muted),
                child: const Text('Reject'),
              ),
              TextButton.icon(
                onPressed: () => _approve(reqId),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Approve'),
                style: TextButton.styleFrom(
                  foregroundColor: AuraSurface.accentText,
                  textStyle: const TextStyle(fontFamily: 'AuraSans', fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          );

    // Admitting someone is a trust decision, so their verification travels
    // with their name, and what they wrote is shown in full under the row.
    // On a narrow screen Approve and Reject move under it, so neither the
    // name nor the mark is squeezed.
    return LayoutBuilder(
      builder: (context, box) {
        final narrow = box.maxWidth < 560;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            WorkspaceRow(
              leading: AuraAvatar(name: person.label, imageUrl: person.avatarUrl, size: 36),
              title: person.label,
              context: [
                if (person.handle.isNotEmpty) '@${person.handle}',
                if (created != null) 'asked ${AuraTemporal.fullShort(created)}',
              ].join(' · '),
              trailing: personTrailing(person, narrow ? null : actions),
            ),
            if (message.isNotEmpty)
              Padding(
                padding: EdgeInsets.fromLTRB(narrow ? AuraSpace.s14 : 62, 0, AuraSpace.s14, AuraSpace.s12),
                child: Container(
                  padding: const EdgeInsets.only(left: AuraSpace.s12),
                  decoration: const BoxDecoration(
                    border: Border(left: BorderSide(color: AuraSurface.divider, width: 2)),
                  ),
                  child: Text(message, style: AuraText.body.copyWith(height: 1.5)),
                ),
              ),
            if (narrow)
              Padding(
                padding: const EdgeInsets.only(bottom: AuraSpace.s12),
                child: Align(alignment: Alignment.centerRight, child: actions),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const WorkspaceLoading();
    if (_error != null) {
      return WorkspaceEmpty(
        icon: Icons.error_outline_rounded,
        title: 'Could not load join requests',
        body: _error!,
        action: WorkspaceAction(
          label: ProductLabels.of(ProductAction.retry),
          icon: Icons.refresh_rounded,
          onPressed: _load,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_actionError != null)
          WorkspaceNotice(message: _actionError!, onDismiss: () => setState(() => _actionError = null)),
        if (_requests.isEmpty)
          const WorkspaceEmpty(
            icon: Icons.inbox_outlined,
            title: 'No pending requests',
            body: 'Requests to join appear here.',
          )
        else
          ..._requests.map(_request),
      ],
    );
  }
}

/// Someone outside the institution asking to join it.
class _RequestAccessPage extends ConsumerStatefulWidget {
  const _RequestAccessPage({required this.institutionId});

  final String institutionId;

  @override
  ConsumerState<_RequestAccessPage> createState() => _RequestAccessPageState();
}

class _RequestAccessPageState extends ConsumerState<_RequestAccessPage> {
  bool _submittingJoin = false;
  String? _joinError;
  String? _joinSuccess;
  final _messageController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitJoin() async {
    if (_submittingJoin) return;
    setState(() {
      _submittingJoin = true;
      _joinError = null;
      _joinSuccess = null;
    });
    try {
      await ref.read(institutionsRepositoryProvider).createJoinRequest(
            widget.institutionId,
            message: _messageController.text.trim().isEmpty ? null : _messageController.text.trim(),
          );
      _messageController.clear();
      setState(() {
        _submittingJoin = false;
        _joinSuccess = 'Your request has been submitted. An admin will review it shortly.';
      });
    } catch (e) {
      setState(() {
        _joinError = _joinRequestMessage(e, 'Could not submit join request.');
        _submittingJoin = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WorkspacePage(
      type: WorkspacePageType.settings,
      title: 'Request access',
      purpose: 'Send a request to the institution admins. They will review and approve or reject it.',
      bar: WorkspaceBar(
        primary: WorkspaceAction(
          label: _submittingJoin ? 'Submitting…' : 'Submit request',
          icon: Icons.send_rounded,
          onPressed: _joinSuccess != null || _submittingJoin ? null : _submitJoin,
        ),
      ),
      children: [
        if (_joinError != null) WorkspaceNotice(message: _joinError!),
        if (_joinSuccess != null) WorkspaceNotice(message: _joinSuccess!, tone: WorkspaceTone.done),
        WorkspaceSection(
          title: 'Your request',
          child: TextFormField(
            controller: _messageController,
            maxLines: null,
            minLines: 3,
            style: AuraText.body,
            enabled: _joinSuccess == null,
            decoration: const InputDecoration(
              labelText: 'Message (optional)',
              hintText: 'Briefly explain why you\'d like to join…',
              alignLabelWithHint: true,
            ),
          ),
        ),
      ],
    );
  }
}

String _joinRequestMessage(Object error, String fallback) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map) {
      final msg = data['message']?.toString().trim() ?? '';
      if (msg.isNotEmpty) return msg;
    }
  }
  return fallback;
}
