import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/institutions/institution_access_provider.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/ui/document_scaffold.dart';

class InstitutionDashboardScreen extends ConsumerWidget {
  const InstitutionDashboardScreen({super.key});

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }

  String _value(dynamic value) => (value ?? '').toString().trim();

  String _institutionDisplayName({
    required Map<String, dynamic>? institution,
    required Map<String, dynamic>? request,
  }) {
    final byInstitution = _value(institution?['name']);
    if (byInstitution.isNotEmpty) return byInstitution;

    final byRequest = _value(request?['organizationName']);
    if (byRequest.isNotEmpty) return byRequest;

    return 'Institution account';
  }

  String _institutionSlug({
    required Map<String, dynamic>? institution,
    required Map<String, dynamic>? request,
  }) {
    final byInstitution = _value(institution?['slug']);
    if (byInstitution.isNotEmpty) return byInstitution;

    final requestName = _value(request?['organizationName']);
    if (requestName.isEmpty) return '';

    return requestName
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '')
        .replaceAll(RegExp(r'-{2,}'), '-');
  }

  String _institutionDomain({
    required Map<String, dynamic>? institution,
    required Map<String, dynamic>? request,
  }) {
    final fromInstitution = _value(institution?['domain']);
    if (fromInstitution.isNotEmpty) return fromInstitution;
    return _value(request?['domain']);
  }

  String _institutionWebsite({
    required Map<String, dynamic>? institution,
    required Map<String, dynamic>? request,
  }) {
    final fromInstitution = _value(institution?['websiteUrl']);
    if (fromInstitution.isNotEmpty) return fromInstitution;
    return _value(request?['websiteUrl']);
  }

  String _institutionJurisdiction({
    required Map<String, dynamic>? institution,
    required Map<String, dynamic>? request,
  }) {
    final fromInstitution = _value(institution?['jurisdiction']);
    if (fromInstitution.isNotEmpty) return fromInstitution;
    return _value(request?['jurisdiction']);
  }

  String _role({
    required Map<String, dynamic>? membership,
    required Map<String, dynamic>? request,
  }) {
    final role = _value(membership?['role']);
    if (role.isNotEmpty) return role;

    final title = _value(request?['roleTitle']);
    if (title.isNotEmpty) return 'Representative';

    return '';
  }

  String _title({
    required Map<String, dynamic>? membership,
    required Map<String, dynamic>? request,
  }) {
    final title = _value(membership?['title']);
    if (title.isNotEmpty) return title;
    return _value(request?['roleTitle']);
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: AuraText.body.copyWith(
        fontWeight: FontWeight.w700,
        fontSize: 16,
      ),
    );
  }

  Widget _statusChip(String label) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AuraSpace.s10,
        vertical: AuraSpace.s6,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AuraText.body.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(bottom: AuraSpace.s8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: AuraText.body.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: AuraText.body),
          ),
        ],
      ),
    );
  }

  Widget _toolTile({
    required String title,
    required String detail,
    required String status,
    VoidCallback? onTap,
  }) {
    final enabled = onTap != null;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 148),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black12),
              borderRadius: BorderRadius.circular(18),
            ),
            padding: EdgeInsets.all(AuraSpace.s14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: AuraSpace.s8),
                Expanded(
                  child: Text(detail, style: AuraText.body),
                ),
                SizedBox(height: AuraSpace.s10),
                Text(
                  status,
                  style: AuraText.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: enabled ? Colors.black87 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _toolGrid(List<Widget> children) {
    return Wrap(
      spacing: AuraSpace.s12,
      runSpacing: AuraSpace.s12,
      children: children
          .map((child) => SizedBox(width: 320, child: child))
          .toList(),
    );
  }

  Widget _heroCard(
    BuildContext context, {
    required String institutionName,
    required String standingLabel,
    required String role,
    required bool isAuthorizedSpeaker,
    required bool hasInstitutionStanding,
  }) {
    final speechLabel = isAuthorizedSpeaker
        ? 'Official speech: Authorized'
        : hasInstitutionStanding
            ? 'Official speech: Not enabled'
            : 'Official speech: Locked';

    final summary = hasInstitutionStanding
        ? 'This dashboard is the institution surface. Open a dedicated institutional tool below to manage one specific institutional function.'
        : 'This dashboard is the institution surface. Institutional tools will open here as standing becomes active.';

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            institutionName,
            style: (Theme.of(context).textTheme.headlineMedium ?? AuraText.body)
                .copyWith(fontWeight: FontWeight.w700, fontSize: 30),
          ),
          SizedBox(height: AuraSpace.s10),
          Wrap(
            spacing: AuraSpace.s8,
            runSpacing: AuraSpace.s8,
            children: [
              _statusChip(standingLabel),
              if (role.isNotEmpty) _statusChip('Role: $role'),
              _statusChip(speechLabel),
            ],
          ),
          SizedBox(height: AuraSpace.s12),
          Text(summary, style: AuraText.body),
        ],
      ),
    );
  }

  Widget _identityCard({
    required Map<String, dynamic>? institution,
    required Map<String, dynamic>? membership,
    required Map<String, dynamic>? request,
  }) {
    final slug = _institutionSlug(institution: institution, request: request);
    final domain = _institutionDomain(institution: institution, request: request);
    final website = _institutionWebsite(institution: institution, request: request);
    final jurisdiction =
        _institutionJurisdiction(institution: institution, request: request);
    final role = _role(membership: membership, request: request);
    final title = _title(membership: membership, request: request);
    final verifiedAt = _value(institution?['verifiedAt']);

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Institution summary'),
          SizedBox(height: AuraSpace.s12),
          _infoRow('Title', title),
          _infoRow('Role', role),
          _infoRow('Domain', domain),
          _infoRow('Website', website),
          _infoRow('Jurisdiction', jurisdiction),
          _infoRow('Public slug', slug),
          _infoRow('Verified at', verifiedAt),
        ],
      ),
    );
  }

  Widget _institutionToolsCard(
    BuildContext context, {
    required bool hasInstitutionStanding,
    required bool isAuthorizedSpeaker,
    required String slug,
  }) {
    final profileStatus = slug.isNotEmpty
        ? 'Available now'
        : 'Available when public institution profile exists';

    final domainsStatus = hasInstitutionStanding
        ? 'Available now'
        : 'Reserved for institutional standing';

    final verificationStatus = hasInstitutionStanding
        ? 'Dedicated institutional tool'
        : 'Reserved for institutional setup';

    final announcementsStatus = hasInstitutionStanding
        ? 'Available now'
        : 'Reserved for institutional standing';

    final correspondenceStatus = hasInstitutionStanding
        ? 'Available now'
        : 'Reserved for institutional standing';

    final officialPostsStatus = isAuthorizedSpeaker
        ? 'Reserved for institution publishing'
        : hasInstitutionStanding
            ? 'Waiting for publishing workflow'
            : 'Locked until institutional standing is active';

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Institution tools'),
          SizedBox(height: AuraSpace.s12),
          _toolGrid([
            _toolTile(
              title: 'Institution profile',
              detail:
                  'Open the institution-facing profile surface attached to this account.',
              status: profileStatus,
              onTap: slug.isNotEmpty
                  ? () => context.go('/institution/profile')
                  : null,
            ),
            _toolTile(
              title: 'Domains',
              detail:
                  'Manage institutional domains and run DNS proof workflows from a dedicated institution screen.',
              status: domainsStatus,
              onTap: hasInstitutionStanding
                  ? () => context.go('/institution/domains')
                  : null,
            ),
            _toolTile(
              title: 'Verification',
              detail:
                  'Open the institutional account request and verification surface from its own dedicated screen.',
              status: verificationStatus,
              onTap: () => context.go('/institution/request-verification'),
            ),
            _toolTile(
              title: 'Announcements',
              detail:
                  'Open the institution announcements workspace, separate from the public member announcements flow.',
              status: announcementsStatus,
              onTap: hasInstitutionStanding
                  ? () => context.go('/institution/announcements')
                  : null,
            ),
            _toolTile(
              title: 'Correspondence',
              detail:
                  'Open the institution correspondence workspace, separate from the signed-in member mailbox.',
              status: correspondenceStatus,
              onTap: hasInstitutionStanding
                  ? () => context.go('/institution/correspondence')
                  : null,
            ),
            _toolTile(
              title: 'Official posts',
              detail:
                  'Institution publishing should live on its own institutional screen, separate from member compose flow.',
              status: officialPostsStatus,
              onTap: null,
            ),
            _toolTile(
              title: 'Representatives',
              detail:
                  'Representative roles, permissions, and official speech authority should live in a dedicated institution tool.',
              status: 'Placeholder',
              onTap: null,
            ),
            _toolTile(
              title: 'Institution record',
              detail:
                  'Official institutional archive, actions, and records should live in a dedicated institution record screen.',
              status: 'Placeholder',
              onTap: null,
            ),
          ]),
        ],
      ),
    );
  }

  Widget _loadingView() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _errorView(WidgetRef ref) {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Could not load institution account.',
            style: AuraText.body.copyWith(fontWeight: FontWeight.w600),
          ),
          SizedBox(height: AuraSpace.s8),
          Text('Please try again.', style: AuraText.body),
          SizedBox(height: AuraSpace.s12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => ref.invalidate(institutionAccessProvider),
                  child: Text('Try again', style: AuraText.body),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref) {
    final accessAsync = ref.watch(institutionAccessProvider);

    return accessAsync.when(
      loading: _loadingView,
      error: (_, __) => _errorView(ref),
      data: (access) {
        final request = _asMap(access.request);
        final membership = _asMap(access.membership);

        final topInstitution = _asMap(access.institution);
        final membershipInstitution = _asMap(membership['institution']);
        final institution =
            topInstitution.isNotEmpty ? topInstitution : membershipInstitution;

        final institutionMap = institution.isNotEmpty ? institution : null;
        final membershipMap = membership.isNotEmpty ? membership : null;
        final requestMap = request.isNotEmpty ? request : null;

        final isPendingRequest =
            access.state == InstitutionAccessState.pending;
        final isVerifiedMember =
            access.state == InstitutionAccessState.verifiedMember ||
            access.state == InstitutionAccessState.authorizedSpeaker;
        final isAuthorizedSpeaker =
            access.state == InstitutionAccessState.authorizedSpeaker;

        final hasInstitutionStanding =
            access.state == InstitutionAccessState.pending ||
            access.state == InstitutionAccessState.verifiedMember ||
            access.state == InstitutionAccessState.authorizedSpeaker;

        final institutionName = _institutionDisplayName(
          institution: institutionMap,
          request: requestMap,
        );

        final role = _role(
          membership: membershipMap,
          request: requestMap,
        );

        final slug = _institutionSlug(
          institution: institutionMap,
          request: requestMap,
        );

        final standingLabel = isPendingRequest
            ? 'Standing: Pending review'
            : isVerifiedMember
                ? 'Standing: Active'
                : 'Standing: Not active';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _heroCard(
              context,
              institutionName: institutionName,
              standingLabel: standingLabel,
              role: role,
              isAuthorizedSpeaker: isAuthorizedSpeaker,
              hasInstitutionStanding: hasInstitutionStanding,
            ),
            SizedBox(height: AuraSpace.s12),
            _identityCard(
              institution: institutionMap,
              membership: membershipMap,
              request: requestMap,
            ),
            SizedBox(height: AuraSpace.s12),
            _institutionToolsCard(
              context,
              hasInstitutionStanding: hasInstitutionStanding,
              isAuthorizedSpeaker: isAuthorizedSpeaker,
              slug: slug,
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DocumentScaffold(
      title: 'Institution dashboard',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Doc.title('Institution dashboard'),
          SizedBox(height: AuraSpace.s10),
          Doc.meta('Institution account, standing, and tool access.'),
          Doc.lede(
            'This dashboard acts as the institution-facing surface. Open a dedicated institution tool below to manage a specific part of the institution workspace.',
          ),
          SizedBox(height: AuraSpace.s12),
          _body(context, ref),
        ],
      ),
    );
  }
}