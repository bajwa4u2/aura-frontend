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
    _loadContext();
  }

  Future<void> _loadContext() async {
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

      final institution =
          _asMap(data['institution']).isNotEmpty
              ? _asMap(data['institution'])
              : _asMap(membership['institution']);

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

      setState(() {
        _error = 'Could not load institution context.';
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'Could not load institution context.';
        _loading = false;
      });
    }
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return {};
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

  Future<void> _enterInstitution() async {
    if (_redirecting) return;

    setState(() {
      _redirecting = true;
    });

    if (!mounted) return;
    context.go('/institution/dashboard');
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
            'Could not load institution entry.',
            style: AuraText.body.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AuraSpace.s8),
          Text(_error ?? '', style: AuraText.body),
          const SizedBox(height: AuraSpace.s12),
          FilledButton(
            onPressed: _loadContext,
            child: Text(
              'Try again',
              style: AuraText.body.copyWith(color: Colors.white),
            ),
          )
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
              'No institutional standing is attached to this account.',
              style: AuraText.body,
            ),
            const SizedBox(height: AuraSpace.s12),
            FilledButton(
              onPressed: () {
                context.go('/institution/request-verification');
              },
              child: Text(
                'Request institutional verification',
                style: AuraText.body.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }

    final institutionName = _value(_institution?['name']);
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
            children: [
              if (role.isNotEmpty) Chip(label: Text('Role: $role')),
              Chip(
                label: Text(
                  canSpeakOfficially
                      ? 'Official speech: Authorized'
                      : 'Official speech: Not authorized',
                ),
              ),
            ],
          ),
          if (title.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s12),
            Text('Your institutional title: $title', style: AuraText.body),
          ],
          const SizedBox(height: AuraSpace.s12),
          FilledButton(
            onPressed: _redirecting ? null : _enterInstitution,
            child: Text(
              'Enter institutional space',
              style: AuraText.body.copyWith(color: Colors.white),
            ),
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
                'Institution access',
                style: _headlineStyle(context),
              ),
              const SizedBox(height: AuraSpace.s8),
              Text(
                'Enter Aura carrying institutional standing.',
                style: AuraText.body,
              ),
            ],
          ),
        ),
        const SizedBox(height: AuraSpace.s12),
        _institutionCard(context),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return DocumentScaffold(
      title: 'Institution access',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Doc.title('Institution access'),
          const SizedBox(height: 10),
          Doc.meta('Verified institutional participation.'),
          Doc.lede(
            'Institutional presence in Aura requires verified standing.',
          ),
          const SizedBox(height: AuraSpace.s12),
          _body(context),
        ],
      ),
    );
  }
}