import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key, this.redirectTo});

  final String? redirectTo;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _busy = false;
  String? _error;

  String _safeRedirect(String? r) {
    final v = (r ?? '').trim();
    if (v.isEmpty) return '/home';
    if (!v.startsWith('/')) return '/home';
    return v;
  }

  Map<String, dynamic> _unwrap(dynamic raw) {
    if (raw is! Map) return <String, dynamic>{};
    final root = Map<String, dynamic>.from(raw);

    dynamic inner = root['data'];
    if (inner is Map && inner['data'] is Map) inner = inner['data'];

    if (inner is Map) return Map<String, dynamic>.from(inner);
    return root;
  }

  String? _extractErrorCode(dynamic data) {
    if (data is! Map) return null;
    final err = data['error'];
    if (err is Map) {
      final code = err['code'];
      if (code is String && code.trim().isNotEmpty) return code.trim();
    }
    return null;
  }

  String? _extractErrorMessage(DioException e) {
    final d = e.response?.data;
    if (d is Map) {
      final err = d['error'];
      if (err is Map) {
        final m = err['message'];
        if (m != null) return m.toString();
      }
      final m2 = d['message'];
      if (m2 != null) return m2.toString();
    }
    return null;
  }

  Future<void> _login() async {
    if (_busy) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      if (!(_formKey.currentState?.validate() ?? false)) {
        setState(() => _busy = false);
        return;
      }

      final dio = ref.read(dioProvider);
      final email = _emailCtrl.text.trim();
      final password = _passwordCtrl.text;

      // For non-web, request refreshToken in body
      final options = !kIsWeb ? Options(headers: {'x-token-transport': 'body'}) : null;

      final res = await dio.post(
        '/auth/login',
        data: {'email': email, 'password': password},
        options: options,
      );

      final data = _unwrap(res.data);

      final accessToken = (data['accessToken'] ?? '').toString().trim();
      if (accessToken.isEmpty) {
        throw Exception('Missing accessToken');
      }

      final refreshTokenRaw = data['refreshToken'];
      final refreshToken = refreshTokenRaw == null ? null : refreshTokenRaw.toString().trim();

      // Persist tokens
      await ref.read(tokenStoreProvider).setTokens(
            accessToken: accessToken,
            refreshToken: (!kIsWeb && (refreshToken ?? '').isNotEmpty) ? refreshToken : null,
          );

      if (!mounted) return;
      context.go(_safeRedirect(widget.redirectTo));
    } on DioException catch (e) {
      final code = _extractErrorCode(e.response?.data);
      final status = e.response?.statusCode;

      if (code == 'EMAIL_NOT_VERIFIED' || status == 403) {
        final redirect = _safeRedirect(widget.redirectTo);
        if (!mounted) return;
        context.go('/verify-pending?redirect=${Uri.encodeComponent(redirect)}&email=${Uri.encodeComponent(_emailCtrl.text.trim())}');
        return;
      }

      final msg = _extractErrorMessage(e);
      setState(() {
        _error = msg ?? 'Login failed (${status ?? 'no status'}).';
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final redirect = _safeRedirect(widget.redirectTo);

    return AuraScaffold(
      title: 'Login',
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: AuraCard(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Welcome back', style: AuraText.title),
                  const SizedBox(height: AuraSpace.s10),
                  Text('Sign in to continue.', style: AuraText.body),

                  const SizedBox(height: AuraSpace.s16),

                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (v) {
                      final s = (v ?? '').trim();
                      if (s.isEmpty) return 'Email is required';
                      if (!s.contains('@')) return 'Enter a valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: AuraSpace.s12),
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                    validator: (v) {
                      if ((v ?? '').isEmpty) return 'Password is required';
                      return null;
                    },
                  ),

                  const SizedBox(height: AuraSpace.s10),

                  Row(
                    children: [
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => context.go('/forgot-password?redirect=${Uri.encodeComponent(redirect)}'),
                        child: const Text('Forgot password'),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => context.go('/verify-email?redirect=${Uri.encodeComponent(redirect)}&email=${Uri.encodeComponent(_emailCtrl.text.trim())}'),
                        child: const Text('Verify email'),
                      ),
                    ],
                  ),

                  const SizedBox(height: AuraSpace.s8),

                  if (_error != null) ...[
                    Text(_error!, style: AuraText.body.copyWith(color: Colors.red)),
                    const SizedBox(height: AuraSpace.s10),
                  ],

                  Wrap(
                    spacing: AuraSpace.s10,
                    runSpacing: AuraSpace.s10,
                    children: [
                      FilledButton(
                        onPressed: _busy ? null : _login,
                        child: Text(_busy ? 'Signing in…' : 'Login'),
                      ),
                      OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () {
                                final r = widget.redirectTo;
                                final q = (r == null || r.trim().isEmpty)
                                    ? ''
                                    : '?redirect=${Uri.encodeComponent(r)}';
                                context.go('/register$q');
                              },
                        child: const Text('Create account'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}