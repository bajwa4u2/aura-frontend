import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/net/dio_provider.dart';
import '../core/ui/aura_card.dart';
import '../core/ui/aura_space.dart';
import '../core/ui/aura_text.dart';
import '../core/ui/document_scaffold.dart';

class InstitutionsHubScreen extends StatefulWidget {
  const InstitutionsHubScreen({super.key});

  @override
  State<InstitutionsHubScreen> createState() => _InstitutionsHubScreenState();
}

class _InstitutionsHubScreenState extends State<InstitutionsHubScreen> {
  bool _loading = true;
  bool _signedIn = false;
  String _state = 'PUBLIC';
  Map<String, dynamic>? _request;
  Map<String, dynamic>? _membership;
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
      final dio = createDio();
      final res = await dio.get('/institutions/me');

      final data = (res.data is Map<String, dynamic>)
          ? res.data as Map<String, dynamic>
          : <String, dynamic>{};

      if (!mounted) return;

      setState(() {
        _signedIn = data['signedIn'] == true;
        _state = (data['state'] ?? 'SIGNED_IN_NO_STANDING').toString();
        _request = data['request'] is Map
            ? Map<String, dynamic>.from(data['request'] as Map)
            : null;
        _membership = data['membership'] is Map
            ? Map<String, dynamic>.from(data['membership'] as Map)
            : null;
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

  Widget _statusCard() {
    String title;
    String text;

    switch (_state) {
      case 'PENDING_REQUEST':
        title = 'Status: Verification request pending';
        text =
            'Your request has been received and is under review. Institutional participation is governed manually, not granted automatically.';
        break;
      case 'VERIFIED_MEMBER':
        title = 'Status: Verified institutional member';
        text =
            'You are attached to a verified institution in Aura. Your participation carries both personal traceability and institutional standing.';
        break;
      case 'AUTHORIZED_SPEAKER':
        title = 'Status: Authorized institutional speaker';
        text =
            'You are authorized to issue institutional speech under your institution’s standing. Official participation remains attributable to you as a named person.';
        break;
      case 'SUSPENDED':
        title = 'Status: Institutional participation suspended';
        text =
            'Your current institutional standing is suspended. Institutional actions remain governed and may be restored only through review.';
        break;
      case 'REJECTED':
        title = 'Status: Request not approved';
        text =
            'Your last institutional request was not approved, or your institutional standing is no longer active.';
        break;
      case 'SIGNED_IN_NO_STANDING':
        title = 'Status: Signed in, no institutional standing yet';
        text =
            'You are signed in, but you do not yet hold an active institutional role in Aura.';
        break;
      default:
        title = 'Status: Not signed in';
        text =
            'This lane is open to institutions that want to participate under visible accountability, continuity of record, and named responsibility.';
    }

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AuraText.body.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AuraSpace.s8),
          Text(text, style: AuraText.body),
        ],
      ),
    );
  }

  Widget _requestDetailsCard() {
    if (_request == null) return const SizedBox.shrink();

    final organizationName = (_request!['organizationName'] ?? '').toString();
    final workEmail = (_request!['workEmail'] ?? '').toString();
    final roleTitle = (_request!['roleTitle'] ?? '').toString();
    final jurisdiction = (_request!['jurisdiction'] ?? '').toString();
    final status = (_request!['status'] ?? '').toString();
    final createdAt = (_request!['createdAt'] ?? '').toString();

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Request details', style: AuraText.body.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AuraSpace.s10),
          if (organizationName.isNotEmpty) Text('Organization: $organizationName', style: AuraText.body),
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

  Widget _membershipDetailsCard() {
    if (_membership == null) return const SizedBox.shrink();

    final role = (_membership!['role'] ?? '').toString();
    final title = (_membership!['title'] ?? '').toString();
    final canSpeakOfficially = _membership!['canSpeakOfficially'] == true;
    final institution = _membership!['institution'] is Map
        ? Map<String, dynamic>.from(_membership!['institution'] as Map)
        : <String, dynamic>{};

    final institutionName = (institution['name'] ?? '').toString();
    final institutionStatus = (institution['status'] ?? '').toString();
    final jurisdiction = (institution['jurisdiction'] ?? '').toString();
    final websiteUrl = (institution['websiteUrl'] ?? '').toString();

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Institutional standing', style: AuraText.body.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AuraSpace.s10),
          if (institutionName.isNotEmpty) Text('Institution: $institutionName', style: AuraText.body),
          if (institutionStatus.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s6),
            Text('Institution status: $institutionStatus', style: AuraText.body),
          ],
          if (role.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s6),
            Text('Your role: $role', style: AuraText.body),
          ],
          if (title.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s6),
            Text('Title: $title', style: AuraText.body),
          ],
          const SizedBox(height: AuraSpace.s6),
          Text(
            'Official institutional speech: ${canSpeakOfficially ? "Authorized" : "Not authorized"}',
            style: AuraText.body,
          ),
          if (jurisdiction.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s6),
            Text('Jurisdiction: $jurisdiction', style: AuraText.body),
          ],
          if (websiteUrl.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s6),
            Text('Website: $websiteUrl', style: AuraText.body),
          ],
        ],
      ),
    );
  }

  Widget _actionsCard(BuildContext context) {
    if (!_signedIn) {
      return Row(
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
      );
    }

    if (_state == 'PENDING_REQUEST') {
      return Row(
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
      );
    }

    if (_state == 'VERIFIED_MEMBER' || _state == 'AUTHORIZED_SPEAKER') {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => context.go('/home'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AuraSpace.s14,
                      vertical: AuraSpace.s12,
                    ),
                  ),
                  child: Text(
                    'Continue to Aura',
                    style: AuraText.body.copyWith(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          if (_state == 'AUTHORIZED_SPEAKER') ...[
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
      );
    }

    if (_state == 'REJECTED' || _state == 'SUSPENDED') {
      return Row(
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
      );
    }

    return Row(
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
    );
  }

  Widget _expectationsCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Doc.h('What institutions can do here'),
        Doc.bullets([
          'Maintain a verified profile with identity integrity',
          'Participate through real named persons, not faceless brand voice',
          'Publish posts and responses under governed institutional standing',
          'Issue clarifications, corrections, and commitments that remain readable over time',
        ]),
        Doc.h('What institutions cannot do here'),
        Doc.bullets([
          'Purchase reach or visibility',
          'Use follower totals or engagement counts as public leverage',
          'Flood the system with PR volume',
          'Hide institutional speech behind anonymous abstraction',
        ]),
        Doc.callout(
          'Verified participation is a responsibility. It is not a privilege lane.',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return DocumentScaffold(
      title: 'Institutions',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Doc.title('Institutions'),
          const SizedBox(height: 10),
          Doc.meta('Verified participation, not branding.'),
          Doc.lede(
            'Institutional participation in Aura is carried by real named persons and governed by visible responsibility.',
          ),
          const SizedBox(height: AuraSpace.s12),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else ...[
            if (_error != null) ...[
              AuraCard(
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
              ),
              const SizedBox(height: AuraSpace.s12),
            ],
            _statusCard(),
            const SizedBox(height: AuraSpace.s12),
            if (_request != null) ...[
              _requestDetailsCard(),
              const SizedBox(height: AuraSpace.s12),
            ],
            if (_membership != null) ...[
              _membershipDetailsCard(),
              const SizedBox(height: AuraSpace.s12),
            ],
            _actionsCard(context),
            const SizedBox(height: AuraSpace.s12),
            Doc.p(
              'This lane exists because alignment requires both public witness and accountable institutional speech. Distortion begins when either side has no structured place to stand.',
            ),
            _expectationsCard(),
          ],
        ],
      ),
    );
  }
}