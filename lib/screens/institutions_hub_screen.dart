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

  Widget _heroCard() {
    final institutionName = _value(_institution?['name']);
    final slug = _value(_institution?['slug']);
    final domain = _value(_institution?['domain']);
    final jurisdiction = _value(_institution?['jurisdiction']);
    final institutionStatus = _value(_institution?['status']);
    final role = _value(_membership?['role']);
    final title = _value(_membership?['title']);
    final canSpeakOfficially = _membership?['canSpeakOfficially'] == true;

    if (_hasInstitutionStanding && institutionName.isNotEmpty) {
      return AuraCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              institutionName,
              style: AuraText.display.copyWith(fontSize: 28),
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
              'This institution now stands inside Aura under visible responsibility, named membership, and continuity of record.',
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
                Text('Your institutional title: $title', style: AuraText.body),
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
                Text('Slug: $slug', style: AuraText.body),
              ],
            ],
          ],
        ),
      );
    }

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Institutions in Aura',
            style: AuraText.display.copyWith(fontSize: 28),
          ),
          const SizedBox(height: AuraSpace.s8),
          Text(
            'Institutional participation is not a brand lane. It is a governed form of public presence carried by real named people under accountable standing.',
            style: AuraText.body,
          ),
          const SizedBox(height: AuraSpace.s12),
          Wrap(
            spacing: AuraSpace.s8,
            runSpacing: AuraSpace.s8,
            children: [
              _statusChip('Verified identity'),
              _statusChip('Named responsibility'),
              _statusChip('Continuity of record'),
            ],
          ),
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
            'Your request has been received and is under review. Institution entry is deliberate and manually governed.';
        break;
      case 'VERIFIED_MEMBER':
        title = 'Verified institutional member';
        text =
            'You are attached to a verified institution in Aura. Your participation carries institutional standing, but not unrestricted institutional speech.';
        break;
      case 'AUTHORIZED_SPEAKER':
        title = 'Authorized institutional speaker';
        text =
            'You are permitted to issue institutional speech under your institution’s standing. That authority remains tied to your named responsibility.';
        break;
      case 'SUSPENDED':
        title = 'Institutional standing suspended';
        text =
            'Your current institutional standing is suspended. Institutional participation is paused until review restores it.';
        break;
      case 'REJECTED':
        title = 'Request not approved';
        text =
            'Your last institutional request was not approved, or your earlier standing is no longer active.';
        break;
      case 'SIGNED_IN_NO_STANDING':
        title = 'Signed in, no institutional standing yet';
        text =
            'You are signed in, but this account does not yet hold an active institutional role in Aura.';
        break;
      default:
        title = 'Public institutional lane';
        text =
            'This lane is open to institutions that want to participate under visible accountability rather than borrowed reach or abstraction.';
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
    final status = _value(_request!['status']);
    final createdAt = _value(_request!['createdAt']);

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Verification request',
            style: AuraText.body.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AuraSpace.s10),
          if (organizationName.isNotEmpty)
            Text('Organization: $organizationName', style: AuraText.body),
          if (workEmail.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s6),
            Text('Work email: $workEmail', style: AuraText.body),
          ],
          if (roleTitle.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s6),
            Text('Role/title: $roleTitle', style: AuraText.body),
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
    final joinedAt = _value(_membership!['createdAt']);

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your institutional authority',
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
            Text('Membership recorded: $joinedAt', style: AuraText.body),
          ],
        ],
      ),
    );
  }

  Widget _toolsCard(BuildContext context) {
    if (!_signedIn) {
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
              'Enter with your existing Aura account if you already hold institutional standing, or request verification first.',
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
                    onPressed: () =>
                        context.go('/institution/request-verification'),
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

    if (_state == 'PENDING_REQUEST') {
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
              'Your request is pending. The next change in standing happens through review, not through self-activation.',
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
                      'Request submitted',
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

    if (_hasInstitutionStanding) {
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
              'This is the beginning of your institution-facing operating surface inside Aura.',
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
                      child:
                          Text('Issue institutional post', style: AuraText.body),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    }

    if (_state == 'REJECTED' || _state == 'SUSPENDED') {
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
              'This account does not currently hold active institutional operating rights.',
              style: AuraText.body,
            ),
            const SizedBox(height: AuraSpace.s12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.go('/home'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AuraSpace.s14,
                        vertical: AuraSpace.s12,
                      ),
                    ),
                    child: Text('Return to Aura', style: AuraText.body),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

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
            'This signed-in account does not yet hold institutional standing.',
            style: AuraText.body,
          ),
          const SizedBox(height: AuraSpace.s12),
          Row(
            children: [
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

  Widget _principlesCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Doc.h('What institutions can do here'),
        Doc.bullets([
          'Maintain a verified institutional identity with continuity of record',
          'Participate through named human responsibility rather than faceless abstraction',
          'Issue posts, responses, clarifications, and commitments under governed standing',
          'Preserve institutional speech as readable public memory over time',
        ]),
        Doc.h('What institutions cannot do here'),
        Doc.bullets([
          'Purchase reach or visibility',
          'Use public metrics as leverage or spectacle',
          'Hide responsibility behind anonymous brand voice',
          'Turn institutional presence into promotional volume',
        ]),
        Doc.callout(
          'Verified participation is a responsibility. It is not a privilege lane.',
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
    final headline = _hasInstitutionStanding && _institution != null
        ? _value(_institution!['name']).isNotEmpty
            ? _value(_institution!['name'])
            : 'Institution'
        : 'Institutions';

    final meta = _hasInstitutionStanding
        ? 'Institution profile and operating surface.'
        : 'Verified participation, not branding.';

    final lede = _hasInstitutionStanding
        ? 'This screen holds your institution’s standing inside Aura through named authority, governed participation, and continuity of record.'
        : 'Institutional participation in Aura is carried by real named persons and governed by visible responsibility.';

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
            _heroCard(),
            const SizedBox(height: AuraSpace.s12),
            _standingCard(),
            const SizedBox(height: AuraSpace.s12),
            if (_request != null) ...[
              _requestCard(),
              const SizedBox(height: AuraSpace.s12),
            ],
            if (_hasInstitutionStanding && _institution != null) ...[
              _institutionIdentityCard(),
              const SizedBox(height: AuraSpace.s12),
            ],
            if (_hasInstitutionStanding && _membership != null) ...[
              _membershipCard(),
              const SizedBox(height: AuraSpace.s12),
            ],
            _toolsCard(context),
            const SizedBox(height: AuraSpace.s12),
            Doc.p(
              'Institutions need a place to stand without dissolving into marketing voice or disappearing into private backchannels. This lane exists so institutional presence can remain legible, answerable, and carried by real people.',
            ),
            _principlesCard(),
          ],
        ],
      ),
    );
  }
}