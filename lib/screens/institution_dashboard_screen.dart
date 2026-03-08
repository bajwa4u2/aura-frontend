import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/net/dio_provider.dart';
import '../core/ui/aura_card.dart';
import '../core/ui/aura_space.dart';
import '../core/ui/aura_text.dart';
import '../core/ui/document_scaffold.dart';

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

  bool _signedIn = false;
  String _state = 'PUBLIC';

  Map<String, dynamic>? _request;
  Map<String, dynamic>? _membership;
  Map<String, dynamic>? _institution;

  @override
  void initState() {
    super.initState();
    _loadInstitutionState();
  }

  Future<void> _loadInstitutionState() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/institutions/me');

      final data = _asMap(res.data);
      final request = _asMap(data['request']);
      final membership = _asMap(data['membership']);

      final topInstitution = _asMap(data['institution']);
      final membershipInstitution = _asMap(membership['institution']);
      final institution =
          topInstitution.isNotEmpty ? topInstitution : membershipInstitution;

      if (!mounted) return;

      setState(() {
        _signedIn = data['signedIn'] == true;
        _state = (data['state'] ?? 'SIGNED_IN_NO_STANDING').toString();
        _request = request.isNotEmpty ? request : null;
        _membership = membership.isNotEmpty ? membership : null;
        _institution = institution.isNotEmpty ? institution : null;
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;

      if (e.response?.statusCode == 401) {
        context.go(
          '/login?redirect=${Uri.encodeComponent('/institution/dashboard')}',
        );
        return;
      }

      String message = 'Could not load institutional dashboard.';
      final data = e.response?.data;
      if (data is Map && data['message'] is String) {
        message = data['message'] as String;
      }

      setState(() {
        _error = message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load institutional dashboard.';
        _loading = false;
      });
    }
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }

  String _value(dynamic value) => (value ?? '').toString().trim();

  bool get _hasInstitutionStanding =>
      _signedIn &&
      (_state == 'VERIFIED_MEMBER' || _state == 'AUTHORIZED_SPEAKER');

  bool get _isAuthorizedSpeaker => _state == 'AUTHORIZED_SPEAKER';

  String get _institutionSlug => _value(_institution?['slug']);

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

  Widget _errorView() {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Could not load institutional dashboard.',
            style: AuraText.body.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AuraSpace.s8),
          Text(_error ?? 'Unknown error.', style: AuraText.body),
          const SizedBox(height: AuraSpace.s12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _loadInstitutionState,
                  child: Text('Try again', style: AuraText.body),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _requestStatusCard() {
    final status = _value(_request?['status']);
    final organizationName = _value(_request?['organizationName']);
    final workEmail = _value(_request?['workEmail']);
    final createdAt = _value(_request?['createdAt']);

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
            'Your request is handled as a back-office review process. Updates are sent by email.',
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
          if (status.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s6),
            Text('Status: $status', style: AuraText.body),
          ],
          if (createdAt.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s6),
            Text('Submitted: $createdAt', style: AuraText.body),
          ],
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
        if (_request != null) _requestStatusCard(),
        if (_request != null) const SizedBox(height: AuraSpace.s12),
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
                'If your institution request has already been submitted, updates will be sent by email. If no request exists yet, begin from the public institutions page.',
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

  Widget _identityCard(BuildContext context) {
    final institutionName = _value(_institution?['name']);
    final status = _value(_institution?['status']);
    final slug = _value(_institution?['slug']);
    final domain = _value(_institution?['domain']);
    final jurisdiction = _value(_institution?['jurisdiction']);
    final websiteUrl = _value(_institution?['websiteUrl']);
    final verifiedAt = _value(_institution?['verifiedAt']);

    final role = _value(_membership?['role']);
    final title = _value(_membership?['title']);
    final canSpeakOfficially = _membership?['canSpeakOfficially'] == true;

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            institutionName.isNotEmpty ? institutionName : 'Institution',
            style: _headlineStyle(context).copyWith(fontSize: 28),
          ),
          const SizedBox(height: AuraSpace.s10),
          Wrap(
            spacing: AuraSpace.s8,
            runSpacing: AuraSpace.s8,
            children: [
              if (status.isNotEmpty) _statusChip('Standing: $status'),
              if (role.isNotEmpty) _statusChip('Role: $role'),
              _statusChip(
                canSpeakOfficially
                    ? 'Official speech: Authorized'
                    : 'Official speech: Not authorized',
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s12),
          Text(
            'This account carries verified institutional standing inside Aura.',
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

  Widget _actionsCard(BuildContext context) {
    final slug = _institutionSlug;

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
            'Institutional work inside Aura is carried from this operating surface.',
            style: AuraText.body,
          ),
          const SizedBox(height: AuraSpace.s12),
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
          if (_isAuthorizedSpeaker) ...[
            const SizedBox(height: AuraSpace.s10),
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
          ],
        ],
      ),
    );
  }

  Widget _recordCard() {
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
            'Recent institutional activity will appear here as Aura’s institutional record grows.',
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

  Widget _body(BuildContext context) {
    if (_loading) return _loadingView();
    if (_error != null) return _errorView();
    if (!_hasInstitutionStanding) return _noStandingView(context);

    final institutionName = _value(_institution?['name']);
    final headline =
        institutionName.isNotEmpty ? institutionName : 'Institution dashboard';

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
                'This account carries verified institutional standing inside Aura.',
                style: AuraText.body,
              ),
            ],
          ),
        ),
        const SizedBox(height: AuraSpace.s12),
        _identityCard(context),
        const SizedBox(height: AuraSpace.s12),
        _actionsCard(context),
        const SizedBox(height: AuraSpace.s12),
        _recordCard(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return DocumentScaffold(
      title: 'Institution dashboard',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Doc.title('Institution dashboard'),
          const SizedBox(height: 10),
          Doc.meta('Verified institutional standing and operating tools.'),
          Doc.lede(
            'This space is reserved for institutional presence carried under approved standing.',
          ),
          const SizedBox(height: AuraSpace.s12),
          _body(context),
        ],
      ),
    );
  }
}