import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';

class InstitutionDashboardScreen extends ConsumerStatefulWidget {
  const InstitutionDashboardScreen({super.key});

  @override
  ConsumerState<InstitutionDashboardScreen> createState() =>
      _InstitutionDashboardScreenState();
}

class _InstitutionDashboardScreenState
    extends ConsumerState<InstitutionDashboardScreen> {
  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _membership;
  Map<String, dynamic>? _institution;
  Map<String, dynamic>? _request;
  String _state = 'SIGNED_IN_NO_STANDING';

  Dio get _dio => ref.read(dioProvider);

  Map<String, dynamic> get _requestData => _request ?? <String, dynamic>{};

  bool get _hasInstitution =>
      _institution != null &&
      ((_institution!['id']?.toString().trim().isNotEmpty) ?? false);

  bool get _canUseInstitutionTools =>
      _state == 'VERIFIED_MEMBER' || _state == 'AUTHORIZED_SPEAKER';

  bool get _canManageDomains =>
      _state == 'VERIFIED_MEMBER' || _state == 'AUTHORIZED_SPEAKER';

  bool get _isAdmin =>
      _membership?['role']?.toString().trim().toUpperCase() == 'ADMIN';

  bool get _isPending => _state == 'PENDING_REQUEST';

  bool get _isRejected => _state == 'REJECTED';

  bool get _isSuspended => _state == 'SUSPENDED';

  bool get _hasRequest => _requestData.isNotEmpty;

  bool get _domainVerified {
    final verifiedAt =
        _institution?['domainVerifiedAt']?.toString().trim() ?? '';
    return verifiedAt.isNotEmpty;
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
      final res = await _dio.get('/institutions/me');
      final data = _map(res.data);

      final membership = _mapOrNull(data['membership']);
      final institution = _mapOrNull(membership?['institution']);
      final request = _mapOrNull(data['request']);
      final state = (data['state']?.toString().trim().isNotEmpty ?? false)
          ? data['state'].toString().trim()
          : 'SIGNED_IN_NO_STANDING';

      setState(() {
        _membership = membership;
        _institution = institution;
        _request = request;
        _state = state;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = _dioMessage(e, 'Could not load institution dashboard.');
        _loading = false;
      });
    }
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }

  Map<String, dynamic>? _mapOrNull(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  String _dioMessage(Object error, String fallback) {
    if (error is DioException) {
      final data = error.response?.data;

      if (data is Map && data['message'] != null) {
        final msg = data['message'].toString().trim();
        if (msg.isNotEmpty) return msg;
      }

      if (data is Map && data['error'] is Map) {
        final inner = data['error'];
        if (inner is Map && inner['message'] != null) {
          final msg = inner['message'].toString().trim();
          if (msg.isNotEmpty) return msg;
        }
      }

      if (error.message != null && error.message!.trim().isNotEmpty) {
        return error.message!.trim();
      }
    }

    return fallback;
  }

  void _go(String route) {
    if (!mounted) return;
    context.go(route);
  }

  String _standingLabel() {
    switch (_state) {
      case 'PUBLIC':
        return 'Public';
      case 'SIGNED_IN_NO_STANDING':
        return 'Signed in, no standing';
      case 'PENDING_REQUEST':
        return 'Under review';
      case 'VERIFIED_MEMBER':
        return 'Verified member';
      case 'AUTHORIZED_SPEAKER':
        return 'Authorized speaker';
      case 'SUSPENDED':
        return 'Suspended';
      case 'REJECTED':
        return 'Rejected';
      default:
        return _state;
    }
  }

  String _nextStepTitle() {
    if (_isPending) return 'Under review';
    if (_canManageDomains) return 'Institution active';
    if (_isRejected) return 'Request outcome';
    if (_isSuspended) return 'Standing suspended';
    return 'Begin institutional standing';
  }

  String _nextStepBody() {
    if (_isPending) {
      final org = _requestData['organizationName']?.toString().trim() ?? '';
      if (org.isNotEmpty) {
        return 'Your institutional account request for $org is under review. There is nothing you need to do right now.';
      }
      return 'Your institutional account request is under review. There is nothing you need to do right now.';
    }

    if (_canManageDomains) {
      if (_domainVerified) {
        return 'Institutional standing is active. Domain ownership is verified and institutional trust is fully established.';
      }
      return 'Institutional standing is active. All institutional surfaces are available. Domain verification is an optional trust enhancement — add it from the Domains screen when ready.';
    }

    if (_isRejected) {
      return 'This institutional request was rejected. Review the request details below, then submit a fresh institutional account request when ready.';
    }

    if (_isSuspended) {
      return 'This institutional standing is currently suspended. Institutional actions remain unavailable until standing is restored.';
    }

    return 'Create an institutional account to begin verification and establish standing inside Aura.';
  }

  String? _primaryActionLabel() {
    if (_isPending) return null;
    if (_canManageDomains) return null;
    if (_isRejected) return 'Create institutional account';
    if (_isSuspended) return null;
    return 'Create institutional account';
  }

  VoidCallback? _primaryAction() {
    if (_isPending) return null;
    if (_canManageDomains) return null;
    if (_isRejected) return () => _go('/institutions/get-started');
    if (_isSuspended) return null;
    return () => _go('/institutions/get-started');
  }

  String _displayInstitutionName() {
    final name = _institution?['name']?.toString().trim() ?? '';
    final requestOrg =
        _requestData['organizationName']?.toString().trim() ?? '';
    if (name.isNotEmpty) return name;
    if (requestOrg.isNotEmpty) return requestOrg;
    return 'Institution';
  }

  Widget _buildStatusCard() {
    final displayName = _displayInstitutionName();
    final slug = _institution?['slug']?.toString().trim() ?? '';
    final domain = _institution?['domain']?.toString().trim() ?? '';
    final website = (_institution?['websiteUrl'] ?? _institution?['website'])
            ?.toString()
            .trim() ??
        '';
    final role = _membership?['role']?.toString().trim() ?? '';
    final memberCount = _institution?['memberCount'];

    final details = <_DetailEntry>[
      _DetailEntry('Standing', _standingLabel()),
      if (role.isNotEmpty) _DetailEntry('Role', role),
      if (memberCount != null) _DetailEntry('Members', memberCount.toString()),
      if (slug.isNotEmpty) _DetailEntry('Public path', '/institutions/$slug'),
      if (domain.isNotEmpty) _DetailEntry('Domain', domain),
      if (website.isNotEmpty) _DetailEntry('Website', website),
      if (_membership?['canSpeakOfficially'] == true)
        const _DetailEntry('Official speech', 'Active'),
    ];

    return _DashCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AuraSurface.accentSoft,
                  borderRadius: BorderRadius.circular(AuraRadius.r12),
                  border: Border.all(
                    color: AuraSurface.accent.withValues(alpha: 0.25),
                  ),
                ),
                child: const Icon(
                  Icons.apartment_outlined,
                  size: 20,
                  color: AuraSurface.accentText,
                ),
              ),
              const SizedBox(width: AuraSpace.s14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(displayName, style: AuraText.subtitle),
                    const SizedBox(height: AuraSpace.s4),
                    Text(
                      'Institution status',
                      style: AuraText.small.copyWith(color: AuraSurface.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s16),
          ...details.map((d) => _DetailRow(label: d.label, value: d.value)),
        ],
      ),
    );
  }

  Widget _buildNextStepCard() {
    final actionLabel = _primaryActionLabel();
    final action = _primaryAction();

    Color iconColor = AuraSurface.accentText;
    IconData stepIcon = Icons.arrow_forward_rounded;
    if (_isPending) {
      stepIcon = Icons.hourglass_top_rounded;
      iconColor = AuraSurface.warnInk;
    } else if (_domainVerified && _canUseInstitutionTools) {
      stepIcon = Icons.check_circle_outline_rounded;
      iconColor = AuraSurface.goodInk;
    } else if (_isRejected || _isSuspended) {
      stepIcon = Icons.error_outline_rounded;
      iconColor = AuraSurface.dangerInk;
    }

    return _DashCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(stepIcon, size: 18, color: iconColor),
              const SizedBox(width: AuraSpace.s10),
              Text(
                _nextStepTitle(),
                style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s10),
          Text(
            _nextStepBody(),
            style: AuraText.small.copyWith(
              color: AuraSurface.muted,
              height: 1.45,
            ),
          ),
          if (actionLabel != null && action != null) ...[
            const SizedBox(height: AuraSpace.s16),
            AuraPrimaryButton(
              label: actionLabel,
              onPressed: action,
              icon: Icons.arrow_forward_rounded,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPipelineCard() {
    final step1Done = _hasRequest || _hasInstitution || _canUseInstitutionTools;
    final step2Done = _isPending || _canUseInstitutionTools || _isSuspended;
    final step3Done =
        _hasInstitution || _canUseInstitutionTools || _isSuspended;
    final step4Done = _domainVerified;
    final step5Done = _canUseInstitutionTools;

    final steps = [
      _PipelineStep(
        title: 'Request submitted',
        subtitle: 'Institutional account request has entered review.',
        isDone: step1Done,
        isCurrent: !step1Done,
      ),
      _PipelineStep(
        title: 'Review',
        subtitle: 'Identity, role, and institutional standing are reviewed.',
        isDone: step2Done,
        isCurrent: _isPending,
      ),
      _PipelineStep(
        title: 'Institution created',
        subtitle: 'Institution and membership are created after approval.',
        isDone: step3Done,
        isCurrent: _hasInstitution && !step4Done,
      ),
      _PipelineStep(
        title: 'Domain verified',
        subtitle: 'Domain ownership is confirmed through DNS verification.',
        isDone: step4Done,
        isCurrent: _canManageDomains && !step4Done,
      ),
      _PipelineStep(
        title: 'Institution active',
        subtitle: 'Official institutional tools become available.',
        isDone: step5Done,
        isCurrent: step4Done && _canUseInstitutionTools,
        isLast: true,
      ),
    ];

    return _DashCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Institution standing',
            style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AuraSpace.s16),
          ...steps.map((s) => _PipelineRow(step: s)),
        ],
      ),
    );
  }

  Widget _buildRequestDetailsCard() {
    if (!_hasRequest) return const SizedBox.shrink();

    final org = _requestData['organizationName']?.toString().trim() ?? '';
    final workEmail = _requestData['workEmail']?.toString().trim() ?? '';
    final website = _requestData['websiteUrl']?.toString().trim() ?? '';
    final domain = _requestData['domain']?.toString().trim() ?? '';
    final roleTitle = _requestData['roleTitle']?.toString().trim() ?? '';
    final jurisdiction = _requestData['jurisdiction']?.toString().trim() ?? '';
    final status = _requestData['status']?.toString().trim() ?? '';
    final reviewNotes = _requestData['reviewNotes']?.toString().trim() ?? '';
    final reviewedAt = _requestData['reviewedAt']?.toString().trim() ?? '';

    return _DashCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Request details',
            style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AuraSpace.s14),
          if (org.isNotEmpty) _DetailRow(label: 'Institution', value: org),
          if (status.isNotEmpty) _DetailRow(label: 'Status', value: status),
          if (reviewNotes.isNotEmpty)
            _DetailRow(label: 'Review notes', value: reviewNotes),
          if (workEmail.isNotEmpty)
            _DetailRow(label: 'Work email', value: workEmail),
          if (website.isNotEmpty) _DetailRow(label: 'Website', value: website),
          if (domain.isNotEmpty) _DetailRow(label: 'Domain', value: domain),
          if (roleTitle.isNotEmpty)
            _DetailRow(label: 'Representative title', value: roleTitle),
          if (jurisdiction.isNotEmpty)
            _DetailRow(label: 'Jurisdiction', value: jurisdiction),
          if (reviewedAt.isNotEmpty)
            _DetailRow(label: 'Reviewed at', value: reviewedAt, isLast: true),
        ],
      ),
    );
  }

  Widget _buildToolsSection() {
    final institutionId = _institution?['id']?.toString() ?? '';
    final pendingJoinCount = _membership?['pendingJoinRequestCount'] as int? ?? 0;

    final tools = [
      _ToolData(
        title: 'Announcements',
        body: 'Publish official institutional announcements to members and the public.',
        icon: Icons.campaign_outlined,
        enabled: _canUseInstitutionTools,
        onTap: _canUseInstitutionTools && institutionId.isNotEmpty
            ? () => _go('/institution/$institutionId/announcements')
            : null,
      ),
      _ToolData(
        title: 'Spaces',
        body: 'Create and manage institution spaces for members to collaborate.',
        icon: Icons.forum_outlined,
        enabled: _canUseInstitutionTools,
        onTap: _canUseInstitutionTools && institutionId.isNotEmpty
            ? () => _go('/institution/$institutionId/spaces')
            : null,
      ),
      _ToolData(
        title: 'Representatives',
        body:
            'View and manage institution members, roles, and speaking authority.',
        icon: Icons.people_outline_rounded,
        enabled: _canUseInstitutionTools,
        onTap: _canUseInstitutionTools && institutionId.isNotEmpty
            ? () => _go('/institution/$institutionId/members')
            : null,
      ),
      _ToolData(
        title: 'Domains',
        body:
            'Attach and verify institutional domains through DNS ownership checks.',
        icon: Icons.language_rounded,
        enabled: _canManageDomains,
        onTap: _canManageDomains ? () => _go('/institution/domains') : null,
      ),
      _ToolData(
        title: 'Invite members',
        body:
            'Send invite codes to colleagues to join your institution workspace.',
        icon: Icons.group_add_outlined,
        enabled: _isAdmin,
        onTap: _isAdmin && institutionId.isNotEmpty
            ? () => _go('/institution/$institutionId/invites')
            : null,
      ),
      _ToolData(
        title: 'Join requests',
        body: 'Review and approve requests from members who want to join.',
        icon: Icons.person_add_outlined,
        enabled: _isAdmin,
        badge: pendingJoinCount > 0 ? pendingJoinCount : null,
        onTap: _isAdmin && institutionId.isNotEmpty
            ? () => _go('/institution/$institutionId/join-requests')
            : null,
      ),
      _ToolData(
        title: 'Institution profile',
        body:
            'View and edit public identity, description, and institutional profile surfaces.',
        icon: Icons.badge_outlined,
        enabled: _canUseInstitutionTools,
        onTap: _canUseInstitutionTools
            ? () => _go('/institution/profile')
            : null,
      ),
      _ToolData(
        title: 'Units & branches',
        body:
            'Manage departments, branches, offices, and products listed under this institution.',
        icon: Icons.account_tree_outlined,
        enabled: _isAdmin && _hasInstitution,
        onTap: _isAdmin && institutionId.isNotEmpty
            ? () => _go('/institution/$institutionId/units')
            : null,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AuraSpace.s4,
            bottom: AuraSpace.s12,
          ),
          child: Text(
            'Institution tools',
            style: AuraText.label.copyWith(
              color: AuraSurface.faint,
              letterSpacing: 0.8,
            ),
          ),
        ),
        ...tools.map(
          (t) => Padding(
            padding: const EdgeInsets.only(bottom: AuraSpace.s10),
            child: _ToolCard(tool: t),
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const AuraLoadingState(message: 'Loading institution dashboard…');
    }

    if (_error != null) {
      return AuraErrorState(
        title: 'Institution dashboard unavailable',
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
        _buildStatusCard(),
        const SizedBox(height: AuraSpace.s12),
        _buildNextStepCard(),
        const SizedBox(height: AuraSpace.s12),
        _buildPipelineCard(),
        const SizedBox(height: AuraSpace.s12),
        if (_hasRequest) ...[
          _buildRequestDetailsCard(),
          const SizedBox(height: AuraSpace.s20),
        ],
        _buildToolsSection(),
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
              constraints: const BoxConstraints(maxWidth: 920),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Institution dashboard', style: AuraText.headline),
                  const SizedBox(height: AuraSpace.s6),
                  Text(
                    'Institutional standing, verification progress, and official surfaces.',
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

// ── Support widgets ────────────────────────────────────────────────────────

class _DashCard extends StatelessWidget {
  const _DashCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AuraSpace.s16),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: child,
    );
  }
}

class _DetailEntry {
  const _DetailEntry(this.label, this.value);

  final String label;
  final String value;
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : AuraSpace.s8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: AuraText.small.copyWith(
                color: AuraSurface.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: Text(value, style: AuraText.small)),
        ],
      ),
    );
  }
}

class _PipelineStep {
  const _PipelineStep({
    required this.title,
    required this.subtitle,
    required this.isDone,
    required this.isCurrent,
    this.isLast = false,
  });

  final String title;
  final String subtitle;
  final bool isDone;
  final bool isCurrent;
  final bool isLast;
}

class _PipelineRow extends StatelessWidget {
  const _PipelineRow({required this.step});

  final _PipelineStep step;

  @override
  Widget build(BuildContext context) {
    final icon = step.isDone
        ? Icons.check_circle_rounded
        : (step.isCurrent
              ? Icons.radio_button_checked
              : Icons.radio_button_off);
    final iconColor = step.isDone
        ? AuraSurface.goodInk
        : (step.isCurrent ? AuraSurface.accentText : AuraSurface.faint);

    return Padding(
      padding: EdgeInsets.only(bottom: step.isLast ? 0 : AuraSpace.s12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: AuraSpace.s10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: AuraText.small.copyWith(
                    fontWeight: FontWeight.w700,
                    color: step.isDone || step.isCurrent
                        ? AuraSurface.ink
                        : AuraSurface.muted,
                  ),
                ),
                const SizedBox(height: AuraSpace.s2),
                Text(
                  step.subtitle,
                  style: AuraText.small.copyWith(color: AuraSurface.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolData {
  const _ToolData({
    required this.title,
    required this.body,
    required this.icon,
    required this.enabled,
    required this.onTap,
    this.badge,
  });

  final String title;
  final String body;
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;
  final int? badge;
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({required this.tool});

  final _ToolData tool;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: tool.onTap,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        child: Opacity(
          opacity: tool.enabled ? 1 : 0.45,
          child: Container(
            padding: const EdgeInsets.all(AuraSpace.s14),
            decoration: BoxDecoration(
              color: AuraSurface.card,
              borderRadius: BorderRadius.circular(AuraRadius.card),
              border: Border.all(color: AuraSurface.divider),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: tool.enabled
                            ? AuraSurface.accentSoft
                            : AuraSurface.subtle,
                        borderRadius: BorderRadius.circular(AuraRadius.r10),
                        border: Border.all(
                          color: tool.enabled
                              ? AuraSurface.accent.withValues(alpha: 0.25)
                              : AuraSurface.divider,
                        ),
                      ),
                      child: Icon(
                        tool.icon,
                        size: 18,
                        color: tool.enabled
                            ? AuraSurface.accentText
                            : AuraSurface.muted,
                      ),
                    ),
                    if (tool.badge != null && tool.badge! > 0)
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                          decoration: BoxDecoration(
                            color: AuraSurface.dangerInk,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Center(
                            child: Text(
                              '${tool.badge}',
                              style: AuraText.micro.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: AuraSpace.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tool.title,
                        style: AuraText.small.copyWith(
                          fontWeight: FontWeight.w700,
                          color: tool.enabled
                              ? AuraSurface.ink
                              : AuraSurface.muted,
                        ),
                      ),
                      const SizedBox(height: AuraSpace.s4),
                      Text(
                        tool.body,
                        style: AuraText.small.copyWith(
                          color: AuraSurface.muted,
                          height: 1.4,
                        ),
                      ),
                      if (tool.onTap != null) ...[
                        const SizedBox(height: AuraSpace.s10),
                        Row(
                          children: [
                            Text(
                              'Open',
                              style: AuraText.small.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AuraSurface.accentText,
                              ),
                            ),
                            const SizedBox(width: AuraSpace.s4),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              size: 12,
                              color: AuraSurface.accentText,
                            ),
                          ],
                        ),
                      ] else ...[
                        const SizedBox(height: AuraSpace.s10),
                        Text(
                          'Unavailable',
                          style: AuraText.small.copyWith(
                            color: AuraSurface.faint,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
