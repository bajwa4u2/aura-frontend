import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_providers.dart';
import '../core/auth/session_providers.dart';
import '../core/institutions/institution_access_provider.dart';
import '../core/net/dio_provider.dart';
import '../core/ui/aura_platform_components.dart';
import '../core/ui/aura_radius.dart';
import '../core/ui/aura_space.dart';
import '../core/ui/aura_surface.dart';
import '../core/ui/aura_text.dart';
import '../core/ui/document_scaffold.dart';

const String _institutionDashboardRoute = '/institution/dashboard';
const String _institutionCreateRoute = '/institution/create';

class InstitutionSignInScreen extends ConsumerStatefulWidget {
  const InstitutionSignInScreen({super.key});

  @override
  ConsumerState<InstitutionSignInScreen> createState() =>
      _InstitutionSignInScreenState();
}

class _InstitutionSignInScreenState
    extends ConsumerState<InstitutionSignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _submitting = false;
  String? _statusMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }

  String _readAccessToken(Map<String, dynamic> outer) {
    final direct = (outer['accessToken'] ?? '').toString().trim();
    if (direct.isNotEmpty) return direct;

    final data = outer['data'];
    if (data is Map) {
      final nested = Map<String, dynamic>.from(data);
      final token = (nested['accessToken'] ?? '').toString().trim();
      if (token.isNotEmpty) return token;
    }

    return '';
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;
    if (_submitting) return;

    setState(() {
      _submitting = true;
      _statusMessage = null;
    });

    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;

    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post(
        '/auth/institution/login',
        data: {
          'email': email,
          'password': password,
        },
      );

      final data = _asMap(res.data);
      final accessToken = _readAccessToken(data);

      if (accessToken.isEmpty) {
        throw Exception('Institution access token was not returned.');
      }

      await ref.read(tokenStoreProvider).setSession(accessToken: accessToken);
      ref.invalidate(authMeDataProvider);
      ref.invalidate(authStatusProvider);
      ref.invalidate(emailVerifiedProvider);
      ref.invalidate(institutionAccessProvider);

      // Wait for institution access to confirm before navigating.
      // This prevents the router from reading stale AsyncData(state: none)
      // and immediately bouncing back to /enter-institution.
      final access = await ref.read(institutionAccessProvider.future);

      if (!mounted) return;
      if (!access.hasAccess) {
        throw Exception('Institution access could not be confirmed. Please try again.');
      }
      context.go(_institutionDashboardRoute);
    } on DioException catch (e) {
      String message = 'Institution sign in failed.';

      final data = e.response?.data;
      if (data is Map && data['message'] is String) {
        message = data['message'] as String;
      }

      if (!mounted) return;
      setState(() {
        _submitting = false;
        _statusMessage = message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _statusMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DocumentScaffold(
      title: 'Institution sign in',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Doc.title('Institution sign in'),
          const SizedBox(height: 10),
          Doc.meta('Private institutional access.'),
          const SizedBox(height: AuraSpace.s16),
          if (_statusMessage != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AuraSpace.s12),
              decoration: BoxDecoration(
                color: AuraSurface.dangerBg,
                border: Border.all(color: AuraSurface.dangerInk.withValues(alpha: 0.35)),
                borderRadius: BorderRadius.circular(AuraRadius.md),
              ),
              child: Text(_statusMessage!, style: AuraText.body.copyWith(color: AuraSurface.dangerInk)),
            ),
            const SizedBox(height: AuraSpace.s12),
          ],
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AuraInput(
                  controller: _emailController,
                  label: 'Institution email',
                  hint: 'name@institution.org',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  prefixIcon: const Icon(Icons.apartment_outlined),
                  validator: (value) {
                    final v = (value ?? '').trim();
                    if (v.isEmpty) return 'Institution email is required';
                    if (!v.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: AuraSpace.s10),
                AuraInput(
                  controller: _passwordController,
                  label: 'Password',
                  hint: 'Enter password',
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  prefixIcon: const Icon(Icons.lock_outline),
                  validator: (value) {
                    final v = value ?? '';
                    if (v.isEmpty) return 'Password is required';
                    if (v.length < 8) return 'Minimum 8 characters';
                    return null;
                  },
                ),
                const SizedBox(height: AuraSpace.s16),
                SizedBox(
                  width: double.infinity,
                  child: AuraPrimaryButton(
                    label: _submitting ? 'Signing in…' : 'Institution sign in',
                    onPressed: _submitting ? null : _submit,
                    icon: Icons.arrow_forward_rounded,
                  ),
                ),
                const SizedBox(height: AuraSpace.s10),
                AuraGhostButton(
                  label: 'Create institutional account',
                  onPressed: _submitting ? null : () => context.go(_institutionCreateRoute),
                  icon: Icons.apartment_outlined,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}