import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_providers.dart';
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
    if (raw is! Map) throw Exception('Unexpected response');

    final m = Map<String, dynamic>.from(raw);

    // Canonical envelope (Aura Contract v1)
    if (m['ok'] == true) {
      final inner = m['data'];
      if (inner is Map) return Map<String, dynamic>.from(inner);
      throw Exception('Unexpected response: ok=true but data is not a map');
    }

    // Legacy fallback
    final inner = m['data'];
    if (inner is Map) return Map<String, dynamic>.from(inner);

    return m;
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
      final status = e.response?.statusCode;
      final msg = e.response?.data is Map
          ? (e.response?.data['error']?['message'] ?? e.response?.data['message'])
          : null;

      setState(() {
        _error = msg?.toString() ?? 'Login failed (${status ?? 'no status'}).';
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

                  const SizedBox(height: AuraSpace.s14),

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
                                final q = (r == null || r.trim().isEmpty) ? '' : '?redirect=${Uri.encodeComponent(r)}';
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
