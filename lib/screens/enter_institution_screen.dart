import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_providers.dart';
import '../core/auth/session_providers.dart';
import '../core/net/dio_provider.dart';
import '../core/ui/aura_card.dart';
import '../core/ui/aura_space.dart';
import '../core/ui/aura_text.dart';
import '../core/ui/document_scaffold.dart';

class EnterInstitutionScreen extends ConsumerStatefulWidget {
  const EnterInstitutionScreen({super.key});

  @override
  ConsumerState<EnterInstitutionScreen> createState() =>
      _EnterInstitutionScreenState();
}

class _EnterInstitutionScreenState
    extends ConsumerState<EnterInstitutionScreen> {
  bool _loading = true;
  bool _redirecting = false;
  String? _error;

  bool _signedIn = false;
  String _state = 'PUBLIC';

  Map<String, dynamic>? _institution;
  Map<String, dynamic>? _membership;

  @override
  void initState() {
    super.initState();
    _loadContextOptions();
  }

  Future<void> _loadContextOptions() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final authStatus = ref.read(authStatusProvider);

      if (authStatus == AuthStatus.unauthed) {
        if (!mounted) return;
        context.go('/login?redirect=${Uri.encodeComponent('/enter-institution')}');
        return;
      }

      final dio = ref.read(dioProvider);
      final res = await dio.get('/institutions/me');

      final data = _asMap(res.data);
      final membership = _asMap(data['membership']);

      final topInstitution = _asMap(data['institution']);
      final membershipInstitution = _asMap(membership['institution']);
      final institution =
          topInstitution.isNotEmpty ? topInstitution : membershipInstitution;

      if (!mounted) return;

      setState(() {
        _signedIn = data['signedIn'] == true;
        _state = (data['state'] ?? 'SIGNED_IN_NO_STANDING').toString();
        _membership = membership.isNotEmpty ? membership : null;
        _institution = institution.isNotEmpty ? institution : null;
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;

      if (e.response?.statusCode == 401) {
        context.go('/login?redirect=${Uri.encodeComponent('/enter-institution')}');
        return;
      }

      String message = 'Could not load your institution entry options.';
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
        _error = 'Could not load your institution entry options.';
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
      _signedIn &&
      (_state == 'VERIFIED_MEMBER' || _state == 'AUTHORIZED_SPEAKER') &&
      _institution != null &&
      _membership != null;

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

  Future<void> _enterPersonal() async {
    if (_redirecting) return;

    setState(() {
      _redirecting = true;
    });

    if (!mounted) return;
    context.go('/home');
  }

  Future<void> _enterInstitution() async {
    if (_redirecting) return;

    setState(() {
      _redirecting = true;
    });

    if (!mounted) return;
    context.go('/institutions');
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
            'Could not load your institution entry options.',
            style: AuraText.body.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AuraSpace.s8),
          Text(_error ?? 'Unknown error.', style: AuraText.body),
          const SizedBox(height: AuraSpace.s12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _loadContextOptions,
                  child: Text('Try again', style: AuraText.body),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _personalCard() {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Continue as yourself',
            style: AuraText.body.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AuraSpace.s8),
          Text(
            'Enter Aura in your personal capacity. Your writing, correspondence, and profile remain your own.',
            style: AuraText.body,
          ),
          const SizedBox(height: AuraSpace.s12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _redirecting ? null : _enterPersonal,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AuraSpace.s14,
                      vertical: AuraSpace.s12,
                    ),
                  ),
                  child: Text(
                    'Enter personal space',
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

  Widget _institutionCard(BuildContext context) {
    if (!_hasInstitutionStanding) {
      return AuraCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Institutional standing',
              style: AuraText.body.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AuraSpace.s8),
            Text(
              'No active institutional context is attached to this account right now.',
              style: AuraText.body,
            ),
          ],
        ),
      );
    }

    final institutionName = _value(_institution?['name']);
    final institutionStatus = _value(_institution?['status']);
    final slug = _value(_institution?['slug']);
    final role = _value(_membership?['role']);
    final title = _value(_membership?['title']);
    final canSpeakOfficially = _membership?['canSpeakOfficially'] == true;

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enter as institution',
            style: AuraText.body.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AuraSpace.s8),
          Text(
            institutionName.isNotEmpty ? institutionName : 'Verified institution',
            style: _headlineStyle(context).copyWith(fontSize: 26),
          ),
          const SizedBox(height: AuraSpace.s10),
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
          if (title.isNotEmpty || slug.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s12),
            if (title.isNotEmpty)
              Text('Your institutional title: $title', style: AuraText.body),
            if (slug.isNotEmpty) ...[
              const SizedBox(height: AuraSpace.s6),
              Text('Institution slug: $slug', style: AuraText.body),
            ],
          ],
          const SizedBox(height: AuraSpace.s12),
          Text(
            'Enter Aura in institutional capacity. Your actions remain personally attributable while being carried under institutional standing.',
            style: AuraText.body,
          ),
          const SizedBox(height: AuraSpace.s12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _redirecting ? null : _enterInstitution,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AuraSpace.s14,
                      vertical: AuraSpace.s12,
                    ),
                  ),
                  child: Text(
                    'Enter institutional space',
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

  Widget _body(BuildContext context) {
    if (_loading) return _loadingView();
    if (_error != null) return _errorView();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AuraCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose how you want to enter Aura',
                style: _headlineStyle(context),
              ),
              const SizedBox(height: AuraSpace.s8),
              Text(
                'A person signs in once. Aura then makes visible the role or standing that person carries.',
                style: AuraText.body,
              ),
            ],
          ),
        ),
        const SizedBox(height: AuraSpace.s12),
        _personalCard(),
        const SizedBox(height: AuraSpace.s12),
        _institutionCard(context),
        const SizedBox(height: AuraSpace.s12),
        Doc.p(
          'Institutions do not speak on their own. People speak while carrying institutional responsibility. This entry point keeps that distinction clear.',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return DocumentScaffold(
      title: 'Enter institution',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Doc.title('Enter institution'),
          const SizedBox(height: 10),
          Doc.meta('One identity, distinct accountable contexts.'),
          Doc.lede(
            'Sign in as a person, then enter Aura in the role you are carrying right now.',
          ),
          const SizedBox(height: AuraSpace.s12),
          _body(context),
        ],
      ),
    );
  }
}