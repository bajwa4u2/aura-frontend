import 'package:dio/dio.dart';
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
      ref.invalidate(authStatusProvider);
      ref.invalidate(emailVerifiedProvider);

      if (!mounted) return;
      context.go(_institutionDashboardRoute);
    } on DioException catch (e) {
      String message = 'Institution sign in failed.';

      final data = e.response?.data;
      if (data is Map && data['message'] is String) {
        message = data['message'] as String;
      } else if ((e.message ?? '').trim().isNotEmpty) {
        message = e.message!.trim();
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
    final authStatus = ref.watch(authStatusProvider);
    final isAlreadySignedIn = authStatus == AuthStatus.authed;

    return DocumentScaffold(
      title: 'Institution sign in',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Doc.title('Institution sign in'),
          const SizedBox(height: 10),
          Doc.meta('Private institutional entry.'),
          Doc.lede(
            'Use your institution account credentials here. This lane is separate from public member sign in and is reserved for approved institutional access.',
          ),
          const SizedBox(height: AuraSpace.s12),
          if (isAlreadySignedIn) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AuraSpace.s12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black12),
                borderRadius: BorderRadius.circular(12),
                color: Colors.black.withValues(alpha: 0.03),
              ),
              child: Text(
                'A session is already active in this browser. Signing in here will replace it with your institution session if the credentials are valid.',
                style: AuraText.body,
              ),
            ),
            const SizedBox(height: AuraSpace.s12),
          ],
          if (_statusMessage != null) ...[
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
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Institution email', style: AuraText.body),
                const SizedBox(height: AuraSpace.s8),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.username],
                  enabled: !_submitting,
                  decoration: const InputDecoration(
                    hintText: 'name@institution.org',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final v = (value ?? '').trim();
                    if (v.isEmpty) return 'Institution email is required';
                    if (!v.contains('@')) return 'Enter a valid institution email';
                    return null;
                  },
                ),
                const SizedBox(height: AuraSpace.s12),
                Text('Password', style: AuraText.body),
                const SizedBox(height: AuraSpace.s8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  enabled: !_submitting,
                  decoration: const InputDecoration(
                    hintText: 'Enter password',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final v = value ?? '';
                    if (v.isEmpty) return 'Password is required';
                    if (v.length < 8) return 'Password must be at least 8 characters';
                    return null;
                  },
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: AuraSpace.s12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: _submitting ? null : _submit,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AuraSpace.s14,
                            vertical: AuraSpace.s12,
                          ),
                        ),
                        child: Text(
                          _submitting ? 'Signing in...' : 'Institution sign in',
                          style: AuraText.body.copyWith(color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: AuraSpace.s10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _submitting
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
              ],
            ),
          ),
          const SizedBox(height: AuraSpace.s12),
          Doc.p(
            'Institution access requires approved institutional credentials. Public member accounts and institution accounts now enter through separate doors.',
          ),
        ],
      ),
    );
  }
}