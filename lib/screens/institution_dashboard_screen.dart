import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/institutions/institution_access_provider.dart';
import '../core/ui/aura_card.dart';
import '../core/ui/aura_space.dart';
import '../core/ui/aura_text.dart';
import '../core/ui/document_scaffold.dart';

class InstitutionDashboardScreen extends ConsumerWidget {
  const InstitutionDashboardScreen({super.key});

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }

  String _value(dynamic value) => (value ?? '').toString().trim();

  String _institutionSlug({
    required Map<String, dynamic>? institution,
    required Map<String, dynamic>? request,
  }) {
    final institutionSlug = _value(institution?['slug']);
    if (institutionSlug.isNotEmpty) return institutionSlug;

    final requestName = _value(request?['organizationName']);
    if (requestName.isEmpty) return '';

    return requestName
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '')
        .replaceAll(RegExp(r'-{2,}'), '-');
  }

  String _institutionDisplayName({
    required Map<String, dynamic>? institution,
    required Map<String, dynamic>? request,
  }) {
    final fromInstitution = _value(institution?['name']);
    if (fromInstitution.isNotEmpty) return fromInstitution;

    final fromRequest = _value(request?['organizationName']);
    if (fromRequest.isNotEmpty) return fromRequest;

    return 'Institution dashboard';
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

  String _institutionRole({
    required Map<String, dynamic>? membership,
    required Map<String, dynamic>? request,
  }) {
    final role = _value(membership?['role']);
    if (role.isNotEmpty) return role;

    final title = _value(request?['roleTitle']);
    if (title.isNotEmpty) return 'Representative';

    return '';
  }

  String _institutionTitle({
    required Map<String, dynamic>? membership,
    required Map<String, dynamic>? request,
  }) {
    final title = _value(membership?['title']);
    if (title.isNotEmpty) return title;
    return _value(request?['roleTitle']);
  }

  TextStyle _headlineStyle(BuildContext context) {
    return (Theme.of(context).textTheme.headlineMedium ?? AuraText.body)
        .copyWith(fontWeight: FontWeight.w700);
  }

  Widget _statusChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(
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
            'Could not load institutional dashboard.',
            style: AuraText.body.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AuraSpace.s8),
          Text(
            'Please try again.',
            style: AuraText.body,
          ),
          const SizedBox(height: AuraSpace.s12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () =>
                      ref.invalidate(institutionAccessProvider),
                  child: Text('Try again', style: AuraText.body),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _requestStatusCard({
    required Map<String, dynamic>? request,
    required bool isPendingRequest,
  }) {
    final status = _value(request?['status']);
    final organizationName = _value(request?['organizationName']);
    final workEmail = _value(request?['workEmail']);
    final createdAt = _value(request?['createdAt']);
    final reviewedAt = _value(request?['reviewedAt']);
    final roleTitle = _value(request?['roleTitle']);
    final jurisdiction = _value(request?['jurisdiction']);
    final domain = _value(request?['domain']);
    final websiteUrl = _value(request?['websiteUrl']);

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Institution request',
            style: AuraText.body.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AuraSpace.s10),
          Text(
            isPendingRequest
                ? 'Your institution is inside Aura and awaiting back-office review. Institutional tools remain visible here and will unlock once standing is approved.'
                : 'Your request is handled as a back-office review process. Updates are sent by email.',
            style: AuraText.body,
          ),
          if (organizationName.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s10),
            Text('Institution: $organizationName', style: AuraText.body),
          ],
          if (workEmail.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s6),
            Text('Institution email: $workEmail', style: AuraText.body),
          ],
          if (roleTitle.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s6),
            Text('Representative title: $roleTitle', style: AuraText.body),
          ],
          if (jurisdiction.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s6),
            Text('Jurisdiction: $jurisdiction', style: AuraText.body),
          ],
          if (domain.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s6),
            Text('Domain: $domain', style: AuraText.body),
          ],
          if (websiteUrl.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s6),
            Text('Website: $websiteUrl', style: AuraText.body),
          ],
          if (status.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s6),
            Text('Status: $status', style: AuraText.body),
          ],
          if (createdAt.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s6),
            Text('Submitted: $createdAt', style: AuraText.body),
          ],
          if (reviewedAt.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s6),
            Text('Reviewed: $reviewedAt', style: AuraText.body),
          ],
        ],
      ),
    );
  }

  Widget _pendingStandingBanner() {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Institution standing pending',
            style: AuraText.body.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AuraSpace.s10),
          Text(
            'Your institution has entered the dashboard and is awaiting approval. The institutional workspace is visible now, but publishing and operating tools stay locked until review is complete.',
            style: AuraText.body,
          ),
          const SizedBox(height: AuraSpace.s12),
          Wrap(
            spacing: AuraSpace.s8,
            runSpacing: AuraSpace.s8,
            children: const [
              _PendingTag(label: 'Dashboard visible'),
              _PendingTag(label: 'Tools locked'),
              _PendingTag(label: 'Review pending'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _noStandingView(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AuraCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'No active institutional standing',
                style: _headlineStyle(context),
              ),
              const SizedBox(height: AuraSpace.s8),
              Text(
                'This account does not currently carry active institutional operating standing inside Aura.',
                style: AuraText.body,
              ),
            ],
          ),
        ),
        const SizedBox(height: AuraSpace.s12),
        AuraCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'What to do next',
                style: AuraText.body.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AuraSpace.s10),
              Text(
                'If no institutional standing exists yet, begin from the institutions page and create an institutional account.',
                style: AuraText.body,
              ),
              const SizedBox(height: AuraSpace.s12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => context.go('/institutions'),
                      child: Text('Go to institutions', style: AuraText.body),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _identityCard(
    BuildContext context, {
    required Map<String, dynamic>? institution,
    required Map<String, dynamic>? membership,
    required Map<String, dynamic>? request,
    required bool isPendingRequest,
    required bool isAuthorizedSpeaker,
  }) {
    final institutionName = _institutionDisplayName(
      institution: institution,
      request: request,
    );
    final status = _value(institution?['status']);
    final slug = _institutionSlug(
      institution: institution,
      request: request,
    );
    final domain = _institutionDomain(
      institution: institution,
      request: request,
    );
    final jurisdiction = _institutionJurisdiction(
      institution: institution,
      request: request,
    );
    final websiteUrl = _institutionWebsite(
      institution: institution,
      request: request,
    );
    final verifiedAt = _value(institution?['verifiedAt']);

    final role = _institutionRole(
      membership: membership,
      request: request,
    );
    final title = _institutionTitle(
      membership: membership,
      request: request,
    );
    final canSpeakOfficially = membership?['canSpeakOfficially'] == true;

    final standingLabel = isPendingRequest
        ? 'Standing: Pending review'
        : status.isNotEmpty
            ? 'Standing: $status'
            : 'Standing: Active';

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            institutionName,
            style: _headlineStyle(context).copyWith(fontSize: 28),
          ),
          const SizedBox(height: AuraSpace.s10),
          Wrap(
            spacing: AuraSpace.s8,
            runSpacing: AuraSpace.s8,
            children: [
              _statusChip(standingLabel),
              if (role.isNotEmpty) _statusChip('Role: $role'),
              _statusChip(
                canSpeakOfficially || isAuthorizedSpeaker
                    ? 'Official speech: Authorized'
                    : isPendingRequest
                        ? 'Official speech: Locked pending review'
                        : 'Official speech: Not authorized',
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s12),
          Text(
            isPendingRequest
                ? 'This institutional account is present inside Aura and awaiting approval.'
                : 'This account carries verified institutional standing inside Aura.',
            style: AuraText.body,
          ),
          if (title.isNotEmpty ||
              slug.isNotEmpty ||
              domain.isNotEmpty ||
              jurisdiction.isNotEmpty ||
              websiteUrl.isNotEmpty ||
              verifiedAt.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s12),
            const Divider(height: 1),
            const SizedBox(height: AuraSpace.s12),
            if (title.isNotEmpty)
              Text('Institutional title: $title', style: AuraText.body),
            if (slug.isNotEmpty) ...[
              const SizedBox(height: AuraSpace.s6),
              Text('Public slug: $slug', style: AuraText.body),
            ],
            if (domain.isNotEmpty) ...[
              const SizedBox(height: AuraSpace.s6),
              Text('Domain: $domain', style: AuraText.body),
            ],
            if (jurisdiction.isNotEmpty) ...[
              const SizedBox(height: AuraSpace.s6),
              Text('Jurisdiction: $jurisdiction', style: AuraText.body),
            ],
            if (websiteUrl.isNotEmpty) ...[
              const SizedBox(height: AuraSpace.s6),
              Text('Website: $websiteUrl', style: AuraText.body),
            ],
            if (verifiedAt.isNotEmpty) ...[
              const SizedBox(height: AuraSpace.s6),
              Text('Verified at: $verifiedAt', style: AuraText.body),
            ],
          ],
        ],
      ),
    );
  }

  Widget _disabledActionTile({
    required String title,
    required String detail,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AuraSpace.s12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AuraText.body.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AuraSpace.s6),
          Text(detail, style: AuraText.body),
        ],
      ),
    );
  }

  Widget _actionsCard(
    BuildContext context, {
    required String slug,
    required bool canUseInstitutionTools,
    required bool canIssueInstitutionalPost,
    required bool isPendingRequest,
  }) {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Institution actions',
            style: AuraText.body.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AuraSpace.s10),
          Text(
            isPendingRequest
                ? 'This operating surface is visible now. Publishing and institutional tools will unlock after standing is approved.'
                : 'Institutional work inside Aura is carried from this operating surface.',
            style: AuraText.body,
          ),
          const SizedBox(height: AuraSpace.s12),
          if (canUseInstitutionTools) ...[
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () => context.go('/me/correspondence'),
                    child: Text(
                      'Open correspondence',
                      style: AuraText.body.copyWith(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            _disabledActionTile(
              title: 'Correspondence locked',
              detail:
                  'Institutional correspondence becomes available once review is complete.',
            ),
          ],
          const SizedBox(height: AuraSpace.s10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.go('/announcements'),
                  child: Text('View announcements', style: AuraText.body),
                ),
              ),
            ],
          ),
          if (slug.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.go('/institutions/$slug'),
                    child: Text(
                      'Open public institution profile',
                      style: AuraText.body,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AuraSpace.s10),
          if (canIssueInstitutionalPost) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.go('/compose'),
                    child: Text('Issue institutional post', style: AuraText.body),
                  ),
                ),
              ],
            ),
          ] else ...[
            _disabledActionTile(
              title: 'Institutional posting locked',
              detail: isPendingRequest
                  ? 'Official posting will unlock after standing is approved and speech authority is granted.'
                  : 'This account is not currently authorized for official institutional speech.',
            ),
          ],
        ],
      ),
    );
  }

  Widget _recordCard({required bool isPendingRequest}) {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Institution record',
            style: AuraText.body.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AuraSpace.s10),
          Text(
            isPendingRequest
                ? 'This institutional record space is prepared and will begin filling as approved institutional activity starts inside Aura.'
                : 'Recent institutional activity will appear here as Aura’s institutional record grows.',
            style: AuraText.body,
          ),
          const SizedBox(height: AuraSpace.s12),
          Text('• Statements and official posts', style: AuraText.body),
          const SizedBox(height: AuraSpace.s6),
          Text('• Correspondence and responses', style: AuraText.body),
          const SizedBox(height: AuraSpace.s6),
          Text('• Announcements and public record', style: AuraText.body),
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

        final canUseInstitutionTools = isVerifiedMember;
        final canIssueInstitutionalPost = isAuthorizedSpeaker;

        final slug = _institutionSlug(
          institution: institution.isNotEmpty ? institution : null,
          request: request.isNotEmpty ? request : null,
        );

        final headline = _institutionDisplayName(
          institution: institution.isNotEmpty ? institution : null,
          request: request.isNotEmpty ? request : null,
        );

        if (!hasInstitutionStanding) {
          return _noStandingView(context);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AuraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(headline, style: _headlineStyle(context)),
                  const SizedBox(height: AuraSpace.s8),
                  Text(
                    isPendingRequest
                        ? 'This institution has entered the dashboard. Access is restricted until review is completed.'
                        : 'This account carries verified institutional standing inside Aura.',
                    style: AuraText.body,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AuraSpace.s12),
            if (isPendingRequest) ...[
              _pendingStandingBanner(),
              const SizedBox(height: AuraSpace.s12),
            ],
            _identityCard(
              context,
              institution: institution.isNotEmpty ? institution : null,
              membership: membership.isNotEmpty ? membership : null,
              request: request.isNotEmpty ? request : null,
              isPendingRequest: isPendingRequest,
              isAuthorizedSpeaker: isAuthorizedSpeaker,
            ),
            const SizedBox(height: AuraSpace.s12),
            if (request.isNotEmpty) ...[
              _requestStatusCard(
                request: request,
                isPendingRequest: isPendingRequest,
              ),
              const SizedBox(height: AuraSpace.s12),
            ],
            _actionsCard(
              context,
              slug: slug,
              canUseInstitutionTools: canUseInstitutionTools,
              canIssueInstitutionalPost: canIssueInstitutionalPost,
              isPendingRequest: isPendingRequest,
            ),
            const SizedBox(height: AuraSpace.s12),
            _recordCard(isPendingRequest: isPendingRequest),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accessAsync = ref.watch(institutionAccessProvider);

    final isPendingRequest = accessAsync.maybeWhen(
      data: (access) => access.state == InstitutionAccessState.pending,
      orElse: () => false,
    );

    final meta = isPendingRequest
        ? 'Institutional dashboard with restricted access pending approval.'
        : 'Verified institutional standing and operating tools.';
    final lede = isPendingRequest
        ? 'This space is now open to the institution in a restricted mode while review is completed.'
        : 'This space is reserved for institutional presence carried under approved standing.';

    return DocumentScaffold(
      title: 'Institution dashboard',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Doc.title('Institution dashboard'),
          const SizedBox(height: 10),
          Doc.meta(meta),
          Doc.lede(lede),
          const SizedBox(height: AuraSpace.s12),
          _body(context, ref),
        ],
      ),
    );
  }
}

class _PendingTag extends StatelessWidget {
  const _PendingTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
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
}