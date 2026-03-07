import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_providers.dart';
import '../core/auth/session_providers.dart';
import '../core/net/dio_provider.dart';
import '../core/ui/aura_space.dart';
import '../core/ui/aura_text.dart';
import '../core/ui/document_scaffold.dart';

const String _institutionDashboardRoute = '/institution/dashboard';

class InstitutionSignInScreen extends ConsumerStatefulWidget {
  const InstitutionSignInScreen({super.key});

  @override
  ConsumerState<InstitutionSignInScreen> createState() =>
      _InstitutionSignInScreenState();
}

class _InstitutionSignInScreenState
    extends ConsumerState<InstitutionSignInScreen> {
  bool _checking = true;
  bool _redirecting = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInstitutionAccess();
    });
  }

  Future<void> _checkInstitutionAccess() async {
    if (!mounted) return;

    setState(() {
      _checking = true;
      _statusMessage = null;
    });

    try {
      final authStatus = ref.read(authStatusProvider);

      if (authStatus == AuthStatus.loading) {
        if (!mounted) return;
        setState(() {
          _checking = false;
          _statusMessage = 'Checking your session...';
        });
        return;
      }

      if (authStatus == AuthStatus.unauthed) {
        if (!mounted) return;
        setState(() {
          _checking = false;
          _statusMessage = null;
        });
        return;
      }

      final verifiedAsync = ref.read(emailVerifiedProvider);
      final verified = verifiedAsync.value ?? false;

      if (!verified) {
        if (!mounted) return;
        setState(() {
          _checking = false;
          _statusMessage =
              'Your account is signed in, but email verification is still pending.';
        });
        return;
      }

      final dio = ref.read(dioProvider);
      final res = await dio.get('/institutions/me');
      final data = _asMap(res.data);

      final signedIn = data['signedIn'] == true;
      final state = '${data['state'] ?? ''}'.trim().toUpperCase();

      final institution = _asMap(data['institution']);
      final membership = _asMap(data['membership']);
      final request = _asMap(data['request']);

      final hasInstitution = institution.isNotEmpty;
      final hasMembership = membership.isNotEmpty;
      final isApprovedRequest =
          '${request['status'] ?? ''}'.trim().toUpperCase() == 'APPROVED';

      final canEnter = signedIn &&
          (state == 'AUTHORIZED_SPEAKER' ||
              state == 'AUTHORIZED' ||
              hasInstitution ||
              hasMembership ||
              isApprovedRequest);

      if (canEnter) {
        _redirecting = true;
        if (!mounted) return;
        context.go(_institutionDashboardRoute);
        return;
      }

      if (!mounted) return;
      setState(() {
        _checking = false;
        _statusMessage =
            'Your account is active, but institution access is not yet available on this profile.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _statusMessage =
            'We could not confirm institution access right now. You can still sign in again or request verification.';
      });
    }
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }

  @override
  Widget build(BuildContext context) {
    final authStatus = ref.watch(authStatusProvider);
    final verifiedAsync = ref.watch(emailVerifiedProvider);
    final verified = verifiedAsync.value ?? false;

    final bool isSignedIn = authStatus == AuthStatus.authed;
    final bool canShowContinue = isSignedIn && verified;

    return DocumentScaffold(
      title: 'Institution sign in',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Doc.title('Institution sign in'),
          const SizedBox(height: 10),
          Doc.meta('For verified institutional participants.'),
          Doc.lede(
            'Institutions participate under the same visibility rules as citizens, but with a formal correction obligation.',
          ),
          const SizedBox(height: AuraSpace.s12),
          if (_checking || _redirecting) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AuraSpace.s12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black12),
                borderRadius: BorderRadius.circular(12),
                color: Colors.black.withValues(alpha: 0.03),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: AuraSpace.s10),
                  Expanded(
                    child: Text(
                      _redirecting
                          ? 'Institution access confirmed. Entering dashboard...'
                          : 'Checking institutional access...',
                      style: AuraText.body,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AuraSpace.s12),
          ],
          if (!_checking && _statusMessage != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AuraSpace.s12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(_statusMessage!, style: AuraText.body),
            ),
            const SizedBox(height: AuraSpace.s12),
          ],
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _redirecting
                      ? null
                      : () {
                          if (canShowContinue) {
                            context.go(_institutionDashboardRoute);
                            return;
                          }
                          context.go(
                            '/login?redirect=${Uri.encodeComponent(_institutionDashboardRoute)}',
                          );
                        },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AuraSpace.s14,
                      vertical: AuraSpace.s12,
                    ),
                  ),
                  child: Text(
                    canShowContinue ? 'Continue' : 'Sign in',
                    style: AuraText.body.copyWith(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: AuraSpace.s10),
              Expanded(
                child: OutlinedButton(
                  onPressed: _redirecting
                      ? null
                      : () => context.go('/institution/request-verification'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AuraSpace.s14,
                      vertical: AuraSpace.s12,
                    ),
                  ),
                  child: Text('Request verification', style: AuraText.body),
                ),
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s12),
          Doc.p(
            'If your institution is not yet verified, request verification first. Once approved, you can publish and respond under your institutional identity.',
          ),
        ],
      ),
    );
  }
}