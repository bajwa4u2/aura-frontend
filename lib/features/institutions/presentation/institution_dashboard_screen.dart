import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/ui/document_scaffold.dart';

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

  Map<String, dynamic> _stateData = <String, dynamic>{};
  Map<String, dynamic>? _membership;
  Map<String, dynamic>? _institution;
  Map<String, dynamic>? _request;
  String _state = 'SIGNED_IN_NO_STANDING';

  Dio get _dio => ref.read(dioProvider);

  Map<String, dynamic> get _requestData => _request ?? <String, dynamic>{};

  bool get _hasInstitution =>
      _institution != null &&
      ((_institution!['id']?.toString().trim().isNotEmpty) ?? false);

  bool get _hasMembership =>
      _membership != null &&
      ((_membership!['institutionMemberId']?.toString().trim().isNotEmpty) ??
          false);

  bool get _canUseInstitutionTools =>
      _state == 'VERIFIED_MEMBER' || _state == 'AUTHORIZED_SPEAKER';

  bool get _canManageDomains =>
      _state == 'VERIFIED_MEMBER' || _state == 'AUTHORIZED_SPEAKER';

  bool get _isPending => _state == 'PENDING_REQUEST';

  bool get _isRejected => _state == 'REJECTED';

  bool get _isSuspended => _state == 'SUSPENDED';

  bool get _hasRequest => _requestData.isNotEmpty;

  bool get _domainVerified {
    final verifiedAt = _institution?['domainVerifiedAt']?.toString().trim() ?? '';
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
        _stateData = data;
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
    if (_isPending) return 'Request under review';
    if (_canManageDomains) {
      if (_domainVerified) return 'Institution active';
      return 'Next step: verify domain ownership';
    }
    if (_isRejected) return 'Request outcome';
    if (_isSuspended) return 'Standing suspended';
    return 'Begin institutional access';
  }

  String _nextStepBody() {
    if (_isPending) {
      final org = _requestData['organizationName']?.toString().trim() ?? '';
      if (org.isNotEmpty) {
        return 'Your institutional account request for $org is under review. No further action is required right now.';
      }
      return 'Your institutional account request is under review. No further action is required right now.';
    }

    if (_canManageDomains) {
      if (_domainVerified) {
        return 'Institutional standing is active. You can now use the institutional surfaces below.';
      }
      return 'Your institution exists and your membership is active. Verify domain ownership next so institutional trust can be completed.';
    }

    if (_isRejected) {
      return 'This institutional request was rejected. Review the request details and submit a fresh institutional account request when ready.';
    }

    if (_isSuspended) {
      return 'This institutional standing is currently suspended. Institutional actions are unavailable until standing is restored.';
    }

    return 'Create an institutional account to begin verification and establish institutional standing inside Aura.';
  }

  String? _primaryActionLabel() {
    if (_isPending) return null;
    if (_canManageDomains) {
      if (_domainVerified) return null;
      return 'Verify domain';
    }
    if (_isRejected) return 'Create institutional account';
    if (_isSuspended) return null;
    return 'Create institutional account';
  }

  VoidCallback? _primaryAction() {
    if (_isPending) return null;
    if (_canManageDomains) {
      if (_domainVerified) return null;
      return () => _go('/institution/domains');
    }
    if (_isRejected) return () => _go('/institution/create');
    if (_isSuspended) return null;
    return () => _go('/institution/create');
  }

  TextStyle _sectionTitleStyle() {
    return AuraText.body.copyWith(
      fontWeight: FontWeight.w700,
      fontSize: 20,
    );
  }

  Widget _buildStatusCard() {
    final name = _institution?['name']?.toString().trim() ?? '';
    final slug = _institution?['slug']?.toString().trim() ?? '';
    final domain = _institution?['domain']?.toString().trim() ?? '';
    final requestOrg = _requestData['organizationName']?.toString().trim() ?? '';
    final displayName = name.isNotEmpty
        ? name
        : (requestOrg.isNotEmpty ? requestOrg : 'Institution');

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Institution status',
            style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AuraSpace.s10),
          Text(
            displayName,
            style: _sectionTitleStyle(),
          ),
          const SizedBox(height: AuraSpace.s8),
          Text('Standing: ${_standingLabel()}'),
          if (slug.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s6),
            Text('Slug: $slug'),
          ],
          if (domain.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s6),
            Text('Domain: $domain'),
          ],
          if (_membership?['role'] != null) ...[
            const SizedBox(height: AuraSpace.s6),
            Text('Role: ${_membership!['role']}'),
          ],
          if (_membership?['canSpeakOfficially'] == true) ...[
            const SizedBox(height: AuraSpace.s6),
            const Text('Official speaking rights: active'),
          ],
        ],
      ),
    );
  }

  Widget _buildNextStepCard() {
    final actionLabel = _primaryActionLabel();
    final action = _primaryAction();

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _nextStepTitle(),
            style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AuraSpace.s10),
          Text(_nextStepBody()),
          if (actionLabel != null && action != null) ...[
            const SizedBox(height: AuraSpace.s14),
            ElevatedButton(
              onPressed: action,
              child: Text(actionLabel),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPipelineCard() {
    final step1Done = _hasRequest || _hasInstitution || _canUseInstitutionTools;
    final step2Done = _isPending || _canUseInstitutionTools || _isSuspended;
    final step3Done = _hasInstitution || _canUseInstitutionTools || _isSuspended;
    final step4Done = _domainVerified;
    final step5Done = step4Done && _canUseInstitutionTools;

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Institution onboarding pipeline',
            style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AuraSpace.s12),
          _pipelineRow(
            title: 'Request submitted',
            subtitle: 'Institutional account request entered into review.',
            isDone: step1Done,
            isCurrent: !step1Done,
          ),
          _pipelineRow(
            title: 'Under review',
            subtitle: 'Identity, email, and institutional standing are reviewed.',
            isDone: step2Done,
            isCurrent: _isPending,
          ),
          _pipelineRow(
            title: 'Institution created',
            subtitle: 'Institution and membership are created after approval.',
            isDone: step3Done,
            isCurrent: _hasInstitution && !step4Done,
          ),
          _pipelineRow(
            title: 'Domain verification',
            subtitle: 'Domain ownership is confirmed through DNS verification.',
            isDone: step4Done,
            isCurrent: _canManageDomains && !step4Done,
          ),
          _pipelineRow(
            title: 'Institution active',
            subtitle: 'Institutional tools become usable with verified standing.',
            isDone: step5Done,
            isCurrent: step4Done && _canUseInstitutionTools,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _pipelineRow({
    required String title,
    required String subtitle,
    required bool isDone,
    required bool isCurrent,
    bool isLast = false,
  }) {
    final icon = isDone
        ? Icons.check_circle
        : (isCurrent ? Icons.radio_button_checked : Icons.radio_button_off);

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : AuraSpace.s12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 18),
          ),
          const SizedBox(width: AuraSpace.s10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(subtitle),
              ],
            ),
          ),
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
    final reviewedAt = _requestData['reviewedAt']?.toString().trim() ?? '';

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Request details',
            style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AuraSpace.s10),
          if (org.isNotEmpty) Text('Institution: $org'),
          if (status.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s6),
            Text('Request status: $status'),
          ],
          if (workEmail.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s6),
            Text('Work email: $workEmail'),
          ],
          if (website.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s6),
            Text('Website: $website'),
          ],
          if (domain.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s6),
            Text('Domain: $domain'),
          ],
          if (roleTitle.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s6),
            Text('Representative title: $roleTitle'),
          ],
          if (jurisdiction.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s6),
            Text('Jurisdiction: $jurisdiction'),
          ],
          if (reviewedAt.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s6),
            Text('Reviewed at: $reviewedAt'),
          ],
        ],
      ),
    );
  }

  Widget _buildToolCard({
    required String title,
    required String body,
    required bool enabled,
    required VoidCallback? onTap,
  }) {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AuraSpace.s8),
          Text(body),
          const SizedBox(height: AuraSpace.s12),
          ElevatedButton(
            onPressed: enabled ? onTap : null,
            child: Text(enabled ? 'Open' : 'Unavailable'),
          ),
        ],
      ),
    );
  }

  Widget _buildToolsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Institution tools',
          style: _sectionTitleStyle(),
        ),
        const SizedBox(height: AuraSpace.s10),
        _buildToolCard(
          title: 'Official posts',
          body:
              'Institutional statements, notices, and official communication surfaces.',
          enabled: _canUseInstitutionTools,
          onTap: () => _go('/announcements'),
        ),
        const SizedBox(height: AuraSpace.s12),
        _buildToolCard(
          title: 'Representatives',
          body:
              'Institutional people, roles, and speaking authority inside the platform.',
          enabled: _canUseInstitutionTools,
          onTap: null,
        ),
        const SizedBox(height: AuraSpace.s12),
        _buildToolCard(
          title: 'Domains',
          body:
              'Attach and verify institutional domains through DNS ownership checks.',
          enabled: _canManageDomains,
          onTap: () => _go('/institution/domains'),
        ),
        const SizedBox(height: AuraSpace.s12),
        _buildToolCard(
          title: 'Institution record',
          body:
              'Institution identity, description, public record, and standing-related data.',
          enabled: _canUseInstitutionTools,
          onTap: null,
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return AuraCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Institution dashboard',
              style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AuraSpace.s10),
            Text(_error!),
            const SizedBox(height: AuraSpace.s12),
            ElevatedButton(
              onPressed: _load,
              child: const Text('Try again'),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Doc.title('Institution dashboard'),
        const SizedBox(height: AuraSpace.s10),
        Doc.meta('Institutional standing, next steps, and governance surfaces.'),
        Doc.lede(
          'A clear view of institutional status, verification progress, and available institutional tools.',
        ),
        const SizedBox(height: AuraSpace.s12),
        _buildStatusCard(),
        const SizedBox(height: AuraSpace.s12),
        _buildNextStepCard(),
        const SizedBox(height: AuraSpace.s12),
        _buildPipelineCard(),
        const SizedBox(height: AuraSpace.s12),
        if (_hasRequest) ...[
          _buildRequestDetailsCard(),
          const SizedBox(height: AuraSpace.s12),
        ],
        _buildToolsSection(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return DocumentScaffold(
      title: 'Institution dashboard',
      child: _buildBody(),
    );
  }
}