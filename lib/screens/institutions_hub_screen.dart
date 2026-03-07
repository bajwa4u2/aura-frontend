import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/net/dio_provider.dart';
import '../core/ui/aura_card.dart';
import '../core/ui/aura_space.dart';
import '../core/ui/aura_text.dart';
import '../core/ui/document_scaffold.dart';

class InstitutionsHubScreen extends ConsumerStatefulWidget {
  const InstitutionsHubScreen({super.key});

  @override
  ConsumerState<InstitutionsHubScreen> createState() =>
      _InstitutionsHubScreenState();
}

class _InstitutionsHubScreenState extends ConsumerState<InstitutionsHubScreen> {
  bool _loading = true;
  bool _signedIn = false;
  String _state = 'PUBLIC';

  Map<String, dynamic>? _request;
  Map<String, dynamic>? _membership;
  Map<String, dynamic>? _institution;

  String? _error;

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
        setState(() {
          _signedIn = false;
          _state = 'PUBLIC';
          _request = null;
          _membership = null;
          _institution = null;
          _loading = false;
        });
        return;
      }

      String message = 'Could not load institutional status.';
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
        _error = 'Could not load institutional status.';
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

  bool get _hasInstitutionStanding =>
      _state == 'VERIFIED_MEMBER' || _state == 'AUTHORIZED_SPEAKER';

  bool get _isAuthorizedSpeaker => _state == 'AUTHORIZED_SPEAKER';

  String _value(dynamic value) => (value ?? '').toString().trim();

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

  Widget _publicHero(BuildContext context) {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Institutions in Aura',
            style: _headlineStyle(context).copyWith(fontSize: 28),
          ),
          const SizedBox(height: AuraSpace.s8),
          Text(
            'Institutional participation is separate from public member entry. Institutions join through their own governed lane, private credentials, and accountable standing.',
            style: AuraText.body,
          ),
          const SizedBox(height: AuraSpace.s12),
          Wrap(
            spacing: AuraSpace.s8,
            runSpacing: AuraSpace.s8,
            children: [
              _statusChip('Separate institution entry'),
              _statusChip('Governed verification'),
              _statusChip('Continuity of record'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _institutionHero(BuildContext context) {
    final institutionName = _value(_institution?['name']);
    final slug = _value(_institution?['slug']);
    final domain = _value(_institution?['domain']);
    final jurisdiction = _value(_institution?['jurisdiction']);
    final institutionStatus = _value(_institution?['status']);
    final role = _value(_membership?['role']);
    final title = _value(_membership?['title']);
    final canSpeakOfficially = _membership?['canSpeakOfficially'] == true;

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            institutionName.isEmpty ? 'Institution' : institutionName,
            style: _headlineStyle(context).copyWith(fontSize: 28),
          ),
          const SizedBox(height: AuraSpace.s8),
          Wrap(
            spacing: AuraSpace.s8,
            runSpacing: AuraSpace.s8,
            children: [
              if (institutionStatus.isNotEmpty)
                _statusChip('Status: $institutionStatus'),
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
            'This institution now stands inside Aura through a distinct institutional lane, governed participation, and accountable public memory.',
            style: AuraText.body,
          ),
          if (title.isNotEmpty ||
              jurisdiction.isNotEmpty ||
              domain.isNotEmpty ||
              slug.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s12),
            const Divider(height: 1),
            const SizedBox(height: AuraSpace.s12),
            if (title.isNotEmpty)
              Text('Institutional title: $title', style: AuraText.body),
            if (jurisdiction.isNotEmpty) ...[
              const SizedBox(height: AuraSpace.s6),
              Text('Jurisdiction: $jurisdiction', style: AuraText.body),
            ],
            if (domain.isNotEmpty) ...[
              const SizedBox(height: AuraSpace.s6),
              Text('Domain: $domain', style: AuraText.body),
            ],
            if (slug.isNotEmpty) ...[
              const SizedBox(height: AuraSpace.s6),
              Text('Public slug: $slug', style: AuraText.body),
            ],
          ],
        ],
      ),
    );
  }

  Widget _standingCard() {
    String title;
    String text;

    switch (_state) {
      case 'PENDING_REQUEST':
        title = 'Verification request pending';
        text =
            'Your institution request exists and remains under review. Approval is deliberate and does not activate automatically.';
        break;
      case 'VERIFIED_MEMBER':
        title = 'Verified institutional member';
        text =
            'This institution account holds verified standing in Aura. Institutional participation is active, but official speech remains governed by role.';
        break;
      case 'AUTHORIZED_SPEAKER':
        title = 'Authorized institutional speaker';
        text =
            'This institution account is allowed to issue official institutional speech under verified standing.';
        break;
      case 'SUSPENDED':
        title = 'Institutional standing suspended';
        text =
            'This institution account is currently suspended. Institutional participation remains paused until review changes that status.';
        break;
      case 'REJECTED':
        title = 'Request not approved';
        text =
            'This institution request was not approved, or the earlier standing is no longer active.';
        break;
      case 'SIGNED_IN_NO_STANDING':
        title = 'Signed in, no institutional standing yet';
        text =
            'This institution session is active, but no verified institutional standing is available on the current account.';
        break;
      default:
        title = 'Public institutional lane';
        text =
            'Institutions enter Aura through a separate lane with verification, bounded identity, and accountable presence.';
    }

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AuraText.body.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AuraSpace.s8),
          Text(text, style: AuraText.body),
        ],
      ),
    );
  }

  Widget _requestCard() {
    if (_request == null) return const SizedBox.shrink();

    final organizationName = _value(_request!['organizationName']);
    final workEmail = _value(_request!['workEmail']);
    final roleTitle = _value(_request!['roleTitle']);
    final jurisdiction = _value(_request!['jurisdiction']);
    final domain = _value(_request!['domain']);
    final status = _value(_request!['status']);
    final createdAt = _value(_request!['createdAt']);
    final emailVerifiedAt = _value(_request!['emailVerifiedAt']);
    final domainVerifiedAt = _value(_request!['domainVerifiedAt']);

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Institution request',
            style: AuraText.body.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AuraSpace.s10),
          if (organizationName.isNotEmpty)
            Text('Institution: $organizationName', style: AuraText.body),
          if (workEmail.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s6),
            Text('Institution email: $workEmail', style: AuraText.body),
          ],
          if (domain.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s6),
            Text('Domain: $domain', style: AuraText.body),
          ],
          if (roleTitle.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s6),
            Text('Applicant title: $roleTitle', style: AuraText.body),
          ],
          if (jurisdiction.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s6),
            Text('Jurisdiction: $jurisdiction', style: AuraText.body),
          ],
          if (status.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s6),
            Text('Request status: $status', style: AuraText.body),
          ],
          if (createdAt.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s6),
            Text('Submitted: $createdAt', style: AuraText.body),
          ],
          if (emailVerifiedAt.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s6),
            Text('Email verified: $emailVerifiedAt', style: AuraText.body),
          ],
          if (domainVerifiedAt.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s6),
            Text('Domain verified: $domainVerifiedAt', style: AuraText.body),
          ],
        ],
      ),
    );
  }

  Widget _institutionIdentityCard() {
    if (_institution == null || !_hasInstitutionStanding) {
      return const SizedBox.shrink();
    }

    final name = _value(_institution!['name']);
    final slug = _value(_institution!['slug']);
    final status = _value(_institution!['status']);
    final jurisdiction = _value(_institution!['jurisdiction']);
    final domain = _value(_institution!['domain']);
    final websiteUrl = _value(_institution!['websiteUrl']);
    final description = _value(_institution!['description']);
    final verifiedAt = _value(_institution!['verifiedAt']);
    final domainVerifiedAt = _value(_institution!['domainVerifiedAt']);

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Institution profile',
            style: AuraText.body.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AuraSpace.s10),
          if (name.isNotEmpty) Text('Name: $name', style: AuraText.body),
          if (status.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s6),
            Text('Standing: $status', style: AuraText.body),
          ],
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
          if (domainVerifiedAt.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s6),
            Text('Domain verified at: $domainVerifiedAt', style: AuraText.body),
          ],
          if (description.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s6),
            Text('Description: $description', style: AuraText.body),
          ],
        ],
      ),
    );
  }

  Widget _membershipCard() {
    if (_membership == null || !_hasInstitutionStanding) {
      return const SizedBox.shrink();
    }

    final role = _value(_membership!['role']);
    final title = _value(_membership!['title']);
    final canSpeakOfficially = _membership!['canSpeakOfficially'] == true;
    final joinedAt = _value(_membership!['joinedAt']);

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Institution authority',
            style: AuraText.body.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AuraSpace.s10),
          if (role.isNotEmpty) Text('Role: $role', style: AuraText.body),
          if (title.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s6),
            Text('Title: $title', style: AuraText.body),
          ],
          const SizedBox(height: AuraSpace.s6),
          Text(
            'Official institutional speech: ${canSpeakOfficially ? "Authorized" : "Not authorized"}',
            style: AuraText.body,
          ),
          if (joinedAt.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s6),
            Text('Membership active since: $joinedAt', style: AuraText.body),
          ],
        ],
      ),
    );
  }

  Widget _entryCard(BuildContext context) {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Institution entry',
            style: AuraText.body.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AuraSpace.s10),
          Text(
            'Institutions now enter through a distinct lane with their own credentials, verification flow, and private dashboard entry.',
            style: AuraText.body,
          ),
          const SizedBox(height: AuraSpace.s12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.go('/institution/sign-in'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AuraSpace.s14,
                      vertical: AuraSpace.s12,
                    ),
                  ),
                  child: Text('Institution sign in', style: AuraText.body),
                ),
              ),
              const SizedBox(width: AuraSpace.s10),
              Expanded(
                child: FilledButton(
                  onPressed: () => context.go('/institution/request-verification'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AuraSpace.s14,
                      vertical: AuraSpace.s12,
                    ),
                  ),
                  child: Text(
                    'Request verification',
                    style: AuraText.body.copyWith(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pendingToolsCard() {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Institution status',
            style: AuraText.body.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AuraSpace.s10),
          Text(
            'This institution request exists but has not yet become an active verified institution account.',
            style: AuraText.body,
          ),
          const SizedBox(height: AuraSpace.s12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: null,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AuraSpace.s14,
                      vertical: AuraSpace.s12,
                    ),
                  ),
                  child: Text(
                    'Request under review',
                    style: AuraText.body.copyWith(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _activeToolsCard(BuildContext context) {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Institution tools',
            style: AuraText.body.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AuraSpace.s10),
          Text(
            'This is your institution-facing operating surface inside Aura.',
            style: AuraText.body,
          ),
          const SizedBox(height: AuraSpace.s12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => context.go('/me/correspondence'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AuraSpace.s14,
                      vertical: AuraSpace.s12,
                    ),
                  ),
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
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AuraSpace.s14,
                      vertical: AuraSpace.s12,
                    ),
                  ),
                  child: Text('View announcements', style: AuraText.body),
                ),
              ),
            ],
          ),
          if (_isAuthorizedSpeaker) ...[
            const SizedBox(height: AuraSpace.s10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.go('/compose'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AuraSpace.s14,
                        vertical: AuraSpace.s12,
                      ),
                    ),
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

  Widget _inactiveToolsCard(BuildContext context) {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Institution access',
            style: AuraText.body.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AuraSpace.s10),
          Text(
            'This institution account does not currently hold active institutional operating rights.',
            style: AuraText.body,
          ),
          const SizedBox(height: AuraSpace.s12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.go('/institution/sign-in'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AuraSpace.s14,
                      vertical: AuraSpace.s12,
                    ),
                  ),
                  child: Text('Return to institution sign in', style: AuraText.body),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _toolsByState(BuildContext context) {
    if (!_signedIn) return _entryCard(context);

    if (_state == 'PENDING_REQUEST') return _pendingToolsCard();

    if (_hasInstitutionStanding) return _activeToolsCard(context);

    if (_state == 'REJECTED' || _state == 'SUSPENDED') {
      return _inactiveToolsCard(context);
    }

    return _entryCard(context);
  }

  Widget _principlesCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Doc.h('What institutions can do here'),
        Doc.bullets([
          'Maintain a verified institutional identity with continuity of record',
          'Enter through a separate institutional credential lane',
          'Issue posts, responses, clarifications, and commitments under governed standing',
          'Preserve institutional speech as readable public memory over time',
        ]),
        Doc.h('What institutions cannot do here'),
        Doc.bullets([
          'Use public member entry as a substitute for institution access',
          'Purchase reach or visibility',
          'Hide responsibility behind anonymous brand voice',
          'Turn institutional presence into promotional volume',
        ]),
        Doc.callout(
          'Institution participation is governed presence. It is not a branding shortcut.',
        ),
      ],
    );
  }

  Widget _errorCard() {
    if (_error == null) return const SizedBox.shrink();

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Could not load institutional status.',
            style: AuraText.body.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AuraSpace.s8),
          Text(_error!, style: AuraText.body),
          const SizedBox(height: AuraSpace.s10),
          OutlinedButton(
            onPressed: _loadInstitutionState,
            child: Text('Try again', style: AuraText.body),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasStanding = _hasInstitutionStanding && _institution != null;
    final headline = hasStanding
        ? _value(_institution!['name']).isNotEmpty
            ? _value(_institution!['name'])
            : 'Institution'
        : 'Institutions';

    final meta = hasStanding
        ? 'Institution profile and operating surface.'
        : 'Separate institutional entry and governed participation.';

    final lede = hasStanding
        ? 'This screen holds your institution’s standing inside Aura through verified entry, governed participation, and continuity of record.'
        : 'Institutional participation in Aura now begins through a distinct institutional lane with separate credentials, verification, and bounded public standing.';

    return DocumentScaffold(
      title: headline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Doc.title(headline),
          const SizedBox(height: 10),
          Doc.meta(meta),
          Doc.lede(lede),
          const SizedBox(height: AuraSpace.s12),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else ...[
            _errorCard(),
            if (_error != null) const SizedBox(height: AuraSpace.s12),
            hasStanding ? _institutionHero(context) : _publicHero(context),
            const SizedBox(height: AuraSpace.s12),
            _standingCard(),
            const SizedBox(height: AuraSpace.s12),
            if (_request != null) ...[
              _requestCard(),
              const SizedBox(height: AuraSpace.s12),
            ],
            if (hasStanding) ...[
              _institutionIdentityCard(),
              const SizedBox(height: AuraSpace.s12),
            ],
            if (_hasInstitutionStanding && _membership != null) ...[
              _membershipCard(),
              const SizedBox(height: AuraSpace.s12),
            ],
            _toolsByState(context),
            const SizedBox(height: AuraSpace.s12),
            Doc.p(
              'Institutions need their own bounded place to stand. This lane exists so institutional presence stays legible, verified, and distinct from ordinary public member entry.',
            ),
            _principlesCard(),
          ],
        ],
      ),
    );
  }
}