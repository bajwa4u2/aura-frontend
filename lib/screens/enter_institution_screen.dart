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

const String _institutionDashboardRoute = '/institution/dashboard';
const String _institutionCreateRoute = '/institution/create';
const String _institutionSignInRoute = '/institution/sign-in';

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

  Map<String, dynamic>? _request;
  Map<String, dynamic>? _institution;
  Map<String, dynamic>? _membership;

  @override
  void initState() {
    super.initState();
    _loadInstitutionContext();
  }

  Future<void> _loadInstitutionContext() async {
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

      if (_canEnterInstitutionSpace && mounted) {
        context.go(_institutionDashboardRoute);
      }
    } on DioException catch (e) {
      if (!mounted) return;

      if (e.response?.statusCode == 401) {
        context.go('/login?redirect=${Uri.encodeComponent('/enter-institution')}');
        return;
      }

      String message = 'Could not load institution access.';
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
        _error = 'Could not load institution access.';
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

  bool get _canEnterInstitutionSpace =>
      _signedIn &&
      (_state == 'PENDING_REQUEST' ||
          _state == 'VERIFIED_MEMBER' ||
          _state == 'AUTHORIZED_SPEAKER');

  bool get _isPendingRequest => _state == 'PENDING_REQUEST';

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

  Future<void> _enterInstitution() async {
    if (_redirecting) return;

    setState(() {
      _redirecting = true;
    });

    if (!mounted) return;
    context.go(_institutionDashboardRoute);
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
            'Could not load institution access.',
            style: AuraText.body.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AuraSpace.s8),
          Text(_error ?? 'Unknown error.', style: AuraText.body),
          const SizedBox(height: AuraSpace.s12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _loadInstitutionContext,
                  child: Text('Try again', style: AuraText.body),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _noStandingCard(BuildContext context) {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Institution access',
            style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AuraSpace.s8),
          Text(
            'This account does not currently carry institutional standing inside Aura.',
            style: AuraText.body,
          ),
          const SizedBox(height: AuraSpace.s12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => context.go(_institutionCreateRoute),
                  child: Text(
                    'Create institutional account',
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
                  onPressed: () => context.go(_institutionSignInRoute),
                  child: Text('Institution sign in', style: AuraText.body),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _institutionCard(BuildContext context) {
    if (!_canEnterInstitutionSpace) {
      return _noStandingCard(context);
    }

    final institutionName = _value(_institution?['name']).isNotEmpty
        ? _value(_institution?['name'])
        : _value(_request?['organizationName']).isNotEmpty
            ? _value(_request?['organizationName'])
            : 'Institution account';

    final institutionStatus = _value(_institution?['status']);
    final requestStatus = _value(_request?['status']);
    final role = _value(_membership?['role']);
    final title = _value(_membership?['title']).isNotEmpty
        ? _value(_membership?['title'])
        : _value(_request?['roleTitle']);
    final canSpeakOfficially = _membership?['canSpeakOfficially'] == true;

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Institution access',
            style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AuraSpace.s8),
          Text(
            institutionName,
            style: _headlineStyle(context).copyWith(fontSize: 26),
          ),
          const SizedBox(height: AuraSpace.s10),
          Wrap(
            spacing: AuraSpace.s8,
            runSpacing: AuraSpace.s8,
            children: [
              if (_isPendingRequest)
                _statusChip('Standing: Pending review')
              else if (institutionStatus.isNotEmpty)
                _statusChip('Standing: $institutionStatus'),
              if (requestStatus.isNotEmpty && _isPendingRequest)
                _statusChip('Request: $requestStatus'),
              if (role.isNotEmpty) _statusChip('Role: $role'),
              if (_isPendingRequest)
                _statusChip('Tools: Restricted')
              else
                _statusChip(
                  canSpeakOfficially
                      ? 'Official speech: Authorized'
                      : 'Official speech: Not authorized',
                ),
            ],
          ),
          if (title.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s12),
            Text('Institutional title: $title', style: AuraText.body),
          ],
          const SizedBox(height: AuraSpace.s12),
          Text(
            _isPendingRequest
                ? 'Your institution is inside Aura and awaiting review. You can enter the institutional dashboard now. Publishing and operational tools remain restricted until standing is approved.'
                : 'This account carries institutional standing inside Aura and may enter the institutional dashboard.',
            style: AuraText.body,
          ),
          const SizedBox(height: AuraSpace.s12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _redirecting ? null : _enterInstitution,
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
          Doc.meta('Private institutional entry.'),
          const SizedBox(height: AuraSpace.s12),
          _body(context),
        ],
      ),
    );
  }
}